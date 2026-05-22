import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../models/device_node.dart';

class LocalStorageService {
  const LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  List<DeviceNode> loadSavedDevices() {
    final raw = _prefs.getString(StorageKeys.savedDevices);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((entry) => DeviceNode.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> saveSavedDevices(List<DeviceNode> devices) async {
    final encoded = jsonEncode(
      devices.map((device) => device.toJson()).toList(),
    );
    await _prefs.setString(StorageKeys.savedDevices, encoded);
  }

  String? loadActiveNodeId() => _prefs.getString(StorageKeys.activeNodeId);

  Future<void> saveActiveNodeId(String? id) async {
    if (id == null || id.isEmpty) {
      await _prefs.remove(StorageKeys.activeNodeId);
      return;
    }
    await _prefs.setString(StorageKeys.activeNodeId, id);
  }

  String loadSensorApBaseUrl() {
    return _prefs.getString(StorageKeys.sensorApBaseUrl) ??
        'http://192.168.4.1';
  }

  Future<void> saveSensorApBaseUrl(String value) async {
    await _prefs.setString(StorageKeys.sensorApBaseUrl, value);
  }

  String loadFftAxis() => _prefs.getString(StorageKeys.fftAxis) ?? 'X';

  Future<void> saveFftAxis(String axis) async {
    await _prefs.setString(StorageKeys.fftAxis, axis);
  }
}
