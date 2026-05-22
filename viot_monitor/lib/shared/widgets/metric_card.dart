import 'package:flutter/material.dart';

import '../../core/models/dashboard_metric.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metric.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              metric.value.toStringAsFixed(metric.key == 'uptime' ? 0 : 3),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(metric.unit),
          ],
        ),
      ),
    );
  }
}
