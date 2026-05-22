class MqttPublishSummary {
  const MqttPublishSummary({
    required this.connected,
    required this.status,
    required this.lastResult,
    required this.lastSentAgoSec,
    this.lastSentText,
    required this.nextSendInSec,
    this.nextSendText,
    required this.publishCount,
    required this.tlsConnectState,
    required this.subscribeRxCount,
    this.subscribeRxAgoSec,
    required this.lastRxAgoSec,
    this.lastRxText,
    required this.lastRxBytes,
    required this.mainPayloadBytes,
  });

  final bool connected;
  final String status;
  final String lastResult;
  final int? lastSentAgoSec;
  final String? lastSentText;
  final int? nextSendInSec;
  final String? nextSendText;
  final int publishCount;
  final String tlsConnectState;
  final int subscribeRxCount;
  final int? subscribeRxAgoSec;
  final int? lastRxAgoSec;
  final String? lastRxText;
  final int lastRxBytes;
  final int mainPayloadBytes;

  factory MqttPublishSummary.fromJson(Map<String, dynamic> json) {
    final mqtt = _map(json['mqtt']);
    final publish = _map(json['publish']);
    final publisher = _map(json['publisher']);
    final summary = _map(json['summary']);
    final rx = _map(json['subscribe_rx']);
    final subscribe = _map(json['subscribe']);
    final tls = _map(json['tls']);

    final connected = _asBool(
      _pick([
        json['mqtt_connected'],
        json['mqttConnected'],
        json['connected'],
        mqtt['connected'],
        mqtt['mqtt_connected'],
        publish['connected'],
        summary['connected'],
      ]),
      fallback: false,
    );
    final status = _asString(
      _pick([
        json['mqtt_status'],
        json['mqttStatus'],
        json['status'],
        mqtt['status'],
        mqtt['mqtt_status'],
        summary['status'],
      ]),
    );
    final publishCount = _asInt(
      _pick([
        json['publish_count'],
        json['publishCount'],
        json['published_count'],
        json['publishedCount'],
        json['mqtt_publish_count'],
        publish['count'],
        publish['publish_count'],
        publish['publishCount'],
        publish['published_count'],
        publisher['count'],
        publisher['publish_count'],
        summary['publish_count'],
        summary['publishCount'],
      ]),
      fallback: 0,
    );
    final useTls = _asBool(
      _pick([
        json['mqtt_use_tls'],
        json['mqttUseTls'],
        json['use_tls'],
        json['useTls'],
        mqtt['use_tls'],
        mqtt['useTls'],
        mqtt['mqtt_use_tls'],
        tls['enabled'],
      ]),
      fallback: false,
    );

    return MqttPublishSummary(
      connected: connected,
      status: status,
      lastResult: _lastResult(
        _pick([
          json['last_result'],
          json['lastResult'],
          json['success'],
          json['last_publish_result'],
          json['lastPublishResult'],
          json['publish_result'],
          json['publishResult'],
          json['mqtt_publish_result'],
          publish['last_result'],
          publish['lastResult'],
          publish['last_publish_result'],
          publish['lastPublishResult'],
          publish['result'],
          publisher['last_result'],
          publisher['lastResult'],
          publisher['last_publish_result'],
          publisher['lastPublishResult'],
          summary['last_result'],
          summary['lastResult'],
          summary['last_publish_result'],
          summary['lastPublishResult'],
        ]),
        connected: connected,
        publishCount: publishCount,
      ),
      lastSentAgoSec: _asDurationSec(
        _pick([
          json['last_sent_ago_sec'],
          json['lastSentAgoSec'],
          json['seconds_since_last_success'],
          json['secondsSinceLastSuccess'],
          json['last_publish_ago_sec'],
          json['lastPublishAgoSec'],
          json['seconds_since_last_publish'],
          json['secondsSinceLastPublish'],
          json['mqtt_last_sent_ago_sec'],
          publish['last_sent_ago_sec'],
          publish['lastSentAgoSec'],
          publish['last_publish_ago_sec'],
          publish['seconds_since_last_publish'],
          publisher['last_sent_ago_sec'],
          summary['last_sent_ago_sec'],
          summary['lastSentAgoSec'],
          summary['last_publish_ago_sec'],
        ]),
      ),
      lastSentText: _asDisplayText(
        _pick([
          json['last_sent'],
          json['lastSent'],
          json['last_publish'],
          json['lastPublish'],
          json['last_sent_at'],
          json['lastSentAt'],
          json['last_publish_at'],
          publish['last_sent'],
          publish['lastSent'],
          publish['last_publish'],
          publish['last_sent_at'],
          publisher['last_sent'],
          summary['last_sent'],
          summary['lastSent'],
        ]),
      ),
      nextSendInSec: _asDurationSec(
        _pick([
          json['next_send_in_sec'],
          json['nextSendInSec'],
          json['seconds_until_next_publish'],
          json['secondsUntilNextPublish'],
          json['next_publish_in_sec'],
          json['nextPublishInSec'],
          json['seconds_to_next_publish'],
          json['secondsToNextPublish'],
          json['publish_in_sec'],
          publish['next_send_in_sec'],
          publish['nextSendInSec'],
          publish['next_publish_in_sec'],
          publish['nextPublishInSec'],
          publish['seconds_to_next_publish'],
          publish['secondsToNextPublish'],
          publisher['next_send_in_sec'],
          publisher['nextSendInSec'],
          publisher['next_publish_in_sec'],
          publisher['nextPublishInSec'],
          summary['next_send_in_sec'],
          summary['nextSendInSec'],
          summary['next_publish_in_sec'],
          summary['nextPublishInSec'],
        ]),
      ),
      nextSendText: _asDisplayText(
        _pick([
          json['next_send'],
          json['nextSend'],
          json['next_publish'],
          json['nextPublish'],
          json['next_send_at'],
          json['nextSendAt'],
          json['next_publish_at'],
          publish['next_send'],
          publish['nextSend'],
          publish['next_publish'],
          publisher['next_send'],
          summary['next_send'],
          summary['nextSend'],
        ]),
      ),
      publishCount: publishCount,
      tlsConnectState: _tlsState(
        _pick([
          json['tls_connect'],
          json['tlsConnect'],
          json['tls_connect_state'],
          json['tlsConnectState'],
          json['tls_state'],
          json['tlsState'],
          json['mqtt_tls_connect'],
          json['mqtt_tls_state'],
          mqtt['tls_connect'],
          mqtt['tlsConnect'],
          mqtt['tls_connect_state'],
          mqtt['tls_state'],
          tls['connect_state'],
          tls['connectState'],
          tls['state'],
          tls['status'],
        ]),
        useTls: useTls,
        connected: connected,
        connecting: _asBool(
          _pick([
            json['tls_connecting'],
            json['tlsConnecting'],
            json['mqtt_tls_connecting'],
            mqtt['tls_connecting'],
            mqtt['tlsConnecting'],
            tls['connecting'],
          ]),
          fallback: false,
        ),
      ),
      subscribeRxCount: _asInt(
        _pick([
          json['subscribe_rx'],
          json['subscribeRx'],
          json['subscribe_rx_count'],
          json['subscribeRxCount'],
          json['subscribe_receive_count'],
          json['subscribeReceiveCount'],
          json['mqtt_subscribe_rx_count'],
          rx['count'],
          rx['subscribe_rx_count'],
          rx['subscribeRxCount'],
          subscribe['rx_count'],
          subscribe['rxCount'],
          subscribe['subscribe_rx_count'],
        ]),
        fallback: 0,
      ),
      subscribeRxAgoSec: _asDurationSec(
        _pick([
          json['seconds_since_last_subscribe'],
          json['secondsSinceLastSubscribe'],
          rx['seconds_since_last_subscribe'],
          rx['secondsSinceLastSubscribe'],
          subscribe['seconds_since_last_subscribe'],
        ]),
      ),
      lastRxAgoSec: _asDurationSec(
        _pick([
          json['last_rx_ago_sec'],
          json['lastRxAgoSec'],
          json['seconds_since_last_subscribe'],
          json['secondsSinceLastSubscribe'],
          json['last_subscribe_rx_ago_sec'],
          rx['last_rx_ago_sec'],
          rx['lastRxAgoSec'],
          rx['seconds_since_last_rx'],
          subscribe['last_rx_ago_sec'],
        ]),
      ),
      lastRxText: _asDisplayText(
        _pick([
          json['last_rx'],
          json['lastRx'],
          json['last_rx_at'],
          json['lastRxAt'],
          rx['last_rx'],
          rx['lastRx'],
          rx['last_rx_at'],
          subscribe['last_rx'],
        ]),
      ),
      lastRxBytes: _asInt(
        _pick([
          json['last_rx_bytes'],
          json['lastRxBytes'],
          json['last_subscribe_size'],
          json['lastSubscribeSize'],
          rx['last_rx_bytes'],
          rx['lastRxBytes'],
          rx['bytes'],
          rx['last_payload_bytes'],
          subscribe['last_rx_bytes'],
        ]),
        fallback: 0,
      ),
      mainPayloadBytes: _asInt(
        _pick([
          json['main_payload_bytes'],
          json['mainPayloadBytes'],
          json['main_size'],
          json['mainSize'],
          publish['main_payload_bytes'],
          publish['mainPayloadBytes'],
          publish['payload_bytes'],
          publish['last_payload_bytes'],
          publisher['main_payload_bytes'],
          summary['main_payload_bytes'],
          summary['mainPayloadBytes'],
        ]),
        fallback: 0,
      ),
    );
  }

  bool get isHealthy =>
      connected && status.toUpperCase() == 'CONNECTED' && lastResult != 'FAIL';

  static String _lastResult(
    dynamic value, {
    required bool connected,
    required int publishCount,
  }) {
    if (value is bool) {
      return value ? 'Success' : 'Fail';
    }
    final text = _asString(value);
    if (text.isNotEmpty) {
      return text;
    }
    if (connected && publishCount > 0) {
      return 'Success';
    }
    return '';
  }

  static String _tlsState(
    dynamic value, {
    required bool useTls,
    required bool connected,
    required bool connecting,
  }) {
    final text = _asString(value);
    if (text.isNotEmpty) {
      return text;
    }
    if (!useTls) {
      return 'Disabled';
    }
    if (connecting) {
      return 'Connecting';
    }
    if (connected) {
      return 'Connected';
    }
    return '';
  }

  static dynamic _pick(List<dynamic> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      return value;
    }
    return null;
  }

  static Map<String, dynamic> _map(dynamic value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  static String _asString(dynamic value) {
    return (value ?? '').toString().trim();
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

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  static int? _asDurationSec(dynamic value) {
    final parsed = _asNullableInt(value);
    if (parsed != null) {
      return parsed;
    }
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    final numeric = RegExp(r'-?\d+').firstMatch(text);
    if (numeric == null) {
      return null;
    }
    final amount = int.tryParse(numeric.group(0) ?? '');
    if (amount == null) {
      return null;
    }
    if (text.contains('ms')) {
      return (amount / 1000).round();
    }
    if (text.contains('min')) {
      return amount * 60;
    }
    return amount;
  }

  static String? _asDisplayText(dynamic value) {
    if (value == null || value is num || value is bool) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = '$value'.toLowerCase();
    if (text == 'true' || text == '1' || text == 'connected') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'disconnected') {
      return false;
    }
    return fallback;
  }
}
