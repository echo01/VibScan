class NetworkConfig {
  const NetworkConfig({
    required this.ssid,
    required this.password,
    required this.apEnabled,
    required this.apSsid,
    required this.apPassword,
    required this.staUseStaticIp,
    required this.staStaticIp,
    required this.staGateway,
    required this.staSubnet,
    required this.staDns1,
    required this.staDns2,
  });

  final String ssid;
  final String password;
  final bool apEnabled;
  final String apSsid;
  final String apPassword;
  final bool staUseStaticIp;
  final String staStaticIp;
  final String staGateway;
  final String staSubnet;
  final String staDns1;
  final String staDns2;

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      ssid: (json['ssid'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      apEnabled: _asBool(json['ap_enabled'], fallback: true),
      apSsid:
          (json['ap_ssid_effective'] ?? json['ap_ssid'] ?? 'VIOT_Config')
              .toString(),
      apPassword: (json['ap_password'] ?? '').toString(),
      staUseStaticIp: _asBool(json['sta_use_static_ip'], fallback: false),
      staStaticIp: (json['sta_static_ip'] ?? '').toString(),
      staGateway: (json['sta_gateway'] ?? '').toString(),
      staSubnet: (json['sta_subnet'] ?? '').toString(),
      staDns1: (json['sta_dns1'] ?? '').toString(),
      staDns2: (json['sta_dns2'] ?? '').toString(),
    );
  }

  NetworkConfig copyWith({
    String? ssid,
    String? password,
    bool? apEnabled,
    String? apSsid,
    String? apPassword,
    bool? staUseStaticIp,
    String? staStaticIp,
    String? staGateway,
    String? staSubnet,
    String? staDns1,
    String? staDns2,
  }) {
    return NetworkConfig(
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      apEnabled: apEnabled ?? this.apEnabled,
      apSsid: apSsid ?? this.apSsid,
      apPassword: apPassword ?? this.apPassword,
      staUseStaticIp: staUseStaticIp ?? this.staUseStaticIp,
      staStaticIp: staStaticIp ?? this.staStaticIp,
      staGateway: staGateway ?? this.staGateway,
      staSubnet: staSubnet ?? this.staSubnet,
      staDns1: staDns1 ?? this.staDns1,
      staDns2: staDns2 ?? this.staDns2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'ap_enabled': apEnabled,
      'ap_ssid': apSsid,
      'ap_password': apPassword,
      'sta_use_static_ip': staUseStaticIp,
      'sta_static_ip': staStaticIp,
      'sta_gateway': staGateway,
      'sta_subnet': staSubnet,
      'sta_dns1': staDns1,
      'sta_dns2': staDns2,
    };
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
