import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/device_node.dart';
import '../../../core/models/mqtt_publish_summary.dart';
import '../../../core/models/mqtt_runtime_status.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/node_header.dart';
import '../../../shared/widgets/section_card.dart';

class MqttPage extends ConsumerWidget {
  const MqttPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNode = ref.watch(activeNodeProvider);
    final savedDevices = ref.watch(savedDevicesProvider);
    final summary = ref.watch(mqttPublishSummaryProvider);
    final runtimeStatus = ref.watch(mqttRuntimeStatusProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NodeHeader(
          title: 'MQTT Monitor',
          subtitle: activeNode == null
              ? 'No active node selected'
              : activeNode.displayName,
          trailing: FilledButton.tonalIcon(
            onPressed: activeNode == null
                ? null
                : () {
                    ref.invalidate(mqttRuntimeStatusProvider);
                    ref.invalidate(mqttPublishSummaryProvider);
                  },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 12),
        _SavedDeviceSelector(
          activeNode: activeNode,
          savedDevices: savedDevices,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'MQTT Status',
          child: runtimeStatus.when(
            data: (value) {
              if (activeNode == null) {
                return const Text('Select a device to monitor MQTT status.');
              }
              if (value == null) {
                return const Text('Reconnecting to MQTT status...');
              }
              return _MqttRuntimeStatusView(node: activeNode, status: value);
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => _RetryPanel(
              message: 'Failed to load MQTT status: $error',
              onRetry: () {
                ref.invalidate(mqttRuntimeStatusProvider);
                ref.invalidate(mqttPublishSummaryProvider);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'MQTT Publish Summary',
          child: summary.when(
            data: (value) {
              if (activeNode == null) {
                return const Text(
                  'Select a device to load MQTT publish summary.',
                );
              }
              if (value == null) {
                return const Text('Reconnecting to MQTT publish summary...');
              }
              return _MqttSummaryGrid(summary: value);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _RetryPanel(
              message: 'Failed to load MQTT summary: $error',
              onRetry: () {
                ref.invalidate(mqttPublishSummaryProvider);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MqttRuntimeStatusView extends ConsumerWidget {
  const _MqttRuntimeStatusView({required this.node, required this.status});

  final DeviceNode node;
  final MqttRuntimeStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = status.connected;
    final color = isConnected
        ? const Color(0xFF22C55E)
        : Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusChip(
              icon: isConnected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              label: isConnected ? 'Connected' : 'Disconnected',
              color: color,
            ),
            _StatusChip(
              icon: Icons.sync_alt_rounded,
              label: status.status.isEmpty ? 'Status unknown' : status.status,
              color: color,
            ),
            _StatusChip(
              icon: Icons.security_rounded,
              label: status.useTls ? 'TLS enabled' : 'TLS disabled',
              color: const Color(0xFF38BDF8),
            ),
            if (status.retryLimited)
              _StatusChip(
                icon: Icons.warning_amber_rounded,
                label: 'Retry limited',
                color: Theme.of(context).colorScheme.error,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (status.broker.isNotEmpty) Text('Broker: ${status.broker}'),
        Text(
          'Connect failures: ${status.connectFailures}/${status.connectFailureLimit}',
        ),
        if (status.retryLimitedLoops > 0)
          Text('Retry limited loops: ${status.retryLimitedLoops}'),
        if (status.recoveryMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(status.recoveryMessage),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _confirmReboot(context, ref),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart MQTT'),
        ),
      ],
    );
  }

  Future<void> _confirmReboot(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart MQTT?'),
        content: Text(
          'This action will reboot ESP32 ${node.displayName} using /api/reboot. It will not factory reset the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reboot'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(viotRepositoryProvider).rebootNode(node);
    ref.invalidate(mqttRuntimeStatusProvider);
    ref.invalidate(mqttPublishSummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reboot command sent to ${node.displayName}.')),
      );
    }
  }
}

class _SavedDeviceSelector extends ConsumerWidget {
  const _SavedDeviceSelector({
    required this.activeNode,
    required this.savedDevices,
  });

  final DeviceNode? activeNode;
  final List<DeviceNode> savedDevices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId =
        savedDevices.any((node) => node.storageKey == activeNode?.storageKey)
        ? activeNode?.storageKey
        : null;

    return DropdownButtonFormField<String>(
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
              await ref.read(activeNodeProvider.notifier).select(selected);
              ref.invalidate(mqttRuntimeStatusProvider);
              ref.invalidate(mqttPublishSummaryProvider);
            },
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

class _MqttSummaryGrid extends StatelessWidget {
  const _MqttSummaryGrid({required this.summary});

  final MqttPublishSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCardData(label: 'Last Result', value: _title(summary.lastResult)),
      _SummaryCardData(
        label: 'Last Sent',
        value: summary.lastSentText ?? _secondsAgo(summary.lastSentAgoSec),
      ),
      _SummaryCardData(
        label: 'Next Send',
        value: summary.nextSendText ?? _seconds(summary.nextSendInSec),
      ),
      _SummaryCardData(
        label: 'Publish Count',
        value: '${summary.publishCount}',
      ),
      _SummaryCardData(
        label: 'TLS Connect',
        value: summary.tlsConnectState.isEmpty
            ? 'Unknown'
            : _title(summary.tlsConnectState),
      ),
      _SummaryCardData(
        label: 'Subscribe RX',
        value: summary.subscribeRxAgoSec == null
            ? '${summary.subscribeRxCount}'
            : _secondsAgo(summary.subscribeRxAgoSec),
      ),
      _SummaryCardData(label: 'Last RX', value: _bytes(summary.lastRxBytes)),
      _SummaryCardData(
        label: 'Main Payload',
        value: _bytes(summary.mainPayloadBytes),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 620
            ? 3
            : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _SummaryCard(card: card),
              ),
          ],
        );
      },
    );
  }

  String _title(String value) {
    if (value.isEmpty) {
      return 'Unknown';
    }
    final lower = value.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _secondsAgo(int? value) {
    if (value == null) {
      return '-';
    }
    return '$value sec ago';
  }

  String _seconds(int? value) {
    if (value == null) {
      return '-';
    }
    return '$value sec';
  }

  String _bytes(int value) {
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card});

  final _SummaryCardData card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            card.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
    );
  }
}
