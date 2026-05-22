import 'package:flutter/services.dart';

class MobileWifiService {
  const MobileWifiService();

  static const MethodChannel _channel = MethodChannel(
    'viot_monitor/mobile_wifi',
  );

  Future<List<MobileWifiNetwork>> scanWifiNetworks() async {
    final rawNetworks = await _channel.invokeListMethod<Object?>(
      'scanWifiNetworks',
    );
    return (rawNetworks ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(MobileWifiNetwork.fromPlatformMap)
        .where((network) => network.ssid.isNotEmpty)
        .toList();
  }

  Future<MobileWifiNetwork?> getCurrentWifi() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getCurrentWifi',
    );
    if (raw == null) {
      return null;
    }
    return MobileWifiNetwork.fromPlatformMap(raw);
  }

  Future<void> openWifiSettings() async {
    await _channel.invokeMethod<void>('openWifiSettings');
  }
}

class MobileWifiNetwork {
  const MobileWifiNetwork({
    required this.ssid,
    this.bssid,
    this.capabilities = '',
    this.level,
    this.frequency,
    this.isConnected = false,
  });

  factory MobileWifiNetwork.fromPlatformMap(Map<Object?, Object?> map) {
    return MobileWifiNetwork(
      ssid: (map['ssid'] as String?)?.trim() ?? '',
      bssid: map['bssid'] as String?,
      capabilities: map['capabilities'] as String? ?? '',
      level: map['level'] as int?,
      frequency: map['frequency'] as int?,
      isConnected: map['isConnected'] as bool? ?? false,
    );
  }

  final String ssid;
  final String? bssid;
  final String capabilities;
  final int? level;
  final int? frequency;
  final bool isConnected;

  bool get isEsp32Ap => ssid.toLowerCase().contains('viot');

  String get securityLabel {
    final value = capabilities.toUpperCase();
    if (value.contains('WPA3')) {
      return 'WPA3';
    }
    if (value.contains('WPA2')) {
      return 'WPA2';
    }
    if (value.contains('WPA')) {
      return 'WPA';
    }
    if (value.contains('WEP')) {
      return 'WEP';
    }
    return 'Open';
  }

  int get signalBars {
    final rssi = level;
    if (rssi == null) {
      return 0;
    }
    if (rssi >= -55) {
      return 4;
    }
    if (rssi >= -67) {
      return 3;
    }
    if (rssi >= -75) {
      return 2;
    }
    return 1;
  }
}
