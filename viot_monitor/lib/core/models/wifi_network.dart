class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.security,
    required this.rssi,
  });

  final String ssid;
  final String security;
  final int rssi;

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    final secure = json['secure'];
    return WifiNetwork(
      ssid: (json['ssid'] ?? json['name'] ?? '').toString(),
      security:
          (json['security'] ??
                  json['auth'] ??
                  (secure is bool ? (secure ? 'Secure' : 'Open') : ''))
              .toString(),
      rssi: _asInt(json['rssi'], fallback: 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {'ssid': ssid, 'security': security, 'rssi': rssi};
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
