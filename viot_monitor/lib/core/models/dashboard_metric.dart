class DashboardMetric {
  const DashboardMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.displayOrder,
  });

  final String key;
  final String label;
  final double value;
  final String unit;
  final int displayOrder;

  factory DashboardMetric.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return DashboardMetric(
      key: (json['key'] ?? 'metric_$index').toString(),
      label: (json['label'] ?? json['key'] ?? 'Metric').toString(),
      value: _asDouble(json['value']),
      unit: (json['unit'] ?? '').toString(),
      displayOrder: _asInt(
        json['displayOrder'] ?? json['order'],
        fallback: index,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'value': value,
      'unit': unit,
      'displayOrder': displayOrder,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }
}
