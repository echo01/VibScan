class DeviceNode {
  const DeviceNode({
    required this.id,
    required this.name,
    this.customName,
    required this.ip,
    required this.hostname,
    required this.port,
    required this.isOnline,
    required this.lastSeen,
    required this.rssi,
    required this.source,
  });

  final String id;
  final String name;
  final String? customName;
  final String ip;
  final String hostname;
  final int port;
  final bool isOnline;
  final DateTime lastSeen;
  final int rssi;
  final String source;

  String get address => ip.isNotEmpty ? ip : hostname;
  String get displayName {
    final custom = customName?.trim() ?? '';
    return custom.isNotEmpty ? custom : name;
  }

  String get displayNameWithEndpoint => '$displayName  ($address:$port)';
  String get storageKey =>
      '${id.trim().toLowerCase()}|${address.trim().toLowerCase()}|$port';

  String get baseUrl =>
      port == 80 ? 'http://$address' : 'http://$address:$port';

  factory DeviceNode.fromJson(Map<String, dynamic> json) {
    final hostname = (json['hostname'] ?? json['mdns_host'] ?? '').toString();
    final ip = _firstNonEmpty([json['ip'], json['sta_ip'], json['ap_ip']]);
    return DeviceNode(
      id:
          (json['device_id'] ??
                  json['id'] ??
                  json['hostname'] ??
                  json['mdns_host'] ??
                  ip)
              .toString(),
      name:
          (json['device_name'] ??
                  json['device'] ??
                  json['name'] ??
                  json['hostname'] ??
                  json['device_id'] ??
                  ip)
              .toString(),
      customName: (json['custom_name'] ?? json['customName'])?.toString(),
      ip: ip,
      hostname: hostname,
      port: _asInt(
        json['http_port'] ?? json['web_port'] ?? json['port'],
        fallback: 80,
      ),
      isOnline: _asBool(json['isOnline'] ?? json['online'], fallback: true),
      lastSeen: _asDateTime(json['lastSeen']),
      rssi: _asInt(json['rssi'] ?? json['wifi_rssi'], fallback: 0),
      source: (json['source'] ?? 'unknown').toString(),
    );
  }

  DeviceNode copyWith({
    String? id,
    String? name,
    String? customName,
    String? ip,
    String? hostname,
    int? port,
    bool? isOnline,
    DateTime? lastSeen,
    int? rssi,
    String? source,
  }) {
    return DeviceNode(
      id: id ?? this.id,
      name: name ?? this.name,
      customName: customName ?? this.customName,
      ip: ip ?? this.ip,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'custom_name': customName,
      'ip': ip,
      'hostname': hostname,
      'port': port,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'rssi': rssi,
      'source': source,
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

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == 'online' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'offline' ||
          normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse('$value') ?? DateTime.now();
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
