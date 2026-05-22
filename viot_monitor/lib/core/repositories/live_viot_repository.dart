import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../models/dashboard_metric.dart';
import '../models/device_node.dart';
import '../models/fft_spectrum.dart';
import '../models/mems_config.dart';
import '../models/mqtt_config.dart';
import '../models/mqtt_publish_summary.dart';
import '../models/mqtt_runtime_status.dart';
import '../models/network_config.dart';
import '../models/operate_config.dart';
import '../models/system_config.dart';
import '../models/wifi_network.dart';
import '../services/api_client.dart';
import '../services/discovery_service.dart';
import 'viot_repository.dart';

class LiveViotRepository implements ViotRepository {
  LiveViotRepository({
    required ApiClient apiClient,
    required DiscoveryService discoveryService,
  }) : _apiClient = apiClient,
       _discoveryService = discoveryService;

  final ApiClient _apiClient;
  final DiscoveryService _discoveryService;

  @override
  Future<List<DeviceNode>> discoverDevices() {
    return _discoverAndHydrate();
  }

  @override
  Future<List<DashboardMetric>> fetchDashboard(DeviceNode node) async {
    final data = await _apiClient.getJson(
      node.baseUrl,
      ApiPaths.dashboard,
      queryParameters: const {'keep_mqtt': 1},
    );
    final rawMetrics =
        (data is Map<String, dynamic> ? data['metrics'] : null)
            as List<dynamic>? ??
        (data is List ? data : const []);
    if (rawMetrics.isNotEmpty) {
      return rawMetrics
          .whereType<Map>()
          .map(
            (entry) =>
                DashboardMetric.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    }

    if (data is Map<String, dynamic>) {
      return _dashboardMetricsFromNodeMap(data);
    }

    return const [];
  }

  @override
  Future<FftSpectrum> fetchFft(DeviceNode node, String axis) async {
    const stepHz = 30;
    final normalizedAxis = axis.toLowerCase();
    final requestId =
        'http-fft-$normalizedAxis-${DateTime.now().millisecondsSinceEpoch}';
    var acceptAnyRequestId = false;

    try {
      await _apiClient.getJson(
        node.baseUrl,
        ApiPaths.fftSpectrum,
        queryParameters: {
          'axis': normalizedAxis,
          'step_hz': stepHz,
          'request_id': requestId,
        },
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != 409) {
        rethrow;
      }
      // A 409 means an FFT job is already active. Poll the current job status
      // so the UI can either render the result or show a clearer busy message.
      acceptAnyRequestId = true;
    }

    for (var attempt = 0; attempt < 30; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      final status = await _apiClient.getJson(node.baseUrl, ApiPaths.fftStatus);
      if (status is! Map<String, dynamic>) {
        continue;
      }

      final statusRequestId = (status['request_id'] ?? '').toString();
      if (!acceptAnyRequestId &&
          statusRequestId.isNotEmpty &&
          statusRequestId != requestId) {
        continue;
      }

      final statusAxis = (status['axis'] ?? '').toString().toLowerCase();
      if (acceptAnyRequestId &&
          statusAxis.isNotEmpty &&
          statusAxis != normalizedAxis) {
        throw StateError(
          'FFT is busy on axis ${statusAxis.toUpperCase()}. Try again after the current job finishes.',
        );
      }

      final done = _asBool(status['done'], fallback: false);
      if (!done) {
        continue;
      }

      final success = _asBool(status['success'], fallback: false);
      if (!success) {
        final message = (status['message'] ?? 'FFT calculation failed')
            .toString();
        throw StateError(message);
      }

      return FftSpectrum.fromDynamic(status, axis: axis);
    }

    throw TimeoutException('FFT status timeout');
  }

  @override
  Future<MemsConfig> fetchMemsConfig(DeviceNode node) async {
    final sections = await _fetchConfigSections(node);
    return MemsConfig.fromSections(
      adxl345: sections.adxl345,
      vibration: sections.vibration,
      power: sections.power,
    );
  }

  @override
  Future<MqttConfig> fetchMqttConfig(DeviceNode node) async {
    final sections = await _fetchConfigSections(node);
    return MqttConfig.fromJson(sections.mqtt);
  }

  @override
  Future<MqttPublishSummary> fetchMqttPublishSummary(DeviceNode node) async {
    final data = await _apiClient.getJson(
      node.baseUrl,
      ApiPaths.mqttPublishSummary,
      queryParameters: const {'keep_mqtt': 1},
    );
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected MQTT publish summary response format');
    }
    return MqttPublishSummary.fromJson(data);
  }

  @override
  Future<MqttRuntimeStatus> fetchMqttRuntimeStatus(DeviceNode node) async {
    final data = await _apiClient.getJson(node.baseUrl, ApiPaths.status);
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected status response format');
    }
    return MqttRuntimeStatus.fromJson(data);
  }

  @override
  Future<NetworkConfig> fetchNetworkConfig(DeviceNode node) async {
    final sections = await _fetchConfigSections(node);
    return NetworkConfig.fromJson(sections.wifi);
  }

  @override
  Future<OperateConfig> fetchOperateConfig(DeviceNode node) async {
    final sections = await _fetchConfigSections(node);
    return OperateConfig.fromJson(sections.operate);
  }

  @override
  Future<SystemConfig> fetchSystemConfig(DeviceNode node) async {
    final sections = await _fetchConfigSections(node);
    return SystemConfig.fromSections(
      power: sections.power,
      operate: sections.operate,
    );
  }

  @override
  Future<void> saveMemsConfig(DeviceNode node, MemsConfig config) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.memsConfig,
      body: config.toJson(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchMemsCalibration(DeviceNode node) async {
    final data = await _apiClient.getJson(
      node.baseUrl,
      ApiPaths.memsCalibration,
    );
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const {};
  }

  @override
  Future<Map<String, dynamic>> calibrateMems(
    DeviceNode node, {
    required int durationSec,
    required double marginFactor,
    required bool apply,
  }) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.memsCalibrate,
      body: {
        'duration_sec': durationSec.clamp(3, 60),
        'margin_factor': marginFactor,
        'apply': apply,
      },
    );

    for (var i = 0; i < 90; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final data = await _apiClient.getJson(
        node.baseUrl,
        ApiPaths.memsCalibrationStatus,
      );
      if (data is! Map<String, dynamic>) {
        continue;
      }
      final done = data['done'] == true;
      if (!done) {
        continue;
      }
      if (data['success'] == true) {
        return data;
      }
      final message = (data['message'] ?? 'MEMS calibration failed').toString();
      throw StateError(message);
    }

    throw TimeoutException('MEMS calibration timeout');
  }

  @override
  Future<void> resetMemsCalibration(DeviceNode node) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.memsCalibrationReset,
      body: const {},
    );
  }

  @override
  Future<void> saveMqttConfig(DeviceNode node, MqttConfig config) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.mqttConfig,
      body: config.toJson(),
    );
  }

  @override
  Future<void> saveNetworkConfig(DeviceNode node, NetworkConfig config) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.networkConfig,
      body: config.toJson(),
    );
  }

  @override
  Future<void> saveOperateConfig(DeviceNode node, OperateConfig config) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.operateConfig,
      body: config.toJson(),
    );
  }

  @override
  Future<void> saveSystemConfig(DeviceNode node, SystemConfig config) async {
    await _apiClient.postForm(
      node.baseUrl,
      ApiPaths.systemConfig,
      body: config.toJson(),
    );
  }

  @override
  Future<void> rebootNode(DeviceNode node) async {
    await _apiClient.postForm(node.baseUrl, ApiPaths.reboot, body: const {});
  }

  @override
  Future<void> resetNode(DeviceNode node) async {
    await _apiClient.postForm(node.baseUrl, ApiPaths.reset, body: const {});
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks(String sensorBaseUrl) async {
    try {
      await _apiClient.postForm(
        sensorBaseUrl,
        ApiPaths.scanSsidStart,
        body: {},
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 405) {
        return _scanWifiNetworksCompat(sensorBaseUrl);
      }
      if (statusCode != 409) {
        rethrow;
      }
    }

    for (var attempt = 0; attempt < 30; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      final data = await _apiClient.getJson(
        sensorBaseUrl,
        ApiPaths.scanSsidStatus,
      );
      if (data is! Map<String, dynamic>) {
        continue;
      }

      final done = _asBool(data['done'], fallback: false);
      if (!done) {
        continue;
      }

      final success = _asBool(data['success'], fallback: false);
      if (!success) {
        final message = (data['message'] ?? 'WiFi scan failed').toString();
        throw StateError(message);
      }

      return _wifiNetworksFromResponse(data);
    }

    return _scanWifiNetworksCompat(sensorBaseUrl);
  }

  @override
  Future<void> submitNetworkConfig(
    String sensorBaseUrl,
    NetworkConfig config,
  ) async {
    await _apiClient.postForm(
      sensorBaseUrl,
      ApiPaths.networkConfig,
      body: config.toJson(),
    );
  }

  Future<List<WifiNetwork>> _scanWifiNetworksCompat(
    String sensorBaseUrl,
  ) async {
    final data = await _apiClient.getJson(sensorBaseUrl, ApiPaths.scanSsid);
    return _wifiNetworksFromResponse(data);
  }

  List<WifiNetwork> _wifiNetworksFromResponse(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (entry) => WifiNetwork.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final rawList =
          (data['ssids'] ?? data['networks'] ?? data['items'])
              as List<dynamic>? ??
          const [];
      return rawList
          .whereType<Map>()
          .map(
            (entry) => WifiNetwork.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    }

    throw StateError('Unexpected WiFi scan response format');
  }

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = '$value'.toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
    return fallback;
  }

  List<DashboardMetric> _dashboardMetricsFromNodeMap(
    Map<String, dynamic> data,
  ) {
    final metrics = <DashboardMetric>[];

    void add({
      required String key,
      required String label,
      required dynamic value,
      required String unit,
    }) {
      if (value is! num) {
        return;
      }
      metrics.add(
        DashboardMetric(
          key: key,
          label: label,
          value: value.toDouble(),
          unit: unit,
          displayOrder: metrics.length,
        ),
      );
    }

    Map<String, dynamic> mapValue(String key) {
      final value = data[key];
      return value is Map<String, dynamic> ? value : const {};
    }

    final accel = mapValue('accel');
    final velocity = mapValue('velocity');
    final vibrationFreq = mapValue('vibration_freq');
    final orientation = mapValue('orientation');
    final displacement = mapValue('displacement');
    final memsTiming = mapValue('mems_timing');

    add(key: 'accel_x', label: 'Accel X', value: accel['x'], unit: 'g');
    add(key: 'accel_y', label: 'Accel Y', value: accel['y'], unit: 'g');
    add(key: 'accel_z', label: 'Accel Z', value: accel['z'], unit: 'g');
    add(
      key: 'velocity_x',
      label: 'Velocity X',
      value: velocity['x'],
      unit: 'mm/s',
    );
    add(
      key: 'velocity_y',
      label: 'Velocity Y',
      value: velocity['y'],
      unit: 'mm/s',
    );
    add(
      key: 'velocity_z',
      label: 'Velocity Z',
      value: velocity['z'],
      unit: 'mm/s',
    );
    add(
      key: 'freq_x',
      label: 'Frequency X',
      value: vibrationFreq['x'],
      unit: 'Hz',
    );
    add(
      key: 'freq_y',
      label: 'Frequency Y',
      value: vibrationFreq['y'],
      unit: 'Hz',
    );
    add(
      key: 'freq_z',
      label: 'Frequency Z',
      value: vibrationFreq['z'],
      unit: 'Hz',
    );
    add(
      key: 'disp_x',
      label: 'Displacement X',
      value: displacement['x_um'],
      unit: 'um',
    );
    add(
      key: 'disp_y',
      label: 'Displacement Y',
      value: displacement['y_um'],
      unit: 'um',
    );
    add(
      key: 'disp_z',
      label: 'Displacement Z',
      value: displacement['z_um'],
      unit: 'um',
    );
    add(key: 'pitch', label: 'Pitch', value: orientation['pitch'], unit: 'deg');
    add(key: 'roll', label: 'Roll', value: orientation['roll'], unit: 'deg');
    add(key: 'yaw', label: 'Yaw', value: orientation['yaw'], unit: 'deg');
    add(key: 'battery', label: 'Battery', value: data['battery'], unit: 'V');
    add(key: 'rssi', label: 'RSSI', value: data['rssi'], unit: 'dBm');
    add(
      key: 'effective_sample_rate_hz',
      label: 'Effective Sample Rate',
      value: memsTiming['effective_sample_rate_hz'],
      unit: 'Hz',
    );
    add(
      key: 'sample_read_us',
      label: 'Sample Read',
      value: memsTiming['avg_read_high_us'],
      unit: 'us',
    );
    add(
      key: 'sample_wait_us',
      label: 'Sample Wait',
      value: memsTiming['avg_wait_low_us'],
      unit: 'us',
    );

    return metrics;
  }

  Future<List<DeviceNode>> _discoverAndHydrate() async {
    final discovered = await _discoveryService.discover();
    final hydrated = await Future.wait(
      discovered.map((node) async {
        try {
          final data = await _apiClient.getJson(
            node.baseUrl,
            ApiPaths.discover,
          );
          if (data is Map<String, dynamic>) {
            return DeviceNode.fromJson({
              ...data,
              'source': node.source,
              'lastSeen': node.lastSeen.toIso8601String(),
              'isOnline': true,
            });
          }
        } catch (_) {
          // Keep the discovery result even if the HTTP enrichment step fails.
        }
        return node;
      }),
    );
    return hydrated..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<_ConfigSections> _fetchConfigSections(DeviceNode node) async {
    final data = await _apiClient.getJson(node.baseUrl, ApiPaths.config);
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected config response format');
    }

    Map<String, dynamic> section(String key) {
      final value = data[key];
      return value is Map<String, dynamic> ? value : const {};
    }

    return _ConfigSections(
      wifi: section('wifi'),
      mqtt: section('mqtt'),
      adxl345: section('adxl345'),
      vibration: section('vibration'),
      power: section('power'),
      operate: section('operate'),
    );
  }
}

class _ConfigSections {
  const _ConfigSections({
    required this.wifi,
    required this.mqtt,
    required this.adxl345,
    required this.vibration,
    required this.power,
    required this.operate,
  });

  final Map<String, dynamic> wifi;
  final Map<String, dynamic> mqtt;
  final Map<String, dynamic> adxl345;
  final Map<String, dynamic> vibration;
  final Map<String, dynamic> power;
  final Map<String, dynamic> operate;
}
