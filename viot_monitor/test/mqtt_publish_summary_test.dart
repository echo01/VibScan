import 'package:flutter_test/flutter_test.dart';
import 'package:viot_monitor/core/models/mqtt_publish_summary.dart';

void main() {
  test('parses mqtt publish summary response from node firmware', () {
    final summary = MqttPublishSummary.fromJson({
      'has_publish': true,
      'success': true,
      'publish_count': 12,
      'last_attempt_ms': 123456,
      'last_success_ms': 123456,
      'seconds_since_last_success': 5,
      'publish_interval_s': 360,
      'next_publish_due_ms': 483456,
      'seconds_until_next_publish': 355,
      'connected': true,
      'status': 'CONNECTED',
      'main_size': 512,
      'fft_x_size': 0,
      'fft_y_size': 0,
      'fft_z_size': 0,
      'subscribe_receive_count': 1,
      'last_subscribe_ms': 120000,
      'seconds_since_last_subscribe': 8,
      'last_subscribe_size': 64,
    });

    expect(summary.connected, isTrue);
    expect(summary.publishCount, 12);
    expect(summary.lastResult, 'Success');
    expect(summary.lastSentAgoSec, 5);
    expect(summary.nextSendInSec, 355);
    expect(summary.subscribeRxCount, 1);
    expect(summary.subscribeRxAgoSec, 8);
    expect(summary.lastRxAgoSec, 8);
    expect(summary.lastRxBytes, 64);
    expect(summary.mainPayloadBytes, 512);
  });
}
