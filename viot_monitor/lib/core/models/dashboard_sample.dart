import 'dashboard_metric.dart';

class DashboardSample {
  const DashboardSample({required this.timestamp, required this.metrics});

  final DateTime timestamp;
  final List<DashboardMetric> metrics;

  DashboardMetric? metricByKey(String key) {
    for (final metric in metrics) {
      if (metric.key == key) {
        return metric;
      }
    }
    return null;
  }
}
