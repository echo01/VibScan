import 'fft_point.dart';

class FftSpectrum {
  const FftSpectrum({
    required this.axis,
    required this.sampleRate,
    required this.pointCount,
    required this.peakFrequency,
    required this.maxAmplitude,
    required this.data,
  });

  final String axis;
  final int sampleRate;
  final int pointCount;
  final double peakFrequency;
  final double maxAmplitude;
  final List<FftPoint> data;

  factory FftSpectrum.fromDynamic(dynamic source, {String? axis}) {
    if (source is Map<String, dynamic>) {
      return FftSpectrum.fromJson(source, axis: axis);
    }
    if (source is List) {
      return FftSpectrum.fromJson({'axis': axis, 'data': source}, axis: axis);
    }
    throw StateError('Unexpected FFT response format');
  }

  factory FftSpectrum.fromJson(Map<String, dynamic> json, {String? axis}) {
    final dataSection = json['data'];
    final nestedData = dataSection is Map<String, dynamic> ? dataSection : null;
    final freq = _asList(
      nestedData?['freq_hz'] ??
          nestedData?['frequencies'] ??
          nestedData?['frequency'] ??
          nestedData?['x_freq_hz'] ??
          json['freq_hz'] ??
          json['frequencies'] ??
          json['frequency'] ??
          json['x'],
    ).map(_asDouble).toList();
    final amp = _asList(
      nestedData?['amplitude_mm_s'] ??
          nestedData?['amp_mm_s'] ??
          nestedData?['amplitudes'] ??
          nestedData?['x_amplitude_mm_s'] ??
          nestedData?['amplitude'] ??
          nestedData?['y'] ??
          nestedData?['values'] ??
          json['amplitude_mm_s'] ??
          json['amp_mm_s'] ??
          json['amplitudes'] ??
          json['amplitude'] ??
          json['y'] ??
          json['values'],
    ).map(_asDouble).toList();
    final rawData = _asList(
      nestedData == null
          ? json['data'] ?? json['fft'] ?? json['spectrum'] ?? json['bins']
          : json['fft'] ?? json['spectrum'] ?? json['bins'],
    );
    final points = rawData.isNotEmpty
        ? rawData
              .map<FftPoint?>((entry) => _pointFromDynamic(entry))
              .whereType<FftPoint>()
              .toList()
        : List<FftPoint>.generate(
            freq.length < amp.length ? freq.length : amp.length,
            (index) => FftPoint(frequency: freq[index], amplitude: amp[index]),
          );
    final maxPoint = points.isEmpty
        ? null
        : points.reduce(
            (best, current) =>
                current.amplitude > best.amplitude ? current : best,
          );
    return FftSpectrum(
      axis: (json['axis'] ?? axis ?? 'X').toString().toUpperCase(),
      sampleRate: _asInt(
        json['sample_rate'] ?? json['sampleRate'],
        fallback: 0,
      ),
      pointCount: _asInt(
        json['points'] ?? json['pointCount'],
        fallback: points.length,
      ),
      peakFrequency: _asDouble(
        json['peak_frequency'] ?? json['peakFrequency'] ?? maxPoint?.frequency,
      ),
      maxAmplitude: _asDouble(
        json['max_amplitude'] ?? json['maxAmplitude'] ?? maxPoint?.amplitude,
      ),
      data: points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'axis': axis,
      'sample_rate': sampleRate,
      'points': pointCount,
      'peak_frequency': peakFrequency,
      'max_amplitude': maxAmplitude,
      'data': data.map((point) => point.toJson()).toList(),
    };
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const [];
  }

  static FftPoint? _pointFromDynamic(dynamic entry) {
    if (entry is Map) {
      return FftPoint.fromJson(Map<String, dynamic>.from(entry));
    }
    if (entry is List && entry.length >= 2) {
      return FftPoint(
        frequency: _asDouble(entry[0]),
        amplitude: _asDouble(entry[1]),
      );
    }
    return null;
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
