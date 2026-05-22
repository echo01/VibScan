import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/device_node.dart';
import '../../../core/models/mems_config.dart';
import '../../../core/models/mqtt_config.dart';
import '../../../core/models/network_config.dart';
import '../../../core/models/operate_config.dart';
import '../../../core/models/system_config.dart';
import '../../../core/models/wifi_network.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/node_header.dart';
import '../../../shared/widgets/section_card.dart';

class ConfigDevicePage extends StatelessWidget {
  const ConfigDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: [
          _ConfigHeader(),
          TabBar(
            tabs: [
              Tab(text: 'MQTT'),
              Tab(text: 'Network'),
              Tab(text: 'MEMS'),
              Tab(text: 'Operate'),
              Tab(text: 'System'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MqttTab(),
                _NetworkTab(),
                _MemsTab(),
                _OperateTab(),
                _SystemTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigHeader extends ConsumerWidget {
  const _ConfigHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNode = ref.watch(activeNodeProvider);
    final savedDevices = ref.watch(savedDevicesProvider);
    final selectedId =
        savedDevices.any((node) => node.storageKey == activeNode?.storageKey)
        ? activeNode?.storageKey
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NodeHeader(
            title: 'Config Device',
            subtitle: activeNode == null
                ? 'No active node selected'
                : '${activeNode.displayName} via GET /api/config',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedId,
            decoration: const InputDecoration(
              labelText: 'Saved Device',
              prefixIcon: Icon(Icons.sensors_rounded),
            ),
            items: [
              for (final node in savedDevices)
                DropdownMenuItem(
                  value: node.storageKey,
                  child: Text(
                    node.displayNameWithEndpoint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: savedDevices.isEmpty
                ? null
                : (id) async {
                    final selected = _findDevice(savedDevices, id);
                    if (selected == null) {
                      return;
                    }
                    await ref
                        .read(activeNodeProvider.notifier)
                        .select(selected);
                    ref.invalidate(mqttConfigProvider);
                    ref.invalidate(networkConfigProvider);
                    ref.invalidate(memsConfigProvider);
                    ref.invalidate(operateConfigProvider);
                    ref.invalidate(systemConfigProvider);
                  },
          ),
        ],
      ),
    );
  }

  DeviceNode? _findDevice(List<DeviceNode> devices, String? id) {
    for (final node in devices) {
      if (node.storageKey == id || node.id == id) {
        return node;
      }
    }
    return null;
  }
}

class _MqttTab extends ConsumerWidget {
  const _MqttTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(mqttConfigProvider);

    return config.when(
      data: (value) => _ConfigScrollView(
        child: value == null
            ? const Text('Select a device to edit MQTT settings.')
            : _MqttConfigForm(config: value),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load MQTT config: $error')),
    );
  }
}

class _NetworkTab extends ConsumerWidget {
  const _NetworkTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(networkConfigProvider);

    return config.when(
      data: (value) => _ConfigScrollView(
        child: value == null
            ? const Text('Select a device to edit network settings.')
            : _NetworkConfigForm(config: value),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load network config: $error')),
    );
  }
}

class _MemsTab extends ConsumerWidget {
  const _MemsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(memsConfigProvider);

    return config.when(
      data: (value) => _ConfigScrollView(
        child: value == null
            ? const Text('Select a device to edit MEMS settings.')
            : _MemsConfigForm(config: value),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load MEMS config: $error')),
    );
  }
}

class _OperateTab extends ConsumerWidget {
  const _OperateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(operateConfigProvider);

    return config.when(
      data: (value) => _ConfigScrollView(
        child: value == null
            ? const Text('Select a device to edit operate settings.')
            : _OperateConfigForm(config: value),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load operate config: $error')),
    );
  }
}

class _SystemTab extends ConsumerWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemConfigProvider);

    return config.when(
      data: (value) => _ConfigScrollView(
        child: value == null
            ? const Text('Select a device to edit system settings.')
            : _SystemConfigForm(config: value),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Failed to load system config: $error')),
    );
  }
}

class _ConfigScrollView extends StatelessWidget {
  const _ConfigScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [SectionCard(title: 'Settings', child: child)],
    );
  }
}

class _MqttConfigForm extends ConsumerStatefulWidget {
  const _MqttConfigForm({required this.config});

  final MqttConfig config;

  @override
  ConsumerState<_MqttConfigForm> createState() => _MqttConfigFormState();
}

class _MqttConfigFormState extends ConsumerState<_MqttConfigForm> {
  late final TextEditingController _brokerController;
  late final TextEditingController _portController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _publishController;
  late final TextEditingController _fftXController;
  late final TextEditingController _fftYController;
  late final TextEditingController _fftZController;
  late final TextEditingController _subscribeController;
  late final TextEditingController _ackController;
  late final TextEditingController _resultController;
  late String _protocol;
  late bool _useTls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _brokerController = TextEditingController(text: widget.config.broker);
    _portController = TextEditingController(text: '${widget.config.port}');
    _clientIdController = TextEditingController(text: widget.config.clientId);
    _usernameController = TextEditingController(text: widget.config.username);
    _passwordController = TextEditingController(text: widget.config.password);
    _publishController = TextEditingController(
      text: widget.config.topicPublish,
    );
    _fftXController = TextEditingController(text: widget.config.topicFftX);
    _fftYController = TextEditingController(text: widget.config.topicFftY);
    _fftZController = TextEditingController(text: widget.config.topicFftZ);
    _subscribeController = TextEditingController(
      text: widget.config.topicSubscribe,
    );
    _ackController = TextEditingController(text: widget.config.topicAck);
    _resultController = TextEditingController(text: widget.config.topicResult);
    _protocol = widget.config.protocol.toLowerCase() == 'mqtts'
        ? 'mqtts'
        : 'mqtt';
    _useTls = widget.config.useTls;
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _clientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _publishController.dispose();
    _fftXController.dispose();
    _fftYController.dispose();
    _fftZController.dispose();
    _subscribeController.dispose();
    _ackController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(viotRepositoryProvider);
      await repository.saveMqttConfig(
        node,
        MqttConfig(
          broker: _brokerController.text.trim(),
          port: int.tryParse(_portController.text.trim()) ?? 1883,
          clientId: _clientIdController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          topicPublish: _publishController.text.trim(),
          topicFftX: _fftXController.text.trim(),
          topicFftY: _fftYController.text.trim(),
          topicFftZ: _fftZController.text.trim(),
          topicSubscribe: _subscribeController.text.trim(),
          topicAck: _ackController.text.trim(),
          topicResult: _resultController.text.trim(),
          publishIntervalSec: widget.config.publishIntervalSec,
          useTls: _useTls,
          protocol: _protocol,
          status: widget.config.status,
        ),
      );
      ref.invalidate(mqttConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MQTT config saved.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.config.status.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Runtime status: ${widget.config.status}'),
            ),
          ),
        _EditableField(label: 'Broker', controller: _brokerController),
        _EditableField(
          label: 'Port',
          controller: _portController,
          keyboardType: TextInputType.number,
        ),
        _EditableField(label: 'Client ID', controller: _clientIdController),
        _EditableField(label: 'Username', controller: _usernameController),
        _EditableField(
          label: 'Password',
          controller: _passwordController,
          obscureText: true,
        ),
        DropdownButtonFormField<String>(
          initialValue: _protocol,
          decoration: const InputDecoration(labelText: 'Protocol'),
          items: const [
            DropdownMenuItem(value: 'mqtt', child: Text('mqtt')),
            DropdownMenuItem(value: 'mqtts', child: Text('mqtts')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _protocol = value;
              _useTls = value == 'mqtts';
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use TLS'),
          value: _useTls,
          onChanged: (value) => setState(() {
            _useTls = value;
            _protocol = value ? 'mqtts' : 'mqtt';
          }),
        ),
        _EditableField(label: 'Publish Topic', controller: _publishController),
        _EditableField(label: 'FFT Topic X', controller: _fftXController),
        _EditableField(label: 'FFT Topic Y', controller: _fftYController),
        _EditableField(label: 'FFT Topic Z', controller: _fftZController),
        _EditableField(
          label: 'Subscribe Topic',
          controller: _subscribeController,
        ),
        _EditableField(label: 'Ack Topic', controller: _ackController),
        _EditableField(label: 'Result Topic', controller: _resultController),
        const SizedBox(height: 12),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

class _NetworkConfigForm extends ConsumerStatefulWidget {
  const _NetworkConfigForm({required this.config});

  final NetworkConfig config;

  @override
  ConsumerState<_NetworkConfigForm> createState() => _NetworkConfigFormState();
}

class _NetworkConfigFormState extends ConsumerState<_NetworkConfigForm> {
  late final TextEditingController _ssidController;
  late final TextEditingController _passwordController;
  late final TextEditingController _apSsidController;
  late final TextEditingController _apPasswordController;
  late final TextEditingController _staIpController;
  late final TextEditingController _gatewayController;
  late final TextEditingController _subnetController;
  late final TextEditingController _dns1Controller;
  late final TextEditingController _dns2Controller;
  late bool _apEnabled;
  late bool _useStaticIp;
  List<WifiNetwork> _availableNetworks = const [];
  String? _selectedScannedSsid;
  String? _scanMessage;
  bool _scanning = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController(text: widget.config.ssid);
    _passwordController = TextEditingController(text: widget.config.password);
    _apSsidController = TextEditingController(text: widget.config.apSsid);
    _apPasswordController = TextEditingController(
      text: widget.config.apPassword,
    );
    _staIpController = TextEditingController(text: widget.config.staStaticIp);
    _gatewayController = TextEditingController(text: widget.config.staGateway);
    _subnetController = TextEditingController(text: widget.config.staSubnet);
    _dns1Controller = TextEditingController(text: widget.config.staDns1);
    _dns2Controller = TextEditingController(text: widget.config.staDns2);
    _apEnabled = widget.config.apEnabled;
    _useStaticIp = widget.config.staUseStaticIp;
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _apSsidController.dispose();
    _apPasswordController.dispose();
    _staIpController.dispose();
    _gatewayController.dispose();
    _subnetController.dispose();
    _dns1Controller.dispose();
    _dns2Controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(viotRepositoryProvider);
      await repository.saveNetworkConfig(
        node,
        NetworkConfig(
          ssid: _ssidController.text.trim(),
          password: _passwordController.text,
          apEnabled: _apEnabled,
          apSsid: _apSsidController.text.trim(),
          apPassword: _apPasswordController.text,
          staUseStaticIp: _useStaticIp,
          staStaticIp: _staIpController.text.trim(),
          staGateway: _gatewayController.text.trim(),
          staSubnet: _subnetController.text.trim(),
          staDns1: _dns1Controller.text.trim(),
          staDns2: _dns2Controller.text.trim(),
        ),
      );
      ref.invalidate(networkConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Network config saved.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _scanNodeWifi() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() {
      _scanning = true;
      _scanMessage = node.baseUrl.contains('192.168.4.1')
          ? 'WiFi scan may briefly interrupt the device AP connection.'
          : 'Scanning WiFi near ${node.displayName}...';
    });

    try {
      final networks = await ref
          .read(viotRepositoryProvider)
          .scanWifiNetworks(node.baseUrl);
      final deduped = _dedupeNetworks(networks);
      if (mounted) {
        setState(() {
          _availableNetworks = deduped;
          _selectedScannedSsid = null;
          _scanMessage = deduped.isEmpty
              ? 'No SSID found near this node.'
              : 'Found ${deduped.length} SSID near this node.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _scanMessage = 'Scan SSID failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditableField(label: 'WiFi SSID', controller: _ssidController),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _scanning ? null : _scanNodeWifi,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find_rounded),
            label: Text(_scanning ? 'Scanning...' : 'Scan SSID'),
          ),
        ),
        if (_scanMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _scanMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedScannedSsid,
          decoration: const InputDecoration(labelText: 'Available SSID'),
          hint: const Text('-- Scan then select SSID --'),
          items: [
            for (final network in _availableNetworks)
              DropdownMenuItem(
                value: network.ssid,
                child: Text(
                  '${network.ssid}  ${network.rssi} dBm  ${network.security}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _availableNetworks.isEmpty
              ? null
              : (ssid) {
                  if (ssid == null) {
                    return;
                  }
                  setState(() {
                    _selectedScannedSsid = ssid;
                    _ssidController.text = ssid;
                  });
                },
        ),
        const SizedBox(height: 10),
        _EditableField(
          label: 'WiFi Password',
          controller: _passwordController,
          obscureText: true,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable AP fallback'),
          value: _apEnabled,
          onChanged: (value) => setState(() => _apEnabled = value),
        ),
        _EditableField(label: 'AP SSID', controller: _apSsidController),
        _EditableField(
          label: 'AP Password',
          controller: _apPasswordController,
          obscureText: true,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use static STA IP'),
          value: _useStaticIp,
          onChanged: (value) => setState(() => _useStaticIp = value),
        ),
        _EditableField(label: 'Static IP', controller: _staIpController),
        _EditableField(label: 'Gateway', controller: _gatewayController),
        _EditableField(label: 'Subnet', controller: _subnetController),
        _EditableField(label: 'DNS 1', controller: _dns1Controller),
        _EditableField(label: 'DNS 2', controller: _dns2Controller),
        const SizedBox(height: 12),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }

  List<WifiNetwork> _dedupeNetworks(List<WifiNetwork> networks) {
    final bySsid = <String, WifiNetwork>{};
    for (final network in networks) {
      if (network.ssid.trim().isEmpty) {
        continue;
      }
      final existing = bySsid[network.ssid];
      if (existing == null || network.rssi > existing.rssi) {
        bySsid[network.ssid] = network;
      }
    }
    final deduped = bySsid.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return deduped;
  }
}

class _MemsConfigForm extends ConsumerStatefulWidget {
  const _MemsConfigForm({required this.config});

  final MemsConfig config;

  @override
  ConsumerState<_MemsConfigForm> createState() => _MemsConfigFormState();
}

class _MemsConfigFormState extends ConsumerState<_MemsConfigForm> {
  late int _bandwidthHz;
  late int _rangeG;
  late final TextEditingController _offsetXController;
  late final TextEditingController _offsetYController;
  late final TextEditingController _offsetZController;
  late final TextEditingController _calibrationDurationController;
  late final TextEditingController _calibrationMarginController;
  late bool _applyCalibration;
  Map<String, dynamic>? _calibrationStatus;
  String? _calibrationMessage;
  bool _calibrating = false;
  bool _resettingCalibration = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bandwidthHz = _normalizeBandwidth(widget.config.rateHz ~/ 2);
    _rangeG = _normalizeRange(widget.config.rangeG);
    _offsetXController = TextEditingController(
      text: _formatOffset(widget.config.offsetX),
    );
    _offsetYController = TextEditingController(
      text: _formatOffset(widget.config.offsetY),
    );
    _offsetZController = TextEditingController(
      text: _formatOffset(widget.config.offsetZ),
    );
    _calibrationDurationController = TextEditingController(text: '10');
    _calibrationMarginController = TextEditingController(text: '2.0');
    _applyCalibration = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCalibration());
  }

  @override
  void dispose() {
    _offsetXController.dispose();
    _offsetYController.dispose();
    _offsetZController.dispose();
    _calibrationDurationController.dispose();
    _calibrationMarginController.dispose();
    super.dispose();
  }

  Future<void> _loadCalibration() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    try {
      final status = await ref
          .read(viotRepositoryProvider)
          .fetchMemsCalibration(node);
      if (mounted) {
        setState(() {
          _calibrationStatus = status;
          _calibrationMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _calibrationMessage = 'Calibration status: $error');
      }
    }
  }

  Future<void> _save() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(viotRepositoryProvider);
      await repository.saveMemsConfig(
        node,
        MemsConfig(
          rateHz: _bandwidthHz * 2,
          rangeG: _rangeG,
          offsetX: double.tryParse(_offsetXController.text.trim()) ?? 0,
          offsetY: double.tryParse(_offsetYController.text.trim()) ?? 0,
          offsetZ: double.tryParse(_offsetZController.text.trim()) ?? 0,
          intThresholdMg: widget.config.intThresholdMg,
          intEnabled: widget.config.intEnabled,
          minRmsG: widget.config.minRmsG,
          minPeakG: widget.config.minPeakG,
          noiseFloorDb: widget.config.noiseFloorDb,
          deadbandG: widget.config.deadbandG,
          minFreqHz: widget.config.minFreqHz,
          maxFreqHz: widget.config.maxFreqHz,
          sleepIntervalSec: widget.config.sleepIntervalSec,
        ),
      );
      ref.invalidate(memsConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MEMS config saved.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _calibrate() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() {
      _calibrating = true;
      _calibrationMessage = 'Calibration running...';
    });
    try {
      final status = await ref
          .read(viotRepositoryProvider)
          .calibrateMems(
            node,
            durationSec:
                int.tryParse(_calibrationDurationController.text.trim()) ?? 10,
            marginFactor:
                double.tryParse(_calibrationMarginController.text.trim()) ??
                2.0,
            apply: _applyCalibration,
          );
      ref.invalidate(memsConfigProvider);
      if (mounted) {
        setState(() {
          _calibrationStatus = status;
          _calibrationMessage = _statusMessage(status);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _calibrationMessage = 'Calibration failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _calibrating = false);
      }
    }
  }

  Future<void> _resetCalibration() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() {
      _resettingCalibration = true;
      _calibrationMessage = 'Resetting calibration...';
    });
    try {
      await ref.read(viotRepositoryProvider).resetMemsCalibration(node);
      ref.invalidate(memsConfigProvider);
      if (mounted) {
        setState(() {
          _calibrationStatus = null;
          _calibrationMessage = 'MEMS calibration reset.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _calibrationMessage = 'Reset failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _resettingCalibration = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _bandwidthHz,
          decoration: const InputDecoration(
            labelText: 'Measurement Bandwidth (Hz)',
          ),
          items: const [
            DropdownMenuItem(value: 50, child: Text('50 Hz')),
            DropdownMenuItem(value: 100, child: Text('100 Hz')),
            DropdownMenuItem(value: 200, child: Text('200 Hz')),
            DropdownMenuItem(value: 400, child: Text('400 Hz')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _bandwidthHz = value);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Text(
            'ADXL345 output data rate is internally set to 2x the selected bandwidth.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: _rangeG,
          decoration: const InputDecoration(labelText: 'Range (G)'),
          items: const [
            DropdownMenuItem(value: 2, child: Text('2G')),
            DropdownMenuItem(value: 4, child: Text('4G')),
            DropdownMenuItem(value: 8, child: Text('8G')),
            DropdownMenuItem(value: 16, child: Text('16G')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _rangeG = value);
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Offset Calibration (G)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EditableField(
                label: 'X Offset',
                controller: _offsetXController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditableField(
                label: 'Y Offset',
                controller: _offsetYController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditableField(
                label: 'Z Offset',
                controller: _offsetZController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save MEMS Config'),
          ),
        ),
        const Divider(height: 28),
        Text(
          'MEMS No-Vibration Calibration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        const Text(
          'Keep the device still before starting calibration. This learns the current noise baseline and reduces false frequency/velocity when there is no vibration.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EditableField(
                label: 'Duration (sec)',
                controller: _calibrationDurationController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditableField(
                label: 'Margin Factor',
                controller: _calibrationMarginController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<bool>(
          initialValue: _applyCalibration,
          decoration: const InputDecoration(labelText: 'Apply Result'),
          items: const [
            DropdownMenuItem(value: true, child: Text('Apply and save')),
            DropdownMenuItem(value: false, child: Text('Test only')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _applyCalibration = value);
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _calibrating ? null : _calibrate,
              child: Text(
                _calibrating ? 'Calibrating...' : 'Calibrate MEMS Now',
              ),
            ),
            FilledButton.tonal(
              onPressed: _resettingCalibration ? null : _resetCalibration,
              child: Text(
                _resettingCalibration
                    ? 'Resetting...'
                    : 'Reset MEMS Calibration',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CalibrationStatusBox(
          status: _calibrationStatus,
          message: _calibrationMessage,
        ),
      ],
    );
  }

  int _normalizeBandwidth(int value) {
    const options = [50, 100, 200, 400];
    return options.contains(value) ? value : 400;
  }

  int _normalizeRange(int value) {
    const options = [2, 4, 8, 16];
    return options.contains(value) ? value : 16;
  }

  String _formatOffset(double value) {
    if (value == 0) {
      return '0';
    }
    return value.toStringAsFixed(3);
  }

  String _statusMessage(Map<String, dynamic> status) {
    final message = (status['message'] ?? '').toString();
    if (message.isNotEmpty) {
      return message;
    }
    return status['success'] == true
        ? 'Calibration complete'
        : 'Calibration status updated';
  }
}

class _CalibrationStatusBox extends StatelessWidget {
  const _CalibrationStatusBox({required this.status, required this.message});

  final Map<String, dynamic>? status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[];
    if (message != null && message!.isNotEmpty) {
      lines.add(message!);
    }
    if (status != null && status!.isNotEmpty) {
      lines.addAll(_statusLines(status!));
    }
    if (lines.isEmpty) {
      lines.add('Calibration status not loaded yet.');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
      ),
      child: Text(lines.join('\n'), style: theme.textTheme.bodySmall),
    );
  }

  List<String> _statusLines(Map<String, dynamic> status) {
    final calibrated = status['calibrated'] ?? status['applied'];
    final autoNoiseGate = status['auto_noise_gate'];
    final margin = status['margin_factor'];
    final rms = _axisMap(status['baseline_rms']);
    final peak = _axisMap(status['baseline_peak']);
    final lines = <String>[
      if (calibrated != null) 'Calibrated: ${_yesNo(calibrated)}',
      if (autoNoiseGate != null || margin != null)
        'Auto noise gate: ${_yesNo(autoNoiseGate ?? true)} | Margin: ${margin ?? '-'}',
      if (rms != null)
        'Baseline RMS G: X=${_fmt(rms['x'])} Y=${_fmt(rms['y'])} Z=${_fmt(rms['z'])}',
      if (peak != null)
        'Baseline Peak G: X=${_fmt(peak['x'])} Y=${_fmt(peak['y'])} Z=${_fmt(peak['z'])}',
    ];

    if (status['success'] != null && lines.isEmpty) {
      lines.add('Success: ${_yesNo(status['success'])}');
    }
    return lines;
  }

  Map<String, dynamic>? _axisMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  String _yesNo(dynamic value) {
    if (value == true || value == 1 || value == '1') {
      return 'yes';
    }
    if (value == false || value == 0 || value == '0') {
      return 'no';
    }
    return '-';
  }

  String _fmt(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) {
      return '-';
    }
    return number.toStringAsFixed(5);
  }
}

class _OperateConfigForm extends ConsumerStatefulWidget {
  const _OperateConfigForm({required this.config});

  final OperateConfig config;

  @override
  ConsumerState<_OperateConfigForm> createState() => _OperateConfigFormState();
}

class _OperateConfigFormState extends ConsumerState<_OperateConfigForm> {
  late final TextEditingController _publishIntervalController;
  late final TextEditingController _wakeupIntThresholdController;
  late final TextEditingController _wakeupTimerController;
  late final TextEditingController _thresholdController;
  late bool _wakeupIntEnabled;
  late bool _publishOnTrigger;
  late bool _logEnabled;
  late bool _debugLogWifi;
  late bool _debugLogMqtt;
  late bool _debugLogMems;
  late bool _debugLogPower;
  late bool _debugLogWeb;
  late bool _debugLogBattery;
  late bool _debugLogOperate;
  late bool _debugLogSystem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _publishIntervalController = TextEditingController(
      text: '${widget.config.publishIntervalSec}',
    );
    _wakeupIntThresholdController = TextEditingController(
      text: '${widget.config.wakeupIntThresholdMg}',
    );
    _wakeupTimerController = TextEditingController(
      text: '${widget.config.wakeupTimerSec}',
    );
    _thresholdController = TextEditingController(
      text: widget.config.publishVibrationThresholdMmS.toStringAsFixed(2),
    );
    _wakeupIntEnabled = widget.config.wakeupIntEnabled;
    _publishOnTrigger = widget.config.publishOnVibrationTrigger;
    _logEnabled = widget.config.logEnabled;
    _debugLogWifi = widget.config.debugLogWifi;
    _debugLogMqtt = widget.config.debugLogMqtt;
    _debugLogMems = widget.config.debugLogMems;
    _debugLogPower = widget.config.debugLogPower;
    _debugLogWeb = widget.config.debugLogWeb;
    _debugLogBattery = widget.config.debugLogBattery;
    _debugLogOperate = widget.config.debugLogOperate;
    _debugLogSystem = widget.config.debugLogSystem;
  }

  @override
  void dispose() {
    _publishIntervalController.dispose();
    _wakeupIntThresholdController.dispose();
    _wakeupTimerController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(viotRepositoryProvider);
      await repository.saveOperateConfig(
        node,
        OperateConfig(
          publishIntervalSec:
              int.tryParse(_publishIntervalController.text.trim()) ?? 60,
          wakeupIntThresholdMg:
              int.tryParse(_wakeupIntThresholdController.text.trim()) ?? 0,
          wakeupIntEnabled: _wakeupIntEnabled,
          wakeupTimerSec:
              int.tryParse(_wakeupTimerController.text.trim()) ?? 3600,
          publishOnVibrationTrigger: _publishOnTrigger,
          publishVibrationThresholdMmS:
              double.tryParse(_thresholdController.text.trim()) ?? 0,
          logEnabled: _logEnabled,
          debugLogWifi: _debugLogWifi,
          debugLogMqtt: _debugLogMqtt,
          debugLogMems: _debugLogMems,
          debugLogPower: _debugLogPower,
          debugLogWeb: _debugLogWeb,
          debugLogBattery: _debugLogBattery,
          debugLogOperate: _debugLogOperate,
          debugLogSystem: _debugLogSystem,
        ),
      );
      ref.invalidate(operateConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Operate config saved.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _EditableField(
          label: 'Publish Interval (sec)',
          controller: _publishIntervalController,
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wakeup by interrupt'),
          value: _wakeupIntEnabled,
          onChanged: (value) => setState(() => _wakeupIntEnabled = value),
        ),
        _EditableField(
          label: 'Wakeup Interrupt Threshold (mg)',
          controller: _wakeupIntThresholdController,
          keyboardType: TextInputType.number,
        ),
        _EditableField(
          label: 'Wakeup Timer (sec)',
          controller: _wakeupTimerController,
          keyboardType: TextInputType.number,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Publish on vibration trigger'),
          value: _publishOnTrigger,
          onChanged: (value) => setState(() => _publishOnTrigger = value),
        ),
        _EditableField(
          label: 'Trigger Threshold (mm/s)',
          controller: _thresholdController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Global logging enabled'),
          value: _logEnabled,
          onChanged: (value) => setState(() => _logEnabled = value),
        ),
        _DebugSwitch(
          label: 'Debug WiFi logs',
          value: _debugLogWifi,
          onChanged: (value) => setState(() => _debugLogWifi = value),
        ),
        _DebugSwitch(
          label: 'Debug MQTT logs',
          value: _debugLogMqtt,
          onChanged: (value) => setState(() => _debugLogMqtt = value),
        ),
        _DebugSwitch(
          label: 'Debug MEMS logs',
          value: _debugLogMems,
          onChanged: (value) => setState(() => _debugLogMems = value),
        ),
        _DebugSwitch(
          label: 'Debug power logs',
          value: _debugLogPower,
          onChanged: (value) => setState(() => _debugLogPower = value),
        ),
        _DebugSwitch(
          label: 'Debug web logs',
          value: _debugLogWeb,
          onChanged: (value) => setState(() => _debugLogWeb = value),
        ),
        _DebugSwitch(
          label: 'Debug battery logs',
          value: _debugLogBattery,
          onChanged: (value) => setState(() => _debugLogBattery = value),
        ),
        _DebugSwitch(
          label: 'Debug operate logs',
          value: _debugLogOperate,
          onChanged: (value) => setState(() => _debugLogOperate = value),
        ),
        _DebugSwitch(
          label: 'Debug system logs',
          value: _debugLogSystem,
          onChanged: (value) => setState(() => _debugLogSystem = value),
        ),
        const SizedBox(height: 12),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

class _DebugSwitch extends StatelessWidget {
  const _DebugSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SystemConfigForm extends ConsumerStatefulWidget {
  const _SystemConfigForm({required this.config});

  final SystemConfig config;

  @override
  ConsumerState<_SystemConfigForm> createState() => _SystemConfigFormState();
}

class _SystemConfigFormState extends ConsumerState<_SystemConfigForm> {
  bool _factoryResetting = false;

  Future<void> _factoryDefault() async {
    final node = ref.read(activeNodeProvider);
    if (node == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory default?'),
        content: Text(
          'This will reset ${node.displayName} to factory defaults using /api/reset. Saved app entries are not removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Factory Default'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _factoryResetting = true);
    try {
      await ref.read(viotRepositoryProvider).resetNode(node);
      ref.invalidate(mqttConfigProvider);
      ref.invalidate(networkConfigProvider);
      ref.invalidate(memsConfigProvider);
      ref.invalidate(operateConfigProvider);
      ref.invalidate(systemConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Factory default command sent to ${node.displayName}.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _factoryResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Factory Default',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Restore the selected ESP32 node to its factory default settings. '
          'This sends POST /api/reset to the device. WiFi, MQTT, MEMS, operate, '
          'and system settings on the ESP32 may be cleared or restored to firmware defaults. '
          'Saved devices in this mobile app are not removed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _factoryResetting ? null : _factoryDefault,
            icon: _factoryResetting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: Text(_factoryResetting ? 'Sending...' : 'Factory Default'),
          ),
        ),
      ],
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        child: Text(saving ? 'Saving...' : 'Save'),
      ),
    );
  }
}
