# Fault Identification by FFT for Vibration Monitoring App

เอกสารนี้อธิบายวิธีการและ Flow การคำนวณใน App สำหรับระบุอาการผิดปกติของเครื่องจักรจากสัญญาณ vibration ด้วย FFT โดยเน้น 4 อาการหลัก:

1. Unbalance
2. Misalignment
3. Mechanical Looseness
4. Bearing Defect

> หมายเหตุ: เอกสารนี้เหมาะสำหรับใช้ออกแบบ Mobile App / Web Dashboard / Edge Gateway ที่รับข้อมูลจาก ESP32 vibration node ผ่าน MQTT, HTTP API หรือ WebSocket

---

## 1. Objective

เป้าหมายของระบบคือรับข้อมูล vibration จาก sensor node แล้ววิเคราะห์ว่าเครื่องจักรมีแนวโน้มผิดปกติแบบใด โดยใช้ข้อมูลหลักจาก:

- Time waveform
- FFT spectrum
- RMS acceleration
- RMS velocity
- Displacement
- RPM
- Bearing geometry
- Trend history
- Baseline ของเครื่องจักรแต่ละตัว

ผลลัพธ์ที่ App ควรแสดงคือ:

- Machine health status
- Fault type
- Confidence score
- Main frequency peak
- Recommendation
- Trend warning
- Export CSV / PDF report

---

## 2. Required Input Data

### 2.1 Sensor Data

ข้อมูลที่รับจาก ESP32 node ควรมีอย่างน้อย:

```json
{
  "device_id": "VN_Node_001",
  "timestamp_ms": 123456789,
  "sample_rate_hz": 1600,
  "num_samples": 512,
  "axis": {
    "x": [],
    "y": [],
    "z": []
  },
  "rms": {
    "accel_x_g": 0.012,
    "accel_y_g": 0.018,
    "accel_z_g": 0.021,
    "velocity_x_mm_s": 0.7,
    "velocity_y_mm_s": 1.1,
    "velocity_z_mm_s": 1.4
  },
  "peak_frequency": {
    "x_hz": 25.0,
    "y_hz": 25.0,
    "z_hz": 50.0
  }
}
```

---

### 2.2 Machine Data

App ต้องให้ผู้ใช้ตั้งค่าข้อมูลเครื่องจักร:

```json
{
  "machine_id": "Motor_Pump_01",
  "machine_type": "motor_pump",
  "rpm": 1500,
  "power_kw": 7.5,
  "mounting": "horizontal",
  "drive_type": "direct_coupling"
}
```

ค่าที่สำคัญที่สุดคือ `rpm`

```text
1X frequency = RPM / 60
```

ตัวอย่าง:

```text
RPM = 1500
1X = 1500 / 60 = 25 Hz
2X = 50 Hz
3X = 75 Hz
```

---

### 2.3 Bearing Data for Advanced Mode

ถ้าต้องการตรวจ Bearing Defect ต้องมีข้อมูล bearing:

```json
{
  "bearing_model": "6205",
  "number_of_balls": 9,
  "ball_diameter_mm": 7.94,
  "pitch_diameter_mm": 39.04,
  "contact_angle_deg": 0
}
```

---

## 3. FFT Processing Flow

### 3.1 Overall Flow

```text
Start
  |
  v
Receive waveform data
  |
  v
Validate sample_rate and num_samples
  |
  v
Remove DC offset
  |
  v
Apply window function
  |
  v
Perform FFT
  |
  v
Convert complex FFT to magnitude spectrum
  |
  v
Calculate frequency bin resolution
  |
  v
Detect frequency peaks
  |
  v
Calculate 1X, 2X, 3X ... 10X from RPM
  |
  v
Compare FFT peaks with fault rules
  |
  v
Calculate confidence score
  |
  v
Display fault result and recommendation
End
```

---

### 3.2 Remove DC Offset

ก่อนทำ FFT ควรลบค่าเฉลี่ยออกจาก waveform

```text
mean = sum(samples) / N
sample[i] = sample[i] - mean
```

เหตุผล:

- ลด DC component ที่ 0 Hz
- ทำให้ peak ของความถี่จริงชัดขึ้น
- ลด error ใน FFT

---

### 3.3 Windowing

แนะนำใช้:

- Hanning window
- Hamming window

```text
windowed_sample[i] = sample[i] * window[i]
```

เหตุผล:

- ลด spectral leakage
- ทำให้ peak ที่ 1X, 2X, harmonic ชัดขึ้น

---

### 3.4 Frequency Resolution

```text
frequency_resolution = sample_rate_hz / num_samples
```

ตัวอย่าง:

```text
sample_rate = 1600 Hz
num_samples = 512

frequency_resolution = 1600 / 512 = 3.125 Hz/bin
```

หมายความว่า FFT แต่ละ bin ห่างกัน 3.125 Hz

---

### 3.5 Nyquist Frequency

```text
nyquist_frequency = sample_rate_hz / 2
```

ตัวอย่าง:

```text
sample_rate = 1600 Hz
nyquist = 800 Hz
```

ดังนั้นระบบจะวิเคราะห์ความถี่ได้สูงสุดประมาณ 800 Hz

---

## 4. Peak Detection

### 4.1 Target Frequencies

หลังจากรู้ RPM ให้คำนวณ order frequency:

```text
1X = RPM / 60
2X = 2 * 1X
3X = 3 * 1X
...
10X = 10 * 1X
```

---

### 4.2 Peak Search Tolerance

เนื่องจาก FFT bin ไม่ตรงกับความถี่เป้าหมาย 100% ควรใช้ tolerance

```text
tolerance_hz = max(fft_resolution, target_frequency * 0.05)
```

ตัวอย่าง:

```text
target = 25 Hz
fft_resolution = 3.125 Hz
5% of target = 1.25 Hz

tolerance = max(3.125, 1.25) = 3.125 Hz
```

---

### 4.3 Function: Find Amplitude Near Target

Pseudo code:

```text
function findAmplitudeNearTarget(spectrum, target_hz, tolerance_hz):
    max_amp = 0
    peak_hz = 0

    for each bin in spectrum:
        if abs(bin.frequency_hz - target_hz) <= tolerance_hz:
            if bin.amplitude > max_amp:
                max_amp = bin.amplitude
                peak_hz = bin.frequency_hz

    return peak_hz, max_amp
```

---

## 5. Fault Rule Engine

ระบบควรใช้ Rule Engine ก่อน AI เพราะ:

- อธิบายผลได้ง่าย
- Debug ง่าย
- เหมาะกับ MVP
- ใช้งานกับข้อมูลจริงได้เร็ว
- แสดงเหตุผลให้ลูกค้าเข้าใจได้

---

# 6. Fault 1: Unbalance

## 6.1 FFT Characteristic

Unbalance มักมีลักษณะ:

- Peak สูงเด่นที่ 1X RPM
- 2X และ 3X ต่ำกว่า 1X มาก
- เด่นในแนว radial
- ค่า phase ค่อนข้างคงที่
- vibration เพิ่มตามความเร็วรอบ

---

## 6.2 Calculation

```text
f_1x = rpm / 60
amp_1x = amplitude near f_1x
amp_2x = amplitude near 2 * f_1x
amp_3x = amplitude near 3 * f_1x
```

---

## 6.3 Rule

```text
IF amp_1x is high
AND amp_2x < 0.5 * amp_1x
AND amp_3x < 0.3 * amp_1x
THEN suspect Unbalance
```

---

## 6.4 Confidence Score

```text
score_unbalance = 0

IF amp_1x > threshold_1x:
    score_unbalance += 40

IF amp_2x < 0.5 * amp_1x:
    score_unbalance += 25

IF amp_3x < 0.3 * amp_1x:
    score_unbalance += 15

IF radial_rms > axial_rms:
    score_unbalance += 20
```

Maximum score = 100

---

## 6.5 Output Example

```json
{
  "fault": "Unbalance",
  "confidence": 82,
  "main_peak_hz": 25.0,
  "main_order": "1X",
  "recommendation": "ตรวจสอบ rotor, fan, pulley หรือทำ balancing"
}
```

---

# 7. Fault 2: Misalignment

## 7.1 FFT Characteristic

Misalignment มักมีลักษณะ:

- มี peak ที่ 1X และ 2X
- 2X อาจสูงใกล้เคียงหรือสูงกว่า 1X
- Angular misalignment มักทำให้ axial vibration สูง
- Parallel misalignment มักเด่นใน radial direction

---

## 7.2 Calculation

```text
amp_1x = amplitude near 1X
amp_2x = amplitude near 2X
axial_rms = rms along axial axis
radial_rms = sqrt(radial_x^2 + radial_y^2)
axial_radial_ratio = axial_rms / radial_rms
```

---

## 7.3 Rule

```text
IF amp_2x >= 0.8 * amp_1x
THEN suspect Misalignment

IF axial_radial_ratio >= 0.5
THEN type = Angular Misalignment
ELSE type = Parallel Misalignment
```

---

## 7.4 Confidence Score

```text
score_misalignment = 0

IF amp_2x >= 0.8 * amp_1x:
    score_misalignment += 40

IF amp_2x > threshold_2x:
    score_misalignment += 20

IF axial_radial_ratio >= 0.5:
    score_misalignment += 25

IF amp_1x is also present:
    score_misalignment += 15
```

---

## 7.5 Output Example

```json
{
  "fault": "Misalignment",
  "type": "Angular Misalignment",
  "confidence": 78,
  "amp_1x": 1.8,
  "amp_2x": 2.1,
  "axial_radial_ratio": 0.62,
  "recommendation": "ตรวจ alignment ของ coupling, shaft และ motor base"
}
```

---

# 8. Fault 3: Mechanical Looseness

## 8.1 FFT Characteristic

Looseness มักมีลักษณะ:

- มี harmonic หลายตัว เช่น 1X, 2X, 3X, 4X, 5X
- อาจพบ 0.5X subharmonic
- ค่า vibration อาจเปลี่ยนเร็วและไม่เสถียร
- บางครั้งพบ broadband noise เพิ่มขึ้น

---

## 8.2 Calculation

```text
harmonic_count = 0

FOR n = 1 to 10:
    target = n * f_1x
    amp_nx = amplitude near target

    IF amp_nx > harmonic_threshold:
        harmonic_count += 1
```

ตรวจ 0.5X:

```text
f_0_5x = 0.5 * f_1x
amp_0_5x = amplitude near f_0_5x
```

---

## 8.3 Rule

```text
IF harmonic_count >= 4
THEN suspect Mechanical Looseness

IF amp_0_5x > threshold_0_5x
THEN increase confidence
```

---

## 8.4 Confidence Score

```text
score_looseness = 0

IF harmonic_count >= 4:
    score_looseness += 50

IF harmonic_count >= 6:
    score_looseness += 20

IF amp_0_5x > threshold_0_5x:
    score_looseness += 15

IF broadband_noise_level > baseline * 1.5:
    score_looseness += 15
```

---

## 8.5 Output Example

```json
{
  "fault": "Mechanical Looseness",
  "confidence": 85,
  "harmonics_detected": ["1X", "2X", "3X", "4X", "5X"],
  "subharmonic": "0.5X detected",
  "recommendation": "ตรวจ bolt, base, foundation, bracket และ bearing seat"
}
```

---

# 9. Fault 4: Bearing Defect

## 9.1 FFT Characteristic

Bearing defect มักมีลักษณะ:

- Peak ที่ bearing fault frequency
- มี harmonic ของ BPFO, BPFI, BSF หรือ FTF
- Inner race defect มักมี sideband รอบ BPFI
- Bearing defect ระยะแรกอาจต้องใช้ envelope analysis
- ถ้า sample rate ต่ำ อาจเห็นเฉพาะ defect ที่เริ่มรุนแรงแล้ว

---

## 9.2 Bearing Fault Frequencies

ให้:

```text
n  = number of rolling elements
Bd = ball diameter
Pd = pitch diameter
α  = contact angle
fs = shaft frequency = RPM / 60
```

---

### BPFO: Ball Pass Frequency Outer Race

```text
BPFO = (n / 2) * fs * (1 - (Bd / Pd) * cos(α))
```

---

### BPFI: Ball Pass Frequency Inner Race

```text
BPFI = (n / 2) * fs * (1 + (Bd / Pd) * cos(α))
```

---

### BSF: Ball Spin Frequency

```text
BSF = (Pd / (2 * Bd)) * fs * (1 - ((Bd / Pd) * cos(α))^2)
```

---

### FTF: Fundamental Train Frequency

```text
FTF = 0.5 * fs * (1 - (Bd / Pd) * cos(α))
```

---

## 9.3 Rule: Outer Race Defect

```text
IF peak near BPFO
AND peak near 2 * BPFO OR 3 * BPFO
THEN suspect Bearing Outer Race Defect
```

---

## 9.4 Rule: Inner Race Defect

```text
IF peak near BPFI
AND sideband near BPFI - 1X OR BPFI + 1X
THEN suspect Bearing Inner Race Defect
```

---

## 9.5 Rule: Ball Defect

```text
IF peak near BSF
OR peak near 2 * BSF
THEN suspect Ball/Roller Defect
```

---

## 9.6 Rule: Cage Defect

```text
IF peak near FTF
AND FTF < 1X
THEN suspect Cage Defect
```

---

## 9.7 Confidence Score

```text
score_bearing = 0

IF peak near BPFO/BPFI/BSF/FTF:
    score_bearing += 40

IF harmonic of bearing frequency exists:
    score_bearing += 20

IF sidebands around bearing frequency exist:
    score_bearing += 20

IF high_frequency_energy > baseline * 1.5:
    score_bearing += 20
```

---

## 9.8 Output Example

```json
{
  "fault": "Bearing Defect",
  "type": "Outer Race Defect",
  "confidence": 72,
  "bpfo_hz": 89.3,
  "detected_peaks_hz": [90.6, 181.2],
  "recommendation": "ตรวจ bearing, lubrication และวางแผนเปลี่ยน bearing"
}
```

---

# 10. App Calculation Pipeline

## 10.1 Pipeline Overview

```text
[Sensor Node]
    |
    | MQTT / HTTP / WebSocket
    v
[Mobile App / Edge Gateway]
    |
    v
[Data Validation]
    |
    v
[Pre-processing]
    |
    v
[FFT Engine]
    |
    v
[Peak Detector]
    |
    v
[Fault Rule Engine]
    |
    v
[Confidence Scoring]
    |
    v
[Dashboard / Alert / Report]
```

---

## 10.2 Step-by-Step

### Step 1: Receive Data

App รับข้อมูล:

- waveform x/y/z
- sample_rate
- num_samples
- RMS
- peak frequency
- device status

---

### Step 2: Validate Data

ตรวจสอบ:

```text
sample_rate > 0
num_samples >= 256
waveform length == num_samples
rpm > 0
```

ถ้าไม่ผ่าน:

```json
{
  "status": "invalid_data",
  "message": "Missing RPM or waveform length mismatch"
}
```

---

### Step 3: Pre-processing

ทำ:

```text
remove DC offset
apply window
optional filter
```

---

### Step 4: FFT

คำนวณ FFT แยกแต่ละแกน:

```text
FFT_X
FFT_Y
FFT_Z
```

---

### Step 5: Calculate Order Frequencies

```text
f_1x = rpm / 60

for n = 1 to 10:
    order_freq[n] = n * f_1x
```

---

### Step 6: Detect Peaks

หา peak ใกล้:

```text
0.5X
1X
2X
3X
...
10X
BPFO
BPFI
BSF
FTF
```

---

### Step 7: Calculate Fault Scores

```text
score_unbalance
score_misalignment
score_looseness
score_bearing
```

---

### Step 8: Select Main Fault

```text
main_fault = fault with highest score

IF highest_score < 50:
    status = "Normal or Unknown"

IF highest_score >= 50 and < 70:
    status = "Suspected"

IF highest_score >= 70:
    status = "Warning"

IF highest_score >= 85:
    status = "Critical"
```

---

### Step 9: Generate Recommendation

ตัวอย่าง:

```text
Unbalance:
- ตรวจ rotor/fan/pulley
- ทำ balancing
- ตรวจสิ่งสกปรกเกาะใบพัด

Misalignment:
- ตรวจ coupling
- laser alignment
- ตรวจ soft foot

Looseness:
- ตรวจ bolt/base/foundation
- ตรวจ bearing seat
- ตรวจ bracket

Bearing Defect:
- ตรวจ bearing model
- ตรวจ lubrication
- วางแผนเปลี่ยน bearing
```

---

# 11. Suggested JSON Result Schema

```json
{
  "device_id": "VN_Node_001",
  "machine_id": "Motor_Pump_01",
  "timestamp_ms": 123456789,
  "rpm": 1500,
  "shaft_frequency_hz": 25.0,
  "status": "warning",
  "main_fault": {
    "type": "Misalignment",
    "subtype": "Angular Misalignment",
    "confidence": 78,
    "reason": [
      "2X amplitude is close to 1X",
      "Axial/Radial ratio is high"
    ],
    "recommendation": [
      "ตรวจ coupling alignment",
      "ตรวจ soft foot",
      "ตรวจฐาน motor"
    ]
  },
  "scores": {
    "unbalance": 25,
    "misalignment": 78,
    "looseness": 30,
    "bearing": 18
  },
  "orders": {
    "1x_hz": 25.0,
    "2x_hz": 50.0,
    "3x_hz": 75.0
  },
  "amplitudes": {
    "amp_1x": 1.8,
    "amp_2x": 2.1,
    "amp_3x": 0.4
  }
}
```

---

# 12. Dashboard UI Flow

## 12.1 Device List Page

แสดง:

- Device name
- Machine name
- Online/offline
- Health status
- Latest fault
- Battery / RSSI
- Last update

---

## 12.2 Machine Dashboard Page

แสดง:

- Health score
- RMS velocity
- Displacement
- Main FFT peak
- Fault status
- Recommendation
- Trend graph

---

## 12.3 FFT Page

แสดง:

- Spectrum X/Y/Z
- Marker 1X, 2X, 3X
- Marker BPFO, BPFI, BSF, FTF
- Peak table
- Export CSV

---

## 12.4 Fault Detail Page

แสดง:

- Fault type
- Confidence score
- Reason
- Detected frequency
- Suggested action
- Severity level
- History trend

---

## 12.5 Config Page

ตั้งค่า:

- RPM
- Machine type
- Axis mapping
- Bearing model
- Threshold
- Baseline
- Alert notification

---

# 13. Threshold and Baseline

## 13.1 Fixed Threshold

เหมาะกับ MVP

```json
{
  "min_rms_g": 0.005,
  "min_peak_g": 0.01,
  "min_freq_hz": 5,
  "warning_velocity_mm_s": 4.5,
  "critical_velocity_mm_s": 7.1
}
```

---

## 13.2 Auto Baseline

แนะนำให้ App รองรับ baseline ต่อเครื่องจักร

```text
baseline_1x = average amp_1x during healthy condition
baseline_2x = average amp_2x during healthy condition
baseline_noise = average broadband noise during healthy condition
```

แจ้งเตือนเมื่อ:

```text
current_amp > baseline * threshold_multiplier
```

ตัวอย่าง:

```text
current_amp_1x > baseline_1x * 2.0
```

---

# 14. Alert Logic

```text
IF status == "warning":
    send notification

IF status == "critical":
    send urgent notification

IF same fault continues for 3 consecutive readings:
    create maintenance event
```

---

# 15. Limitations

## 15.1 RPM Required

ถ้าไม่มี RPM การวิเคราะห์ 1X, 2X, 3X จะไม่แม่น

ทางเลือก:

- ให้ผู้ใช้กรอก RPM
- อ่าน RPM จาก tachometer
- estimate RPM จาก peak หลัก
- ดึง RPM จาก inverter ผ่าน Modbus

---

## 15.2 Bearing Defect Limitation

ถ้า sample rate ต่ำ เช่น 1600 Hz:

```text
Nyquist = 800 Hz
```

อาจตรวจ bearing defect ระยะแรกไม่ได้ดี เพราะ defect ระยะแรกมักอยู่ใน high frequency band และต้องใช้ envelope analysis

ดังนั้นใน App ควรแสดงเป็น:

```text
Suspected Bearing Defect
```

ไม่ควรฟันธงว่า bearing เสียแน่นอน

---

## 15.3 MEMS Sensor Limitation

MEMS sensor ราคาต่ำเหมาะกับ:

- trend monitoring
- low-cost vibration monitoring
- unbalance
- misalignment
- looseness

แต่สำหรับ bearing defect ระยะแรก อาจต้องใช้:

- accelerometer bandwidth สูงกว่า
- sample rate สูงกว่า
- low-noise sensor
- envelope analysis
- proper mounting

---

# 16. Recommended MVP Implementation

## 16.1 MVP v1

ควรเริ่มจาก:

- RPM input
- FFT spectrum
- 1X / 2X / harmonic marker
- Unbalance rule
- Misalignment rule
- Looseness rule
- Simple bearing suspected rule
- CSV export
- Fault JSON output

---

## 16.2 MVP v2

เพิ่ม:

- Bearing geometry input
- BPFO / BPFI / BSF / FTF marker
- Baseline learning
- Trend analysis
- Alert notification

---

## 16.3 MVP v3

เพิ่ม:

- Envelope analysis
- AI anomaly detection
- Fault history
- Maintenance report PDF
- Cloud sync

---

# 17. Recommended Pseudo Code

```text
function analyzeFault(waveform, sample_rate, rpm, bearing_config):
    spectrum = calculateFFT(waveform, sample_rate)

    f1x = rpm / 60
    tolerance = max(sample_rate / len(waveform), f1x * 0.05)

    amp_1x = findAmplitude(spectrum, f1x, tolerance)
    amp_2x = findAmplitude(spectrum, 2 * f1x, tolerance)
    amp_3x = findAmplitude(spectrum, 3 * f1x, tolerance)

    score_unbalance = calcUnbalanceScore(amp_1x, amp_2x, amp_3x)
    score_misalignment = calcMisalignmentScore(amp_1x, amp_2x, axial_rms, radial_rms)
    score_looseness = calcLoosenessScore(spectrum, f1x, tolerance)

    if bearing_config exists:
        bearing_freq = calculateBearingFrequency(rpm, bearing_config)
        score_bearing = calcBearingScore(spectrum, bearing_freq, tolerance)
    else:
        score_bearing = 0

    scores = {
        "unbalance": score_unbalance,
        "misalignment": score_misalignment,
        "looseness": score_looseness,
        "bearing": score_bearing
    }

    main_fault = getMaxScoreFault(scores)

    return createFaultResult(main_fault, scores)
```

---

# 18. Notes for ESP32 + Flutter Architecture

## Option A: ESP32 Calculates FFT

ESP32 ส่ง:

```json
{
  "rpm": 1500,
  "fft": {
    "x": [],
    "y": [],
    "z": []
  },
  "rms": {},
  "peak": {}
}
```

ข้อดี:

- App เบา
- ใช้งาน realtime ง่าย
- ลด bandwidth

ข้อเสีย:

- เปลี่ยน algorithm ต้อง update firmware
- debug ยากกว่า

---

## Option B: App Calculates FFT

ESP32 ส่ง waveform raw:

```json
{
  "sample_rate_hz": 1600,
  "samples": {
    "x": [],
    "y": [],
    "z": []
  }
}
```

ข้อดี:

- ปรับ algorithm ใน App ได้ง่าย
- ทำ AI / visualization ง่ายกว่า

ข้อเสีย:

- ใช้ bandwidth มากกว่า
- ใช้ memory App มากกว่า
- ต้อง optimize data transfer

---

## Option C: Hybrid

แนะนำที่สุด

ESP32 ส่งทั้ง:

- RMS
- peak frequency
- FFT summary
- optional raw waveform

App ใช้ raw เฉพาะตอนผู้ใช้กดวิเคราะห์ละเอียด

---

# 19. Final Recommendation

สำหรับ App รุ่นแรก แนะนำให้ทำ Rule Engine แบบนี้:

```text
Basic Detection:
- Unbalance: 1X dominant
- Misalignment: 2X high
- Looseness: multiple harmonics
- Bearing: BPFO/BPFI/BSF/FTF suspected

Display:
- Normal / Suspected / Warning / Critical
- Confidence score
- Main peak
- Reason
- Recommendation
```

เป้าหมายของ App ไม่ควรเป็นการฟันธง 100% แต่ควรเป็น:

```text
Early warning + maintenance recommendation
```

เพราะในงาน vibration จริงต้องใช้หลายปัจจัยร่วมกัน เช่น mounting, load, RPM, sensor location, historical trend และ baseline ของเครื่องจักรแต่ละตัว
