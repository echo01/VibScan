class MqttRuntimeStatus {
  const MqttRuntimeStatus({
    required this.connected,
    required this.status,
    required this.broker,
    required this.useTls,
    required this.retryLimited,
    required this.connectFailures,
    required this.connectFailureLimit,
    required this.retryLimitedLoops,
    required this.softRecoveryAttempted,
    required this.heapRebootRequired,
    required this.recoveryMessage,
    required this.retryAction,
  });

  final bool connected;
  final String status;
  final String broker;
  final bool useTls;
  final bool retryLimited;
  final int connectFailures;
  final int connectFailureLimit;
  final int retryLimitedLoops;
  final bool softRecoveryAttempted;
  final bool heapRebootRequired;
  final String recoveryMessage;
  final String retryAction;

  factory MqttRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return MqttRuntimeStatus(
      connected: _asBool(json['mqtt_connected'], fallback: false),
      status: (json['mqtt_status'] ?? '').toString(),
      broker: (json['mqtt_broker'] ?? '').toString(),
      useTls: _asBool(json['mqtt_use_tls'], fallback: false),
      retryLimited: _asBool(json['mqtt_retry_limited'], fallback: false),
      connectFailures: _asInt(json['mqtt_connect_failures'], fallback: 0),
      connectFailureLimit: _asInt(
        json['mqtt_connect_failure_limit'],
        fallback: 0,
      ),
      retryLimitedLoops: _asInt(json['mqtt_retry_limited_loops'], fallback: 0),
      softRecoveryAttempted: _asBool(
        json['mqtt_soft_recovery_attempted'],
        fallback: false,
      ),
      heapRebootRequired: _asBool(
        json['mqtt_heap_reboot_required'],
        fallback: false,
      ),
      recoveryMessage: (json['mqtt_recovery_message'] ?? '').toString(),
      retryAction: (json['mqtt_retry_action'] ?? '').toString(),
    );
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
