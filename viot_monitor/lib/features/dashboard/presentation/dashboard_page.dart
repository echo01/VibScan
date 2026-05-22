import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/dashboard_metric.dart';
import '../../../core/models/device_node.dart';
import '../../../core/providers/app_providers.dart';
import '../../fft/presentation/fft_page.dart';
import '../../../shared/widgets/node_header.dart';
import '../../../shared/widgets/section_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: ref.read(dashboardTabIndexProvider),
    );
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(dashboardLiveProvider.notifier)
          .start(ref.read(activeNodeProvider));
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    ref.read(dashboardLiveProvider.notifier).stop();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    ref.read(dashboardTabIndexProvider.notifier).state = _tabController.index;
  }

  @override
  Widget build(BuildContext context) {
    final activeNode = ref.watch(activeNodeProvider);
    final savedDevices = ref.watch(savedDevicesProvider);
    final live = ref.watch(dashboardLiveProvider);
    final dashboardTabIndex = ref.watch(dashboardTabIndexProvider);

    ref.listen<DeviceNode?>(activeNodeProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(dashboardLiveProvider.notifier).start(next);
      });
    });
    ref.listen<int>(dashboardTabIndexProvider, (_, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    if (_tabController.index != dashboardTabIndex &&
        !_tabController.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index != dashboardTabIndex) {
          _tabController.animateTo(dashboardTabIndex);
        }
      });
    }

    final metrics = live.latestMetrics;
    final selectedMetricKey = live.effectiveSelectedMetricKey;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: NodeHeader(
            title: 'Dashboard',
            subtitle: activeNode == null
                ? 'No active node selected'
                : '${activeNode.displayName} - ${live.isRunning ? 'Live ${live.sampleModeLabel}' : 'Paused'}',
            trailing: FilledButton.tonalIcon(
              onPressed: activeNode == null
                  ? null
                  : () => ref.read(dashboardLiveProvider.notifier).refreshNow(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Select Device'),
            Tab(text: 'Vibration'),
            Tab(text: 'Orientation'),
            Tab(text: 'Real Time Chart'),
            Tab(text: 'System'),
            Tab(text: 'FFT'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SelectDeviceTab(
                activeNode: activeNode,
                savedDevices: savedDevices,
                live: live,
              ),
              _VibrationTab(activeNode: activeNode, metrics: metrics),
              _OrientationTab(activeNode: activeNode, metrics: metrics),
              _RealtimeChartTab(
                activeNode: activeNode,
                metrics: metrics,
                selectedMetricKey: selectedMetricKey,
                onMetricChanged: (key) {
                  if (key != null) {
                    ref.read(dashboardLiveProvider.notifier).selectMetric(key);
                  }
                },
              ),
              _SystemTab(activeNode: activeNode, live: live, metrics: metrics),
              const FftPanel(showHeader: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectDeviceTab extends StatelessWidget {
  const _SelectDeviceTab({
    required this.activeNode,
    required this.savedDevices,
    required this.live,
  });

  final DeviceNode? activeNode;
  final List<DeviceNode> savedDevices;
  final DashboardLiveState live;

  @override
  Widget build(BuildContext context) {
    return _DashboardTabScrollView(
      children: [
        SectionCard(
          title: 'Saved Device',
          child: Consumer(
            builder: (context, ref, _) {
              return DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    savedDevices.any(
                      (node) => node.storageKey == activeNode?.storageKey,
                    )
                    ? activeNode?.storageKey
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Device for /api/dashboard',
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
                      },
              );
            },
          ),
        ),
        if (activeNode == null)
          const _EmptyDashboardState()
        else
          _LiveStatusCard(live: live),
      ],
    );
  }

  DeviceNode? _findDevice(List<DeviceNode> devices, String? id) {
    for (final node in devices) {
      if (node.id == id) {
        return node;
      }
      if (node.storageKey == id) {
        return node;
      }
    }
    return null;
  }
}

class _VibrationTab extends StatelessWidget {
  const _VibrationTab({required this.activeNode, required this.metrics});

  final DeviceNode? activeNode;
  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (activeNode == null) {
      return const _DashboardTabScrollView(children: [_EmptyDashboardState()]);
    }
    if (metrics.isEmpty) {
      return const _DashboardTabScrollView(children: [_WaitingForDataState()]);
    }

    return _DashboardTabScrollView(
      children: [
        _MetricSection(
          title: 'Acceleration',
          subtitle: 'MEMS acceleration by axis',
          color: const Color(0xFF4ADE80),
          metrics: _pickMetrics(metrics, ['accel_x', 'accel_y', 'accel_z']),
        ),
        _MetricSection(
          title: 'Velocity',
          subtitle: 'RMS velocity by axis',
          color: const Color(0xFF38BDF8),
          metrics: _pickMetrics(metrics, [
            'velocity_x',
            'velocity_y',
            'velocity_z',
          ]),
        ),
        _MetricSection(
          title: 'Frequency',
          subtitle: 'Dominant vibration frequency',
          color: const Color(0xFFFBBF24),
          metrics: _pickMetrics(metrics, ['freq_x', 'freq_y', 'freq_z']),
        ),
        _MetricSection(
          title: 'Displacement',
          subtitle: 'Estimated displacement',
          color: const Color(0xFFA78BFA),
          metrics: _pickMetrics(metrics, ['disp_x', 'disp_y', 'disp_z']),
        ),
      ],
    );
  }
}

class _OrientationTab extends StatelessWidget {
  const _OrientationTab({required this.activeNode, required this.metrics});

  final DeviceNode? activeNode;
  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (activeNode == null) {
      return const _DashboardTabScrollView(children: [_EmptyDashboardState()]);
    }
    if (metrics.isEmpty) {
      return const _DashboardTabScrollView(children: [_WaitingForDataState()]);
    }

    final pitch = _metricValue(metrics, 'pitch');
    final roll = _metricValue(metrics, 'roll');
    return _DashboardTabScrollView(
      children: [
        SectionCard(
          title: 'Orientation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pitch and roll with 1 decimal precision. Yaw is hidden because this sensor does not measure it reliably.',
              ),
              const SizedBox(height: 16),
              _OrientationVisualizer(pitch: pitch, roll: roll),
              const SizedBox(height: 16),
              _MetricTileGrid(
                tiles: [
                  _MetricTileData(
                    label: 'Pitch',
                    value: pitch.toStringAsFixed(1),
                    unit: 'deg',
                    color: const Color(0xFFFB7185),
                  ),
                  _MetricTileData(
                    label: 'Roll',
                    value: roll.toStringAsFixed(1),
                    unit: 'deg',
                    color: const Color(0xFFF97316),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RealtimeChartTab extends StatelessWidget {
  const _RealtimeChartTab({
    required this.activeNode,
    required this.metrics,
    required this.selectedMetricKey,
    required this.onMetricChanged,
  });

  final DeviceNode? activeNode;
  final List<DashboardMetric> metrics;
  final String? selectedMetricKey;
  final ValueChanged<String?> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    if (activeNode == null) {
      return const _DashboardTabScrollView(children: [_EmptyDashboardState()]);
    }
    if (metrics.isEmpty) {
      return const _DashboardTabScrollView(children: [_WaitingForDataState()]);
    }

    return _DashboardTabScrollView(
      children: [
        _RealtimeChartCard(
          metrics: metrics,
          selectedMetricKey: selectedMetricKey,
          onMetricChanged: onMetricChanged,
        ),
      ],
    );
  }
}

class _SystemTab extends StatelessWidget {
  const _SystemTab({
    required this.activeNode,
    required this.live,
    required this.metrics,
  });

  final DeviceNode? activeNode;
  final DashboardLiveState live;
  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (activeNode == null) {
      return const _DashboardTabScrollView(children: [_EmptyDashboardState()]);
    }
    if (metrics.isEmpty) {
      return _DashboardTabScrollView(children: [const _WaitingForDataState()]);
    }

    return _DashboardTabScrollView(
      children: [
        SectionCard(
          title: 'System Health',
          child: _MetricTileGrid(
            tiles: [
              _MetricTileData.fromMetric(
                _metricByKey(metrics, 'battery'),
                fallbackLabel: 'Battery',
                fallbackUnit: 'V',
                color: const Color(0xFF4ADE80),
              ),
              _MetricTileData.fromMetric(
                _metricByKey(metrics, 'rssi'),
                fallbackLabel: 'RSSI',
                fallbackUnit: 'dBm',
                color: const Color(0xFF2DD4BF),
              ),
              _MetricTileData.fromMetric(
                _metricByKey(metrics, 'effective_sample_rate_hz'),
                fallbackLabel: 'Effective Sample Rate',
                fallbackUnit: 'Hz',
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Sample Read/Wait',
          child: _MetricTileGrid(
            tiles: [
              _MetricTileData.fromMetric(
                _metricByKey(metrics, 'sample_read_us'),
                fallbackLabel: 'Sample Read',
                fallbackUnit: 'us',
                color: const Color(0xFFF59E0B),
              ),
              _MetricTileData.fromMetric(
                _metricByKey(metrics, 'sample_wait_us'),
                fallbackLabel: 'Sample Wait',
                fallbackUnit: 'us',
                color: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ),
        _ExportCard(node: activeNode!, live: live),
      ],
    );
  }
}

class _DashboardTabScrollView extends StatelessWidget {
  const _DashboardTabScrollView({required this.children});

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

class _LiveStatusCard extends ConsumerWidget {
  const _LiveStatusCard({required this.live});

  final DashboardLiveState live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastUpdated = live.lastUpdated;

    return SectionCard(
      title: 'Live Capture',
      action: live.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              live.error == null
                  ? Icons.sensors_rounded
                  : Icons.warning_amber_rounded,
              color: live.error == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: live.sampleIntervalSec,
            decoration: const InputDecoration(
              labelText: 'Sampling rate',
              prefixIcon: Icon(Icons.update_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 2, child: Text('Fast  (every 2 sec)')),
              DropdownMenuItem(value: 3, child: Text('Normal  (every 3 sec)')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(dashboardLiveProvider.notifier)
                    .updateSampleInterval(value);
              }
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.timeline_rounded, size: 18),
                label: Text(
                  'Showing last ${live.chartWindowSeconds}s on chart',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.storage_rounded, size: 18),
                label: Text(
                  '${live.samples.length} samples kept for ${live.historyWindowSeconds}s',
                ),
              ),
              if (lastUpdated != null)
                Chip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('Last ${_clock(lastUpdated)}'),
                ),
            ],
          ),
          if (live.error != null) ...[
            const SizedBox(height: 12),
            Text(
              _friendlyLiveError(live.error!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _clock(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _friendlyLiveError(Object error) {
    final text = error.toString();
    if (text.contains('503')) {
      return 'ESP32 returned 503 low memory. Live capture keeps previous samples and retries on the next tick.';
    }
    return 'Last update failed: $text';
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 16),
          _MetricTileGrid(
            tiles: [
              for (final metric in metrics)
                _MetricTileData(
                  label: metric.label,
                  value: _formatMetricValue(metric),
                  unit: metric.unit,
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTileGrid extends StatelessWidget {
  const _MetricTileGrid({required this.tiles});

  final List<_MetricTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720
            ? 3
            : constraints.maxWidth > 420
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: _MetricTile(tile: tile),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.tile});

  final _MetricTileData tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tile.color.withValues(alpha: 0.18),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: tile.color.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tile.label,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tile.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              tile.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tile.unit.isEmpty ? 'value' : tile.unit,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  factory _MetricTileData.fromMetric(
    DashboardMetric? metric, {
    required String fallbackLabel,
    required String fallbackUnit,
    required Color color,
  }) {
    return _MetricTileData(
      label: metric?.label ?? fallbackLabel,
      value: metric == null ? '--' : _formatMetricValue(metric),
      unit: metric?.unit ?? fallbackUnit,
      color: color,
    );
  }

  final String label;
  final String value;
  final String unit;
  final Color color;
}

class _OrientationVisualizer extends StatelessWidget {
  const _OrientationVisualizer({required this.pitch, required this.roll});

  final double pitch;
  final double roll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.26,
                  ),
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: pitch),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedPitch, _) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: roll),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedRoll, _) {
                        return CustomPaint(
                          painter: _OrientationCubePainter(
                            theme: theme,
                            pitch: animatedPitch,
                            roll: animatedRoll,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '3D attitude preview',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OrientationCubePainter extends CustomPainter {
  _OrientationCubePainter({
    required this.theme,
    required this.pitch,
    required this.roll,
  });

  final ThemeData theme;
  final double pitch;
  final double roll;

  static const double _halfSize = 56;
  static const double _cameraDistance = 280;
  static const double _cubeScale = 118;
  static const double _baseYawDeg = 0;
  static const double _basePitchDeg = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final rotation = _CubeRotation(
      yaw: _degToRad(_baseYawDeg),
      pitch: _degToRad(_basePitchDeg + pitch.clamp(-85.0, 85.0)),
      roll: _degToRad(-roll.clamp(-85.0, 85.0)),
    );

    final vertices = <_Point3>[
      const _Point3(-_halfSize, -_halfSize, _halfSize),
      const _Point3(_halfSize, -_halfSize, _halfSize),
      const _Point3(_halfSize, _halfSize, _halfSize),
      const _Point3(-_halfSize, _halfSize, _halfSize),
      const _Point3(-_halfSize, -_halfSize, -_halfSize),
      const _Point3(_halfSize, -_halfSize, -_halfSize),
      const _Point3(_halfSize, _halfSize, -_halfSize),
      const _Point3(-_halfSize, _halfSize, -_halfSize),
    ].map(rotation.apply).toList(growable: false);

    final faces = <_CubeFaceData>[
      const _CubeFaceData(
        label: 'Front',
        color: Color(0xFF4F87E6),
        borderColor: Color(0xFF356CC6),
        vertexIndexes: [0, 1, 2, 3],
      ),
      const _CubeFaceData(
        label: 'Top',
        color: Color(0xFF2CC197),
        borderColor: Color(0xFF249A7A),
        vertexIndexes: [3, 2, 6, 7],
      ),
      const _CubeFaceData(
        label: 'Left',
        color: Color(0xFF21B8D5),
        borderColor: Color(0xFF1595AF),
        vertexIndexes: [4, 0, 3, 7],
      ),
      const _CubeFaceData(
        label: 'Right',
        color: Color(0xFF1595AF),
        borderColor: Color(0xFF11778B),
        vertexIndexes: [1, 5, 6, 2],
      ),
      const _CubeFaceData(
        label: 'Bottom',
        color: Color(0xFF249A7A),
        borderColor: Color(0xFF1C765D),
        vertexIndexes: [4, 5, 1, 0],
      ),
      const _CubeFaceData(
        label: 'Back',
        color: Color(0xFF356CC6),
        borderColor: Color(0xFF254E99),
        vertexIndexes: [5, 4, 7, 6],
      ),
    ];

    final projected = vertices
        .map((point) => _project(point, center))
        .toList(growable: false);
    final visibleFaces =
        faces
            .map((face) => _ProjectedFace.from(face, vertices, projected))
            .where((face) => face.normal.z > 0)
            .toList()
          ..sort((a, b) => a.depth.compareTo(b.depth));

    final shadowPaint = Paint()
      ..color = const Color(0x22000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final outlinePaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final face in visibleFaces) {
      final shadowPath = face.path.shift(const Offset(0, 4));
      canvas.drawPath(shadowPath, shadowPaint);

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            face.data.color.withValues(alpha: 0.98),
            Color.alphaBlend(const Color(0x14000000), face.data.color),
          ],
        ).createShader(face.path.getBounds());
      final borderPaint = Paint()
        ..color = face.data.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      canvas.drawPath(face.path, fillPaint);
      canvas.drawPath(face.path, borderPaint);
      canvas.drawPath(face.path, outlinePaint);
      _paintFaceLabel(canvas, face);
    }
  }

  void _paintFaceLabel(Canvas canvas, _ProjectedFace face) {
    final bounds = face.path.getBounds();
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: face.data.label, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: bounds.width - 12);

    final offset = Offset(
      face.center.dx - textPainter.width / 2,
      face.center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  Offset _project(_Point3 point, Offset center) {
    final perspective = _cameraDistance / (_cameraDistance - point.z);
    return Offset(
      center.dx + (point.x * perspective * (_cubeScale / 112)),
      center.dy - (point.y * perspective * (_cubeScale / 112)),
    );
  }

  double _degToRad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant _OrientationCubePainter oldDelegate) {
    return oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.theme.colorScheme != theme.colorScheme;
  }
}

class _CubeRotation {
  const _CubeRotation({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  final double yaw;
  final double pitch;
  final double roll;

  _Point3 apply(_Point3 point) {
    var rotated = point.rotateY(yaw);
    rotated = rotated.rotateX(pitch);
    rotated = rotated.rotateZ(roll);
    return rotated;
  }
}

class _CubeFaceData {
  const _CubeFaceData({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.vertexIndexes,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final List<int> vertexIndexes;
}

class _ProjectedFace {
  _ProjectedFace({
    required this.data,
    required this.path,
    required this.center,
    required this.normal,
    required this.depth,
  });

  factory _ProjectedFace.from(
    _CubeFaceData data,
    List<_Point3> vertices,
    List<Offset> projected,
  ) {
    final points3 = data.vertexIndexes.map((index) => vertices[index]).toList();
    final points2 = data.vertexIndexes
        .map((index) => projected[index])
        .toList();
    final path = Path()..moveTo(points2.first.dx, points2.first.dy);
    for (final point in points2.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    final normal = (points3[1] - points3[0]).cross(points3[2] - points3[0]);
    final center = Offset(
      points2.fold<double>(0, (sum, point) => sum + point.dx) / points2.length,
      points2.fold<double>(0, (sum, point) => sum + point.dy) / points2.length,
    );
    final depth =
        points3.fold<double>(0, (sum, point) => sum + point.z) / points3.length;

    return _ProjectedFace(
      data: data,
      path: path,
      center: center,
      normal: normal,
      depth: depth,
    );
  }

  final _CubeFaceData data;
  final Path path;
  final Offset center;
  final _Point3 normal;
  final double depth;
}

class _Point3 {
  const _Point3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Point3 rotateX(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return _Point3(x, y * cosA - z * sinA, y * sinA + z * cosA);
  }

  _Point3 rotateY(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return _Point3(x * cosA + z * sinA, y, -x * sinA + z * cosA);
  }

  _Point3 rotateZ(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return _Point3(x * cosA - y * sinA, x * sinA + y * cosA, z);
  }

  _Point3 operator -(_Point3 other) {
    return _Point3(x - other.x, y - other.y, z - other.z);
  }

  _Point3 cross(_Point3 other) {
    return _Point3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }
}

class _RealtimeChartCard extends ConsumerWidget {
  const _RealtimeChartCard({
    required this.metrics,
    required this.selectedMetricKey,
    required this.onMetricChanged,
  });

  final List<DashboardMetric> metrics;
  final String? selectedMetricKey;
  final ValueChanged<String?> onMetricChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(dashboardLiveProvider);
    final selectedMetric = selectedMetricKey == null
        ? null
        : _metricByKey(metrics, selectedMetricKey!);
    final points = _pointsFor(live, selectedMetricKey);
    final minY = _minY(points);
    final maxY = _maxY(points);
    final yInterval = _axisInterval(minY, maxY, targetTickCount: 5);
    final xInterval = _axisInterval(
      points.isEmpty ? 0 : points.first.x,
      points.isEmpty ? 1 : points.last.x,
      targetTickCount: 4,
      minimumInterval: 1,
    );
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Real-time Chart',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing the latest ${live.chartWindowSeconds} seconds. '
            'Full history up to ${live.historyWindowSeconds} seconds stays available for CSV export.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedMetricKey,
            decoration: const InputDecoration(
              labelText: 'Metric to plot',
              prefixIcon: Icon(Icons.show_chart_rounded),
            ),
            items: [
              for (final metric in metrics)
                DropdownMenuItem(
                  value: metric.key,
                  child: Text('${metric.label} (${metric.unit})'),
                ),
            ],
            onChanged: onMetricChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: points.length < 2
                ? const Center(child: Text('Waiting for chart samples...'))
                : LineChart(
                    LineChartData(
                      minX: points.first.x,
                      maxX: points.last.x,
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: yInterval,
                        verticalInterval: xInterval,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              child: Text(
                                _formatChartAxisValue(value),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              child: Text(
                                value.toStringAsFixed(0),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: true,
                          barWidth: 2.4,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          if (selectedMetric != null) ...[
            const SizedBox(height: 8),
            Text(
              'Latest ${selectedMetric.label}: '
              '${_formatChartAxisValue(selectedMetric.value)} ${selectedMetric.unit}',
            ),
          ],
        ],
      ),
    );
  }

  List<FlSpot> _pointsFor(DashboardLiveState live, String? key) {
    if (key == null || live.samples.isEmpty) {
      return const [];
    }

    final latestTimestamp = live.samples.last.timestamp;
    final cutoff = latestTimestamp.subtract(
      Duration(seconds: live.chartWindowSeconds),
    );
    final visibleSamples = live.samples
        .where((sample) => !sample.timestamp.isBefore(cutoff))
        .toList();
    if (visibleSamples.isEmpty) {
      return const [];
    }

    final firstTimestamp = visibleSamples.first.timestamp;
    final points = <FlSpot>[];
    for (final sample in visibleSamples) {
      final metric = sample.metricByKey(key);
      if (metric == null) {
        continue;
      }
      final seconds =
          sample.timestamp
              .difference(firstTimestamp)
              .inMilliseconds
              .toDouble() /
          1000;
      points.add(FlSpot(seconds, metric.value));
    }
    return points;
  }

  double _minY(List<FlSpot> points) {
    if (points.isEmpty) {
      return 0;
    }
    var minValue = points.first.y;
    var maxValue = points.first.y;
    for (final point in points.skip(1)) {
      minValue = math.min(minValue, point.y);
      maxValue = math.max(maxValue, point.y);
    }
    final interval = _axisInterval(minValue, maxValue, targetTickCount: 5);
    final padding = math.max(interval * 0.6, 0.01);
    return ((minValue - padding) / interval).floorToDouble() * interval;
  }

  double _maxY(List<FlSpot> points) {
    if (points.isEmpty) {
      return 1;
    }
    var minValue = points.first.y;
    var maxValue = points.first.y;
    for (final point in points.skip(1)) {
      minValue = math.min(minValue, point.y);
      maxValue = math.max(maxValue, point.y);
    }
    final interval = _axisInterval(minValue, maxValue, targetTickCount: 5);
    final padding = math.max(interval * 0.6, 0.01);
    return ((maxValue + padding) / interval).ceilToDouble() * interval;
  }

  double _axisInterval(
    double minValue,
    double maxValue, {
    required int targetTickCount,
    double minimumInterval = 0.01,
  }) {
    final range = (maxValue - minValue).abs();
    if (range == 0) {
      return minimumInterval;
    }

    final rawInterval = math.max(range / targetTickCount, minimumInterval);
    final magnitude = math
        .pow(10, (math.log(rawInterval) / math.ln10).floor())
        .toDouble();
    final normalized = rawInterval / magnitude;

    final niceNormalized = switch (normalized) {
      <= 1 => 1.0,
      <= 2 => 2.0,
      <= 5 => 5.0,
      _ => 10.0,
    };

    return math.max(niceNormalized * magnitude, minimumInterval).toDouble();
  }

  String _formatChartAxisValue(double value) {
    final normalized = value.abs() < 0.005 ? 0.0 : value;
    return normalized.toStringAsFixed(2);
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.node, required this.live});

  final DeviceNode node;
  final DashboardLiveState live;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return SectionCard(
          title: 'Export History to CSV',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exports up to the latest ${live.historyWindowSeconds} seconds of stored dashboard history.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: live.samples.isEmpty
                          ? null
                          : () async {
                              final file = await ref
                                  .read(csvExportServiceProvider)
                                  .saveDashboardHistoryCsv(
                                    node: node,
                                    samples: live.samples,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Saved ${file.savedLocation}',
                                    ),
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
                      onPressed: live.samples.isEmpty
                          ? null
                          : () async {
                              final file = await ref
                                  .read(csvExportServiceProvider)
                                  .saveDashboardHistoryCsv(
                                    node: node,
                                    samples: live.samples,
                                  );
                              await ref
                                  .read(csvExportServiceProvider)
                                  .shareFile(
                                    file.shareFile,
                                    subject:
                                        'VIOT Dashboard Live Export - ${node.displayName}',
                                  );
                            },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Clear live history',
                    onPressed: live.samples.isEmpty
                        ? null
                        : () => ref
                              .read(dashboardLiveProvider.notifier)
                              .clearHistory(),
                    icon: const Icon(Icons.delete_sweep_rounded),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaitingForDataState extends StatelessWidget {
  const _WaitingForDataState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
      ),
      child: const Text(
        'Waiting for /api/dashboard data. Live capture retries every second.',
      ),
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
      ),
      child: const Text(
        'Select a saved device to start live /api/dashboard capture.',
      ),
    );
  }
}

List<DashboardMetric> _pickMetrics(
  List<DashboardMetric> metrics,
  List<String> keys,
) {
  final byKey = {for (final metric in metrics) metric.key: metric};
  return [
    for (final key in keys)
      if (byKey[key] != null) byKey[key]!,
  ];
}

DashboardMetric? _metricByKey(List<DashboardMetric> metrics, String key) {
  for (final metric in metrics) {
    if (metric.key == key) {
      return metric;
    }
  }
  return null;
}

double _metricValue(List<DashboardMetric> metrics, String key) {
  return _metricByKey(metrics, key)?.value ?? 0;
}

String _formatMetricValue(DashboardMetric metric) {
  if (metric.key == 'rssi') {
    return metric.value.toStringAsFixed(0);
  }
  if (metric.key == 'sample_read_us' || metric.key == 'sample_wait_us') {
    return metric.value.toStringAsFixed(0);
  }
  if (metric.key == 'pitch' || metric.key == 'roll' || metric.key == 'yaw') {
    return metric.value.toStringAsFixed(1);
  }
  if (metric.value.abs() >= 100) {
    return metric.value.toStringAsFixed(1);
  }
  return metric.value.toStringAsFixed(2);
}
