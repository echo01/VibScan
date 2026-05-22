class MqttConfig {
  const MqttConfig({
    required this.broker,
    required this.port,
    required this.clientId,
    required this.username,
    required this.password,
    required this.topicPublish,
    required this.topicFftX,
    required this.topicFftY,
    required this.topicFftZ,
    required this.topicSubscribe,
    required this.topicAck,
    required this.topicResult,
    required this.publishIntervalSec,
    required this.useTls,
    required this.protocol,
    required this.status,
  });

  final String broker;
  final int port;
  final String clientId;
  final String username;
  final String password;
  final String topicPublish;
  final String topicFftX;
  final String topicFftY;
  final String topicFftZ;
  final String topicSubscribe;
  final String topicAck;
  final String topicResult;
  final int publishIntervalSec;
  final bool useTls;
  final String protocol;
  final String status;

  factory MqttConfig.fromJson(Map<String, dynamic> json) {
    final protocol = (json['protocol'] ?? '').toString();
    return MqttConfig(
      broker: (json['broker'] ?? '').toString(),
      port: _asInt(json['port'], fallback: 1883),
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      topicPublish: (json['topic_publish'] ?? '').toString(),
      topicFftX: (json['topic_fft_x'] ?? '').toString(),
      topicFftY: (json['topic_fft_y'] ?? '').toString(),
      topicFftZ: (json['topic_fft_z'] ?? '').toString(),
      topicSubscribe: (json['topic_subscribe'] ?? '').toString(),
      topicAck: (json['topic_ack'] ?? '').toString(),
      topicResult: (json['topic_result'] ?? '').toString(),
      publishIntervalSec: _asInt(json['publish_interval_s'], fallback: 60),
      useTls: _asBool(
        json['use_tls'],
        fallback: protocol.toLowerCase() == 'mqtts',
      ),
      protocol: protocol.isEmpty ? 'mqtt' : protocol,
      status: (json['status'] ?? '').toString(),
    );
  }

  MqttConfig copyWith({
    String? broker,
    int? port,
    String? clientId,
    String? username,
    String? password,
    String? topicPublish,
    String? topicFftX,
    String? topicFftY,
    String? topicFftZ,
    String? topicSubscribe,
    String? topicAck,
    String? topicResult,
    int? publishIntervalSec,
    bool? useTls,
    String? protocol,
    String? status,
  }) {
    return MqttConfig(
      broker: broker ?? this.broker,
      port: port ?? this.port,
      clientId: clientId ?? this.clientId,
      username: username ?? this.username,
      password: password ?? this.password,
      topicPublish: topicPublish ?? this.topicPublish,
      topicFftX: topicFftX ?? this.topicFftX,
      topicFftY: topicFftY ?? this.topicFftY,
      topicFftZ: topicFftZ ?? this.topicFftZ,
      topicSubscribe: topicSubscribe ?? this.topicSubscribe,
      topicAck: topicAck ?? this.topicAck,
      topicResult: topicResult ?? this.topicResult,
      publishIntervalSec: publishIntervalSec ?? this.publishIntervalSec,
      useTls: useTls ?? this.useTls,
      protocol: protocol ?? this.protocol,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'broker': broker,
      'port': port,
      'client_id': clientId,
      'username': username,
      'password': password,
      'topic_publish': topicPublish,
      'topic_fft_x': topicFftX,
      'topic_fft_y': topicFftY,
      'topic_fft_z': topicFftZ,
      'topic_subscribe': topicSubscribe,
      'topic_ack': topicAck,
      'topic_result': topicResult,
      'publish_interval_s': publishIntervalSec,
      'use_tls': useTls,
      'protocol': protocol,
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
