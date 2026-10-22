# Cape design issues

Open issues for the Skylark cape (KiCad project `BeagleBone-cape/`).

Rewritten 2026-10-22 against the committed schematic and PCB (KiCad 9.0.9, `kicad-cli`
netlist, BOM, ERC and DRC with schematic parity). Original reviews were done 2026-10-10 and
2026-10-12 against the BBB System Reference Manual (Table 10 P8 / Table 11 P9), the AM335x
mux tables (SPRS717 rev L) and the device datasheets. Closed items are kept at the end
under "Done" so their numbers stay stable.

Status legend: `OPEN` not addressed, `REVIEW` needs a decision, `WONTFIX` accepted as is.

## Current state (2026-10-22)

- ERC: 42 items. 40 `label_dangling` on unused P8/P9 pins (cosmetic) and 2 `pin_to_pin`
  (#33). `lib_symbol_mismatch` is cleared.
- Schematic-side fixes of 2026-10-22 (#21, #22, #24, #25, #27, #29, #30, #33) are in the
  schematic but NOT yet in the PCB: run Update PCB from Schematic, then place and route the
  new parts (list under "PCB follow-up" below).
- DRC: 16 violations, 4 unconnected pads. The important ones are the crossed IMU
  interrupt tracks (#39). The rest are 5 `lib_footprint_mismatch`, 3 `silk_overlap`,
  1 `silk_over_copper`, the R25 `+3V3` stub and the split `+24V` zone (#19).
- Design as built: A6983 buck from the 24 V input (J12) -> ideal diode LTC4412/Q1 ->
  +5V; BBB 3V3. Sensors, all on +3V3, no 1.8 V rail: two LSM6DSV16X (U2, U4) on SPI1,
  IIS2MDC (U1) and BMP390 (IC3) on I2C1. TCAN3413 CAN (IC2) on DCAN1, DS1307 RTC (U3)
  on I2C2. Outputs: servos J1-J4, motors J9/J10, LEDs J5/J6, buzzer BZ1, MAVLink J13,
  airspeed J8.
- Net names now: `/CAN_TX`, `/CAN_RX`, `/CANH`, `/CANL`. The PCB still has the old
  `/FDCAN_*` and `CAN-`/`CAN+` names until "Update PCB from Schematic" is run (#25).

---

## Critical / High

### 39. IMU_INT1 and IMU_INT2 tracks cross at P9.14 / P9.16 — OPEN (new)
DRC reports 3 `shorting_items` between `/IMU_INT1` and `/IMU_INT2`, 3 `solder_mask_bridge`
and 2 unconnected items at P9.14 (INT1) and P9.16 (INT2), around (134.9-137.5, 92-96 mm).
As routed the two nets are shorted on F.Cu. Reroute or swap the nets so INT1 goes to P9.14
and INT2 to P9.16 (or swap the header pins in the schematic), then re-run DRC.

### 21. 24 V input has no protection and too little input capacitance — PARTLY DONE (schematic, 2026-10-22)
Schematic now: J12 -> F1 (2 A 63 V, 1206, Littelfuse 0466002.NRHF) -> `VIN_F` -> Q3 (AOD4185L
P-FET reverse protection, gate zener D8 BZT52C12, R29 100k) -> +24V; D7 SMBJ33CA bidirectional TVS
on `VIN_F`; C12 10 uF 50 V 1206; C31 100 uF 50 V electrolytic after Q3 (place next to J12).
Still open: EN/UVLO divider (depends on cell count, PWR-01 TBD); the TVS clamps ~53 V at full
pulse current (above the 42 V abs max, the bulk cap absorbs most hot-plug ringing); Q3 is only
rated -40 V (SQD50P06-15L is a -60 V drop-in, no LCSC number found); F1 is a fast fuse, check
I2t against inrush and that it does not limit the 3 A output at low input voltage; PCB not
updated. Original analysis:
Power sheet: J12 -> F1 (1812, no rating, no part) -> +24V -> A6983 VIN. There is
no reverse-polarity protection (PWR-05), no TVS and no bulk capacitor. Input caps
are C10/C11 1 uF 50 V and C12 10 uF **35 V in 0603** (GRM188R6YA106MA73D); at 24 V
DC bias that is roughly 2-3 uF total.

- Hot-plugging a battery through its leads into an all-ceramic input rings up to
  about 2x VIN. At 6S (25.2 V) that is ~50 V, above the A6983 absolute maximum of
  42 V (VIN, EN, SW, PGOOD).
- A reversed battery forward-biases the A6983 internal body diodes; with an
  unspecified F1 the IC is likely lost.
- PWR-01 mentions up to 8S (33.6 V): C12 (35 V) would have no margin.
- EN/CLKIN is tied straight to VIN, so there is no input UVLO (the A6983 runs down
  to ~3.5 V and will deep-discharge a LiPo).

Fix: bulk electrolytic/polymer (47-100 uF, 50 V) at J12; TVS chosen so its
clamping voltage is below 42 V at the maximum battery voltage; reverse protection
(P-FET, or an ideal-diode controller with an N-FET); C12 -> 10 uF 50 V 1206/1210;
specify F1 (rating per PWR-04); optional EN divider for UVLO (EN threshold 1.2 V).

### 22. Servos share the BBB 5 V rail and the 3 A budget — PARTLY DONE (minimum fix, schematic)
C32 470 uF 16 V added on +5V next to J1/J2 (place at the servo connectors). A separate servo
rail and the PWR-03 current limit are still open. Original analysis:
+5V (after Q1) feeds the BBB VDD_5V (P9.5/P9.6) **and** servo power on J1-J4 pin
2, the LED connectors J5/J6, J8, J13 and the buzzer. The A6983 is rated 3 A. The BBB
alone takes 0.5-1 A; one stalled standard servo takes 1-2.5 A. A servo stall or
several servos moving at once will brown out the BBB in flight. There is no bulk
capacitance near the servo connectors (only C14-C16 near the buck). PWR-03 is still TBD.

Fix: separate servo rail (second buck/BEC, or an external BEC input with a jumper),
keep the BBB on its own 5 V; at minimum add 220-470 uF bulk at the servo connectors and
set the PWR-03 current limit.

### 23. BBB pins go straight to off-board connectors, including SYSBOOT pins — OPEN
- P8.45/P8.43/P8.44/P8.41/P8.42/P8.39 (lcd_data0/2/3/4/5/6 = SYSBOOT0/2/3/4/5/6)
  go directly to J10, J9, J4, J2, J3, J1. These pins are sampled as boot straps
  when the BBB comes out of reset, and the cape 5 V (which powers servos/ESCs)
  is up before that. An ESC or servo input with a pull-up/pull-down, or one that
  back-drives the line, can change the boot mode (docs/prus.md R-1).
- On every servo/LED connector the pin next to the signal is +5V. A mis-plugged
  or damaged cable puts 5 V on an AM335x pin that is not 5 V tolerant.
- Same exposure without series resistors or ESD protection on P8.17/P8.18 (J5/J6),
  P9.21/P9.22 (J13) and P9.19/P9.20 (J8).

Fix: a 5 V-tolerant buffer (e.g. 74LVC1G125 per channel or a 74LVC541) between the
BBB and J1-J4/J9/J10, with OE pulled to "disabled" and released by a GPIO after
boot. That isolates SYSBOOT and protects the SoC. Add series resistors
(100-220 ohm) plus an ESD array on the UART/I2C/LED lines.

### 24. Piezo buzzer BZ1 cannot be driven by the current circuit — DONE in schematic (R28 1k across BZ1; place next to BZ1/Q2 on the PCB)
BZ1 is a TDK PS1240P02BT, an external-drive piezo element (capacitive, no internal
oscillator). It sits between +5V and the drain of the low-side Q2 (BSS138) with nothing
across it. When Q2 turns on the element discharges; when Q2 turns off nothing
recharges it, so it barely moves after the first edge (it clicks instead of sounding).
The gate is on `/BUZZER` = P9.42 (eCAP0) with R24 10k pull-down, which is fine.

Fix: put a resistor across BZ1 (about 1 k) or from the Q2 drain to +5V, or drive
the piezo push-pull. Alternatively use a magnetic transducer and add a flyback diode.

---

## Medium

### 3. BMP390 I2C address is 0x76 — OPEN (check against firmware)
IC3 pin 5 (SDO) is tied to GND, which selects 0x76. If firmware/devicetree expects
0x77, tie SDO to +3V3. No address clash on I2C1: IIS2MDC is at 0x1E.

### 11. BMP390 `INT` goes nowhere — OPEN
`/BARO_INT` (IC3 pin 7) only reaches TP21. Wire it to a free GPIO if wanted; it runs
at 3.3 V so no level shifter is needed.

### 7. +5V back-feed through P9.5/P9.6 — REVIEW (mostly mitigated)
The buck output reaches VDD_5V through ideal diode U6 (LTC4412) / Q1 (DMP3013SFV,
drain on BUCK_OUT, source on +5V), so a higher BBB barrel-jack supply turns Q1 off
and the A6983 (which senses VOUT/FB on +5V, after Q1) just stops switching. No
damage path found. Still, do not run the barrel jack and the cape at the same time
in normal use: the BBB then runs from whichever source is higher.

### 15. I2C2 external connector J8 assumes a 3.3 V device — REVIEW
The air-speed sensor port has 4k7 pull-ups (R22/R23) to +3V3 (plus the BBB's own 4k7 on
I2C2, 2.35 k combined). Any 5 V-only device plugged in must be open-drain with
VIH below 3.3 V. Pin order: see #28.

### 25. CAN port: no ground pin, fixed termination, naming — DONE in schematic, PCB update pending
Schematic: J11 is now a 3-pin terminal (1 CANH, 2 CANL, 3 GND, footprint
`TerminalBlock_Xinya_XY308-2.54-3P`), JP1 solder jumper (CAN_TERM, bridged by default) in series
with R7, nets renamed `/CAN_TX`/`/CAN_RX`. PCB: needs the footprint swap, GND connection for
pin 3 and room next to the RJ45 notch (#26); remove the JP1 bridge when not at the bus end.
Original notes:
- J11 is a 2-pin terminal (CANH, CANL) with no GND. CAN transceivers need a common
  ground between nodes; here the return has to go through the power wiring.
  DroneCAN devices (GPS, FLT-05) use JST-GH 4-pin: 5 V, CANH, CANL, GND.
- R7 (120 ohm) is fixed. If the cape is not at the end of the bus it adds a third
  terminator. Use a solder jumper (CAN-03 is still open).
- The nets are named FDCAN_TX/RX, but AM335x DCAN1 is classic CAN 2.0B only (the
  TCAN3413 supports FD, the SoC does not); rename to CAN_TX/CAN_RX.
- Merged net names (FDCAN_RX/GPIO15, FDCAN_TX/GPIO14, CAN-/CANL, CAN+/CANH) were
  unified on 2026-10-22: GPIO14/15 labels removed, CAN-/CAN+ renamed CANL/CANH. Run Update
  PCB from Schematic to rename the PCB nets.
- Verified OK: P9.24 = dcan1_rx and P9.26 = dcan1_tx (mode 2) into TCAN3413
  RXD/TXD; VCC/VIO = 3.3 V; STB tied low (always normal mode); SZNUP2105L (D6) ESD on
  the bus.

### 26. P8/P9 header part not defined; mechanical checks — OPEN
P8/P9 use a generic male `PinHeader_2x23` footprint on F.Cu with no part number. A
cape needs either long-tail stacking female headers (fitted from the top) or male
headers fitted from the bottom; pick the part and check the stack height.
Also check that J11/J12 (terminal bodies end ~2.4 mm from the RJ45 notch edge at
y = 79.05) leave room to insert wires next to the BBB Ethernet jack, which sticks
up through the notch.

### 27. Connector labels do not match the schematic — PARTLY DONE
Schematic values fixed 2026-10-22 (J2 = "Servo 2" on SERVO_2, J3 = "Servo 1" on SERVO_1; J9/J10
already matched). Open on the PCB: swapped MR/ML silk on J9/J10, J11/J12 label positions.
Original notes:
- J9 (value MotorL, net /MOTOR_L, P8.43) has the silk label **MR**, and J10
  (MotorR, /MOTOR_R, P8.45) has **ML**. Verify on the PCB silk.
- J2 (value "Servo 1") carries `/SERVO_2` (P8.41), and J3 ("Servo 2") carries `/SERVO_1`
  (P8.42) (docs/prus.md O-3). Decide on one mapping and make the net names, symbol
  values, silk and docs agree.
- The J11/J12 labels (CANH, CANL, +24V, GND) are rotated 180 degrees and sit
  1.2-2.1 mm to the right of their pins. CANL (x = 107.22) lands between J11 and
  J12, which makes it easy to wire 24 V into the wrong terminal. Centre each label
  over its pin.

### 28. External connector pinouts are non-standard — REVIEW
- J8 (airspeed): 1 = +5V, 2 = SDA, 3 = SCL, 4 = GND. The Pixhawk/Dronecode
  standard is 1 = VCC, 2 = SCL, 3 = SDA, 4 = GND.
- J13 (MAVLink): 1 = +5V, 2 = BBB RX (P9.22), 3 = BBB TX (P9.21), 4 = GND. The
  flight-controller side of the Pixhawk TELEM standard is 2 = TX (out),
  3 = RX (in).
- Both are JST-EH while Pixhawk accessories use JST-GH, so off-the-shelf cables
  won't fit either way. Either switch to GH with the standard pin order, or
  document the pinout on the silk and in docs.
- J13/J8 pin 1 supply +5V out. A device with its own supply will tie two 5 V
  sources together.

### 29. Production files are stale and the LCSC field is misnamed — PARTLY DONE
Done 2026-10-22: field renamed `LSCS Part Number` -> `LCSC` in all sheets, library and the
BOM field in `.kicad_pro`; orphan R8/R9 deleted. Still open: MPN/LCSC missing on D1, D2, Q1,
U1, U2, U4, U6, the J connectors and P8/P9, and the production files are not regenerated.
Original notes:
`BeagleBone-cape/production/` predates the current design (files dated 2026-10-01). It
does not contain the two-IMU design.
Every LCSC column in the current BOM is empty because the symbol field is named
`LSCS Part Number` (typo), while the Fabrication Toolkit reads `LCSC` / `LCSC Part #`.
Parts with no MPN/LCSC at all: D1, D2, F1, IC1 (LCSC), Q1, U1, U2, U4, U6, R10, R11,
all J connectors, P8/P9. Rename the field, complete the part data, then regenerate
everything after the fixes above. R8/R9 are DNP 4k7 with no net connections; delete
them from the schematic.

### 30. Value / part-number mismatches — PARTLY DONE
Done 2026-10-22: R10 (blue D1) 100, R11 (red D2) 470; C33/C34 22 uF 25 V 1206 added on BUCK_OUT
in parallel with C14-C16 (confirm the loop on the bench). Open: C14-C16 still "40u"
non-ceramic, L1 Isat check, D1/D2 part numbers.
- C14-C16: value "40u" (copied from the A6983 typical-application COUT), but the MPN
  EFVM016ADA470M0545 indicates 47 uF and is a non-ceramic part. The A6983 internal
  compensation is specified with MLCC output caps; add/replace with ceramic
  (e.g. 2 x 22 uF 10 V 1206) and confirm the loop on the bench.
- L1 15 uH (SDRH0704 class): confirm Isat >= ~3.6 A for 3 A output; many 7 mm
  15 uH parts saturate at 2-3 A.
- R10/R11 "420": not an E24 value. With a blue LED at 3.3 V that gives ~1 mA
  (dim); use 470 for red and ~100-150 for blue, and give D1/D2 real parts.

### 32. No power LED, no battery monitoring — REVIEW
PWR-06 (power indication) and PWR-07 (battery voltage) are not implemented: D1/D2
are GPIO driven, and AIN0-6 only pass through. If a VBAT divider is added, the
AM335x ADC input range is 0-1.8 V (reference GNDA, P9.34), so size the divider for
<= 1.8 V at maximum battery voltage and add a clamp. PGOOD (P8.12) could drive a
power-good LED.

### 40. Two IMUs are undocumented; check the second one's wiring — REVIEW (new)
The schematic has two LSM6DSV16X: U2 (CS `/SPI1.CS0` = P9.28, INT1 P9.14, INT2 P9.16)
and U4 (CS `/IMU2_CS` = P9.27, INT1 `/IMU2_INT1` = P9.12, INT2 unconnected). Both share
SPI1 D0/D1/SCLK. P9.27 and P9.12 are plain GPIOs (GPIO3_19, GPIO1_28), so the second chip
select has to be a GPIO chip select; confirm the firmware (ArduPilot Linux hwdef, device
tree) supports that. Both parts still lack LCSC data in the BOM (#29). Update #38 and
#20 once this is decided.

---

## Low / cosmetic

### 6. P9.7/P9.8 = SYS_5V net — mostly done, trace on In1.Cu
The net is now named `SYS_5V` and only reaches TP34. The trace still runs on In1.Cu,
see #36. It is a BBB *output* (250 mA): never feed it from the cape.

### 16. Silkscreen — mostly done
- Reference designators are 0.6 mm / 0.1 mm stroke on F.SilkS; test point designators
  and J designators are hidden.
- Open: C29 is the only designator left at 90 degrees; some text pairs are within
  KiCad's coarse bounding boxes (~0.3 mm real glyph clearance); DRC reports 3
  `silk_overlap` and 1 `silk_over_copper` (R25/C4, R26/TP17, R26 over mask).
- Connector labels that do not match the schematic: see #27.

### 19. DRC summary — PARTLY OPEN (2026-10-22)
Current DRC (kicad-cli, schematic parity): 16 violations, 4 unconnected pads.
- `shorting_items` / `solder_mask_bridge` / unconnected on P9.14 and P9.16: see #39.
- `+3V3` track to R25 pad 1 at (157.34-158.87, 79.44) is unconnected, and the `+24V`
  F.Cu zone near (121.4, 83.8-86.8) is split in two pieces. Refill zones in KiCad and
  re-check (headless ZONE_FILLER segfaults).
- Silk: R25/C4, R26/TP17, R26 silk over mask. Cosmetic, check visually.
- `lib_footprint_mismatch` (5): footprint copies differ from libraries (P8/P9 headers,
  D1, Q1, U6, Y1).
- Netclass default clearance is 0.127 mm in `BeagleBone-cape.kicad_pro` (JLCPCB 5 mil
  minimum); this cleared the earlier SMD pad-pitch errors on the LGA parts.

### 20. Pin mux / firmware notes — REVIEW
- **P9.41 and P9.42 are each wired to two AM335x balls** on the BBB (P9.41: GPIO0_20 and
  GPIO3_20; P9.42: GPIO0_7 and GPIO3_18). The device tree must mux the unused ball of each
  pair as an input without pull, otherwise the two drivers fight.
- P9.42 is the buzzer (eCAP0, `/BUZZER`). P9.41 (`/GPIO7`, R10 -> D1, LED0) is GPIO0_20,
  whose default mux is CLKOUT2. LED1 (`/GPIO49`, R11 -> D2) is on P9.23 (GPIO1_17).
  `/LED_0` (P8.18) and `/LED_1` (P8.17) go only to J5/J6 and TP7/TP8, not to D1/D2.
- Servo/ESC outputs (P8.39, P8.42, P8.41, P8.44, P8.43, P8.45) are PRU1 R30
  outputs (mode 5) and match `docs/prus.md`; pin-to-connector order is
  non-monotonic, see #27.
- P9.32 (VADC) unconnected is fine: the cape only passes AIN0-6 through.
- `br2-skylark/board/skylark/dts/skylark-cape.dts` (as of 2026-10-12) only enables DCAN1,
  UART4 (console) and the DS1307. Missing for this cape: I2C1 pinmux (P9.17/P9.18,
  mode 2), SPI1 pinmux (P9.28 cs0, P9.29 d0, P9.30 d1, P9.31 sclk, mode 3), UART2
  (P9.21/P9.22, MAVLink J13), IMU interrupt GPIOs (P9.14, P9.16, P9.12), the
  magnetometer DRDY GPIO (P9.15), the U4 chip select GPIO (P9.27), eCAP0 PWM for the
  buzzer (P9.42), the LED GPIOs and the dual-ball fix above. DCAN1 pinmux (P9.24 rx /
  P9.26 tx, mode 2) is correct.
- The LSM6DSV16X supports SPI mode 0 or 3, up to 10 MHz (D0 = MISO with the default
  McSPI pin direction). Addresses on I2C1: IIS2MDC 0x1E, BMP390 0x76.
- ArduPilot Linux hwdef: IMU LSM6DSV on SPI1, compass IIS2MDC and baro BMP390 on I2C1.
- `docs/ROADMAP.md` still plans a `kmod-bmm350` driver; the BMM350 is gone, update it.

### 33. Schematic hygiene — PARTLY DONE
ERC (2026-10-22): 42 items. `lib_symbol_mismatch` and the stray wire endpoint were cleared (the
A6983C50QTR symbol in `Cape_lib` was replaced by the schematic's version; the six `+3.3V`
symbols became `+3V3`).
- 40 `label_dangling`: labels on unused P8/P9 header pins. Acceptable, but they inflate
  the count; delete them or add no-connect flags if a clean ERC is wanted.
- 2 `pin_to_pin`: `#FLG0106` (PWR_FLAG on GND) shares the GND net with the SDx pins
  (Bidirectional) of U2 and U4. Removing the flag leaves GND undriven (new
  `power_pin_not_driven`), so it stays. Clear with an ERC exclusion in the KiCad GUI, or
  drive GND from a real power-output pin.

### 35. Magnetometer placement — REVIEW
- The IIS2MDC (U1) should be kept away from the CR2032 holder BT1. The cell's steel can
  is ferromagnetic and causes a fixed hard-iron offset; calibrate with the cell fitted,
  or move the magnetometer or the cell further apart. Check the distance on the PCB.
- The IIS2MDC C1 pin needs a low-ESR 220 nF cap (C4, 220n X7R 50 V, right at pins 5/6).

### 36. Routing on the In1.Cu GND plane — OPEN
In1.Cu is the reference plane, but it carries signal/power nets: `/SYS_5V` (4 segments,
along the bottom edge, only to TP34), `/Power/+24V_IN` (4 segments near F1), the DS1307
SQW net (2 segments), and now also `/SPI1.SCLK`, `/SPI1.CS0`, `/SPI1.D0`, `/SPI1.D1`,
`/IMU2_CS`, `/I2C1.SCL` and `/I2C1.SDA` (the IMU routing). Move them to another layer
where possible (or delete the SYS_5V test-point trace) so the GND plane is solid under
the buck and the header.

### 38. IMU swap (LSM6DSV16X + IIS2MDC) — schematic done, PCB routing partly OPEN
History: BHI360 + BMM350 and the 1.8 V domain were replaced because there is no ArduPilot
driver for the BHI360, the BMM350 sat behind it, it was capped at 800 Hz output, and the
BMM350/BHI360 parts were broker-only. The new parts are stocked by authorized
distributors and have ArduPilot drivers (LSM6DSV, IIS2MDC).

Current schematic: U2 and U4 LSM6DSV16X (LGA-14 2.5x3, MPN LSM6DSV16XTR) on SPI1, VDD/VDDIO
on +3V3; U1 IIS2MDC (LGA-12, MPN IIS2MDCTR), SCL/SDA on I2C1, CS to +3V3 (I2C mode),
DRDY to P9.15; BMP390 (IC3) on +3V3 on the same I2C1. LSM6DSV16X SDx/SCx go to GND (Qvar/
analog hub unused, per DS13510 Table 2); OCS_Aux/SDO_Aux left open.

Open: reroute the INT1/INT2 crossing (#39), fix the R25 stub and `+24V` zone (#19), move
SPI/I2C routing off In1.Cu (#36), regenerate the production files (#29). Fallback IMU:
BMI270 (different footprint and pinout, not a drop-in).

---

## PCB follow-up for the 2026-10-22 schematic changes

Run Update PCB from Schematic (adds Q3, D7, D8, R29, C31, C32, C33, C34, R28, JP1; swaps F1
1812 -> 1206, C12 0603 -> 1206, J11 2P -> 3P; renames `/FDCAN_*` -> `/CAN_*` and `CAN-/CAN+` ->
`CANL/CANH`; creates nets `/Power/VIN_F`, `Net-(D8-A)`, `Net-(JP1-B)`). Then:
- D7, Q3, D8, R29, C31 between J12/F1 and the buck; reroute F1 -> Q3 drain and Q3 source ->
  +24V (Q3 needs copper area on its tab); C33/C34 beside C14-C16; C32 at the servo connectors;
  R28 by BZ1/Q2; JP1 in series with R7; J11 pin 3 to GND.
- Fix the IMU interrupt crossing (#39), refill zones, run DRC, regenerate BOM and production
  files (#29).

---

## Done

Closed items, kept for reference:

- **#1, #9, #31** — BHI360 level shifting / JTAG_DIO / host bandwidth. Obsolete after the
  IMU swap (#38); the BHI360, BMM350, TLV75518 and PCA9306 are gone.
- **#2** Buzzer moved to P9.42 (eCAP0).
- **#4** Cape EEPROM section removed (U1, SW1, TP1). The reference U1 now belongs to the
  IIS2MDC.
- **#5** LED feeds: D1 via R10 from P9.41 (`/GPIO7`), D2 via R11 from P9.23 (`/GPIO49`).
- **#8** Q2 is BSS138LT1G (C82045); the drive stage problem is #24.
- **#10** PGOOD leaves the power sheet (P8.12, R27 10k pull-up to +3V3).
- **#12** PWR_FLAGs on the root sheet.
- **#13** Footprint fields set; IC3 symbol moved to `Cape_lib`.
- **#14** DS1307 (U3) on +5V with 3.3 V I2C2 bus: WONTFIX, works (open-drain, VIH 2.2 V).
  Keep SQW/OUT (pulled up to +5V by R19) off any BBB pin.
- **#17** Dangling copper stubs and vias removed.
- **#18** GND zone island removed by zone refill.
- **#34** A6983 VBIAS tied to BUCK_OUT.
- **#37** Design rules: outer track 0.10 mm, edge clearance 0.3 mm, zone clearance 0.2 mm.

---

## Verified correct (no action)

- P9/P8 assignments match SRM Tables 10/11: UART2 (P9.21/22), DCAN1 (P9.24/26),
  SPI1 (P9.28/29/30/31), I2C1/I2C2 (P9.17-20), MMC1 (P8.3-25), LCD (P8.26-38),
  AIN0-6 (P9.33/35/36/37/38/39/40), GPIO numbering convention throughout.
- BMP390 pinout (VDDIO/SCK/SDI/SDO/CSB/INT/VDD) matches the datasheet; CSB high selects
  I2C; VDD/VDDIO on +3V3.
- A6983 setup follows the datasheet typical application: RFILT 100 ohm + 1 uF on
  VINLDO, 1 uF VCC, 100 nF BOOT, FSW 3.3k to GND = 500 kHz with 15 uH, PGOOD 1M pull-up
  to BUCK_OUT. Exposed pad footprint (0.5 x 0.9 mm) matches the ST recommended land pattern.
- Ideal diode: LTC4412 VIN = BUCK_OUT, SENSE = +5V, CTL low, Q1 drain on BUCK_OUT;
  orientation correct.
- DS1307 with 32.768 kHz FC-135 (12.5 pF, as required), CR2032 on VBAT with C18.
- +3V3 comes from BBB P9.3/4 (load well under the 250 mA budget).
- Board outline: 86.36 x 54.61 mm with the RJ45 and barrel-jack notches; mounting
  holes at the BBB positions (66.04 / 48.26 / 41.91 mm spacing); P8-P9 pitch 48.25 mm.

---

## Tooling state / caveats

- Edit KiCad files only with the project closed (or use **File -> Revert** in KiCad
  before saving); otherwise the in-memory copy can overwrite external edits.
- Headless ZONE_FILLER segfaults; refill zones in the GUI before checking DRC.
- Reports used for this rewrite were generated with `kicad-cli sch export netlist/bom`,
  `kicad-cli sch erc` and `kicad-cli pcb drc --schematic-parity` on 2026-10-22.
