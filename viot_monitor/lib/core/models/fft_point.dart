class FftPoint {
  const FftPoint({required this.frequency, required this.amplitude});

  final double frequency;
  final double amplitude;

  factory FftPoint.fromJson(Map<String, dynamic> json) {
    return FftPoint(
      frequency: _asDouble(json['frequency'] ?? json['x']),
      amplitude: _asDouble(json['amplitude'] ?? json['y'] ?? json['value']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'frequency': frequency, 'amplitude': amplitude};
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
}
