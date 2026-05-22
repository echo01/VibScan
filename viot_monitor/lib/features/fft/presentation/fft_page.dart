import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/device_node.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/node_header.dart';
import '../../../shared/widgets/section_card.dart';

class FftPage extends ConsumerWidget {
  const FftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const FftPanel(showHeader: true);
  }
}

class FftPanel extends ConsumerWidget {
  const FftPanel({super.key, required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNode = ref.watch(activeNodeProvider);
    final savedDevices = ref.watch(savedDevicesProvider);
    final axis = ref.watch(fftAxisProvider);
    final spectrum = ref.watch(fftSpectrumProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showHeader)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NodeHeader(
                title: 'FFT Analyzer',
                subtitle: activeNode == null
                    ? 'No active node selected'
                    : activeNode.displayName,
                trailing: FilledButton.tonalIcon(
                  onPressed: activeNode == null
                      ? null
                      : () => ref.invalidate(fftSpectrumProvider),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: const Text('Load FFT'),
                ),
              ),
              const SizedBox(height: 12),
              _SavedDeviceSelector(
                activeNode: activeNode,
                savedDevices: savedDevices,
              ),
            ],
          )
        else
          SectionCard(
            title: 'FFT Analyzer',
            action: FilledButton.tonalIcon(
              onPressed: activeNode == null
                  ? null
                  : () => ref.invalidate(fftSpectrumProvider),
              icon: const Icon(Icons.show_chart_rounded),
              label: const Text('Load FFT'),
            ),
            child: _SavedDeviceSelector(
              activeNode: activeNode,
              savedDevices: savedDevices,
            ),
          ),
        if (savedDevices.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('Save a device first, then select it here to load FFT.'),
        ],
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'X', label: Text('X')),
            ButtonSegment(value: 'Y', label: Text('Y')),
            ButtonSegment(value: 'Z', label: Text('Z')),
          ],
          selected: {axis},
          onSelectionChanged: (selection) {
            ref.read(fftAxisProvider.notifier).update(selection.first);
            ref.invalidate(fftSpectrumProvider);
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Spectrum',
          child: SizedBox(
            height: 280,
            child: spectrum.when(
              data: (fft) {
                if (fft == null) {
                  return const Center(
                    child: Text('Select a device to view FFT.'),
                  );
                }
                if (fft.data.isEmpty) {
                  return Center(
                    child: Text(
                      'FFT response received but no spectrum points were found for axis ${fft.axis}.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (final point in fft.data)
                            FlSpot(point.frequency, point.amplitude),
                        ],
                        isCurved: true,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  _friendlyFftError(error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Info',
          child: spectrum.when(
            data: (fft) {
              if (fft == null) {
                return const Text('No FFT data loaded.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample Rate: ${fft.sampleRate} Hz'),
                  Text('Points: ${fft.pointCount}'),
                  Text(
                    'Peak Frequency: ${fft.peakFrequency.toStringAsFixed(1)} Hz',
                  ),
                  Text(
                    'Max Amplitude: ${fft.maxAmplitude.toStringAsFixed(3)} mm/s',
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: activeNode == null
                    ? null
                    : () async {
                        final fft = await ref.read(fftSpectrumProvider.future);
                        if (fft == null) {
                          return;
                        }
                        final file = await ref
                            .read(csvExportServiceProvider)
                            .saveFftCsv(node: activeNode, spectrum: fft);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved ${file.savedLocation}'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Save CSV'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: activeNode == null
                    ? null
                    : () async {
                        final fft = await ref.read(fftSpectrumProvider.future);
                        if (fft == null) {
                          return;
                        }
                        final file = await ref
                            .read(csvExportServiceProvider)
                            .saveFftCsv(node: activeNode, spectrum: fft);
                        await ref
                            .read(csvExportServiceProvider)
                            .shareFile(
                              file.shareFile,
                              subject:
                                  'VIOT FFT Export - ${activeNode.displayName} - Axis ${fft.axis}',
                            );
                      },
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Share Email'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _friendlyFftError(Object error) {
  final text = error.toString();
  if (text.contains('403')) {
    return 'HTTP FFT is available only in debug mode on this firmware.';
  }
  if (text.contains('409') || text.contains('FFT is busy')) {
    return 'FFT is busy. Another FFT job is running, please try again shortly.';
  }
  if (text.contains('503')) {
    return 'ESP32 has low memory for FFT right now. Try again after MQTT/network activity settles.';
  }
  if (text.contains('timeout')) {
    return 'FFT request timed out. Check the node connection and try Load FFT again.';
  }
  return 'Failed to load FFT: $error';
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
              ref.invalidate(fftSpectrumProvider);
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
