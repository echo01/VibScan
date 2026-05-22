import 'dart:async';
import 'dart:math';

import '../models/dashboard_metric.dart';
import '../models/device_node.dart';
import '../models/fft_point.dart';
import '../models/fft_spectrum.dart';
import '../models/mems_config.dart';
import '../models/mqtt_config.dart';
import '../models/mqtt_publish_summary.dart';
import '../models/mqtt_runtime_status.dart';
import '../models/network_config.dart';
import '../models/operate_config.dart';
import '../models/system_config.dart';
import '../models/wifi_network.dart';
import 'viot_repository.dart';

class MockViotRepository implements ViotRepository {
  MockViotRepository();

  final Random _random = Random();

  @override
  Future<List<DeviceNode>> discoverDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    return [
      DeviceNode(
        id: 'esp32-viot-a1b2c3',
        name: 'esp32-viot-a1b2c3',
        ip: '192.168.1.45',
        hostname: 'esp32-viot-a1b2c3.local',
        port: 80,
        isOnline: true,
        lastSeen: now,
        rssi: -48,
        source: 'mdns',
      ),
      DeviceNode(
        id: 'factory-node-01',
        name: 'factory-node-01',
        ip: '192.168.1.46',
        hostname: 'factory-node-01.local',
        port: 80,
        isOnline: true,
        lastSeen: now.subtract(const Duration(seconds: 4)),
        rssi: -52,
        source: 'udp',
      ),
      DeviceNode(
        id: 'viot-sensor-03',
        name: 'viot-sensor-03',
        ip: '192.168.1.48',
        hostname: 'viot-sensor-03.local',
        port: 80,
        isOnline: false,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        rssi: -84,
        source: 'mdns',
      ),
    ];
  }

  @override
  Future<List<DashboardMetric>> fetchDashboard(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      DashboardMetric(
        key: 'rms',
        label: 'RMS',
        value: 0.020 + _random.nextDouble() * 0.02,
        unit: 'g',
        displayOrder: 0,
      ),
      DashboardMetric(
        key: 'velocity',
        label: 'Velocity',
        value: 1.1 + _random.nextDouble() * 0.4,
        unit: 'mm/s RMS',
        displayOrder: 1,
      ),
      DashboardMetric(
        key: 'peak',
        label: 'Peak',
        value: 0.040 + _random.nextDouble() * 0.03,
        unit: 'g',
        displayOrder: 2,
      ),
      DashboardMetric(
        key: 'frequency',
        label: 'Frequency',
        value: 28.0 + _random.nextDouble() * 3,
        unit: 'Hz',
        displayOrder: 3,
      ),
      DashboardMetric(
        key: 'displacement',
        label: 'Displacement',
        value: 11.0 + _random.nextDouble() * 2,
        unit: 'um',
        displayOrder: 4,
      ),
      DashboardMetric(
        key: 'battery',
        label: 'Battery',
        value: 3.8 + _random.nextDouble() * 0.3,
        unit: 'V',
        displayOrder: 5,
      ),
      DashboardMetric(
        key: 'rssi',
        label: 'RSSI',
        value: node.rssi.toDouble(),
        unit: 'dBm',
        displayOrder: 6,
      ),
      DashboardMetric(
        key: 'uptime',
        label: 'Uptime',
        value: 8133,
        unit: 's',
        displayOrder: 7,
      ),
    ];
  }

  @override
  Future<FftSpectrum> fetchFft(DeviceNode node, String axis) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final data = List<FftPoint>.generate(80, (index) {
      final frequency = index * 12.5;
      final peak = exp(-pow((frequency - 300) / 90, 2).toDouble()) * 0.04;
      final ripple =
          (_random.nextDouble() * 0.004) + (sin(index / 4) + 1.2) * 0.0015;
      return FftPoint(frequency: frequency, amplitude: 0.0005 + peak + ripple);
    });

    return FftSpectrum(
      axis: axis.toUpperCase(),
      sampleRate: 1000,
      pointCount: 512,
      peakFrequency: 29.6,
      maxAmplitude: 0.056,
      data: data,
    );
  }

  @override
  Future<MemsConfig> fetchMemsConfig(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const MemsConfig(
      rateHz: 800,
      rangeG: 16,
      offsetX: 0,
      offsetY: 0,
      offsetZ: 0,
      intThresholdMg: 150,
      intEnabled: true,
      minRmsG: 0.02,
      minPeakG: 0.05,
      noiseFloorDb: -40,
      deadbandG: 0.01,
      minFreqHz: 10,
      maxFreqHz: 400,
      sleepIntervalSec: 3600,
    );
  }

  @override
  Future<MqttConfig> fetchMqttConfig(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const MqttConfig(
      broker: 'broker.hivemq.com',
      port: 1883,
      clientId: 'ESP32_VIOT',
      username: '',
      password: '',
      topicPublish: 'viot/vibration',
      topicFftX: 'viot/vibration/fft/x',
      topicFftY: 'viot/vibration/fft/y',
      topicFftZ: 'viot/vibration/fft/z',
      topicSubscribe: 'viot/config',
      topicAck: 'viot/config/ack',
      topicResult: 'viot/config/result',
      publishIntervalSec: 60,
      useTls: false,
      protocol: 'mqtt',
      status: 'CONNECTED',
    );
  }

  @override
  Future<MqttPublishSummary> fetchMqttPublishSummary(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const MqttPublishSummary(
      connected: true,
      status: 'CONNECTED',
      lastResult: 'Success',
      lastSentAgoSec: 21,
      nextSendInSec: 36,
      publishCount: 19,
      tlsConnectState: 'Idle',
      subscribeRxCount: 4,
      lastRxAgoSec: 364,
      lastRxBytes: 0,
      mainPayloadBytes: 400,
    );
  }

  @override
  Future<MqttRuntimeStatus> fetchMqttRuntimeStatus(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const MqttRuntimeStatus(
      connected: true,
      status: 'CONNECTED',
      broker: 'broker.hivemq.com',
      useTls: false,
      retryLimited: false,
      connectFailures: 0,
      connectFailureLimit: 5,
      retryLimitedLoops: 0,
      softRecoveryAttempted: false,
      heapRebootRequired: false,
      recoveryMessage: '',
      retryAction: '/api/mqtt_restart',
    );
  }

  @override
  Future<NetworkConfig> fetchNetworkConfig(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return NetworkConfig(
      ssid: 'Office_WiFi',
      password: '',
      apEnabled: true,
      apSsid: 'VIOT_A1B2',
      apPassword: '12345678',
      staUseStaticIp: false,
      staStaticIp: node.ip,
      staGateway: '192.168.1.1',
      staSubnet: '255.255.255.0',
      staDns1: '8.8.8.8',
      staDns2: '1.1.1.1',
    );
  }

  @override
  Future<OperateConfig> fetchOperateConfig(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const OperateConfig(
      publishIntervalSec: 60,
      wakeupIntThresholdMg: 250,
      wakeupIntEnabled: true,
      wakeupTimerSec: 3600,
      publishOnVibrationTrigger: false,
      publishVibrationThresholdMmS: 1.2,
      logEnabled: true,
      debugLogWifi: false,
      debugLogMqtt: false,
      debugLogMems: false,
      debugLogPower: false,
      debugLogWeb: false,
      debugLogBattery: false,
      debugLogOperate: false,
      debugLogSystem: false,
    );
  }

  @override
  Future<void> saveMemsConfig(DeviceNode node, MemsConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<Map<String, dynamic>> fetchMemsCalibration(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const {
      'calibrated': true,
      'auto_noise_gate': true,
      'margin_factor': 2.0,
      'baseline_rms': {'x': 0.00634, 'y': 0.00626, 'z': 0.00956},
      'baseline_peak': {'x': 0.02817, 'y': 0.03646, 'z': 0.04693},
    };
  }

  @override
  Future<Map<String, dynamic>> calibrateMems(
    DeviceNode node, {
    required int durationSec,
    required double marginFactor,
    required bool apply,
  }) async {
    await Future<void>.delayed(Duration(seconds: durationSec.clamp(1, 3)));
    return {
      'done': true,
      'success': true,
      'message': 'Calibration complete',
      'duration_sec': durationSec,
      'margin_factor': marginFactor,
      'applied': apply,
      'baseline_rms': {'x': 0.00634, 'y': 0.00626, 'z': 0.00956},
      'baseline_peak': {'x': 0.02817, 'y': 0.03646, 'z': 0.04693},
    };
  }

  @override
  Future<void> resetMemsCalibration(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> saveMqttConfig(DeviceNode node, MqttConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> saveNetworkConfig(DeviceNode node, NetworkConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> saveOperateConfig(DeviceNode node, OperateConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<SystemConfig> fetchSystemConfig(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const SystemConfig(logEnabled: true);
  }

  @override
  Future<void> saveSystemConfig(DeviceNode node, SystemConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> rebootNode(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> resetNode(DeviceNode node) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks(String sensorBaseUrl) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      WifiNetwork(ssid: 'Office_WiFi', security: 'WPA2', rssi: -44),
      WifiNetwork(ssid: 'Home_5G', security: 'WPA2', rssi: -55),
      WifiNetwork(ssid: 'Factory_2.4G', security: 'WPA2', rssi: -61),
      WifiNetwork(ssid: 'VIOT_Config_5G', security: 'WPA2', rssi: -72),
    ];
  }

  @override
  Future<void> submitNetworkConfig(
    String sensorBaseUrl,
    NetworkConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
