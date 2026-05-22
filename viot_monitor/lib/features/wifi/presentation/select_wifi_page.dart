import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/device_node.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/mobile_wifi_service.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_badge.dart';

class SelectWifiPage extends ConsumerStatefulWidget {
  const SelectWifiPage({super.key});

  @override
  ConsumerState<SelectWifiPage> createState() => _SelectWifiPageState();
}

class _SelectWifiPageState extends ConsumerState<SelectWifiPage> {
  String? _selectedSsid;

  Future<void> _openWifiSettings() async {
    debugPrint('[SelectWifiPage] OPEN Android WiFi settings');
    try {
      await ref.read(mobileWifiServiceProvider).openWifiSettings();
    } on PlatformException catch (error) {
      debugPrint('[SelectWifiPage] OPEN WiFi settings error=$error');
    } on MissingPluginException catch (error) {
      debugPrint('[SelectWifiPage] OPEN WiFi settings unsupported=$error');
    }
  }

  void _selectNetwork(MobileWifiNetwork network) {
    setState(() {
      _selectedSsid = network.ssid;
    });
    if (network.isEsp32Ap) {
      ref.read(sensorApBaseUrlProvider.notifier).update('http://192.168.4.1');
    }

    debugPrint(
      '[SelectWifiPage] SELECT ssid=${network.ssid} '
      'rssi=${network.level} security=${network.securityLabel}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MobileWifiScanner(
          selectedSsid: _selectedSsid,
          onRefresh: () => ref.invalidate(mobileWifiNetworksProvider),
          onOpenSettings: _openWifiSettings,
          onSelected: _selectNetwork,
        ),
        const SizedBox(height: 16),
        const _DiscoveryDevicesSection(),
        const SizedBox(height: 16),
        const _SavedDevicesSection(),
      ],
    );
  }
}

class _MobileWifiScanner extends ConsumerWidget {
  const _MobileWifiScanner({
    required this.selectedSsid,
    required this.onRefresh,
    required this.onOpenSettings,
    required this.onSelected,
  });

  final String? selectedSsid;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;
  final ValueChanged<MobileWifiNetwork> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networks = ref.watch(mobileWifiNetworksProvider);

    return SectionCard(
      title: 'Mobile WiFi Networks',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open WiFi Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton(
            tooltip: 'Scan WiFi',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: networks.when(
        data: (items) {
          if (items.isEmpty) {
            return _WifiScanMessage(
              icon: Icons.wifi_off_rounded,
              title: 'No WiFi networks found',
              message:
                  'Turn on WiFi and Location, then scan again. Android may '
                  'return cached or empty results on emulators.',
            );
          }

          return Column(
            children: [
              for (final network in items) ...[
                _WifiNetworkTile(
                  network: network,
                  selected: selectedSsid == network.ssid || network.isConnected,
                  onTap: () => onSelected(network),
                ),
                if (network != items.last) const Divider(height: 1),
              ],
            ],
          );
        },
        error: (error, _) => _WifiScanMessage(
          icon: Icons.location_disabled_rounded,
          title: 'Cannot scan WiFi',
          message: _friendlyWifiError(error),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  String _friendlyWifiError(Object error) {
    if (error is MissingPluginException) {
      return 'Mobile WiFi scan is available on Android builds only.';
    }
    if (error is PlatformException) {
      return switch (error.code) {
        'wifi_scan_permission_denied' =>
          'Allow Location/Nearby WiFi permission, then scan again.',
        _ => error.message ?? error.toString(),
      };
    }
    return error.toString();
  }
}

class _WifiNetworkTile extends StatelessWidget {
  const _WifiNetworkTile({
    required this.network,
    required this.selected,
    required this.onTap,
  });

  final MobileWifiNetwork network;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _wifiIcon(network.signalBars),
        color: theme.colorScheme.primary,
      ),
      title: Text(network.ssid),
      subtitle: Text(
        [
          network.securityLabel,
          if (network.level != null) '${network.level} dBm',
          if (network.frequency != null) '${network.frequency} MHz',
        ].join('  '),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: onTap,
    );
  }

  IconData _wifiIcon(int bars) {
    return switch (bars) {
      4 => Icons.wifi_rounded,
      3 => Icons.network_wifi_3_bar_rounded,
      2 => Icons.network_wifi_2_bar_rounded,
      1 => Icons.network_wifi_1_bar_rounded,
      _ => Icons.wifi_find_rounded,
    };
  }
}

class _WifiScanMessage extends StatelessWidget {
  const _WifiScanMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryDevicesSection extends ConsumerWidget {
  const _DiscoveryDevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovered = ref.watch(discoveredDevicesProvider);
    final active = ref.watch(activeNodeProvider);

    return SectionCard(
      title: 'Discovered Devices',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discovered.isRefreshing || discovered.isReloading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Start Discovery',
            onPressed: () => ref.invalidate(discoveredDevicesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: discovered.when(
        skipLoadingOnRefresh: true,
        data: (items) {
          if (items.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (discovered.isRefreshing || discovered.isReloading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'No devices found. Connect to the same network, then scan again.',
                ),
              ],
            );
          }

          return Column(
            children: [
              if (discovered.isRefreshing || discovered.isReloading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
              ],
              for (final node in items) ...[
                _DiscoveredDeviceTile(
                  node: node,
                  isActive: active?.storageKey == node.storageKey,
                ),
                if (node != items.last) const Divider(height: 1),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('Discovery failed: $error'),
      ),
    );
  }
}

class _DiscoveredDeviceTile extends ConsumerWidget {
  const _DiscoveredDeviceTile({required this.node, required this.isActive});

  final DeviceNode node;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.sensors_rounded),
      title: Text(node.displayName),
      subtitle: Text('${node.ip}  RSSI ${node.rssi} dBm'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(isOnline: node.isOnline),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Save device',
            onPressed: () async {
              await ref.read(savedDevicesProvider.notifier).add(node);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${node.displayName} saved.')),
                );
              }
            },
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Set active',
            onPressed: () async {
              await ref.read(activeNodeProvider.notifier).select(node);
              ref.invalidate(dashboardProvider);
              ref.invalidate(fftSpectrumProvider);
              ref.invalidate(mqttConfigProvider);
              ref.invalidate(networkConfigProvider);
              ref.invalidate(memsConfigProvider);
              ref.invalidate(operateConfigProvider);
              ref.invalidate(systemConfigProvider);
            },
            icon: Icon(
              isActive ? Icons.check_circle : Icons.play_circle_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDevicesSection extends ConsumerWidget {
  const _SavedDevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDevicesProvider);
    final active = ref.watch(activeNodeProvider);

    return SectionCard(
      title: 'Saved Devices (${saved.length}/32)',
      child: saved.isEmpty
          ? const Text('No saved devices yet.')
          : Column(
              children: [
                for (final node in saved) ...[
                  _SavedDeviceTile(
                    node: node,
                    isActive: active?.storageKey == node.storageKey,
                  ),
                  if (node != saved.last) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

class _SavedDeviceTile extends ConsumerWidget {
  const _SavedDeviceTile({required this.node, required this.isActive});

  final DeviceNode node;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isActive ? Icons.memory_rounded : Icons.device_hub_rounded),
      title: Text(node.displayName),
      subtitle: Text('${node.baseUrl}\nNode: ${node.name}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) const Chip(label: Text('Active')),
          IconButton(
            tooltip: 'Rename device',
            onPressed: () => _renameDevice(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove device',
            onPressed: () async {
              await ref.read(savedDevicesProvider.notifier).remove(node);
              if (isActive) {
                await ref.read(activeNodeProvider.notifier).select(null);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      onTap: () async {
        await ref.read(activeNodeProvider.notifier).select(node);
        ref.invalidate(dashboardProvider);
        ref.invalidate(fftSpectrumProvider);
        ref.invalidate(mqttConfigProvider);
        ref.invalidate(networkConfigProvider);
        ref.invalidate(memsConfigProvider);
        ref.invalidate(operateConfigProvider);
        ref.invalidate(systemConfigProvider);
      },
    );
  }

  Future<void> _renameDevice(BuildContext context, WidgetRef ref) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDeviceDialog(
        initialValue: node.customName ?? '',
        hintText: node.name,
      ),
    );
    if (renamed == null || !context.mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(savedDevicesProvider.notifier).rename(node, renamed);
    });
  }
}

class _RenameDeviceDialog extends StatefulWidget {
  const _RenameDeviceDialog({
    required this.initialValue,
    required this.hintText,
  });

  final String initialValue;
  final String hintText;

  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set device name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Custom device name',
          hintText: widget.hintText,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop('');
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop(_controller.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
