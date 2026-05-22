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

abstract class ViotRepository {
  Future<List<WifiNetwork>> scanWifiNetworks(String sensorBaseUrl);

  Future<void> submitNetworkConfig(String sensorBaseUrl, NetworkConfig config);

  Future<List<DeviceNode>> discoverDevices();

  Future<List<DashboardMetric>> fetchDashboard(DeviceNode node);

  Future<FftSpectrum> fetchFft(DeviceNode node, String axis);

  Future<MqttConfig> fetchMqttConfig(DeviceNode node);

  Future<MqttPublishSummary> fetchMqttPublishSummary(DeviceNode node);

  Future<MqttRuntimeStatus> fetchMqttRuntimeStatus(DeviceNode node);

  Future<NetworkConfig> fetchNetworkConfig(DeviceNode node);

  Future<MemsConfig> fetchMemsConfig(DeviceNode node);

  Future<OperateConfig> fetchOperateConfig(DeviceNode node);

  Future<SystemConfig> fetchSystemConfig(DeviceNode node);

  Future<void> saveMqttConfig(DeviceNode node, MqttConfig config);

  Future<void> saveNetworkConfig(DeviceNode node, NetworkConfig config);

  Future<void> saveMemsConfig(DeviceNode node, MemsConfig config);

  Future<Map<String, dynamic>> fetchMemsCalibration(DeviceNode node);

  Future<Map<String, dynamic>> calibrateMems(
    DeviceNode node, {
    required int durationSec,
    required double marginFactor,
    required bool apply,
  });

  Future<void> resetMemsCalibration(DeviceNode node);

  Future<void> saveOperateConfig(DeviceNode node, OperateConfig config);

  Future<void> saveSystemConfig(DeviceNode node, SystemConfig config);

  Future<void> rebootNode(DeviceNode node);

  Future<void> resetNode(DeviceNode node);
}
