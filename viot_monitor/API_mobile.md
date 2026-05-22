# Mobile App API Guide

เอกสารนี้สรุป HTTP API และ MQTT command สำหรับเขียน Mobile App ให้เชื่อมต่อกับ firmware ปัจจุบันของ `IotModule2_v2.00`.

## Firmware Defaults

- HTTP server: port `80`
- SoftAP fallback IP: `192.168.4.1`
- Discovery UDP port: `37020`
- mDNS service: `_iot-sensor._tcp.local`
- Protocol ID: `viot-discovery-v1`
- `ENABLE_WEB_FFT = 0`: `/api/fft_spectrum` เป็น shortcut เริ่ม HTTP FFT job ใน debug mode
- `ENABLE_MOBILE_FFT = 1`: MQTT FFT command เปิดใช้งาน
- Mode switch: `GPIO27 HIGH = debug/always-on`, `LOW = normal/sleep`

## Connection Strategy

1. หา device ด้วย mDNS, UDP discovery หรือ IP ที่ผู้ใช้กรอก
2. เรียก `GET http://<ip>/api/discover` เพื่อยืนยันว่าเป็น VIOT device
3. ถ้า setup ครั้งแรก ให้ต่อ SoftAP ของ device แล้วใช้ `http://192.168.4.1`
4. ใช้ HTTP API สำหรับ dashboard/config/calibration
5. ใช้ MQTT/MQTTS สำหรับ telemetry ระยะไกลและ FFT command/result

คำแนะนำเมื่อใช้ MQTTS:

- Poll dashboard ด้วย `GET /api/dashboard?keep_mqtt=1`
- Poll publish summary ด้วย `GET /api/mqtt_publish_summary?keep_mqtt=1`
- `GET /api/status`, `/api/health`, `/api/discover`, `/api/config` เป็น MQTT-safe ใน code ปัจจุบัน
- Config write/reconfigure อาจกระทบ MQTT/MQTTS ชั่วคราว เพราะ firmware ต้องป้องกัน heap ไม่พอ

## Request Format

POST endpoints ส่วนใหญ่ใช้ `request->hasParam(name, true)` จึงให้ Mobile App ส่งแบบ form:

```http
Content-Type: application/x-www-form-urlencoded
```

ตัวอย่าง Dart helper:

```dart
Future<Map<String, dynamic>> postForm(
  String baseUrl,
  String path,
  Map<String, String> fields,
) async {
  final res = await http.post(
    Uri.parse('$baseUrl$path'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: fields,
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('$path failed: ${res.statusCode} ${res.body}');
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}
```

## HTTP API Summary

| Method | Path | Use |
| --- | --- | --- |
| `GET` | `/api/discover` | device identity และ network metadata |
| `GET` | `/api/status` | system/WiFi/MQTT/battery status |
| `GET` | `/api/health` | heap/reset reason/restart recommendation |
| `GET` | `/api/dashboard?keep_mqtt=1` | dashboard data ล่าสุด |
| `GET` | `/api/config` | config ทั้งหมด |
| `POST` | `/api/config` | legacy WiFi save: `ssid`, `password` |
| `POST` | `/api/network_config` | WiFi STA/AP/static IP |
| `POST` | `/api/mqtt_config` | MQTT/MQTTS config |
| `POST` | `/api/mems_config` | ADXL345 และ vibration thresholds |
| `POST` | `/api/operate_config` | operate/sleep/debug settings |
| `POST` | `/api/system_config` | system log setting |
| `POST` | `/api/ap_config` | AP SSID/password |
| `POST` | `/api/scan_ssid_start` | start background WiFi scan |
| `GET` | `/api/scan_ssid_status` | poll scan result |
| `GET` | `/api/scan_ssid` | compatibility scan status/cache |
| `POST` | `/api/mems_calibrate` | start MEMS no-vibration calibration |
| `GET` | `/api/mems_calibration_status` | poll calibration job |
| `GET` | `/api/mems_calibration` | read saved calibration |
| `POST` | `/api/mems_calibration_reset` | reset calibration |
| `GET` | `/api/fft_spectrum` | default build: start HTTP FFT job in debug mode |
| `POST` | `/api/fft_request` | start HTTP FFT job in debug mode |
| `GET` | `/api/fft_status` | poll HTTP FFT job |
| `GET` | `/api/mqtt_publish_summary?keep_mqtt=1` | MQTT publish and command summary |
| `POST` | `/api/mqtt_restart` | reset MQTT retry and reconnect |
| `POST` | `/api/mqtt_retry` | alias ของ `/api/mqtt_restart` |
| `POST` | `/api/reboot` | reboot |
| `POST` | `/api/reset` | factory reset |
| `WS` | `/ws` | realtime dashboard push |

## Discover

```http
GET /api/discover
```

ตัวอย่าง response:

```json
{
  "protocol": "viot-discovery-v1",
  "device_type": "viot-sensor-node",
  "device_name": "VIOT_NODE_001",
  "device_id": "VIOT_NODE_001",
  "hostname": "viot-node-001",
  "mdns_host": "viot-node-001.local",
  "mdns_service": "_iot-sensor._tcp.local",
  "web_port": 80,
  "udp_port": 37020,
  "discover_path": "/api/discover",
  "status_path": "/api/status",
  "wifi_state": "WIFI_CONNECTED",
  "sta_connected": true,
  "sta_ip": "192.168.1.111",
  "ap_ip": "192.168.4.1",
  "ap_ssid": "VIOT_Config",
  "mac": "AA:BB:CC:DD:EE:FF",
  "mqtt_client_id": "VIOT_NODE_001",
  "rssi": -55,
  "uptime_sec": 360,
  "mdns_ready": true,
  "udp_ready": true,
  "fw_build_date": "May 21 2026",
  "fw_build_time": "20:30:00"
}
```

Mobile App ควรใช้ `protocol`, `device_type`, `sta_ip`, `web_port`, `status_path` และ `discover_path` เพื่อยืนยัน device ไม่ควร hardcode hostname อย่างเดียว.

## Status

```http
GET /api/status
```

ตัวอย่าง response:

```json
{
  "debug_mode": false,
  "log_enabled": true,
  "uptime_sec": 42,
  "battery_v": 3.91,
  "wifi_rssi": -55,
  "wifi_state": "WIFI_CONNECTED",
  "ap_ip": "192.168.4.1",
  "sta_ip": "192.168.1.111",
  "mqtt_connected": true,
  "mqtt_status": "CONNECTED",
  "mqtt_broker": "broker.hivemq.com",
  "mqtt_use_tls": false,
  "mqtt_retry_limited": false,
  "mqtt_connect_failures": 0,
  "mqtt_connect_failure_limit": 5,
  "mqtt_retry_limited_loops": 0,
  "mqtt_soft_recovery_attempted": false,
  "mqtt_heap_reboot_required": false,
  "mqtt_tls_min_largest_heap_bytes": 45000,
  "mqtt_retry_action": "/api/mqtt_restart",
  "mems_timing": {
    "effective_sample_rate_hz": 795.6,
    "target_period_us": 1250,
    "capture_elapsed_us": 1287011,
    "avg_read_high_us": 286,
    "avg_wait_low_us": 963
  }
}
```

UI mapping:

- Battery card: `battery_v`
- WiFi badge: `wifi_state`, `wifi_rssi`
- MQTT badge: `mqtt_status`, `mqtt_connected`
- Warning: `mqtt_retry_limited`, `mqtt_heap_reboot_required`
- Debug indicator: `debug_mode`

## Health

```http
GET /api/health
```

ตัวอย่าง response:

```json
{
  "ok": true,
  "restart_recommended": false,
  "restart_action": "/api/reboot",
  "uptime_sec": 360,
  "debug_mode": false,
  "reset_reason": "DEEPSLEEP",
  "heap": {
    "free_bytes": 120000,
    "largest_free_block_bytes": 76000,
    "minimum_free_bytes": 90000,
    "warning": false,
    "critical": false,
    "warn_free_threshold_bytes": 60000,
    "warn_largest_threshold_bytes": 45000,
    "critical_free_threshold_bytes": 30000,
    "critical_largest_threshold_bytes": 25000
  },
  "mqtt": {
    "connected": true,
    "status": "CONNECTED",
    "use_tls": false,
    "tls_connecting": false,
    "retry_limited": false,
    "connect_failures": 0,
    "connect_failure_limit": 5,
    "heap_reboot_required": false,
    "tls_min_largest_heap_bytes": 45000,
    "tls_heap_blocked": false,
    "retry_action": "/api/mqtt_restart"
  },
  "restart_reasons": [],
  "message": "Device health is OK."
}
```

ถ้า `restart_recommended=true` ให้แสดงปุ่ม reboot ที่เรียก `POST /api/reboot`.

## Dashboard

```http
GET /api/dashboard?keep_mqtt=1
```

ตัวอย่าง response:

```json
{
  "has_data": true,
  "ts": 123456789,
  "accel": { "x": 0.03, "y": 0.02, "z": 1.01 },
  "velocity": { "x": 0.12, "y": 0.08, "z": 0.34 },
  "vibration_freq": { "x": 19.1, "y": 0.0, "z": 53.4 },
  "orientation": { "pitch": -20.4, "roll": -3.4, "yaw": 0.0 },
  "displacement": { "x_um": 1.0, "y_um": 0.4, "z_um": 2.6 },
  "battery": 3.91,
  "rssi": -55,
  "wifi_state": "WIFI_CONNECTED",
  "mqtt": {
    "broker": "broker.hivemq.com",
    "status": "CONNECTED",
    "connected": true,
    "use_tls": false,
    "retry_limited": false,
    "connect_failures": 0,
    "connect_failure_limit": 5,
    "heap_reboot_required": false,
    "tls_min_largest_heap_bytes": 45000,
    "retry_action": "/api/mqtt_restart"
  },
  "ap_ip": "192.168.4.1",
  "mems_timing": {
    "effective_sample_rate_hz": 795.6,
    "target_period_us": 1250,
    "capture_elapsed_us": 1287011,
    "avg_read_high_us": 286,
    "avg_wait_low_us": 963
  }
}
```

ถ้า `has_data=false` ให้ UI แสดงสถานะรอ sample แรก.

## Config

```http
GET /api/config
```

โครงสร้างหลัก:

```json
{
  "wifi": {
    "ssid": "OfficeWiFi",
    "password": "secret",
    "ap_enabled": true,
    "ap_ssid": "VIOT_Config",
    "ap_ssid_effective": "VIOT_Config",
    "ap_password": "12345678",
    "sta_use_static_ip": false,
    "sta_static_ip": "",
    "sta_gateway": "",
    "sta_subnet": "",
    "sta_dns1": "",
    "sta_dns2": "",
    "state": "WIFI_CONNECTED"
  },
  "mqtt": {
    "broker": "broker.hivemq.com",
    "port": 1883,
    "client_id": "VIOT_NODE_001",
    "username": "",
    "password": "",
    "topic_publish": "viot/vibration",
    "topic_fft_x": "viot/vibration/fft/x",
    "topic_fft_y": "viot/vibration/fft/y",
    "topic_fft_z": "viot/vibration/fft/z",
    "topic_subscribe": "viot/config",
    "topic_ack": "viot/config/ack",
    "topic_result": "viot/config/result",
    "publish_interval_s": 60,
    "publish_on_vibration_trigger": false,
    "publish_vibration_threshold_mm_s": 5.0,
    "use_tls": false,
    "protocol": "mqtt",
    "status": "CONNECTED"
  },
  "adxl345": {
    "rate_hz": 800,
    "range_g": 16,
    "offset_x": 0.0,
    "offset_y": 0.0,
    "offset_z": 0.0,
    "int_threshold_mg": 250,
    "int_enabled": true
  },
  "vibration": {
    "min_rms_g": 0.02,
    "min_peak_g": 0.05,
    "noise_floor_db": -20.0,
    "deadband_g": 0.005,
    "min_freq_hz": 5.0,
    "max_freq_hz": 1000.0
  },
  "power": {
    "sleep_enabled": true,
    "sleep_interval_sec": 3600,
    "log_enabled": true,
    "debug_log_mask": 255,
    "debug_logs": {
      "wifi": true,
      "mqtt": true,
      "mems": true,
      "power": true,
      "web": true,
      "battery": true,
      "operate": true,
      "system": true
    }
  },
  "operate": {
    "publish_interval_s": 60,
    "wakeup_int_threshold_mg": 250,
    "wakeup_int_enabled": true,
    "wakeup_timer_sec": 3600,
    "publish_on_vibration_trigger": false,
    "publish_vibration_threshold_mm_s": 5.0,
    "log_enabled": true,
    "debug_log_mask": 255
  }
}
```

## Configure Network

```http
POST /api/network_config
```

Fields:

| Field | Example | Note |
| --- | --- | --- |
| `ssid` | `OfficeWiFi` | STA SSID |
| `password` | `wifi-password` | STA password |
| `ap_enabled` | `1` | omit หรือ `1` = enable, `0` = disable |
| `ap_ssid` | `VIOT_Config` | optional |
| `ap_password` | `12345678` | ถ้าใส่ต้องอย่างน้อย 8 chars |
| `sta_use_static_ip` | `0` | `1` = static IP |
| `sta_static_ip` | `192.168.1.111` | required เมื่อ static |
| `sta_gateway` | `192.168.1.1` | required เมื่อ static |
| `sta_subnet` | `255.255.255.0` | required เมื่อ static |
| `sta_dns1` | `8.8.8.8` | optional |
| `sta_dns2` | `1.1.1.1` | optional |

ตัวอย่าง:

```dart
await postForm(baseUrl, '/api/network_config', {
  'ssid': 'OfficeWiFi',
  'password': 'wifi-password',
  'ap_enabled': '1',
  'ap_ssid': 'VIOT_Config',
  'ap_password': '12345678',
  'sta_use_static_ip': '0',
});
```

## WiFi Scan

เริ่ม scan:

```dart
await http.post(Uri.parse('$baseUrl/api/scan_ssid_start'));
```

Poll:

```dart
Future<List<dynamic>> scanWifi(String baseUrl) async {
  await http.post(Uri.parse('$baseUrl/api/scan_ssid_start'));

  for (var i = 0; i < 30; i++) {
    await Future.delayed(const Duration(seconds: 1));
    final res = await http.get(Uri.parse('$baseUrl/api/scan_ssid_status'));
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['done'] == true) {
      if (json['success'] == true) return (json['networks'] as List?) ?? [];
      throw Exception(json['message'] ?? 'WiFi scan failed');
    }
  }
  throw TimeoutException('WiFi scan timeout');
}
```

## Configure MQTT / MQTTS

```http
POST /api/mqtt_config
```

Fields:

| Field | Example | Note |
| --- | --- | --- |
| `protocol` | `mqtts` | `mqtt` หรือ `mqtts`; หรือส่ง `use_tls=1` |
| `broker` | `example.s1.eu.hivemq.cloud` | required |
| `port` | `8883` | required |
| `client_id` | `VIOT_NODE_001` | optional แต่ควรตั้ง |
| `username` | `viot_node1` | optional |
| `password` | `secret` | optional |
| `topic_publish` | `viot/vibration` | empty = default |
| `topic_fft_x` | `viot/vibration/fft/x` | empty = default |
| `topic_fft_y` | `viot/vibration/fft/y` | empty = default |
| `topic_fft_z` | `viot/vibration/fft/z` | empty = default |
| `topic_subscribe` | `viot/config` | empty = default |
| `topic_ack` | `viot/config/ack` | empty = default |
| `topic_result` | `viot/config/result` | empty = default |
| `publish_interval_s` | `60` | clamp `1..3600` |

ตัวอย่าง:

```dart
await postForm(baseUrl, '/api/mqtt_config', {
  'protocol': 'mqtts',
  'broker': 'example.s1.eu.hivemq.cloud',
  'port': '8883',
  'client_id': 'VIOT_NODE_001',
  'username': 'viot_node1',
  'password': 'secret',
  'topic_publish': 'viot/vibration',
  'topic_fft_x': 'viot/vibration/fft/x',
  'topic_fft_y': 'viot/vibration/fft/y',
  'topic_fft_z': 'viot/vibration/fft/z',
  'topic_subscribe': 'viot/config',
  'topic_ack': 'viot/config/ack',
  'topic_result': 'viot/config/result',
  'publish_interval_s': '60',
});
```

## Configure MEMS

```http
POST /api/mems_config
```

Fields:

| Field | Example | Note |
| --- | --- | --- |
| `rate_hz` | `800` | normalize เป็น `400`, `800`, หรือ `1600` |
| `range_g` | `16` | ADXL345 range |
| `offset_x` | `0` | offset |
| `offset_y` | `0` | offset |
| `offset_z` | `0` | offset |
| `int_threshold_mg` | `250` | motion wake threshold |
| `int_enabled` | `1` | `1` enable |
| `min_rms_g` | `0.02` | vibration validation |
| `min_peak_g` | `0.05` | vibration validation |
| `noise_floor_db` | `-20` | FFT noise floor |
| `deadband_g` | `0.005` | zero-crossing deadband |
| `min_freq_hz` | `5` | min valid frequency |
| `max_freq_hz` | `1000` | max valid frequency |
| `sleep_interval_sec` | `3600` | clamp `60..86400` |

ตัวอย่าง:

```dart
await postForm(baseUrl, '/api/mems_config', {
  'rate_hz': '800',
  'range_g': '16',
  'offset_x': '0',
  'offset_y': '0',
  'offset_z': '0',
  'int_threshold_mg': '250',
  'int_enabled': '1',
  'min_rms_g': '0.02',
  'min_peak_g': '0.05',
  'noise_floor_db': '-20',
  'deadband_g': '0.005',
  'min_freq_hz': '5',
  'max_freq_hz': '1000',
  'sleep_interval_sec': '3600',
});
```

## MEMS Calibration

Start:

```http
POST /api/mems_calibrate
```

Fields:

| Field | Example | Note |
| --- | --- | --- |
| `duration_sec` | `10` | default `10` |
| `margin_factor` | `2.0` | default `2.0` |
| `apply` | `1` | `1` save thresholds, `0` test only |

ตัวอย่าง start response:

```json
{
  "status": "accepted",
  "running": true,
  "message": "MEMS calibration started.",
  "duration_sec": 10,
  "margin_factor": 2.0,
  "apply": true
}
```

Poll:

```http
GET /api/mems_calibration_status
```

ตัวอย่าง done response:

```json
{
  "running": false,
  "done": true,
  "success": true,
  "started_ms": 1000,
  "finished_ms": 12000,
  "message": "Calibration complete",
  "duration_sec": 10,
  "rounds": 8,
  "margin_factor": 2.0,
  "applied": true,
  "baseline": {
    "rms_g": { "x": 0.006, "y": 0.007, "z": 0.010 },
    "peak_g": { "x": 0.031, "y": 0.037, "z": 0.051 }
  },
  "thresholds": {
    "min_rms_g": 0.02,
    "min_peak_g": 0.05,
    "deadband_g": 0.005
  }
}
```

Reset:

```dart
await http.post(Uri.parse('$baseUrl/api/mems_calibration_reset'));
```

## Configure Operate

```http
POST /api/operate_config
```

Fields:

| Field | Example | Note |
| --- | --- | --- |
| `publish_interval_s` | `60` | clamp `1..3600` |
| `int_threshold_mg` | `250` | clamp `1..16000` |
| `int_enabled` | `1` | ADXL345 wake interrupt |
| `sleep_interval_sec` | `3600` | clamp `60..86400` |
| `publish_on_vibration_trigger` | `1` | motion wake gate |
| `publish_vibration_threshold_mm_s` | `5.0` | clamp `0.1..1000` |
| `log_enabled` | `1` | serial log master |
| `debug_log_wifi` | `1` | debug category |
| `debug_log_mqtt` | `1` | debug category |
| `debug_log_mems` | `0` | debug category |
| `debug_log_power` | `1` | debug category |
| `debug_log_web` | `0` | debug category |
| `debug_log_battery` | `0` | debug category |
| `debug_log_operate` | `1` | debug category |
| `debug_log_system` | `1` | debug category |

ตัวอย่าง:

```dart
await postForm(baseUrl, '/api/operate_config', {
  'publish_interval_s': '60',
  'int_threshold_mg': '250',
  'int_enabled': '1',
  'sleep_interval_sec': '3600',
  'publish_on_vibration_trigger': '1',
  'publish_vibration_threshold_mm_s': '5.0',
  'log_enabled': '1',
  'debug_log_wifi': '1',
  'debug_log_mqtt': '1',
  'debug_log_mems': '0',
  'debug_log_power': '1',
  'debug_log_web': '0',
  'debug_log_battery': '0',
  'debug_log_operate': '1',
  'debug_log_system': '1',
});
```

## HTTP FFT Debug Flow

ใช้ได้เฉพาะ debug mode (`GPIO27 HIGH`). ใน default build:

- `GET /api/fft_spectrum?axis=x&step_hz=30&request_id=req-1` เริ่ม job และคืน `202`
- `POST /api/fft_request` เริ่ม job และคืน `202`
- `GET /api/fft_status` ใช้ poll result

Start response:

```json
{
  "status": "accepted",
  "running": true,
  "done": false,
  "axis": "x",
  "step_hz": 30,
  "request_id": "req-1",
  "status_url": "/api/fft_status",
  "message": "HTTP FFT calculation started. Poll /api/fft_status."
}
```

Done response:

```json
{
  "running": false,
  "done": true,
  "success": true,
  "started_ms": 1000,
  "finished_ms": 5000,
  "axis": "x",
  "step_hz": 30,
  "request_id": "req-1",
  "message": "HTTP FFT calculation complete.",
  "points": 27,
  "data": {
    "freq_hz": [10, 40, 70, 100],
    "amplitude_mm_s": [0.12, 0.34, 0.08, 0.01]
  }
}
```

Error rules:

- ไม่ใช่ debug mode: `403 {"error":"debug mode required"}`
- MQTT FFT กำลังทำงาน: `409`
- HTTP FFT job กำลังทำงาน: `409`
- heap ต่ำ: `503`

## MQTT Publish Summary

```http
GET /api/mqtt_publish_summary?keep_mqtt=1
```

ตัวอย่าง response:

```json
{
  "has_publish": true,
  "success": true,
  "publish_count": 12,
  "last_attempt_ms": 120000,
  "last_success_ms": 120000,
  "seconds_since_last_success": 3,
  "publish_interval_s": 60,
  "next_publish_due_ms": 180000,
  "seconds_until_next_publish": 57,
  "tls_connecting": false,
  "connected": true,
  "status": "CONNECTED",
  "use_tls": false,
  "retry_limited": false,
  "connect_failures": 0,
  "connect_failure_limit": 5,
  "heap_reboot_required": false,
  "tls_min_largest_heap_bytes": 45000,
  "retry_action": "/api/mqtt_restart",
  "main_size": 420,
  "fft_x_size": 0,
  "fft_y_size": 0,
  "fft_z_size": 0,
  "subscribe_receive_count": 1,
  "last_subscribe_ms": 90000,
  "seconds_since_last_subscribe": 33,
  "last_subscribe_size": 58
}
```

## MQTT Telemetry

Device publish ไปที่ `topic_publish`, default:

```text
viot/vibration
```

Payload:

```json
{
  "timestamp": 123456789,
  "data": {
    "accel_x_rms": 0.01,
    "accel_y_rms": 0.02,
    "accel_z_rms": 1.0,
    "vibration_x_rms_mm_s": 0.5,
    "vibration_y_rms_mm_s": 0.8,
    "vibration_z_rms_mm_s": 1.2,
    "vibration_freq_x_hz": 48.0,
    "vibration_freq_y_hz": 49.0,
    "vibration_freq_z_hz": 50.0,
    "displacement_x_um": 10.0,
    "displacement_y_um": 11.0,
    "displacement_z_um": 12.0,
    "pitch_deg": 0.0,
    "roll_deg": 0.0,
    "yaw_deg": 0.0,
    "battery_v": 3.91,
    "wifi_rssi": -55,
    "uptime_ms": 120000
  }
}
```

Normal mode จะ publish payload แรกเมื่อ MQTT connected และ MEMS analysis พร้อม แล้วเข้า deep sleep หลัง publish สำเร็จถ้าไม่มีงานค้าง.

## MQTT FFT Command

Default topics:

| Purpose | Default Topic |
| --- | --- |
| Command publish | `viot/config` |
| ACK subscribe | `viot/config/ack` |
| Result subscribe | `viot/config/result` |
| Axis X mirror | `viot/vibration/fft/x` |
| Axis Y mirror | `viot/vibration/fft/y` |
| Axis Z mirror | `viot/vibration/fft/z` |

Command JSON:

```json
{
  "action": "fft_x",
  "request_id": "mobile-001",
  "step_hz": 10
}
```

รองรับ:

- `action`: `fft_x`, `fft_y`, `fft_z`
- alias field: `command`
- `step_hz` หรือ `resolution_hz`
- plain text command: `fft_x`, `fft_y`, `fft_z`
- normalized step: `10`, `15`, `20`, `25`, `30`, `35`, `40`, `45`, `50`

ACK examples:

```json
{ "status": "accepted", "axis": "x", "request_id": "mobile-001", "detail": "queued_for_3_rounds", "timestamp": 12345 }
```

```json
{ "status": "processing", "axis": "x", "request_id": "mobile-001", "detail": "3_rounds_collected", "timestamp": 14567 }
```

```json
{ "status": "done", "axis": "x", "request_id": "mobile-001", "detail": "result_published", "timestamp": 17890 }
```

Result example:

```json
{
  "timestamp": 123456789,
  "axis": "x",
  "request_id": "mobile-001",
  "step_hz": 10,
  "data": {
    "x_freq_hz": [10, 20, 30, 40, 50],
    "x_amplitude_mm_s": [0.0, 0.4, 1.2, 0.8, 0.1]
  }
}
```

Rules:

- Device เก็บ MEMS analysis 3 rounds ก่อน publish FFT result
- ถ้ามี FFT pending อยู่ command ใหม่จะได้ ACK `busy`
- ถ้า `request_id` เดิมยัง pending จะได้ ACK `duplicate_ignored`
- Timeout ประมาณ `8000 ms` แล้วส่ง ACK `timeout`
- Result publish ไปทั้ง `topic_result` และ axis mirror topic

## MQTT Retry / Reboot / Reset

Retry MQTT:

```dart
await http.post(Uri.parse('$baseUrl/api/mqtt_restart'));
```

Response:

```json
{
  "status": "ok",
  "message": "MQTT reconnect requested.",
  "was_retry_limited": true,
  "connect_failures_before": 5,
  "connect_failures_after": 0,
  "connect_failure_limit": 5,
  "mqtt_status": "DISCONNECTED"
}
```

Reboot:

```dart
await http.post(Uri.parse('$baseUrl/api/reboot'));
```

Factory reset:

```dart
await postForm(baseUrl, '/api/reset', {
  'clear_spiffs': '0',
});
```

ใน code ปัจจุบัน factory reset เช็ค `clear_spiffs == "true"` ดังนั้นถ้าต้องล้าง SPIFFS ให้ส่ง:

```dart
await postForm(baseUrl, '/api/reset', {
  'clear_spiffs': 'true',
});
```

## WebSocket Dashboard

```text
ws://<ip>/ws
```

WebSocket เป็น server push สำหรับ dashboard data. ไม่มี incoming command protocol สำหรับ mobile ใน code ปัจจุบัน. ถ้า app ไม่ต้องการ realtime มาก ให้ poll `/api/dashboard?keep_mqtt=1` ทุก 1-2 วินาทีง่ายกว่า.

## Recommended Mobile Pages

- Home/Dashboard: `/api/dashboard?keep_mqtt=1`, battery, WiFi, MQTT, velocity/frequency/displacement
- Device Health: `/api/status`, `/api/health`
- Network Settings: `/api/config`, `/api/scan_ssid_start`, `/api/scan_ssid_status`, `/api/network_config`
- MQTT Settings: `/api/config`, `/api/mqtt_config`, `/api/mqtt_restart`
- MEMS Settings: `/api/config`, `/api/mems_config`, `/api/mems_calibrate`
- Operate Settings: `/api/operate_config`
- FFT: MQTT command/result เป็นหลัก; HTTP FFT เฉพาะ debug mode

## Error Handling

- `202`: operation accepted, poll status endpoint ต่อ
- `400`: parameter ไม่ครบหรือไม่ถูกต้อง
- `403`: mode ไม่ถูก เช่น HTTP FFT แต่ไม่ได้อยู่ debug mode
- `409`: job busy/conflict
- `500`: firmware/internal failure
- `503`: heap/resource ต่ำ ให้รอหรือ retry
- timeout: reconnect network หรือให้ผู้ใช้เช็ค AP/STA

## Quick Test With curl

```bash
curl http://192.168.1.111/api/discover
curl http://192.168.1.111/api/status
curl http://192.168.1.111/api/health
curl "http://192.168.1.111/api/dashboard?keep_mqtt=1"
curl -X POST http://192.168.1.111/api/scan_ssid_start
curl http://192.168.1.111/api/scan_ssid_status
curl -X POST -d "protocol=mqtt&broker=broker.hivemq.com&port=1883&client_id=VIOT_NODE_001&publish_interval_s=60" http://192.168.1.111/api/mqtt_config
curl -X POST -d "duration_sec=10&margin_factor=2.0&apply=1" http://192.168.1.111/api/mems_calibrate
curl http://192.168.1.111/api/mems_calibration_status
curl -X POST http://192.168.1.111/api/mqtt_restart
```
