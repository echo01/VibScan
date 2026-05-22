# VIOT ESP32 Firmware

Firmware สำหรับ ESP32 vibration monitoring node ที่ใช้ `ADXL345`, WiFi, HTTP/WebSocket API และ MQTT/MQTTS. เอกสารนี้สรุปตาม code ปัจจุบันของโปรเจกต์ `IotModule2_v2.00`.

## ภาพรวมระบบ

- อ่านข้อมูลสั่นสะเทือนจาก `ADXL345` จำนวน `1024` samples ต่อรอบ
- คำนวณ RMS acceleration, RMS velocity, dominant frequency, displacement และ FFT snapshot
- เปิด HTTP API สำหรับ dashboard, status, config, WiFi scan, MEMS calibration, FFT job, MQTT retry, reboot และ reset
- ส่งข้อมูล realtime ผ่าน `WebSocket /ws`
- Publish telemetry ไป MQTT/MQTTS และรับ MQTT command สำหรับขอ FFT รายแกน
- บันทึก config ใน SPIFFS ที่ `/config.json`
- รองรับ discovery ผ่าน mDNS, UDP port `37020` และ `GET /api/discover`

ไฟล์หลักที่ควรดูเมื่อแก้ logic:

- `src/main.cpp`
- `src/web_server.cpp`
- `src/mqtt_handler.cpp`
- `src/wifi_handler.cpp`
- `src/discovery_service.cpp`
- `src/power_management.cpp`
- `src/storage.cpp`
- `src/sensors.cpp`
- `include/config.h`
- `include/common.h`

## Hardware Mapping

อ้างอิงจาก `include/config.h` และ code ปัจจุบัน:

| Pin | หน้าที่ |
| --- | --- |
| `GPIO27` | Mode switch, `HIGH = Debug/Always ON`, `LOW = Normal/Sleep` |
| `GPIO32` | Status LED, เปิดตอน wake |
| `GPIO33` | MQTT activity LED, blink ตอน publish สำเร็จ |
| `GPIO34` | Battery ADC ผ่าน divider `100k/100k` |
| `GPIO25` | ADXL345 `INT1`, ใช้ wake จาก motion |
| `GPIO26` | ADXL345 `INT2` |
| `GPIO23` | Debug sample pulse |
| `GPIO21` | I2C SDA |
| `GPIO22` | I2C SCL |

หมายเหตุสำคัญของ `GPIO27`: วงจรมี external pull-down อยู่แล้ว จึงตั้ง runtime เป็น `INPUT` และตั้ง RTC deep sleep เป็น `pulldown_en` / `pullup_dis`. ถ้า GPIO27 เป็น HIGH เครื่องจะเข้า debug mode และไม่ deep sleep.

## Runtime Modes

### Normal Mode

เงื่อนไข: `GPIO27 = LOW`

- ตั้ง unused pins บางตัวเป็น low-power state
- อ่าน battery แบบ average หลังรอให้ระบบนิ่งประมาณ `5s`
- ไม่สร้าง ADC task อ่านแบตซ้ำทุก 30 วินาที
- เมื่อ publish MQTT สำเร็จอย่างน้อย 1 payload จะเข้า deep sleep
- Wake ได้จาก timer และ ADXL345 motion interrupt

### Debug Mode

เงื่อนไข: `GPIO27 = HIGH`

- ปิด sleep (`g_power_manager.disableSleep()`)
- ADC task อ่าน battery ทุก `30s`
- Web/API/MQTT/MEMS tasks ทำงานต่อเนื่อง
- เหมาะสำหรับ config, debug, HTTP FFT, calibration และดู dashboard realtime

## Power / Sleep Behavior

- ค่า default `sleep_interval_sec` คือ `3600` วินาที
- Normal mode จะ publish ครั้งแรกทันทีเมื่อ MQTT connected และมี MEMS analysis พร้อม ไม่ต้องรอครบ `publish_interval_s`
- ถ้า WiFi หรือ MQTT fail ครบ retry limit ใน normal mode เครื่องจะกลับเข้า deep sleep โดยไม่ publish
- Motion wake policy จะ suppress ADXL345 wake ชั่วคราวเมื่อเกิด motion wake ติดต่อกันหลายครั้ง เพื่อลด wake loop
- Battery timing ต่างกันตาม mode:
  - normal: sample ครั้งเดียวต่อ wake cycle
  - debug: refresh ทุก 30 วินาที

## Network และ Discovery

- HTTP port: `80`
- SoftAP fallback IP: `192.168.4.1`
- mDNS service: `_iot-sensor._tcp.local`
- UDP discovery port: `37020`
- Discovery endpoint: `GET /api/discover`
- Protocol ID: `viot-discovery-v1`

SoftAP ไม่ได้ถูกคงไว้เสมอหลัง STA connected. Mobile app ควรค้นหา device ด้วย mDNS/UDP/known IP ก่อน แล้ว confirm ด้วย `/api/discover`.

## HTTP / WebSocket Surface

หน้าเว็บหลัก:

- `/`
- `/index.html`
- `/mqtt_setting.html`
- `/network_setting.html`
- `/mems_setting.html`
- `/operate_config.html`
- `/system_setting.html`
- `/mqtt_log`
- `/fft_chart.html` เฉพาะเมื่อ build ด้วย `ENABLE_WEB_FFT=1`

API หลัก:

| Method | Path | ใช้สำหรับ |
| --- | --- | --- |
| `GET` | `/api/discover` | device identity, IP, discovery metadata |
| `GET` | `/api/status` | system/WiFi/MQTT/battery status |
| `GET` | `/api/health` | heap, reset reason, restart recommendation |
| `GET` | `/api/dashboard?keep_mqtt=1` | vibration dashboard ล่าสุด |
| `GET` | `/api/config` | อ่าน config ทั้งหมด |
| `POST` | `/api/config` | legacy WiFi save: `ssid`, `password` |
| `POST` | `/api/network_config` | STA/AP/static IP |
| `POST` | `/api/mqtt_config` | MQTT/MQTTS/topics/publish interval |
| `POST` | `/api/mems_config` | ADXL345 และ vibration thresholds |
| `POST` | `/api/operate_config` | publish/sleep/interrupt/debug logs |
| `POST` | `/api/system_config` | system log enable |
| `POST` | `/api/ap_config` | AP SSID/password |
| `POST` | `/api/scan_ssid_start` | start background WiFi scan |
| `GET` | `/api/scan_ssid_status` | poll WiFi scan result |
| `GET` | `/api/scan_ssid` | compatibility scan status/cache |
| `POST` | `/api/mems_calibrate` | start no-vibration calibration |
| `GET` | `/api/mems_calibration_status` | poll calibration job |
| `GET` | `/api/mems_calibration` | read saved calibration |
| `POST` | `/api/mems_calibration_reset` | reset calibration |
| `GET` | `/api/fft_spectrum` | default build: start HTTP FFT job in debug mode |
| `POST` | `/api/fft_request` | start HTTP FFT job in debug mode |
| `GET` | `/api/fft_status` | poll HTTP FFT job |
| `GET` | `/api/fft_csv` | only when `ENABLE_WEB_FFT=1` |
| `GET` | `/api/mqtt_publish_summary?keep_mqtt=1` | MQTT publish/command summary |
| `POST` | `/api/mqtt_restart` | reset MQTT retry and reconnect |
| `POST` | `/api/mqtt_retry` | alias ของ `/api/mqtt_restart` |
| `POST` | `/api/reboot` | reboot device |
| `POST` | `/api/reset` | factory reset |
| `WS` | `/ws` | realtime dashboard push |

POST handlers อ่านค่าจาก form parameters (`request->hasParam(name, true)`) เป็นหลัก จึงควรส่งเป็น `application/x-www-form-urlencoded` หรือ `multipart/form-data`. ไม่ควรส่ง JSON body ยกเว้น firmware ถูกแก้ให้ parse เพิ่ม.

## MQTT Surface

Default topics:

| Purpose | Default |
| --- | --- |
| Main telemetry | `viot/vibration` |
| FFT X mirror | `viot/vibration/fft/x` |
| FFT Y mirror | `viot/vibration/fft/y` |
| FFT Z mirror | `viot/vibration/fft/z` |
| Command subscribe | `viot/config` |
| Command ACK | `viot/config/ack` |
| Command result | `viot/config/result` |

Main telemetry payload:

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

MQTT FFT command รองรับ plain text `fft_x`, `fft_y`, `fft_z` หรือ JSON:

```json
{
  "action": "fft_x",
  "request_id": "mobile-001",
  "step_hz": 10
}
```

`step_hz` จะ normalize เป็นหนึ่งใน `10,15,20,25,30,35,40,45,50`.

## Mobile App Handoff

คู่มือ API สำหรับ Mobile อยู่ที่ [API_mobile.md](API_mobile.md). แนวทางที่แนะนำ:

1. ค้นหา device ด้วย mDNS หรือ UDP discovery
2. Confirm device ด้วย `GET /api/discover`
3. Poll `GET /api/status` หรือ `GET /api/health` สำหรับ health
4. ใช้ `GET /api/dashboard?keep_mqtt=1` หรือ `WS /ws` สำหรับ dashboard
5. อ่าน config ด้วย `GET /api/config`
6. Save config ด้วย form POST endpoints
7. ใช้ MQTT command/result สำหรับ FFT เมื่ออยู่นอก LAN หรือไม่ต้องการ HTTP debug FFT

## Build / Flash

PlatformIO environment:

- env: `esp32-s3-devkitc-1`
- board: `esp32dev`
- framework: Arduino
- filesystem: SPIFFS
- serial baud: `115200`

Commands:

```bash
pio run
pio run --target upload
pio run --target uploadfs
pio device monitor --baud 115200
```

ถ้า `pio` ไม่อยู่ใน PATH บนเครื่องนี้ มักใช้ path:

```powershell
& "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe" run
```
