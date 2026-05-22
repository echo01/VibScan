class MemsConfig {
  const MemsConfig({
    required this.rateHz,
    required this.rangeG,
    required this.offsetX,
    required this.offsetY,
    required this.offsetZ,
    required this.intThresholdMg,
    required this.intEnabled,
    required this.minRmsG,
    required this.minPeakG,
    required this.noiseFloorDb,
    required this.deadbandG,
    required this.minFreqHz,
    required this.maxFreqHz,
    required this.sleepIntervalSec,
  });

  final int rateHz;
  final int rangeG;
  final double offsetX;
  final double offsetY;
  final double offsetZ;
  final int intThresholdMg;
  final bool intEnabled;
  final double minRmsG;
  final double minPeakG;
  final double noiseFloorDb;
  final double deadbandG;
  final double minFreqHz;
  final double maxFreqHz;
  final int sleepIntervalSec;

  factory MemsConfig.fromSections({
    required Map<String, dynamic> adxl345,
    required Map<String, dynamic> vibration,
    required Map<String, dynamic> power,
  }) {
    return MemsConfig(
      rateHz: _asInt(adxl345['rate_hz'], fallback: 800),
      rangeG: _asInt(adxl345['range_g'], fallback: 16),
      offsetX: _asDouble(adxl345['offset_x']),
      offsetY: _asDouble(adxl345['offset_y']),
      offsetZ: _asDouble(adxl345['offset_z']),
      intThresholdMg: _asInt(adxl345['int_threshold_mg'], fallback: 0),
      intEnabled: _asBool(adxl345['int_enabled'], fallback: false),
      minRmsG: _asDouble(vibration['min_rms_g']),
      minPeakG: _asDouble(vibration['min_peak_g']),
      noiseFloorDb: _asDouble(vibration['noise_floor_db']),
      deadbandG: _asDouble(vibration['deadband_g']),
      minFreqHz: _asDouble(vibration['min_freq_hz']),
      maxFreqHz: _asDouble(vibration['max_freq_hz']),
      sleepIntervalSec: _asInt(power['sleep_interval_sec'], fallback: 3600),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rate_hz': rateHz,
      'range_g': rangeG,
      'offset_x': offsetX,
      'offset_y': offsetY,
      'offset_z': offsetZ,
      'int_threshold_mg': intThresholdMg,
      'int_enabled': intEnabled,
      'min_rms_g': minRmsG,
      'min_peak_g': minPeakG,
      'noise_floor_db': noiseFloorDb,
      'deadband_g': deadbandG,
      'min_freq_hz': minFreqHz,
      'max_freq_hz': maxFreqHz,
      'sleep_interval_sec': sleepIntervalSec,
    };
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

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = '$value'.toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
    return fallback;
  }
}
