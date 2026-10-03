# Skylark Functional Specification

Version 0.1 (draft), 2026-10-02
Applies to: cape HW-1.0 (current KiCad design) + system image SYS-0.1.x

This document defines **what the Skylark board must do**. Every
requirement has an ID and an acceptance check so that a board, an
image or a release can be signed off against it. How each function is
implemented is out of scope; see `ROADMAP.md` and the source tree.

Conventions:

- **Must**: required for the release. **Should**: wanted, a release can
  ship without it. **Later**: agreed direction, not part of this release.
- Values marked **(TBD)** still need a product decision. Values marked
  **(proposed)** are a starting suggestion and need confirming.
- Verification: **T** = test on hardware, **I** = inspection (design,
  config or image contents), **A** = analysis/measurement with
  instruments.

---

## 1. Product summary

Skylark is a flight controller for small unmanned aircraft. It is a
BeagleBone Black with the Skylark cape on top, running Linux and
ArduPilot. It powers itself and its servos from the aircraft battery,
senses attitude, heading, altitude and airspeed, drives 4 servos and
2 motors, talks to ground control over MAVLink and to other aircraft
equipment over CAN. The software can be updated safely in the field
with automatic rollback.

### 1.1 External interfaces

| Connector | Function                    | Type                    |
|-----------|-----------------------------|-------------------------|
| J12       | Main power in (24 V)        | 2-pin screw terminal    |
| J1–J4     | Servo 0–3                   | JST-EH 3-pin            |
| J9, J10   | Motor L, Motor R (ESC)      | JST-EH 2-pin            |
| J13       | MAVLink telemetry (UART)    | JST-EH 4-pin            |
| J11       | CAN bus                     | 2-pin screw terminal    |
| J8        | Airspeed sensor (I2C)       | JST-EH 4-pin            |
| J5, J6    | External LEDs L/R           | JST-EH 3-pin            |
| BBB       | Ethernet, USB, micro-SD, serial debug (J1 header) | BeagleBone Black |

---

## 2. Functional requirements

### 2.1 Power (PWR)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| PWR-01 | The board shall run from a single DC supply on J12, nominal 24 V, range **(TBD, e.g. 7–36 V for 2S–8S)**. | Must | Board boots and runs at min, nominal and max input voltage. | T |
| PWR-02 | The board shall power the BeagleBone from the cape; no separate BBB supply is needed. | Must | Boot with only J12 connected. | T |
| PWR-03 | The 5 V rail shall supply BBB + servos + sensors at **(TBD) A** continuous without dropping below 4.75 V. | Must | Load test at rated current, measure 5 V rail. | A |
| PWR-04 | The input shall be protected by a fuse against short circuit. | Must | F1 present and rated **(TBD) A**. | I |
| PWR-05 | Reverse-polarity input shall not damage the board. | Should | Apply reversed supply for 10 s, board works afterwards. (Not in current design: TBD.) | T |
| PWR-06 | The board shall indicate that power is present. | Should | Visible indication with only J12 connected. | T |
| PWR-07 | Board shall report input voltage to software (battery monitoring). | Should | Voltage readable in ArduPilot within ±2 %. (Not in current design: TBD.) | T |

### 2.2 Attitude sensing (IMU)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| IMU-01 | The board shall measure 3-axis acceleration and 3-axis angular rate (BHI360). | Must | Rotating/tilting the board changes readings on the correct axes with correct sign. | T |
| IMU-02 | IMU data shall reach the flight stack at ≥ **400 Hz (proposed)**. | Must | Measure sample rate in ArduPilot logs. | T |
| IMU-03 | IMU samples shall be timestamped and delivered without gaps or duplicates under full flight load. | Must | 10 min log, no missed/duplicated samples. | T |
| IMU-04 | Software shall be able to reset the IMU and detect when new data is ready (interrupt). | Must | Reset line and data-ready interrupt observed working. | T |
| IMU-05 | IMU axes shall be aligned with the board's marked forward/right/down axes, or the rotation shall be configured in software. | Must | Orientation check passes in ArduPilot. | T |

### 2.3 Heading (MAG)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| MAG-01 | The board shall measure the 3-axis magnetic field (BMM350). | Must | Rotating the board 360° gives a full heading circle. | T |
| MAG-02 | Compass data shall reach the flight stack at ≥ **50 Hz (proposed)**. | Must | Measure rate in logs. | T |
| MAG-03 | Compass shall pass ArduPilot compass calibration. | Must | Calibration completes with fitness "good". | T |
| MAG-04 | The board shall support an external compass (e.g. on GPS mast). | Later | — | — |

### 2.4 Altitude (BARO)

| ID      | Requirement | Pri | Acceptance check | Ver |
|---------|-------------|-----|------------------|-----|
| BARO-01 | The board shall measure barometric pressure and temperature (BMP390). | Must | Pressure within ±1 hPa of reference. | T |
| BARO-02 | Altitude data shall reach the flight stack at ≥ **20 Hz (proposed)**. | Must | Measure rate in logs. | T |

### 2.5 Airspeed (ASPD)

| ID      | Requirement | Pri | Acceptance check | Ver |
|---------|-------------|-----|------------------|-----|
| ASPD-01 | The board shall accept an external I2C airspeed sensor on J8 and supply it with power. | Must | Supported sensor **(TBD: e.g. MS4525DO)** detected and reads. | T |
| ASPD-02 | Airspeed data shall reach the flight stack. | Must | Blowing on the pitot changes airspeed in ground station. | T |

### 2.6 Servo and motor outputs (OUT)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| OUT-01 | The board shall provide 4 servo outputs (J1–J4) and 2 motor/ESC outputs (J9, J10). | Must | All 6 outputs produce pulses. | T |
| OUT-02 | Pulse width shall be settable 1000–2000 µs (extended 500–2500 µs), resolution ≤ 1 µs. | Must | Scope measurement at 1000/1500/2000 µs. | A |
| OUT-03 | Output frame rate shall be configurable per group, 50 Hz (servos) and up to 400 Hz (ESC) **(proposed)**. | Must | Scope measurement. | A |
| OUT-04 | Pulse jitter shall be < 1 µs under full CPU load. | Must | Scope persistence for 60 s while CPU is loaded. | A |
| OUT-05 | Outputs shall stay low (no pulses) from power-on until the flight software arms them. | Must | Scope during power-up and boot: no pulses. | T |
| OUT-06 | If the flight software stops updating outputs for > **500 ms (proposed)**, outputs shall go to their configured failsafe values without CPU involvement. | Must | Kill ArduPilot process; outputs go to failsafe within timeout. | T |
| OUT-07 | Servo connectors shall supply 5 V servo power. | Must | 5 V present on servo power pin. | T |
| OUT-08 | Output signal level shall be compatible with standard servos/ESCs (3.3 V logic). | Must | Tested with reference servo and ESC **(TBD models)**. | T |

### 2.7 Telemetry (TLM)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| TLM-01 | The board shall provide a MAVLink serial port on J13 for a telemetry radio. | Must | Mission Planner/QGC connects through a radio on J13. | T |
| TLM-02 | Default baud rate 57600, configurable up to 921600. | Must | Connect at default and at 921600. | T |
| TLM-03 | MAVLink shall also be available over Ethernet (UDP) for bench use. | Should | Ground station connects over Ethernet. | T |

### 2.8 CAN bus (CAN)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| CAN-01 | The board shall provide one CAN 2.0B port on J11. | Must | `cansend`/`candump` exchange frames with a USB-CAN adapter. | T |
| CAN-02 | Bit rates 500 kbit/s and 1 Mbit/s shall be supported. | Must | Exchange at both rates with no errors for 10 min. | T |
| CAN-03 | The port shall be terminated (120 Ω) on board. | Must | 60 Ω measured with one external terminator. Note: termination is fixed; a switchable one is **(TBD)**. | I |
| CAN-04 | The CAN lines shall be ESD protected. | Must | Protection device present. | I |
| CAN-05 | The flight stack shall run DroneCAN on the port (e.g. CAN GPS, ESCs). | Should | DroneCAN GPS detected in ArduPilot. | T |
| CAN-06 | CAN FD support. | Later | Transceiver supports it; AM335x controller does not. | — |

### 2.9 Time keeping (RTC)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| RTC-01 | The board shall keep wall-clock time while unpowered (coin cell). | Must | Set time, power off 24 h, time correct ±2 s after boot. | T |
| RTC-02 | System time shall be set from the RTC at boot so logs have correct timestamps without network/GPS. | Must | Boot without network; `date` correct. | T |
| RTC-03 | Coin cell shall last ≥ **(TBD) years** with the board unpowered. | Should | Analysis from datasheet currents. | A |

### 2.10 Indicators (IND)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| IND-01 | Two on-board status LEDs (blue, red) controllable by software. | Must | Both toggle from software. | T |
| IND-02 | Two external LED outputs (J5, J6) controllable by software. | Should | External LEDs toggle. | T |
| IND-03 | Buzzer controllable by software, audible at **(TBD) dB at 1 m**. | Must | Arming/failsafe tones audible. | T |
| IND-04 | The LEDs and buzzer shall show flight-stack state (booting, ready, armed, failsafe, error). | Should | State patterns match ArduPilot notify. | T |

### 2.11 Flight control (FLT)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| FLT-01 | The board shall run ArduPilot **(TBD: Plane / Copter / both)** as the flight stack. | Must | Firmware starts automatically after boot. | T |
| FLT-02 | Flight stack shall start within **30 s (proposed)** of power-on. | Must | Time from power to MAVLink heartbeat. | T |
| FLT-03 | Flight stack shall be restarted automatically if it crashes; outputs shall be in failsafe while it is down (see OUT-06). | Must | Kill process; it restarts and outputs failsafe meanwhile. | T |
| FLT-04 | Parameters, flight logs and terrain data shall be stored on the persistent data partition and survive updates and rollbacks. | Must | Change a parameter, update image, parameter kept. | T |
| FLT-05 | GPS input **(TBD: UART or DroneCAN only?)**. | Must | GPS fix shown in ground station. | T |
| FLT-06 | RC receiver input **(TBD: SBUS/CRSF on which port?)**. | Must | Stick movements visible in ground station. | T |

### 2.12 Boot, software update and recovery (SYS)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| SYS-01 | The board shall boot from the micro-SD card. | Must | Flash image, board boots to login. | T |
| SYS-02 | The system shall hold two complete system copies (A/B); an update is written to the inactive copy only. | Must | Running system untouched during update. | T |
| SYS-03 | Updates shall be accepted only if signed with a trusted key and built for this board. | Must | Unsigned and wrong-`compatible` bundles rejected. | T |
| SYS-04 | If a new system fails to boot 3 times, the board shall automatically go back to the previous system. | Must | Install a deliberately broken bundle; board returns to old slot. | T |
| SYS-05 | Power loss at any point during an update shall leave the board bootable. | Must | Cut power at random points during 20 updates; always boots. | T |
| SYS-06 | Updates shall be installable over Ethernet (SSH) and from a USB stick **(USB: TBD)**. | Must | Both methods tested. | T |
| SYS-07 | User data (`/data`) shall survive updates and rollbacks. | Must | See FLT-04. | T |
| SYS-08 | A factory reset shall erase configuration and logs but keep device keys. | Should | Run reset; config gone, keys kept. | T |
| SYS-09 | The data partition shall use the full SD card size automatically. | Must | 8 GB and 32 GB cards: `/data` fills card after first boot. | T |
| SYS-10 | The installed software version shall be readable on the board and over MAVLink. | Must | `/etc/skylark/version` and ground station show the same version. | T |
| SYS-11 | Each release shall ship as an SD card image, an update bundle and a manifest with component versions and checksums. | Must | Release artifacts present. | I |
| SYS-12 | Production units shall use production signing keys, and debug login shall be disabled. | Later | — | — |

### 2.13 Maintenance access (MNT)

| ID     | Requirement | Pri | Acceptance check | Ver |
|--------|-------------|-----|------------------|-----|
| MNT-01 | A serial console shall be available on the BBB debug header (115200 8N1). | Must | Login over serial. | T |
| MNT-02 | SSH access over Ethernet with DHCP. | Must | `ssh root@<ip>` works. | T |
| MNT-03 | Test points shall be present on all key signals for bring-up. | Should | TP list matches signal list. | I |

---

## 3. Non-functional requirements (NFR)

| ID     | Requirement | Pri | Value |
|--------|-------------|-----|-------|
| NFR-01 | Operating temperature | Must | **(TBD, e.g. −20…+60 °C)** |
| NFR-02 | Mass of cape (without BBB) | Should | **(TBD) g** |
| NFR-03 | Power consumption (board only, no servos) | Should | **(TBD) W** |
| NFR-04 | Vibration tolerance for IMU | Must | **(TBD)** — mounting/damping defined |
| NFR-05 | Mechanical | Must | Fits BeagleBone Black footprint, standard cape headers |
| NFR-06 | SD card | Must | Works with 8 GB minimum, industrial-grade card recommended **(TBD model)** |

---

## 4. Open product decisions

These block final sign-off of the requirements above.

1. Vehicle type(s): Plane, Copter or both (FLT-01). The output set
   (4 servos + 2 motors) suggests a fixed-wing / twin-motor aircraft.
2. GPS and RC receiver connection (FLT-05, FLT-06). There is no
   dedicated GPS or RC connector on the cape today; options are
   DroneCAN GPS and an RC receiver on a spare UART or over MAVLink.
3. Battery voltage/current monitoring (PWR-07). Not in the current
   hardware.
4. Reverse-polarity protection (PWR-05). Not in the current hardware.
5. Input voltage range and current ratings (PWR-01, PWR-03, PWR-04).
6. Whether CAN termination needs to be switchable (CAN-03).
7. USB-stick updates (SYS-06).
8. Environmental limits (NFR section).

---

## 5. Sign-off checklist

Copy this table per board/release under test and fill in results.

| Board S/N | Image version | Tester | Date |
|-----------|---------------|--------|------|
|           |               |        |      |

| ID | Result (Pass / Fail / N/A) | Notes |
|----|----------------------------|-------|
| PWR-01 | | |
| PWR-02 | | |
| PWR-03 | | |
| PWR-04 | | |
| PWR-05 | | |
| PWR-06 | | |
| PWR-07 | | |
| IMU-01 | | |
| IMU-02 | | |
| IMU-03 | | |
| IMU-04 | | |
| IMU-05 | | |
| MAG-01 | | |
| MAG-02 | | |
| MAG-03 | | |
| BARO-01 | | |
| BARO-02 | | |
| ASPD-01 | | |
| ASPD-02 | | |
| OUT-01 | | |
| OUT-02 | | |
| OUT-03 | | |
| OUT-04 | | |
| OUT-05 | | |
| OUT-06 | | |
| OUT-07 | | |
| OUT-08 | | |
| TLM-01 | | |
| TLM-02 | | |
| TLM-03 | | |
| CAN-01 | | |
| CAN-02 | | |
| CAN-03 | | |
| CAN-04 | | |
| CAN-05 | | |
| RTC-01 | | |
| RTC-02 | | |
| RTC-03 | | |
| IND-01 | | |
| IND-02 | | |
| IND-03 | | |
| IND-04 | | |
| FLT-01 | | |
| FLT-02 | | |
| FLT-03 | | |
| FLT-04 | | |
| FLT-05 | | |
| FLT-06 | | |
| SYS-01 | | |
| SYS-02 | | |
| SYS-03 | | |
| SYS-04 | | |
| SYS-05 | | |
| SYS-06 | | |
| SYS-07 | | |
| SYS-08 | | |
| SYS-09 | | |
| SYS-10 | | |
| SYS-11 | | |
| MNT-01 | | |
| MNT-02 | | |
| MNT-03 | | |

---

## Appendix A: Hardware mapping (reference)

For testers; where each function lives on the board.

| Function        | Part            | BBB connection                                   |
|-----------------|-----------------|--------------------------------------------------|
| Power 24→5 V    | IC1 A6983C50, F1| P9_7/P9_8 (VBUS/SYS_5V)                          |
| IMU             | U2 BHI360       | I2C1 (P9_17/P9_18), INT P9_14, RESET P9_16       |
| Magnetometer    | IC4 BMM350      | BHI360 auxiliary I2C (not directly on BBB)       |
| Barometer       | IC3 BMP390      | I2C1                                             |
| Airspeed (J8)   | external        | I2C2 (P9_19/P9_20)                               |
| RTC             | U3 DS1307 + CR2032 | I2C2, addr 0x68                               |
| Servo 0–3       | J1–J4           | P8_39, P8_42, P8_41, P8_44 (PRU1 outputs)        |
| Motor L / R     | J9 / J10        | P8_43 / P8_45 (PRU1 outputs)                     |
| CAN             | IC2 TCAN3413, J11 | DCAN1: TX P9_26, RX P9_24                      |
| MAVLink (J13)   | —               | UART2: TX P9_21, RX P9_22                        |
| LED blue / red  | D1 / D2         | P9_42 / P9_41                                    |
| Ext. LED L / R  | J5 / J6         | P8_18 / P8_17                                    |
| Buzzer          | BZ1 via Q2      | P9_30                                            |
