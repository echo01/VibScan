# VibScan Mobile App

Flutter mobile app for discovering, monitoring, analyzing, and configuring ESP32 VIOT vibration sensor nodes.

This README summarizes the current mobile app behavior. Firmware/API details are documented in [API_mobile.md](API_mobile.md), and vibration fault rules are documented in [Fault_Identification.md](Fault_Identification.md).

## Overview

VibScan connects to ESP32 vibration sensor nodes over local network REST APIs. The app focuses on:

- Device discovery by mDNS, UDP discovery, and known IP
- Live dashboard polling with MQTT-safe REST calls
- Machine health assessment using ISO 10816-1 velocity RMS thresholds
- VibScan FFT-based fault identification
- MQTT runtime and publish monitoring
- Device configuration by REST form POST endpoints
- CSV export and sharing for dashboard and FFT data

## Tech Stack

- Flutter
- Riverpod for state management
- Dio for REST API calls
- SharedPreferences for local saved devices and preferences
- fl_chart and custom painting for charts
- Android platform channel for mobile WiFi scan and CSV Downloads save

## App Navigation

The app uses a five-item bottom navigation shell:

| Menu | Purpose |
| --- | --- |
| WiFi | Scan mobile WiFi networks, discover VIOT devices, save/select devices |
| Analyze | Machine Health and VibScan analysis |
| Dashboard | Live dashboard, realtime chart, FFT panel, CSV export |
| MQTT | MQTT status and publish summary |
| Config | MQTT, Network, MEMS, Operate, and System actions |

## Core Flow

1. Open WiFi menu.
2. Discover VIOT nodes or connect to the device AP.
3. Save a discovered node.
4. Select the active node.
5. Use Dashboard, Analyze, MQTT, or Config menus against the active node.

Saved device and active node are persisted locally with SharedPreferences.

## REST API Usage

The app uses REST polling and form POST APIs. Config POST requests are sent as `application/x-www-form-urlencoded`.

Key endpoints:

| Method | Endpoint | Used For |
| --- | --- | --- |
| GET | `/api/discover` | Confirm device identity |
| GET | `/api/dashboard?keep_mqtt=1` | Live dashboard polling |
| GET | `/api/status` | MQTT/runtime status |
| GET | `/api/config` | Load current configuration |
| POST | `/api/network_config` | Save STA/AP/static IP settings |
| POST | `/api/mqtt_config` | Save MQTT/MQTTS settings |
| POST | `/api/mems_config` | Save MEMS and vibration thresholds |
| POST | `/api/operate_config` | Save publish/sleep/debug settings |
| POST | `/api/system_config` | System config endpoint, currently not exposed in System tab |
| POST | `/api/scan_ssid_start` | Start background WiFi scan on node |
| GET | `/api/scan_ssid_status` | Poll node WiFi scan result |
| GET | `/api/mqtt_publish_summary?keep_mqtt=1` | MQTT publish summary |
| GET | `/api/fft_spectrum` | Start HTTP FFT job in debug mode |
| GET | `/api/fft_status` | Poll HTTP FFT job |
| POST | `/api/reboot` | Reboot ESP32; used by Restart MQTT button |
| POST | `/api/reset` | Factory default reset |

## Dashboard

Dashboard uses:

```text
GET /api/dashboard?keep_mqtt=1
```

The `keep_mqtt=1` query is used so dashboard polling does not pause or disconnect MQTTS on firmware builds that support this behavior.

Displayed data includes:

- Acceleration X/Y/Z
- Velocity X/Y/Z in `mm/s`
- Frequency X/Y/Z in `Hz`
- Displacement X/Y/Z in `um`
- Pitch and roll
- Battery
- RSSI
- MEMS timing diagnostics
- Realtime trend chart
- CSV export/share

## Analyze

The Analyze menu has a shared compact Device card above its tabs. The Device card can be collapsed to save vertical space.

Analyze contains two tabs:

### Machine Health

Machine Health evaluates vibration velocity RMS by axis against ISO 10816-1 style machine classes.

Supported machine classes:

| Class | Good | Satisfactory | Unsatisfactory | Unacceptable |
| --- | ---: | ---: | ---: | ---: |
| Class I | `<= 0.71` | `<= 1.80` | `<= 4.50` | `> 4.50` |
| Class II | `<= 1.12` | `<= 2.80` | `<= 7.10` | `> 7.10` |
| Class III | `<= 1.80` | `<= 4.50` | `<= 11.20` | `> 11.20` |
| Class IV | `<= 2.80` | `<= 7.10` | `<= 18.00` | `> 18.00` |

Machine Health shows:

- Machine class selector
- Overall health result
- Axis X/Y/Z compact cards
- `mm/s RMS` value on one line
- ISO class threshold bar with A/B/C/D zones
- Decision marker based on the highest measured axis

### VibScan

VibScan performs FFT-based fault identification using the rule engine from [Fault_Identification.md](Fault_Identification.md).

User inputs:

- RPM
- FFT axis X/Y/Z

RPM is converted to order frequencies:

```text
1X = RPM / 60
2X = 2 * 1X
3X = 3 * 1X
```

VibScan loads FFT data from the selected node, then calculates:

- FFT resolution
- 0.5X, 1X, 2X, and 3X amplitudes
- Harmonic count from 1X to 10X
- Main peak frequency
- Fault confidence scores

Implemented fault rules:

- Unbalance
- Misalignment
- Mechanical Looseness
- Bearing Defect, shown as suspected/basic MVP without bearing geometry

VibScan displays:

- Main fault type
- Status: Normal or Unknown, Suspected, Warning, Critical
- Confidence score
- Spectrum FFT chart with 1X, 2X, and 3X markers
- Order amplitude table
- Per-fault score bars
- Reason list
- Maintenance recommendations

## MQTT Menu

MQTT menu monitors:

- MQTT connected/disconnected state
- MQTT status string
- TLS enabled/disabled
- Retry limited state
- Connect failure count
- Publish summary
- Last sent/next send
- Subscribe RX information
- Payload byte counts

The `Restart MQTT` button intentionally calls:

```text
POST /api/reboot
```

This reboots the ESP32 rather than calling `/api/mqtt_restart`.

## Config Device

Config Device has five tabs:

- MQTT
- Network
- MEMS
- Operate
- System

### MQTT

Loads from `/api/config` and saves to `/api/mqtt_config`.

Supports:

- Broker
- Port
- Client ID
- Username/password
- MQTT/MQTTS protocol
- TLS toggle
- Publish, FFT, subscribe, ACK, and result topics

### Network

Loads from `/api/config` and saves to `/api/network_config`.

Supports:

- STA SSID/password
- Device-side SSID scan
- AP fallback enable
- AP SSID/password
- Static STA IP, gateway, subnet, DNS

### MEMS

Loads from `/api/config` and saves to `/api/mems_config`.

Supports:

- ADXL345 rate/range/offsets
- Interrupt threshold and enable
- Vibration RMS/peak thresholds
- Noise floor
- Deadband
- Frequency range
- Sleep interval
- MEMS no-vibration calibration
- MEMS calibration reset

### Operate

Loads from `/api/config` and saves to `/api/operate_config`.

Supports:

- Publish interval
- Wake interrupt threshold
- Wake timer
- Publish on vibration trigger
- Vibration trigger threshold
- Log enable
- Debug log category toggles

### System

The System tab is intentionally simplified. It only exposes Factory Default reset.

Factory Default calls:

```text
POST /api/reset
```

The app shows a confirmation dialog before sending the command. Saved devices in the mobile app are not removed.

## WiFi and Discovery

The WiFi menu supports two WiFi-related flows:

- Mobile-side WiFi scan through Android platform APIs
- Device discovery through mDNS and UDP

Discovery methods:

- mDNS service: `_iot-sensor._tcp.local`
- UDP discovery port: `37020`
- HTTP confirmation: `GET /api/discover`

The default AP setup base URL is:

```text
http://192.168.4.1
```

## CSV Export

The app can save and share:

- Dashboard current metrics
- Dashboard live history
- FFT spectrum data

On Android, CSV files are saved to Downloads through a native platform channel.

## Tests

Run tests:

```bash
flutter test
```

Current test coverage includes:

- MQTT publish summary parsing
- App shell/tab rendering

## Related Documents

- [API_mobile.md](API_mobile.md): ESP32 HTTP/MQTT API guide for mobile integration
- [Fault_Identification.md](Fault_Identification.md): FFT fault identification rule engine
- [README_IOTnode.md](README_IOTnode.md): ESP32 firmware/node README
