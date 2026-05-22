class OperateConfig {
  const OperateConfig({
    required this.publishIntervalSec,
    required this.wakeupIntThresholdMg,
    required this.wakeupIntEnabled,
    required this.wakeupTimerSec,
    required this.publishOnVibrationTrigger,
    required this.publishVibrationThresholdMmS,
    required this.logEnabled,
    required this.debugLogWifi,
    required this.debugLogMqtt,
    required this.debugLogMems,
    required this.debugLogPower,
    required this.debugLogWeb,
    required this.debugLogBattery,
    required this.debugLogOperate,
    required this.debugLogSystem,
  });

  final int publishIntervalSec;
  final int wakeupIntThresholdMg;
  final bool wakeupIntEnabled;
  final int wakeupTimerSec;
  final bool publishOnVibrationTrigger;
  final double publishVibrationThresholdMmS;
  final bool logEnabled;
  final bool debugLogWifi;
  final bool debugLogMqtt;
  final bool debugLogMems;
  final bool debugLogPower;
  final bool debugLogWeb;
  final bool debugLogBattery;
  final bool debugLogOperate;
  final bool debugLogSystem;

  factory OperateConfig.fromJson(Map<String, dynamic> json) {
    final debugMask = _asInt(json['debug_log_mask'], fallback: 0);
    return OperateConfig(
      publishIntervalSec: _asInt(json['publish_interval_s'], fallback: 60),
      wakeupIntThresholdMg: _asInt(
        json['wakeup_int_threshold_mg'] ?? json['int_threshold_mg'],
        fallback: 0,
      ),
      wakeupIntEnabled: _asBool(
        json['wakeup_int_enabled'] ?? json['int_enabled'],
        fallback: false,
      ),
      wakeupTimerSec: _asInt(
        json['wakeup_timer_sec'] ?? json['sleep_interval_sec'],
        fallback: 3600,
      ),
      publishOnVibrationTrigger: _asBool(
        json['publish_on_vibration_trigger'],
        fallback: false,
      ),
      publishVibrationThresholdMmS: _asDouble(
        json['publish_vibration_threshold_mm_s'],
      ),
      logEnabled: _asBool(json['log_enabled'], fallback: true),
      debugLogWifi: _flag(
        json: json,
        key: 'debug_log_wifi',
        fallback: _maskEnabled(debugMask, 0),
      ),
      debugLogMqtt: _flag(
        json: json,
        key: 'debug_log_mqtt',
        fallback: _maskEnabled(debugMask, 1),
      ),
      debugLogMems: _flag(
        json: json,
        key: 'debug_log_mems',
        fallback: _maskEnabled(debugMask, 2),
      ),
      debugLogPower: _flag(
        json: json,
        key: 'debug_log_power',
        fallback: _maskEnabled(debugMask, 3),
      ),
      debugLogWeb: _flag(
        json: json,
        key: 'debug_log_web',
        fallback: _maskEnabled(debugMask, 4),
      ),
      debugLogBattery: _flag(
        json: json,
        key: 'debug_log_battery',
        fallback: _maskEnabled(debugMask, 5),
      ),
      debugLogOperate: _flag(
        json: json,
        key: 'debug_log_operate',
        fallback: _maskEnabled(debugMask, 6),
      ),
      debugLogSystem: _flag(
        json: json,
        key: 'debug_log_system',
        fallback: _maskEnabled(debugMask, 7),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publish_interval_s': publishIntervalSec,
      'int_threshold_mg': wakeupIntThresholdMg,
      'int_enabled': wakeupIntEnabled,
      'sleep_interval_sec': wakeupTimerSec,
      'publish_on_vibration_trigger': publishOnVibrationTrigger,
      'publish_vibration_threshold_mm_s': publishVibrationThresholdMmS,
      'log_enabled': logEnabled,
      'debug_log_wifi': debugLogWifi,
      'debug_log_mqtt': debugLogMqtt,
      'debug_log_mems': debugLogMems,
      'debug_log_power': debugLogPower,
      'debug_log_web': debugLogWeb,
      'debug_log_battery': debugLogBattery,
      'debug_log_operate': debugLogOperate,
      'debug_log_system': debugLogSystem,
    };
  }

  static bool _flag({
    required Map<String, dynamic> json,
    required String key,
    required bool fallback,
  }) {
    return _asBool(json[key], fallback: fallback);
  }

  static bool _maskEnabled(int mask, int bitIndex) {
    return (mask & (1 << bitIndex)) != 0;
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
