import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dashboard_metric.dart';
import '../../../core/models/device_node.dart';
import '../../../core/models/fft_spectrum.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/node_header.dart';
import '../../../shared/widgets/section_card.dart';

class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends ConsumerState<DeviceListPage> {
  _MachineClass _machineClass = _MachineClass.classI;
  bool _deviceCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final live = ref.read(dashboardLiveProvider.notifier);
      live.updateSampleInterval(3);
      live.start(ref.read(activeNodeProvider));
    });
  }

  @override
  void dispose() {
    ref.read(dashboardLiveProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedDevices = ref.watch(savedDevicesProvider);
    final discovered = ref.watch(discoveredDevicesProvider);
    final activeNode = ref.watch(activeNodeProvider);
    final live = ref.watch(dashboardLiveProvider);
    final metrics = live.latestMetrics;
    final availableDevices = _mergeDevices(
      savedDevices,
      discovered.value ?? [],
    );

    ref.listen<DeviceNode?>(activeNodeProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final liveNotifier = ref.read(dashboardLiveProvider.notifier);
        liveNotifier.updateSampleInterval(3);
        liveNotifier.start(next);
      });
    });

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: NodeHeader(
              title: 'Analyze',
              subtitle: activeNode == null
                  ? 'Select a readable device'
                  : '${activeNode.displayName} - sampling every 3 seconds',
              trailing: IconButton.filledTonal(
                tooltip: 'Refresh now',
                onPressed: activeNode == null
                    ? null
                    : () =>
                          ref.read(dashboardLiveProvider.notifier).refreshNow(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildDeviceSection(
              context: context,
              discovered: discovered,
              availableDevices: availableDevices,
              activeNode: activeNode,
              live: live,
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Machine Health'),
              Tab(text: 'VibScan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AnalyzeTabScrollView(
                  children: [
                    _MachineHealthSection(
                      activeNode: activeNode,
                      metrics: metrics,
                      machineClass: _machineClass,
                      onMachineClassChanged: (value) =>
                          setState(() => _machineClass = value),
                    ),
                  ],
                ),
                _VibScanTab(activeNode: activeNode, metrics: metrics),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection({
    required BuildContext context,
    required AsyncValue<List<DeviceNode>> discovered,
    required List<DeviceNode> availableDevices,
    required DeviceNode? activeNode,
    required DashboardLiveState live,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.sensors_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device', style: theme.textTheme.titleMedium),
                      Text(
                        activeNode == null
                            ? 'Select a readable device'
                            : activeNode.displayNameWithEndpoint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Discover devices',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.invalidate(discoveredDevicesProvider),
                  icon: const Icon(Icons.radar_rounded),
                ),
                IconButton(
                  tooltip: _deviceCollapsed
                      ? 'Expand device'
                      : 'Collapse device',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _deviceCollapsed = !_deviceCollapsed),
                  icon: Icon(
                    _deviceCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _deviceCollapsed
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDeviceKey(
                        availableDevices,
                        activeNode,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Readable device',
                        prefixIcon: Icon(Icons.sensors_rounded),
                      ),
                      items: [
                        for (final node in availableDevices)
                          DropdownMenuItem(
                            value: node.storageKey,
                            child: Text(
                              node.displayNameWithEndpoint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: availableDevices.isEmpty
                          ? null
                          : (key) => _selectDevice(availableDevices, key),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const _CompactStatusChip(
                          icon: Icons.update_rounded,
                          label: '3 sec',
                        ),
                        if (live.lastUpdated != null)
                          _CompactStatusChip(
                            icon: Icons.schedule_rounded,
                            label: 'Last ${_clock(live.lastUpdated!)}',
                          ),
                        if (live.isLoading)
                          const _CompactStatusChip(
                            icon: Icons.sync_rounded,
                            label: 'Reading',
                          ),
                      ],
                    ),
                    if (availableDevices.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        discovered.isLoading
                            ? 'Discovering devices...'
                            : 'No saved or discovered devices found.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (live.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last read failed: ${live.error}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DeviceNode> _mergeDevices(
    List<DeviceNode> saved,
    List<DeviceNode> discovered,
  ) {
    final byKey = <String, DeviceNode>{};
    for (final node in [...saved, ...discovered]) {
      byKey[node.storageKey] = node;
    }
    return byKey.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  String? _selectedDeviceKey(List<DeviceNode> devices, DeviceNode? active) {
    if (active == null) {
      return null;
    }
    return devices.any((node) => node.storageKey == active.storageKey)
        ? active.storageKey
        : null;
  }

  Future<void> _selectDevice(List<DeviceNode> devices, String? key) async {
    final selected = _findDevice(devices, key);
    if (selected == null) {
      return;
    }
    await ref.read(activeNodeProvider.notifier).select(selected);
  }

  DeviceNode? _findDevice(List<DeviceNode> devices, String? key) {
    for (final node in devices) {
      if (node.storageKey == key) {
        return node;
      }
    }
    return null;
  }
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _AnalyzeTabScrollView extends StatelessWidget {
  const _AnalyzeTabScrollView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemCount: children.length,
    );
  }
}

class _VibScanTab extends ConsumerStatefulWidget {
  const _VibScanTab({required this.activeNode, required this.metrics});

  final DeviceNode? activeNode;
  final List<DashboardMetric> metrics;

  @override
  ConsumerState<_VibScanTab> createState() => _VibScanTabState();
}

class _VibScanTabState extends ConsumerState<_VibScanTab> {
  final TextEditingController _rpmController = TextEditingController(
    text: '1500',
  );
  String _axis = 'X';
  bool _scanning = false;
  String? _error;
  FftSpectrum? _spectrum;
  _FaultAnalysisResult? _result;

  @override
  void dispose() {
    _rpmController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final node = widget.activeNode;
    final rpm = double.tryParse(_rpmController.text.trim());
    if (node == null) {
      setState(() => _error = 'Select a device before running VibScan.');
      return;
    }
    if (rpm == null || rpm <= 0) {
      setState(() => _error = 'Enter RPM greater than 0.');
      return;
    }

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final spectrum = await ref
          .read(viotRepositoryProvider)
          .fetchFft(node, _axis);
      final result = _FaultAnalyzer.analyze(
        spectrum: spectrum,
        rpm: rpm,
        metrics: widget.metrics,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _spectrum = spectrum;
        _result = result;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'VibScan failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rpm = double.tryParse(_rpmController.text.trim());
    final shaftFrequencyHz = rpm == null || rpm <= 0 ? null : rpm / 60;

    return _AnalyzeTabScrollView(
      children: [
        SectionCard(
          title: 'VibScan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan vibration spectrum and identify machine issues quickly.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                widget.activeNode == null
                    ? 'Select a device above, enter RPM, then scan FFT spectrum.'
                    : 'Selected device: ${widget.activeNode!.displayName}',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rpmController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'RPM',
                  prefixIcon: Icon(Icons.speed_rounded),
                  helperText: '1X frequency = RPM / 60',
                ),
              ),
              const SizedBox(height: 12),
              if (shaftFrequencyHz == null)
                Text(
                  'Enter RPM to calculate frequency in Hz.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                _FaultKeyValueGrid(
                  entries: [
                    _FaultEntry(
                      '1X frequency',
                      '${shaftFrequencyHz.toStringAsFixed(2)} Hz',
                    ),
                    _FaultEntry(
                      '2X frequency',
                      '${(shaftFrequencyHz * 2).toStringAsFixed(2)} Hz',
                    ),
                    _FaultEntry(
                      '3X frequency',
                      '${(shaftFrequencyHz * 3).toStringAsFixed(2)} Hz',
                    ),
                    _FaultEntry(
                      'RPM',
                      rpm!.toStringAsFixed(
                        rpm.truncateToDouble() == rpm ? 0 : 1,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'X', label: Text('X')),
                  ButtonSegment(value: 'Y', label: Text('Y')),
                  ButtonSegment(value: 'Z', label: Text('Z')),
                ],
                selected: {_axis},
                onSelectionChanged: _scanning
                    ? null
                    : (selection) => setState(() => _axis = selection.first),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.query_stats_rounded),
                  label: Text(_scanning ? 'Scanning...' : 'Scan FFT'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        if (_result != null)
          _FaultResultCard(result: _result!, spectrum: _spectrum),
      ],
    );
  }
}

class _FaultResultCard extends StatelessWidget {
  const _FaultResultCard({required this.result, required this.spectrum});

  final _FaultAnalysisResult result;
  final FftSpectrum? spectrum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (result.status) {
      'Critical' => const Color(0xFFD32F2F),
      'Warning' => const Color(0xFFF9A825),
      'Suspected' => const Color(0xFF38BDF8),
      _ => theme.colorScheme.primary,
    };

    return SectionCard(
      title: 'Fault Identification',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: statusColor.withValues(alpha: 0.14),
              border: Border.all(color: statusColor.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.status,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.mainFault}${result.subtype == null ? '' : ' - ${result.subtype}'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Confidence ${result.confidence}/100'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FaultKeyValueGrid(
            entries: [
              _FaultEntry('Axis', spectrum?.axis ?? '-'),
              _FaultEntry(
                '1X',
                '${result.shaftFrequencyHz.toStringAsFixed(1)} Hz',
              ),
              _FaultEntry(
                'Main peak',
                '${result.mainPeakHz.toStringAsFixed(1)} Hz',
              ),
              _FaultEntry('FFT points', '${spectrum?.pointCount ?? 0}'),
            ],
          ),
          if (spectrum != null && spectrum!.data.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SpectrumFftChart(spectrum: spectrum!, result: result),
          ],
          const SizedBox(height: 14),
          _FaultScoreBars(scores: result.scores),
          const SizedBox(height: 14),
          _OrderAmplitudeTable(result: result),
          const SizedBox(height: 14),
          Text('Reason', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final reason in result.reasons)
            _FaultBullet(text: reason, icon: Icons.check_circle_outline),
          const SizedBox(height: 12),
          Text('Recommendation', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final item in result.recommendations)
            _FaultBullet(text: item, icon: Icons.build_rounded),
          const SizedBox(height: 12),
          Text(
            'Uses FFT order rules from Fault_Identification.md. Bearing result is a simple suspected rule unless bearing geometry is configured.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultKeyValueGrid extends StatelessWidget {
  const _FaultKeyValueGrid({required this.entries});

  final List<_FaultEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 4 : 2;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: _FaultValueTile(entry: entry),
              ),
          ],
        );
      },
    );
  }
}

class _SpectrumFftChart extends StatelessWidget {
  const _SpectrumFftChart({required this.spectrum, required this.result});

  final FftSpectrum spectrum;
  final _FaultAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final points = spectrum.data;
    final maxFrequency = points
        .map((point) => point.frequency)
        .fold(0.0, math.max);
    final minPositiveAmplitude = points
        .where((point) => point.amplitude > 0)
        .map((point) => point.amplitude)
        .fold<double>(double.infinity, math.min);
    final maxAmplitude = points
        .map((point) => point.amplitude)
        .fold(0.0, math.max);
    final markers = [
      _SpectrumMarker('1X', result.shaftFrequencyHz, result.amp1x),
      _SpectrumMarker('2X', result.shaftFrequencyHz * 2, result.amp2x),
      _SpectrumMarker('3X', result.shaftFrequencyHz * 3, result.amp3x),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF07110F),
        border: Border.all(color: const Color(0xFF1F3B34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spectrum (FFT)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text('mm/s', style: TextStyle(color: Color(0xFFB9C8C1))),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpectrumChartPainter(
                points: points,
                markers: markers,
                maxFrequency: maxFrequency <= 0 ? 1 : maxFrequency,
                minAmplitude: minPositiveAmplitude.isFinite
                    ? minPositiveAmplitude
                    : 0.001,
                maxAmplitude: maxAmplitude <= 0 ? 1 : maxAmplitude,
              ),
            ),
          ),
          const Divider(color: Color(0xFF1F3B34), height: 24),
          Row(
            children: [
              Expanded(
                child: _SpectrumReadout(
                  label: 'Cursor',
                  value:
                      '${result.shaftFrequencyHz.toStringAsFixed(1)} Hz (1X)',
                ),
              ),
              Container(width: 1, height: 48, color: const Color(0xFF1F3B34)),
              const SizedBox(width: 16),
              Expanded(
                child: _SpectrumReadout(
                  label: 'Amplitude',
                  value: '${result.amp1x.toStringAsFixed(2)} mm/s',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpectrumReadout extends StatelessWidget {
  const _SpectrumReadout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB9C8C1),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpectrumMarker {
  const _SpectrumMarker(this.label, this.frequency, this.amplitude);

  final String label;
  final double frequency;
  final double amplitude;
}

class _SpectrumChartPainter extends CustomPainter {
  const _SpectrumChartPainter({
    required this.points,
    required this.markers,
    required this.maxFrequency,
    required this.minAmplitude,
    required this.maxAmplitude,
  });

  final List<dynamic> points;
  final List<_SpectrumMarker> markers;
  final double maxFrequency;
  final double minAmplitude;
  final double maxAmplitude;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 8.0;
    const right = 6.0;
    const bottom = 28.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFF18342D)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5522C55E), Color(0x220EA56B)],
      ).createShader(chart);
    final linePaint = Paint()
      ..color = const Color(0xFF38D36B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = const Color(0xFF244A41)
      ..strokeWidth = 1.2;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final minLog = math.log(math.max(minAmplitude, 0.001));
    final maxLog = math.log(math.max(maxAmplitude, minAmplitude * 10));

    double xFor(double frequency) {
      return chart.left +
          (frequency / maxFrequency).clamp(0.0, 1.0) * chart.width;
    }

    double yFor(double amplitude) {
      final safeAmp = math.max(amplitude, minAmplitude);
      final normalized = ((math.log(safeAmp) - minLog) / (maxLog - minLog))
          .clamp(0.0, 1.0);
      return chart.bottom - normalized * chart.height;
    }

    canvas.drawRect(chart, Paint()..color = const Color(0xFF061B17));
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    for (var i = 0; i <= 4; i++) {
      final x = chart.left + chart.width * i / 4;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
    }
    canvas.drawRect(chart, axisPaint..style = PaintingStyle.stroke);

    final line = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final offset = Offset(xFor(point.frequency), yFor(point.amplitude));
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
        fill
          ..moveTo(offset.dx, chart.bottom)
          ..lineTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
        fill.lineTo(offset.dx, offset.dy);
      }
    }
    if (points.isNotEmpty) {
      fill.lineTo(xFor(points.last.frequency), chart.bottom);
      fill.close();
      canvas.drawPath(fill, fillPaint);
      canvas.drawPath(line, linePaint);
    }

    _drawYAxisLabels(canvas, textPainter, chart);
    _drawXAxisLabels(canvas, textPainter, chart);
    for (final marker in markers) {
      _drawMarker(canvas, textPainter, marker, xFor, yFor, chart);
    }
  }

  void _drawYAxisLabels(Canvas canvas, TextPainter textPainter, Rect chart) {
    final values = [
      maxAmplitude,
      math.sqrt(maxAmplitude * minAmplitude),
      minAmplitude,
    ];
    for (final value in values) {
      final y = _logY(value, chart);
      textPainter
        ..text = TextSpan(
          text: value >= 1
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(2),
          style: const TextStyle(color: Color(0xFFE5ECE8), fontSize: 12),
        )
        ..layout(maxWidth: 36);
      textPainter.paint(
        canvas,
        Offset(chart.left - textPainter.width - 8, y - 8),
      );
    }
  }

  void _drawXAxisLabels(Canvas canvas, TextPainter textPainter, Rect chart) {
    for (var i = 0; i <= 4; i++) {
      final value = maxFrequency * i / 4;
      final x = chart.left + chart.width * i / 4;
      textPainter
        ..text = TextSpan(
          text: i == 4
              ? '${value.toStringAsFixed(0)} Hz'
              : value.toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFFE5ECE8), fontSize: 12),
        )
        ..layout(maxWidth: 54);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chart.bottom + 8),
      );
    }
  }

  double _logY(double amplitude, Rect chart) {
    final minLog = math.log(math.max(minAmplitude, 0.001));
    final maxLog = math.log(math.max(maxAmplitude, minAmplitude * 10));
    final normalized =
        ((math.log(math.max(amplitude, minAmplitude)) - minLog) /
                (maxLog - minLog))
            .clamp(0.0, 1.0);
    return chart.bottom - normalized * chart.height;
  }

  void _drawMarker(
    Canvas canvas,
    TextPainter textPainter,
    _SpectrumMarker marker,
    double Function(double frequency) xFor,
    double Function(double amplitude) yFor,
    Rect chart,
  ) {
    if (marker.frequency <= 0 || marker.amplitude <= 0) {
      return;
    }
    final x = xFor(marker.frequency);
    final y = yFor(marker.amplitude);
    if (x < chart.left || x > chart.right) {
      return;
    }

    final bubble = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, math.max(chart.top + 18, y - 32)),
        width: 38,
        height: 30,
      ),
      const Radius.circular(7),
    );
    final bubblePaint = Paint()..color = const Color(0xFF756B0B);
    canvas.drawLine(
      Offset(x, bubble.bottom),
      Offset(x, y),
      bubblePaint..strokeWidth = 2,
    );
    canvas.drawRRect(bubble, bubblePaint);
    textPainter
      ..text = TextSpan(
        text: marker.label,
        style: const TextStyle(
          color: Color(0xFFF7F2A4),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      )
      ..layout(maxWidth: 36);
    textPainter.paint(
      canvas,
      Offset(
        bubble.center.dx - textPainter.width / 2,
        bubble.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SpectrumChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxFrequency != maxFrequency ||
        oldDelegate.minAmplitude != minAmplitude ||
        oldDelegate.maxAmplitude != maxAmplitude ||
        oldDelegate.markers != markers;
  }
}

class _FaultValueTile extends StatelessWidget {
  const _FaultValueTile({required this.entry});

  final _FaultEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            entry.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultScoreBars extends StatelessWidget {
  const _FaultScoreBars({required this.scores});

  final Map<String, int> scores;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scores', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final entry in scores.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FaultScoreBar(label: entry.key, score: entry.value),
          ),
      ],
    );
  }
}

class _FaultScoreBar extends StatelessWidget {
  const _FaultScoreBar({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score.clamp(0, 100) / 100,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 32, child: Text('$score', textAlign: TextAlign.end)),
      ],
    );
  }
}

class _OrderAmplitudeTable extends StatelessWidget {
  const _OrderAmplitudeTable({required this.result});

  final _FaultAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      _FaultEntry('0.5X', result.ampHalfX.toStringAsFixed(3)),
      _FaultEntry('1X', result.amp1x.toStringAsFixed(3)),
      _FaultEntry('2X', result.amp2x.toStringAsFixed(3)),
      _FaultEntry('3X', result.amp3x.toStringAsFixed(3)),
      _FaultEntry('Harmonics', '${result.harmonicCount}/10'),
      _FaultEntry('Resolution', '${result.resolutionHz.toStringAsFixed(2)} Hz'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order amplitudes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _FaultKeyValueGrid(entries: rows),
      ],
    );
  }
}

class _FaultBullet extends StatelessWidget {
  const _FaultBullet({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FaultEntry {
  const _FaultEntry(this.label, this.value);

  final String label;
  final String value;
}

class _FaultAnalysisResult {
  const _FaultAnalysisResult({
    required this.status,
    required this.mainFault,
    required this.subtype,
    required this.confidence,
    required this.shaftFrequencyHz,
    required this.mainPeakHz,
    required this.resolutionHz,
    required this.ampHalfX,
    required this.amp1x,
    required this.amp2x,
    required this.amp3x,
    required this.harmonicCount,
    required this.scores,
    required this.reasons,
    required this.recommendations,
  });

  final String status;
  final String mainFault;
  final String? subtype;
  final int confidence;
  final double shaftFrequencyHz;
  final double mainPeakHz;
  final double resolutionHz;
  final double ampHalfX;
  final double amp1x;
  final double amp2x;
  final double amp3x;
  final int harmonicCount;
  final Map<String, int> scores;
  final List<String> reasons;
  final List<String> recommendations;
}

class _FaultAnalyzer {
  const _FaultAnalyzer._();

  static _FaultAnalysisResult analyze({
    required FftSpectrum spectrum,
    required double rpm,
    required List<DashboardMetric> metrics,
  }) {
    final points = spectrum.data;
    final maxAmplitude = points.isEmpty
        ? 0.0
        : points.map((point) => point.amplitude).reduce(math.max);
    final mainPeak = points.isEmpty
        ? 0.0
        : points
              .reduce(
                (best, point) =>
                    point.amplitude > best.amplitude ? point : best,
              )
              .frequency;
    final resolution = _resolutionHz(spectrum);
    final f1x = rpm / 60;
    final ampHalfX = _findAmplitude(points, f1x * 0.5, resolution).amplitude;
    final amp1x = _findAmplitude(points, f1x, resolution).amplitude;
    final amp2x = _findAmplitude(points, f1x * 2, resolution).amplitude;
    final amp3x = _findAmplitude(points, f1x * 3, resolution).amplitude;
    final significant = math.max(maxAmplitude * 0.25, 0.001);
    final strong = math.max(maxAmplitude * 0.35, 0.001);
    final harmonicThreshold = math.max(maxAmplitude * 0.18, 0.001);
    var harmonicCount = 0;
    for (var order = 1; order <= 10; order++) {
      final amp = _findAmplitude(points, f1x * order, resolution).amplitude;
      if (amp > harmonicThreshold) {
        harmonicCount++;
      }
    }

    final radialRms = math.sqrt(
      math.pow(_metricValue(metrics, 'velocity_x') ?? 0, 2) +
          math.pow(_metricValue(metrics, 'velocity_y') ?? 0, 2),
    );
    final axialRms = _metricValue(metrics, 'velocity_z') ?? 0;
    final axialRadialRatio = radialRms <= 0 ? 0.0 : axialRms / radialRms;
    final highBand = _averageAmplitude(
      points.where((point) => point.frequency >= f1x * 5),
    );
    final lowBand = _averageAmplitude(
      points.where((point) => point.frequency > 0 && point.frequency < f1x * 5),
    );

    final scores = <String, int>{
      'Unbalance': _scoreUnbalance(
        amp1x: amp1x,
        amp2x: amp2x,
        amp3x: amp3x,
        threshold: significant,
        radialRms: radialRms,
        axialRms: axialRms,
      ),
      'Misalignment': _scoreMisalignment(
        amp1x: amp1x,
        amp2x: amp2x,
        threshold: significant,
        axialRadialRatio: axialRadialRatio,
      ),
      'Looseness': _scoreLooseness(
        harmonicCount: harmonicCount,
        ampHalfX: ampHalfX,
        threshold: harmonicThreshold,
        highBand: highBand,
        lowBand: lowBand,
      ),
      'Bearing': _scoreBearing(
        highBand: highBand,
        lowBand: lowBand,
        strongThreshold: strong,
      ),
    };

    final main = scores.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    );
    final subtype = main.key == 'Misalignment'
        ? axialRadialRatio >= 0.5
              ? 'Angular Misalignment'
              : 'Parallel Misalignment'
        : main.key == 'Bearing'
        ? 'Suspected Bearing Defect'
        : null;
    return _FaultAnalysisResult(
      status: _statusFor(main.value),
      mainFault: main.value < 50 ? 'Normal or Unknown' : main.key,
      subtype: main.value < 50 ? null : subtype,
      confidence: main.value,
      shaftFrequencyHz: f1x,
      mainPeakHz: mainPeak,
      resolutionHz: resolution,
      ampHalfX: ampHalfX,
      amp1x: amp1x,
      amp2x: amp2x,
      amp3x: amp3x,
      harmonicCount: harmonicCount,
      scores: scores,
      reasons: _reasons(
        main.key,
        amp1x: amp1x,
        amp2x: amp2x,
        amp3x: amp3x,
        harmonicCount: harmonicCount,
        ampHalfX: ampHalfX,
        axialRadialRatio: axialRadialRatio,
        highBand: highBand,
        lowBand: lowBand,
        threshold: significant,
      ),
      recommendations: _recommendations(main.value < 50 ? 'Normal' : main.key),
    );
  }

  static double _resolutionHz(FftSpectrum spectrum) {
    if (spectrum.sampleRate > 0 && spectrum.pointCount > 0) {
      return spectrum.sampleRate / spectrum.pointCount;
    }
    final frequencies = spectrum.data.map((point) => point.frequency).toList()
      ..sort();
    var best = double.infinity;
    for (var i = 1; i < frequencies.length; i++) {
      final diff = frequencies[i] - frequencies[i - 1];
      if (diff > 0 && diff < best) {
        best = diff;
      }
    }
    return best.isFinite ? best : 1;
  }

  static _TargetPeak _findAmplitude(
    List<dynamic> points,
    double targetHz,
    double resolutionHz,
  ) {
    final tolerance = math.max(resolutionHz, targetHz * 0.05);
    var peakHz = 0.0;
    var maxAmp = 0.0;
    for (final point in points) {
      if ((point.frequency - targetHz).abs() <= tolerance &&
          point.amplitude > maxAmp) {
        peakHz = point.frequency;
        maxAmp = point.amplitude;
      }
    }
    return _TargetPeak(peakHz, maxAmp);
  }

  static double _averageAmplitude(Iterable<dynamic> points) {
    var sum = 0.0;
    var count = 0;
    for (final point in points) {
      sum += point.amplitude;
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  static int _scoreUnbalance({
    required double amp1x,
    required double amp2x,
    required double amp3x,
    required double threshold,
    required double radialRms,
    required double axialRms,
  }) {
    var score = 0;
    if (amp1x > threshold) score += 40;
    if (amp2x < 0.5 * amp1x) score += 25;
    if (amp3x < 0.3 * amp1x) score += 15;
    if (radialRms > axialRms) score += 20;
    return score.clamp(0, 100);
  }

  static int _scoreMisalignment({
    required double amp1x,
    required double amp2x,
    required double threshold,
    required double axialRadialRatio,
  }) {
    var score = 0;
    if (amp1x > 0 && amp2x >= 0.8 * amp1x) score += 40;
    if (amp2x > threshold) score += 20;
    if (axialRadialRatio >= 0.5) score += 25;
    if (amp1x > threshold) score += 15;
    return score.clamp(0, 100);
  }

  static int _scoreLooseness({
    required int harmonicCount,
    required double ampHalfX,
    required double threshold,
    required double highBand,
    required double lowBand,
  }) {
    var score = 0;
    if (harmonicCount >= 4) score += 50;
    if (harmonicCount >= 6) score += 20;
    if (ampHalfX > threshold) score += 15;
    if (lowBand > 0 && highBand > lowBand * 1.5) score += 15;
    return score.clamp(0, 100);
  }

  static int _scoreBearing({
    required double highBand,
    required double lowBand,
    required double strongThreshold,
  }) {
    var score = 0;
    if (highBand > strongThreshold) score += 40;
    if (lowBand > 0 && highBand > lowBand * 1.5) score += 40;
    return score.clamp(0, 80);
  }

  static String _statusFor(int score) {
    if (score >= 85) return 'Critical';
    if (score >= 70) return 'Warning';
    if (score >= 50) return 'Suspected';
    return 'Normal or Unknown';
  }

  static List<String> _reasons(
    String mainFault, {
    required double amp1x,
    required double amp2x,
    required double amp3x,
    required int harmonicCount,
    required double ampHalfX,
    required double axialRadialRatio,
    required double highBand,
    required double lowBand,
    required double threshold,
  }) {
    return switch (mainFault) {
      'Unbalance' => [
        '1X amplitude is ${amp1x.toStringAsFixed(3)} against threshold ${threshold.toStringAsFixed(3)}.',
        '2X and 3X are compared against 1X using the unbalance rule.',
      ],
      'Misalignment' => [
        '2X amplitude is ${amp2x.toStringAsFixed(3)} versus 1X ${amp1x.toStringAsFixed(3)}.',
        'Axial/radial ratio is ${axialRadialRatio.toStringAsFixed(2)}.',
      ],
      'Looseness' => [
        '$harmonicCount harmonics were detected above threshold.',
        '0.5X amplitude is ${ampHalfX.toStringAsFixed(3)}.',
      ],
      'Bearing' => [
        'High-frequency average is ${highBand.toStringAsFixed(3)}.',
        'Low-band average is ${lowBand.toStringAsFixed(3)}.',
      ],
      _ => [
        'No fault score reached 50 confidence.',
        'RPM and FFT spectrum were processed with order-based rules.',
      ],
    };
  }

  static List<String> _recommendations(String fault) {
    return switch (fault) {
      'Unbalance' => [
        'ตรวจ rotor, fan, pulley และสิ่งสกปรกเกาะใบพัด',
        'พิจารณาทำ balancing',
      ],
      'Misalignment' => [
        'ตรวจ coupling alignment และ soft foot',
        'ตรวจฐาน motor และ shaft alignment',
      ],
      'Looseness' => [
        'ตรวจ bolt, base, foundation และ bracket',
        'ตรวจ bearing seat และจุดยึดเครื่องจักร',
      ],
      'Bearing' => [
        'ตรวจ bearing และ lubrication',
        'วางแผนตรวจซ้ำด้วย bearing geometry/envelope analysis',
      ],
      _ => ['ติดตาม trend และ scan ซ้ำเมื่อโหลดเครื่องจักรเปลี่ยน'],
    };
  }
}

class _TargetPeak {
  const _TargetPeak(this.frequency, this.amplitude);

  final double frequency;
  final double amplitude;
}

class _MachineHealthSection extends StatelessWidget {
  const _MachineHealthSection({
    required this.activeNode,
    required this.metrics,
    required this.machineClass,
    required this.onMachineClassChanged,
  });

  final DeviceNode? activeNode;
  final List<DashboardMetric> metrics;
  final _MachineClass machineClass;
  final ValueChanged<_MachineClass> onMachineClassChanged;

  @override
  Widget build(BuildContext context) {
    if (activeNode == null) {
      return SectionCard(
        title: 'Machine Health',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MachineClassSelector(
              machineClass: machineClass,
              onChanged: onMachineClassChanged,
            ),
            const SizedBox(height: 12),
            const Text('Select a device to start vibration analysis.'),
          ],
        ),
      );
    }

    final axes = [
      _AxisVelocity('X', _metricValue(metrics, 'velocity_x')),
      _AxisVelocity('Y', _metricValue(metrics, 'velocity_y')),
      _AxisVelocity('Z', _metricValue(metrics, 'velocity_z')),
    ];
    final availableAxes = axes.where((axis) => axis.value != null).toList();
    if (availableAxes.isEmpty) {
      return SectionCard(
        title: 'Machine Health',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MachineClassSelector(
              machineClass: machineClass,
              onChanged: onMachineClassChanged,
            ),
            const SizedBox(height: 12),
            const Text('Waiting for vibration velocity data in mm/s.'),
          ],
        ),
      );
    }

    final peak = availableAxes.reduce(
      (current, next) => next.value! > current.value! ? next : current,
    );
    final overall = machineClass.severityFor(peak.value!);

    return SectionCard(
      title: 'Machine Health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MachineClassSelector(
            machineClass: machineClass,
            onChanged: onMachineClassChanged,
          ),
          const SizedBox(height: 16),
          _OverallHealthCard(
            severity: overall,
            peakAxis: peak,
            machineClass: machineClass,
          ),
          const SizedBox(height: 16),
          _AxisVelocityGrid(axes: axes, machineClass: machineClass),
          const SizedBox(height: 16),
          _IsoClassThresholdChart(machineClass: machineClass, peakAxis: peak),
          const SizedBox(height: 16),
          Text(
            'ISO velocity RMS assessment uses the highest measured axis.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MachineClassSelector extends StatelessWidget {
  const _MachineClassSelector({
    required this.machineClass,
    required this.onChanged,
  });

  final _MachineClass machineClass;
  final ValueChanged<_MachineClass> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_MachineClass>(
      isExpanded: true,
      initialValue: machineClass,
      decoration: const InputDecoration(
        labelText: 'ISO machine class',
        prefixIcon: Icon(Icons.precision_manufacturing_rounded),
      ),
      items: [
        for (final option in _MachineClass.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _OverallHealthCard extends StatelessWidget {
  const _OverallHealthCard({
    required this.severity,
    required this.peakAxis,
    required this.machineClass,
  });

  final _IsoSeverity severity;
  final _AxisVelocity peakAxis;
  final _MachineClass machineClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: severity.color.withValues(alpha: 0.16),
        border: Border.all(color: severity.color.withValues(alpha: 0.44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severity.icon, color: severity.color),
              const SizedBox(width: 8),
              Text(
                severity.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: severity.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(severity.description),
          const SizedBox(height: 8),
          Text(
            'Peak ${peakAxis.axis}: ${peakAxis.value!.toStringAsFixed(2)} mm/s - ${machineClass.shortLabel}',
          ),
        ],
      ),
    );
  }
}

class _AxisVelocityGrid extends StatelessWidget {
  const _AxisVelocityGrid({required this.axes, required this.machineClass});

  final List<_AxisVelocity> axes;
  final _MachineClass machineClass;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720
            ? 3
            : constraints.maxWidth > 330
            ? 3
            : constraints.maxWidth > 220
            ? 2
            : 1;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final axis in axes)
              SizedBox(
                width: width,
                child: _AxisVelocityTile(
                  axis: axis,
                  severity: axis.value == null
                      ? null
                      : machineClass.severityFor(axis.value!),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AxisVelocityTile extends StatelessWidget {
  const _AxisVelocityTile({required this.axis, required this.severity});

  final _AxisVelocity axis;
  final _IsoSeverity? severity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = severity?.color ?? theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Axis ${axis.axis}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  axis.value == null ? '--' : axis.value!.toStringAsFixed(2),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'mm/s RMS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                severity?.icon ?? Icons.hourglass_empty,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  severity?.label ?? 'Waiting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IsoClassThresholdChart extends StatelessWidget {
  const _IsoClassThresholdChart({
    required this.machineClass,
    required this.peakAxis,
  });

  final _MachineClass machineClass;
  final _AxisVelocity peakAxis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = peakAxis.value ?? 0;
    final severity = machineClass.severityFor(value);
    final chartMax = value > machineClass.unsatisfactoryLimit
        ? value * 1.18
        : machineClass.unsatisfactoryLimit * 1.18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${machineClass.shortLabel} criteria',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Decision ${peakAxis.axis}: ${value.toStringAsFixed(2)} mm/s',
              style: theme.textTheme.labelMedium?.copyWith(
                color: severity.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final markerLeft =
                ((value / chartMax).clamp(0.0, 1.0) * constraints.maxWidth);
            return SizedBox(
              height: 58,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        children: [
                          _ThresholdSegment(
                            flex: machineClass.goodLimit,
                            color: _IsoSeverity.good.color,
                          ),
                          _ThresholdSegment(
                            flex:
                                machineClass.satisfactoryLimit -
                                machineClass.goodLimit,
                            color: _IsoSeverity.satisfactory.color,
                          ),
                          _ThresholdSegment(
                            flex:
                                machineClass.unsatisfactoryLimit -
                                machineClass.satisfactoryLimit,
                            color: _IsoSeverity.unsatisfactory.color,
                          ),
                          _ThresholdSegment(
                            flex: chartMax - machineClass.unsatisfactoryLimit,
                            color: _IsoSeverity.unacceptable.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: (markerLeft - 7).clamp(
                      0.0,
                      constraints.maxWidth - 14,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        border: Border.all(color: severity.color, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const SizedBox(width: 14, height: 14),
                    ),
                  ),
                  Positioned(
                    top: 36,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _ThresholdLabel(
                          label: 'A',
                          value: '<= ${machineClass.goodLimit}',
                        ),
                        _ThresholdLabel(
                          label: 'B',
                          value: '<= ${machineClass.satisfactoryLimit}',
                        ),
                        _ThresholdLabel(
                          label: 'C',
                          value: '<= ${machineClass.unsatisfactoryLimit}',
                        ),
                        const _ThresholdLabel(label: 'D', value: '> C'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ThresholdSegment extends StatelessWidget {
  const _ThresholdSegment({required this.flex, required this.color});

  final double flex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (flex * 100).round().clamp(1, 100000),
      child: ColoredBox(color: color, child: const SizedBox(height: 20)),
    );
  }
}

class _ThresholdLabel extends StatelessWidget {
  const _ThresholdLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

enum _MachineClass {
  classI(
    label: 'Small Machines - Class I (up to 15 kW)',
    shortLabel: 'Class I',
    goodLimit: 0.71,
    satisfactoryLimit: 1.80,
    unsatisfactoryLimit: 4.50,
  ),
  classII(
    label: 'Medium Machines - Class II (15-75 kW)',
    shortLabel: 'Class II',
    goodLimit: 1.12,
    satisfactoryLimit: 2.80,
    unsatisfactoryLimit: 7.10,
  ),
  classIII(
    label: 'Large Machines, Rigid Support - Class III',
    shortLabel: 'Class III',
    goodLimit: 1.80,
    satisfactoryLimit: 4.50,
    unsatisfactoryLimit: 11.20,
  ),
  classIV(
    label: 'Large Machines, Less Rigid Support - Class IV',
    shortLabel: 'Class IV',
    goodLimit: 2.80,
    satisfactoryLimit: 7.10,
    unsatisfactoryLimit: 18.00,
  );

  const _MachineClass({
    required this.label,
    required this.shortLabel,
    required this.goodLimit,
    required this.satisfactoryLimit,
    required this.unsatisfactoryLimit,
  });

  final String label;
  final String shortLabel;
  final double goodLimit;
  final double satisfactoryLimit;
  final double unsatisfactoryLimit;

  _IsoSeverity severityFor(double velocity) {
    if (velocity <= goodLimit) {
      return _IsoSeverity.good;
    }
    if (velocity <= satisfactoryLimit) {
      return _IsoSeverity.satisfactory;
    }
    if (velocity <= unsatisfactoryLimit) {
      return _IsoSeverity.unsatisfactory;
    }
    return _IsoSeverity.unacceptable;
  }
}

enum _IsoSeverity {
  good(
    label: 'Good',
    description: 'Machine vibration is in a good operating range.',
    color: Color(0xFF2E7D32),
    icon: Icons.check_circle_rounded,
  ),
  satisfactory(
    label: 'Satisfactory',
    description: 'Machine is usable, but vibration should be monitored.',
    color: Color(0xFF76B900),
    icon: Icons.task_alt_rounded,
  ),
  unsatisfactory(
    label: 'Unsatisfactory',
    description: 'Alert level. Inspect the machine and plan maintenance.',
    color: Color(0xFFF9A825),
    icon: Icons.warning_amber_rounded,
  ),
  unacceptable(
    label: 'Unacceptable',
    description:
        'Danger level. Stop or service the machine as soon as possible.',
    color: Color(0xFFD32F2F),
    icon: Icons.dangerous_rounded,
  );

  const _IsoSeverity({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String description;
  final Color color;
  final IconData icon;
}

class _AxisVelocity {
  const _AxisVelocity(this.axis, this.value);

  final String axis;
  final double? value;
}

double? _metricValue(List<DashboardMetric> metrics, String key) {
  for (final metric in metrics) {
    if (metric.key == key) {
      return metric.value;
    }
  }
  return null;
}

String _clock(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
