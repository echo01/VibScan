class SystemConfig {
  const SystemConfig({required this.logEnabled});

  final bool logEnabled;

  factory SystemConfig.fromSections({
    required Map<String, dynamic> power,
    required Map<String, dynamic> operate,
  }) {
    return SystemConfig(
      logEnabled: _asBool(
        operate['log_enabled'] ?? power['log_enabled'],
        fallback: true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'log_enabled': logEnabled};
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
