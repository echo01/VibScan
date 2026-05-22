import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_metric.dart';
import '../models/dashboard_sample.dart';
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
import '../repositories/live_viot_repository.dart';
import '../repositories/viot_repository.dart';
import '../services/api_client.dart';
import '../services/csv_export_service.dart';
import '../services/discovery_service.dart';
import '../services/mobile_wifi_service.dart';
import '../storage/local_storage_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return const CsvExportService();
});

final mobileWifiServiceProvider = Provider<MobileWifiService>((ref) {
  return const MobileWifiService();
});

final viotRepositoryProvider = Provider<ViotRepository>((ref) {
  return LiveViotRepository(
    apiClient: ref.watch(apiClientProvider),
    discoveryService: ref.watch(discoveryServiceProvider),
  );
});

final navigationIndexProvider = StateProvider<int>((ref) => 0);
final dashboardTabIndexProvider = StateProvider<int>((ref) => 0);

final sensorApBaseUrlProvider =
    StateNotifierProvider<SensorApBaseUrlNotifier, String>((ref) {
      final storage = ref.watch(localStorageServiceProvider);
      return SensorApBaseUrlNotifier(storage);
    });

final savedDevicesProvider =
    StateNotifierProvider<SavedDevicesNotifier, List<DeviceNode>>((ref) {
      final storage = ref.watch(localStorageServiceProvider);
      return SavedDevicesNotifier(storage);
    });

final activeNodeProvider =
    StateNotifierProvider<ActiveNodeNotifier, DeviceNode?>((ref) {
      final storage = ref.watch(localStorageServiceProvider);
      final notifier = ActiveNodeNotifier(storage);
      ref.listen<List<DeviceNode>>(savedDevicesProvider, (_, next) {
        notifier.sync(next);
      });
      return notifier;
    });

final discoveredDevicesProvider = FutureProvider<List<DeviceNode>>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  return repository.discoverDevices();
});

final wifiNetworksProvider = FutureProvider<List<WifiNetwork>>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final sensorBaseUrl = ref.watch(sensorApBaseUrlProvider);
  return repository.scanWifiNetworks(sensorBaseUrl);
});

final mobileWifiNetworksProvider = FutureProvider<List<MobileWifiNetwork>>((
  ref,
) async {
  return ref.watch(mobileWifiServiceProvider).scanWifiNetworks();
});

final dashboardProvider = FutureProvider<List<DashboardMetric>>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return [];
  }
  return repository.fetchDashboard(node);
});

final dashboardLiveProvider =
    StateNotifierProvider<DashboardLiveNotifier, DashboardLiveState>((ref) {
      return DashboardLiveNotifier(ref.watch(viotRepositoryProvider));
    });

final fftAxisProvider = StateNotifierProvider<FftAxisNotifier, String>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return FftAxisNotifier(storage);
});

final fftSpectrumProvider = FutureProvider<FftSpectrum?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  final axis = ref.watch(fftAxisProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchFft(node, axis);
});

final mqttConfigProvider = FutureProvider<MqttConfig?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchMqttConfig(node);
});

final mqttPublishSummaryProvider = StreamProvider<MqttPublishSummary?>((
  ref,
) async* {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    yield null;
    return;
  }

  MqttPublishSummary? latest;
  while (true) {
    try {
      latest = await repository.fetchMqttPublishSummary(node);
      yield latest;
    } catch (_) {
      yield latest;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final mqttRuntimeStatusProvider = StreamProvider<MqttRuntimeStatus?>((
  ref,
) async* {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    yield null;
    return;
  }

  MqttRuntimeStatus? latest;
  while (true) {
    try {
      latest = await repository.fetchMqttRuntimeStatus(node);
      yield latest;
    } catch (_) {
      yield latest;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final networkConfigProvider = FutureProvider<NetworkConfig?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchNetworkConfig(node);
});

final memsConfigProvider = FutureProvider<MemsConfig?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchMemsConfig(node);
});

final operateConfigProvider = FutureProvider<OperateConfig?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchOperateConfig(node);
});

final systemConfigProvider = FutureProvider<SystemConfig?>((ref) async {
  final repository = ref.watch(viotRepositoryProvider);
  final node = ref.watch(activeNodeProvider);
  if (node == null) {
    return null;
  }
  return repository.fetchSystemConfig(node);
});

class SavedDevicesNotifier extends StateNotifier<List<DeviceNode>> {
  SavedDevicesNotifier(this._storage) : super(const []) {
    _load();
  }

  final LocalStorageService _storage;

  Future<void> _load() async {
    state = _storage.loadSavedDevices();
  }

  Future<void> add(DeviceNode node) async {
    if (state.any((device) => device.storageKey == node.storageKey)) {
      return;
    }
    final next = [...state, node];
    state = next;
    await _storage.saveSavedDevices(next);
  }

  Future<void> remove(DeviceNode node) async {
    final next = state
        .where((device) => device.storageKey != node.storageKey)
        .toList();
    state = next;
    await _storage.saveSavedDevices(next);
  }

  Future<void> rename(DeviceNode node, String? customName) async {
    final normalized = customName?.trim();
    final next = [
      for (final device in state)
        if (device.storageKey == node.storageKey)
          device.copyWith(
            customName: normalized == null || normalized.isEmpty
                ? null
                : normalized,
          )
        else
          device,
    ];
    state = next;
    await _storage.saveSavedDevices(next);
  }
}

class ActiveNodeNotifier extends StateNotifier<DeviceNode?> {
  ActiveNodeNotifier(this._storage) : super(null) {
    _preferredId = _storage.loadActiveNodeId();
  }

  final LocalStorageService _storage;
  String? _preferredId;

  Future<void> select(DeviceNode? node) async {
    state = node;
    _preferredId = node?.storageKey;
    await _storage.saveActiveNodeId(node?.storageKey);
  }

  void sync(List<DeviceNode> devices) {
    if (devices.isEmpty) {
      state = null;
      return;
    }

    final selected = _firstWhereOrNull(
      devices,
      (device) => device.storageKey == _preferredId,
    );
    if (selected != null) {
      state = selected;
      return;
    }

    if (state != null) {
      final matchingCurrent = _firstWhereOrNull(
        devices,
        (device) => device.storageKey == state!.storageKey,
      );
      if (matchingCurrent != null) {
        state = matchingCurrent;
        return;
      }
    }

    state = devices.first;
    unawaited(_storage.saveActiveNodeId(state?.storageKey));
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}

class SensorApBaseUrlNotifier extends StateNotifier<String> {
  SensorApBaseUrlNotifier(this._storage)
    : super(_storage.loadSensorApBaseUrl());

  final LocalStorageService _storage;

  Future<void> update(String value) async {
    state = value;
    await _storage.saveSensorApBaseUrl(value);
  }
}

class FftAxisNotifier extends StateNotifier<String> {
  FftAxisNotifier(this._storage) : super(_storage.loadFftAxis());

  final LocalStorageService _storage;

  Future<void> update(String value) async {
    state = value;
    await _storage.saveFftAxis(value);
  }
}

class DashboardLiveState {
  const DashboardLiveState({
    this.node,
    this.samples = const [],
    this.selectedMetricKey,
    this.sampleIntervalSec = 3,
    this.isRunning = false,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  final DeviceNode? node;
  final List<DashboardSample> samples;
  final String? selectedMetricKey;
  final int sampleIntervalSec;
  final bool isRunning;
  final bool isLoading;
  final Object? error;
  final DateTime? lastUpdated;

  static const int chartTargetSamples = 60;
  static const int historyTargetSamples = 300;

  List<DashboardMetric> get latestMetrics =>
      samples.isEmpty ? const [] : samples.last.metrics;

  bool get isFastMode => sampleIntervalSec <= 2;
  String get sampleModeLabel => isFastMode ? 'Fast' : 'Normal';
  int get chartWindowSeconds => sampleIntervalSec * chartTargetSamples;
  int get historyWindowSeconds => sampleIntervalSec * historyTargetSamples;

  DashboardMetric? get selectedMetric {
    final key = selectedMetricKey;
    if (key == null || samples.isEmpty) {
      return null;
    }
    return samples.last.metricByKey(key);
  }

  String? get effectiveSelectedMetricKey {
    if (selectedMetricKey != null &&
        latestMetrics.any((metric) => metric.key == selectedMetricKey)) {
      return selectedMetricKey;
    }
    if (latestMetrics.isEmpty) {
      return null;
    }
    return latestMetrics.first.key;
  }

  DashboardLiveState copyWith({
    DeviceNode? node,
    bool clearNode = false,
    List<DashboardSample>? samples,
    String? selectedMetricKey,
    bool clearSelectedMetricKey = false,
    int? sampleIntervalSec,
    bool? isRunning,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) {
    return DashboardLiveState(
      node: clearNode ? null : node ?? this.node,
      samples: samples ?? this.samples,
      selectedMetricKey: clearSelectedMetricKey
          ? null
          : selectedMetricKey ?? this.selectedMetricKey,
      sampleIntervalSec: sampleIntervalSec ?? this.sampleIntervalSec,
      isRunning: isRunning ?? this.isRunning,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class DashboardLiveNotifier extends StateNotifier<DashboardLiveState> {
  DashboardLiveNotifier(this._repository) : super(const DashboardLiveState());

  final ViotRepository _repository;
  Timer? _timer;
  bool _fetching = false;
  bool _stopped = true;
  bool _disposed = false;

  void _setStateIfMounted(DashboardLiveState nextState) {
    if (_disposed || !mounted) {
      return;
    }
    try {
      state = nextState;
    } on AssertionError {
      _stopped = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void start(DeviceNode? node) {
    if (_disposed) {
      return;
    }
    if (node == null) {
      stop(clearNode: true);
      return;
    }

    _stopped = false;
    final nodeChanged = state.node?.storageKey != node.storageKey;
    if (nodeChanged) {
      _setStateIfMounted(
        DashboardLiveState(node: node, isRunning: true, isLoading: true),
      );
    } else {
      _setStateIfMounted(state.copyWith(node: node, isRunning: true));
    }

    _restartTimer();
    unawaited(_fetchOnce());
  }

  void stop({bool clearNode = false}) {
    _timer?.cancel();
    _timer = null;
    _stopped = true;
    if (_disposed) {
      return;
    }
    _setStateIfMounted(
      state.copyWith(clearNode: clearNode, isRunning: false, isLoading: false),
    );
  }

  void clearHistory() {
    if (_disposed) {
      return;
    }
    _setStateIfMounted(state.copyWith(samples: const [], clearError: true));
  }

  void updateSampleInterval(int seconds) {
    if (_disposed) {
      return;
    }
    final normalized = seconds <= 2 ? 2 : 3;
    if (normalized == state.sampleIntervalSec) {
      return;
    }
    _setStateIfMounted(state.copyWith(sampleIntervalSec: normalized));
    if (state.isRunning && state.node != null) {
      _restartTimer();
    }
  }

  void selectMetric(String key) {
    if (_disposed) {
      return;
    }
    _setStateIfMounted(state.copyWith(selectedMetricKey: key));
  }

  Future<void> refreshNow() async {
    await _fetchOnce();
  }

  Future<void> _fetchOnce() async {
    final node = state.node;
    if (_disposed || _stopped || node == null || _fetching) {
      return;
    }

    _fetching = true;
    _setStateIfMounted(
      state.copyWith(isLoading: state.samples.isEmpty, clearError: true),
    );
    try {
      final metrics = await _repository.fetchDashboard(node);
      if (_disposed ||
          !mounted ||
          _stopped ||
          state.node?.storageKey != node.storageKey) {
        return;
      }
      final now = DateTime.now();
      final nextSamples = [
        ...state.samples,
        DashboardSample(timestamp: now, metrics: metrics),
      ];
      final cutoff = now.subtract(
        Duration(seconds: state.historyWindowSeconds),
      );
      final trimmed = nextSamples
          .where((sample) => !sample.timestamp.isBefore(cutoff))
          .toList();
      final selectedKey =
          state.effectiveSelectedMetricKey ??
          (metrics.isEmpty ? null : metrics.first.key);
      _setStateIfMounted(
        state.copyWith(
          samples: trimmed,
          selectedMetricKey: selectedKey,
          isLoading: false,
          clearError: true,
          lastUpdated: now,
        ),
      );
    } catch (error) {
      if (mounted && !_stopped && state.node?.storageKey == node.storageKey) {
        _setStateIfMounted(state.copyWith(isLoading: false, error: error));
      }
    } finally {
      _fetching = false;
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_disposed || _stopped) {
      return;
    }
    _timer = Timer.periodic(
      Duration(seconds: state.sampleIntervalSec),
      (_) => unawaited(_fetchOnce()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopped = true;
    _disposed = true;
    super.dispose();
  }
}
