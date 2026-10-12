# Cape design issues

Open issues found while reviewing the Skylark cape (KiCad project `BeagleBone-cape/`).
Reviews done 2026-10-10 against KiCad 9.0.9, the BBB System Reference Manual
(Table 10 P8 / Table 11 P9), the AM335x mux tables, and the device datasheets
(BHI360 BST-BHI360-DS000-03 rev 1.2, BMP390 BST-BMP390-DS002-07 rev 1.7,
AM335x SPRS717 rev L).

Status legend: `OPEN` not addressed, `DONE` fixed in the working tree (uncommitted
unless noted), `WONTFIX` accepted as is.

---

## Critical / High

### 1. BHI360 INT and RESETN crossed the 1.8 V / 3.3 V domains — DONE
`OPEN` -> fixed by adding level shifters U7/U8 (SN74LVC1T45) plus R28 pull-up and
C40-C43 decoupling. Committed in `680b031d`, edited further in the working tree.

- BHI360 (U2) VDDIO is 1.8 V; abs max on any logic pin is VDDIO+0.3 V (2.1 V), and
  VDDIO abs max is 2.75 V (BHI360 DS000 Tables 117/118).
- AM335x P9/P8 are 3.3 V LVCMOS: VIH min 2.0 V, VIL max 0.8 V (SPRS717), so a 1.8 V
  high does not read as a valid high.
- Reset is host -> sensor (3.3 V into a 1.8 V pin, overstress), INT is
  sensor -> host (1.8 V high below the AM335x VIH).
- The open-drain-with-3.3V-pull-up idea was rejected: it exceeds the BHI360 pad
  limit, and open-drain is a firmware setting (register 0x07 bit 7), not a
  hardware option.

### 2. Buzzer was not on a hardware-PWM pin — DONE
`OPEN` -> /BUZZER moved to **P9.42** (eCAP0, PWM capable).

- It was on P9.30 (GPIO3_16, mcasp0_axr0). Per SRM Table 11 that pad has no
  eHRPWM/eCAP output mux (only `ehrpwm0_tripzone` as an *input*), so the standard
  `/sys/class/pwm` path was not available.
- Note: P9.30 can still do PWM from PRU0 R30 if firmware-driven PWM is acceptable.

### 3. BMP390 I2C address is 0x76, not 0x77 — OPEN
IC3 pin 5 (SDO) is tied to GND, which selects 0x76. If firmware/devicetree expects
0x77, move SDO to +1V8.

### 4. Cape EEPROM U1 (CAT24C256) pin A2 is floating — OPEN
A2 is a real address bit and must be strapped (GND or VCC). Also verify U1's
address range against the BBB cape interface spec so it does not clash with the
baseboard EEPROM on I2C2.

### 5. LED designators / LED pin reassignment — REVIEW
`DONE (as built)` — after moving the buzzer to P9.42 the LED aux feeds were
reassigned because no free pin is adjacent to P9.42:

| Net | Was | Now | Note |
|---|---|---|---|
| /BUZZER | P9.30 (P8.13 briefly) | P9.42 (eCAP0) | hardware PWM |
| /GPIO7 (R10 -> D1, LED0) | P9.42 | P9.41 | GPIO0_20 |
| /GPIO20 (R11 -> D2, LED1) | P9.41 | P9.30 | GPIO3_16 |

Both LEDs keep their original P8 feeds (/LED_0 = P8.18, /LED_1 = P8.17), so the P9
feeds are only a second driver. Optional simplification: delete the P9 feed of
LED1 (R11) entirely, since P8.17 already drives it.

---

## Medium

### 6. Net named `VBUS` sits on P9.7/P9.8 = SYS_5V — OPEN
SRM Table 11: P9.7/P9.8 are SYS_5V (a BBB *output*, 250 mA). The net is misnamed;
today it only reaches TP34, so it is harmless, but the name invites feeding VBUS
into a BBB output. Rename to SYS_5V.

### 7. +5V back-feed through P9.5/P9.6 — REVIEW
The buck output (via ideal diode U6/Q1) reaches VDD_5V. Fine while the cape is the
only 5 V source; do not allow a second source (USB/barrel) at the same time.

### 8. Q2 (buzzer low-side FET) has no real part number — OPEN
Q2 is the generic `Q_NMOS_GSD` symbol. At 3.3 V gate drive a logic-level NMOS is
required (AO3400A class). R24 10k gate pulldown (keep-off at boot) is correct.

### 9. `JTAG_DIO` and `~{BMM350_INT}` share one net — OPEN
Net has IC4.A1 (BMM350 INT), U2.16 and TP16. Confirm which BHI360 pad this really
is and whether the BMM350 interrupt is meant to land there.

### 10. `PGOOD` does not leave the power sheet — OPEN
`pwr.kicad_sch` has a hierarchical label PGOOD, but the Power sheet symbol on the
root sheet has only +5V and +24V_IN pins. IC1 PGOOD reaches R18 only.

### 11. BMP390 `INT` goes nowhere — OPEN
Uses a root-level hierarchical label "INT" (`BeagleBone-cape.kicad_sch`), which
does nothing on the root sheet. Net /INT reaches only TP21. If it is ever wired to
a header pin it needs another SN74LVC1T45 (BMP390 INT is push-pull, active high;
pins limited to VDDIO+0.3 V).

### 12. Missing PWR_FLAGs — OPEN
ERC `power_pin_not_driven` on GND, +5V, +3V3, VBUS and GNDA nets, plus U3 VBAT
(coin cell).

### 13. Footprint fields empty / parts without footprints — OPEN
IC2, IC3, IC4 and U2 have empty Footprint fields in the schematic. U1 (EEPROM),
SW1 and TP1 have no footprint assigned. "Update PCB from Schematic" would orphan or
strip them.

### 14. DS1307 (U3) is a 5 V part on a 3.3 V I2C bus — WONTFIX (works)
U3 VCC is on +5V while SDA/SCL sit on the 3.3 V I2C2 bus with 4k7 pull-ups. Works
because the interface is open-drain and VIH (2.2 V at 5 V VCC) is below 3.3 V.
A 3.3 V RTC (DS1338/PCF8563) would be cleaner.

### 15. I2C2 external connector J8 assumes a 3.3 V device — REVIEW
The air-speed sensor port has 4k7 pull-ups to +3V3. Any 5 V-only device plugged in
must be open-drain with VIH above 3.3 V.

---

## Low / cosmetic

### 16. Silkscreen — mostly DONE
- All reference designators are now 0.6 mm / 0.1 mm stroke, on F.SilkS, upright
  where possible, positioned outside the courtyard.
- Test points keep their 0.7 mm silk ring; their designators are hidden.
- All J connector designators were hidden on request.
- BHI360 (U2) silk outline at ±1.62 x ±1.37 mm, BMP390 (IC3) at ±1.12 mm, both
  derived from the datasheet body dimensions. The BHI360 outline has one open
  corner (bottom-left) where a full rectangle touched C4's reference text.
- 6 designators were hidden because the parts are boxed in: C42, C43, R13, U4, U2,
  R16.
- `AIR SPEED` board text was moved off IC4/C6/C7/C41/U7.
- Open: C29 is the only designator left at 90 degrees; some text pairs are within
  KiCad's coarse bounding boxes (~0.3 mm real glyph clearance).

### 17. Dangling copper — OPEN
- `+1V8` track stub at (145.5, 83.2), `/I2C_SCL_MAG` stub at (157.6, 83.1).
- Dangling via on the 3.3 V RESET net at (157.8, 91.7) area (see DRC).

### 18. GND zone island — OPEN
DRC reports an isolated GND island on F.Cu/In1.Cu at about (100, 79). Re-check
after refilling zones in the GUI (headless ZONE_FILLER segfaults).

### 19. DRC cosmetics — OPEN
DRC: 1 clearance error (C42 pad to a +1V8 track, 0.175 mm), 4 unconnected items,
3 track dangling, 1 via dangling, plus lib_footprint_mismatch warnings that appear
because footprint copies on the board were edited (silk/outlines) and no longer
match their library sources.

### 20. Pin mux / firmware notes — REVIEW
- P9.42 was eCAP0 and is now the buzzer (intended). P9.41 (LED0 aux) is GPIO0_20,
  whose default mux is CLKOUT2; P9.30 (LED1 aux) is GPIO3_16 (SPI1_D1 pad).
- Servo/ESC outputs (P8.39, P8.42, P8.41, P8.44, P8.43, P8.45) are PRU1 R30
  outputs (mode 5) and match `docs/prus.md`; pin-to-connector order is
  non-monotonic (SERVO_1 -> J3, SERVO_2 -> J2), check the silkscreen.
- P9.32 (VADC) unconnected is fine: the cape only passes AIN0-6 through.

---

## Verified correct (no action)

- P9/P8 assignments match SRM Tables 10/11: UART2 (P9.21/22), DCAN1 (P9.24/26),
  SPI1 (P9.28/29/31), I2C1/I2C2 (P9.17-20), MMC1 (P8.3-25), LCD (P8.26-38),
  AIN0-6 (P9.33/35/36/37/38/39/40), GPIO numbering convention throughout.
- I2C1 1.8 V side: BHI360 + BMP390 + U5 A-side, 4k7 pull-ups to +1V8; 3.3 V side
  to P9.17/18 with 4k7 to +3V3; PCA9306 bias (VREF1 = +1V8, EN via R27 200k).
  Every device's abs max is respected.
- BHI360 aux I2C (M3) to BMM350 on +1V8 with 4k7 pull-ups (R16/R17).
- Decoupling: a cap sits within ~2-3 mm of every power pin on U2, IC3, IC4, U4,
  IC2 and IC1.

---

## Tooling state / caveats

- Edits were applied to the repo files directly while KiCad (PID 1104117) held the
  project open. Use **File -> Revert** in KiCad before saving; otherwise the
  in-memory copy can overwrite these changes.
- The PCB has **not** been synced from the schematic (F8) since the level shifters,
  buzzer/LED moves and no-connect flags were added.
- Backups of each step are under `~/.hermes/cache/scratch/bbcape/`
  (`pre-levelshift/`, `pre-silk/`, `pre-tp-silk/`, `pre-designator/`,
  `pre-pkg-silk/`, `pre-hide-J/`, `pre-buzzer/`, `pre-ledmove2/`).
- ERC baseline after these edits: errors unchanged (48 label_dangling,
  6 power_pin_not_driven, 3 pin_not_connected, 1 pin_not_driven, 1
  hier_label_mismatch). Warnings include 44 `endpoint_off_grid` and extra
  `lib_symbol_mismatch` entries left by power symbols placed at half-grid
  (0.635 mm) coordinates during the level-shifter edit - worth a cleanup pass.
