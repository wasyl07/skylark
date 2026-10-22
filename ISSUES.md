# Cape design issues

**2026-10-18 update (schematic + PCB pass):** items 4, 6, 10, 12, 13, 17, 18, 34, 37 and 38
(schematic part) are DONE in the committed schematic/PCB. Items 33 and 30 are partly done.
Remaining: PCB routing (52 unconnected pads, see 19 and 38), R27/R18 courtyard overlap,
and the open redesigns #21-24. Current DRC on the committed PCB (5ae1013d): 83 violations,
52 unconnected, not yet reviewed. ERC (2026-10-22): 62 items, all cosmetic or pre-existing.

Open issues found while reviewing the Skylark cape (KiCad project `BeagleBone-cape/`).
Reviews done 2026-10-10 and 2026-10-12 against KiCad 9.0.9, the BBB System Reference
Manual (Table 10 P8 / Table 11 P9), the AM335x mux tables, and the device datasheets
(BHI360 BST-BHI360-DS000-03 rev 1.2, BMM350 BST-BMM350-DS001-27, BMP390
BST-BMP390-DS002-07 rev 1.7, A6983 (ST), TCAN3413 SLLSFS8A, PCA9306, CAT24C256
(onsemi), AM335x SPRS717 rev L).

Status legend: `OPEN` not addressed, `DONE` fixed in the working tree (uncommitted
unless noted), `WONTFIX` accepted as is, `REVIEW` needs a decision.

Issues 1-20 come from the 2026-10-10 review (statuses updated 2026-10-12).
Issues 21-37 are new in the 2026-10-12 full review (schematic + PCB + production
files); they are listed after the older items, grouped by severity.

**2026-10-12 IMU swap (see #38):** BHI360 + BMM350 and the whole 1.8 V domain were
replaced by an LSM6DSV16X on SPI1 and an IIS2MDC on I2C1, both on +3V3. Items 1, 9,
31 and the BMM350 part of 35 are closed by that change.

---

## Critical / High

### 1. BHI360 INT and RESETN crossed the 1.8 V / 3.3 V domains — DONE (obsolete, #38)
`OPEN` -> fixed by adding level shifters U7/U8 (SN74LVC1T45) plus R28 pull-up and
C40-C43 decoupling. Committed in `680b031d`, edited further in the working tree.
Re-checked 2026-10-12: U7 DIR = +1V8 (A->B, sensor -> P9.14), U8 DIR = GND
(B->A, P9.16 -> RESETN), R28 10k keeps RESET deasserted while P9.16 floats. OK.

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
- See also #24: the buzzer drive stage itself does not work with a piezo.

### 3. BMP390 I2C address is 0x76, not 0x77 — OPEN
IC3 pin 5 (SDO) is tied to GND, which selects 0x76. If firmware/devicetree expects
0x77, move SDO to +1V8. (No clash: the BHI360 on the same bus is at 0x28 because
its HSDO pin is tied to GND.)

### 4. Cape EEPROM (U1) section is a half-removed stub — DONE (2026-10-18: removed U1, SW1, TP1 and their wiring)
U1 (CAT24C256), SW1 and TP1 are now marked DNP but are still `in_bom`/`on_board`
with no footprint, and the pull-up resistors around them were deleted: ERC shows 12
unconnected wire stubs at x 306-362 mm, y 381-396 mm on the root sheet.
As drawn, the circuit would not work even if fitted:

- A2 is floating, and A0/A1 can only be switched to GND by SW1. The CAT24C256 has
  internal pull-downs on A0-A2 and WP, so the address is always 0x50. The BBB cape
  manager / U-Boot only probe 0x54-0x57 on I2C2 (SRM cape EEPROM: A2 high, A0/A1
  on switches with pull-ups).
- WP only goes to a test pad; with the internal pull-down the EEPROM is always
  writable.

Decide: either delete the section (fine for the Buildroot image, which loads the
cape DT itself), or complete it: A2 -> +3V3, 10k pull-ups on A0/A1 (SW1 to GND),
pull-up on WP with a test pad to GND for programming, and assign footprints.

### 5. LED designators / LED pin reassignment — REVIEW
`DONE (as built)` — after moving the buzzer to P9.42 the LED feeds were
reassigned because no free pin is adjacent to P9.42:

| Net | Was | Now | Note |
|---|---|---|---|
| /BUZZER | P9.30 (P8.13 briefly) | P9.42 (eCAP0) | hardware PWM |
| /GPIO7 (R10 -> D1, LED0) | P9.42 | P9.41 | GPIO0_20 |
| /GPIO20 (R11 -> D2, LED1) | P9.41 | P9.30 | GPIO3_16 |

Correction (2026-10-12, from the netlist): the on-board LEDs have **only** these
P9 feeds. D1 is driven only by P9.41 (via R10) and D2 only by P9.30 (via R11).
/LED_0 (P8.18) and /LED_1 (P8.17) go only to the external LED connectors J5/J6
(and TP7/TP8), not to D1/D2. The earlier note that the "P9 feeds are only a
second driver" was wrong; do not delete R11.

---

## Medium

### 6. Net named `VBUS` sits on P9.7/P9.8 = SYS_5V — OPEN
SRM Table 11: P9.7/P9.8 are SYS_5V (a BBB *output*, 250 mA). The net is misnamed;
today it only reaches TP34, so it is harmless, but the name invites feeding VBUS
into a BBB output. Rename to SYS_5V (ERC also reports VBUS/SYS_5V on the same
net). Its only trace runs on In1.Cu (the GND plane) along the bottom board edge,
see #36.

### 7. +5V back-feed through P9.5/P9.6 — REVIEW (mostly mitigated)
The buck output reaches VDD_5V through ideal diode U6 (LTC4412) / Q1 (DMP3013SFV,
drain on BUCK_OUT, source on +5V), so a higher BBB barrel-jack supply turns Q1 off
and the A6983 (which senses VOUT/FB on +5V, after Q1) just stops switching. No
damage path found. Still, do not run the barrel jack and the cape at the same time
in normal use: the BBB then runs from whichever source is higher.

### 8. Q2 (buzzer low-side FET) part — DONE (part), see #24
MPN is now BSS138LT1G (LCSC C82045), pinout G-S-D matches the `Q_NMOS_GSD`
symbol, and BSS138 is fine at 3.3 V gate drive for a piezo load. The symbol is
still the generic one; swap to a BSS138 symbol for a cleaner BOM. R24 10k gate
pull-down is correct. The drive stage still has a functional problem: #24.

### 9. `JTAG_DIO` and `~{BMM350_INT}` share one net — DONE (removed with BHI360, #38)
Net has IC4.A1 (BMM350 INT), U2.16 and TP16. U2.16 is the BHI360 Fuser2 debug data
pad (JTAG_DIO, alt GPIO20 / event input). Using it for the BMM350 interrupt works
only if the BHI360 firmware maps it as an event input, and it blocks Fuser2
debugging. The BMM350 can also be polled (data-ready register), so the INT line is
optional. Decide and rename the net.

### 10. `PGOOD` does not leave the power sheet — DONE (2026-10-18: PGOOD output pin on the Power sheet, R27 10k pull-up to +3V3, net on P8.12)
`pwr.kicad_sch` has a hierarchical label PGOOD, but the Power sheet symbol on the
root sheet has only +5V and +24V_IN pins (ERC `hier_label_mismatch`). IC1 PGOOD
reaches R18 (1M to BUCK_OUT) only. Either route it to a GPIO (through a divider or
pull-up to 3.3 V, PGOOD is open-drain) or a power LED (#33), or remove the label.

### 11. BMP390 `INT` goes nowhere — OPEN
Update (#38): the root-sheet hierarchical label is now a local label `BARO_INT`, and the
BMP390 runs at 3.3 V, so no level shifter is needed any more; it still only reaches TP21.
Wire it to a free GPIO if wanted.
Uses a root-level hierarchical label "INT" (`BeagleBone-cape.kicad_sch`), which
does nothing on the root sheet (ERC `pin_not_connected`). Net /INT reaches only
TP21, plus a dangling via at (163.38, 88.23) on the PCB. If it is ever wired to
a header pin it needs another SN74LVC1T45 (BMP390 INT is push-pull, active high;
pins limited to VDDIO+0.3 V).

### 12. Missing PWR_FLAGs — DONE (2026-10-18: six PWR_FLAGs on the root sheet; power_pin_not_driven cleared)
ERC still reports 6 `power_pin_not_driven` (2026-10-12): #PWR02, #PWR026, #PWR077
(GND/+5V/+3V3 symbols on the root sheet), #PWR0103 (VBUS), #PWR0107 (GNDA) and U3
VBAT (coin cell). The power sheet has its own PWR_FLAGs; add them on the root
sheet for +3V3 (from P9.3/4), GNDA, VBUS/SYS_5V and the coin-cell net.

### 13. Footprint fields empty / parts without footprints — DONE (2026-10-18: footprints set for IC2, IC3, U9, U10, C44-C49; IC3 symbol moved to Cape_lib)
IC2, IC3, IC4 and U2 have empty Footprint fields in the schematic; the PCB uses
caplib footprints for them (DRC `footprint_symbol_mismatch` x4). U1, SW1 and TP1
have no footprint (DRC `missing_footprint` x3, see #4). "Update PCB from
Schematic" with "replace footprints" would strip them.
Also (2026-10-12): IC3 uses a symbol from library `sensor_fuser_symbol`, which is
not in `sym-lib-table` (ERC `lib_symbol_issues`) — move the symbol into
`Cape_lib`.

### 14. DS1307 (U3) is a 5 V part on a 3.3 V I2C bus — WONTFIX (works)
U3 VCC is on +5V while SDA/SCL sit on the 3.3 V I2C2 bus with 4k7 pull-ups. Works
because the interface is open-drain and VIH (2.2 V at 5 V VCC) is below 3.3 V.
A 3.3 V RTC (DS1338/PCF8563) would be cleaner. SQW/OUT is pulled up to +5V
(R19); keep it off any BBB pin.

### 15. I2C2 external connector J8 assumes a 3.3 V device — REVIEW
The air-speed sensor port has 4k7 pull-ups to +3V3 (plus the BBB's own 4k7 on
I2C2, 2.35 k combined). Any 5 V-only device plugged in must be open-drain with
VIH below 3.3 V. Pin order: see #28.

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
- Connector labels that do not match the schematic: see #27.

### 17. Dangling copper — DONE (2026-10-18: stubs and dangling via removed; IMU-area +3V3/INT1 copper and old In2 pour cleared)
DRC now reports:
- `+3V3` stub at (141.90, 83.35), 0.15 mm.
- `+1V8` stub at (145.48, 83.19), 0.01 mm.
- `/I2C_SCL_MAG` stub at (163.22, 79.64), 0.64 mm.
- Dangling via on `/INT` (BMP390 INT) at (163.38, 88.23), see #11.

### 18. GND zone island — DONE (2026-10-18: removed by zone refill, no isolated copper)
DRC still reports 3 unconnected GND items at (100.0, 79.04) — the corner where the
RJ45 notch meets the left edge (F.Cu/In1.Cu GND zone). Re-check after refilling
zones in the GUI (headless ZONE_FILLER segfaults); add a stitching via or remove
the island.

### 19. DRC summary — PARTLY DONE (2026-10-22 analysis pass)
Current DRC on the working-tree PCB (kicad-cli, schematic parity, 2026-10-22): 14 violations,
3 unconnected (routing to-do, see #38), 4 clearance, 3 silk_overlap, 1 silk_over_copper,
6 lib_footprint_mismatch.
Removed on 2026-10-22: dangling +24V via pair at (121.92/122.52, 87.16) with its stub; dangling
SPI1.SCLK stubs at (153.45, 87.53-87.57) F.Cu and (153.54, 87.70) In2.Cu.
Netclass default clearance 0.20 -> 0.127 mm in BeagleBone-cape.kicad_pro; this
cleared the 38 SMD pad-pitch errors on U1/U2/U4 (JLCPCB 5 mil minimum).
Still open:
- Via [/PGOOD] at (118.31, 84.27): 0.00 mm to zones [+3V3] on B.Cu and [+5V] on In2.Cu (4 clearance
  errors). Probably a stale zone fill. Fill all zones in KiCad, then re-check; if still 0 mm, move the via.
- Silk overlaps: R25/C4, R26/TP17, R26 silk over mask. Cosmetic, check visually.
- lib_footprint_mismatch (6): footprint copies differ from libraries (P8/P9 headers, D2, Q1, U6, Y1).

### 20. Pin mux / firmware notes — REVIEW
- P9.42 was eCAP0 and is now the buzzer (intended). P9.41 (LED0) is GPIO0_20,
  whose default mux is CLKOUT2; P9.30 (LED1) is GPIO3_16 (SPI1_D1 pad).
- New 2026-10-12: **P9.41 and P9.42 are each wired to two AM335x balls** on the
  BBB (P9.41: GPIO0_20 and GPIO3_20; P9.42: GPIO0_7 and GPIO3_18). The DT must mux
  the unused ball of each pair as an input without pull, otherwise the two drivers
  fight.
- Servo/ESC outputs (P8.39, P8.42, P8.41, P8.44, P8.43, P8.45) are PRU1 R30
  outputs (mode 5) and match `docs/prus.md`; pin-to-connector order is
  non-monotonic (SERVO_1 -> J3, SERVO_2 -> J2), see #27.
- P9.32 (VADC) unconnected is fine: the cape only passes AIN0-6 through.
- New 2026-10-12: `br2-skylark/board/skylark/dts/skylark-cape.dts` only enables
  DCAN1, UART4 (console) and the DS1307. Still missing for this cape: I2C1 pinmux
  (P9.17/P9.18 mode 2), UART2 (P9.21/P9.22, MAVLink J13), BHI360 INT/RESET GPIOs
  (P9.14/P9.16), eCAP0 PWM for the buzzer (P9.42), LED GPIOs, and the dual-ball
  fix above. DCAN1 pinmux (P9.24 rx / P9.26 tx, mode 2) is correct.
- `docs/ROADMAP.md` plans a `kmod-bmm350` driver, but the BMM350 is on the BHI360
  master interface (ASDX/ASCX), not on a BBB bus; Linux cannot reach it directly.
  Only the BHI360 firmware can read it.

---

## 2026-10-12 review — new issues

### Critical / High

### 21. 24 V input has no protection and too little input capacitance — OPEN
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
specify F1 (rating per PWR-04); optional EN divider for UVLO (EN threshold
1.2 V).

### 22. Servos share the BBB 5 V rail and the 3 A budget — OPEN
+5V (after Q1) feeds the BBB VDD_5V (P9.5/P9.6) **and** servo power on J1-J4 pin
2, the LED connectors J5/J6, J8 and J13. The A6983 is rated 3 A. The BBB alone
takes 0.5-1 A; one stalled standard servo takes 1-2.5 A. A servo stall or several
servos moving at once will brown out the BBB in flight, and servo current
spikes go straight onto the BBB supply and the sensor LDO input chain. There is no
bulk capacitance near the servo connectors (only C14-C16 near the buck). PWR-03 is
still TBD.

Fix: separate servo rail (second buck/BEC, or an external BEC input with a
jumper), keep the BBB on its own 5 V; at minimum add 220-470 uF bulk at the servo
connectors and set the PWR-03 current limit.

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

### 24. Piezo buzzer BZ1 cannot be driven by the current circuit — OPEN
BZ1 is a TDK PS1240P02BT, an external-drive piezo element (capacitive, no internal
oscillator). It sits between +5V and the drain of the low-side Q2 with nothing
across it. When Q2 turns on the element discharges; when Q2 turns off nothing
recharges it, so it barely moves after the first edge (it clicks instead of
sounding).

Fix: put a resistor across BZ1 (about 1 k) or from the Q2 drain to +5V, or drive
the piezo push-pull. Alternatively use a magnetic transducer and add a flyback
diode.

### Medium

### 25. CAN port: no ground pin, fixed termination, naming — OPEN
- J11 is a 2-pin terminal (CANH, CANL) with no GND. CAN transceivers need a common
  ground between nodes; here the return has to go through the power wiring.
  DroneCAN devices (GPS, FLT-05) use JST-GH 4-pin: 5 V, CANH, CANL, GND.
- R7 (120 ohm) is fixed. If the cape is not at the end of the bus it adds a third
  terminator. Use a solder jumper (CAN-03 is still open).
- The nets are named FDCAN_TX/RX, but AM335x DCAN1 is classic CAN 2.0B only (the
  TCAN3413 supports FD, the SoC does not). Merged net names
  (FDCAN_RX/GPIO15, FDCAN_TX/GPIO14, CAN-/CANL, CAN+/CANH) were unified on 2026-10-22: GPIO14/15
  labels removed, CAN-/CAN+ renamed CANL/CANH. Run Update PCB from Schematic to rename the PCB nets.
- Verified OK: P9.24 = dcan1_rx and P9.26 = dcan1_tx (mode 2) into TCAN3413
  RXD/TXD; VCC/VIO = 3.3 V; STB tied low (always normal mode); SZNUP2105L ESD on
  the bus.

### 26. P8/P9 header part not defined; mechanical checks — OPEN
P8/P9 use a generic male `PinHeader_2x23` footprint on F.Cu with no part number. A
cape needs either long-tail stacking female headers (fitted from the top) or male
headers fitted from the bottom; pick the part and check the stack height.
Also check that J11/J12 (terminal bodies end ~2.4 mm from the RJ45 notch edge at
y = 79.05) leave room to insert wires next to the BBB Ethernet jack, which sticks
up through the notch.

### 27. Connector labels do not match the schematic — OPEN
- J9 (value MotorL, net /MOTOR_L, P8.43) has the silk label **MR**, and J10
  (MotorR, /MOTOR_R, P8.45) has **ML**.
- J2 (value "Servo 1", silk FR) carries net SERVO_2, and J3 ("Servo 2", silk RL)
  carries SERVO_1 (docs/prus.md O-3). Decide on one mapping and make the net
  names, symbol values, silk and docs agree.
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

### 29. Production files are stale and the LCSC field is misnamed — OPEN
`BeagleBone-cape/production/` predates the current design. The gerber zip is dated
2026-05-31. `bom.csv` still lists D3 and J7 (both removed) and has no U4-U8, Q1,
C19-C21, C40-C43, R25-R28. `positions.csv` puts BT1 on the bottom layer.
Every LCSC column is empty because the symbol field is named `LSCS Part Number`
(typo), while the Fabrication Toolkit reads `LCSC` / `LCSC Part #`. Parts with
no MPN/LCSC at all: C19-C21, C40-C43, D1, D2, F1, IC1 (LCSC), IC4 (LCSC), U2 (LCSC),
U4-U8, Q1, R10, R11, R25-R28, all J connectors, P8/P9. Rename the field,
complete the part data, then regenerate everything after the fixes above.

### 30. Value / part-number mismatches — PARTLY DONE (2026-10-18: IC3 MPN BMP388 -> BMP390, C48 value/MPN fixed; C14-C16 "40u", L1 Isat, R10/R11 values still open)
- IC3: value BMP390, but Manufacturer_Part_Number = **BMP388**.
- C14-C16: value "40u" (copied from the A6983 typical-application COUT), but the MPN
  EFVM016ADA470M0545 indicates 47 uF and is a non-ceramic part. The A6983 internal
  compensation is specified with MLCC output caps; add/replace with ceramic
  (e.g. 2 x 22 uF 10 V 1206) and confirm the loop on the bench.
- L1 15 uH (SDRH0704 class): confirm Isat >= ~3.6 A for 3 A output; many 7 mm
  15 uH parts saturate at 2-3 A.
- R10/R11 "420": not an E24 value. With a blue LED at 3.3 V that gives ~1 mA
  (dim); use 470 for red and ~100-150 for blue, and give D1/D2 real parts.
- C3 "Part number" field says 10 V while the MPN is a different part; clean up the
  leftover Part 1/Part 2/Mouser fields on C3-C7, C33, C39, R16, R17.

### 31. BHI360 host interface bandwidth vs flight-control use — DONE (#38)
The BHI360 is on I2C1 through the PCA9306 (BBB I2C at 400 kHz), and its virtual
sensor stack outputs at most 800 Hz (DS000, virtual sensor ODR). ArduPilot usually runs
the gyro at >= 1 kHz. That may be acceptable for Plane at 400 Hz, but it is a
system risk with a single IMU and no redundancy. The BHI360 also supports an SPI
host (up to 50 MHz); SPI1 is still free on P9.28/P9.29/P9.31, but P9.30 (SPI1_D1)
is now used for LED1, which would block a later SPI host option.

### 32. No power LED, no battery monitoring — REVIEW
PWR-06 (power indication) and PWR-07 (battery voltage) are not implemented: D1/D2
are GPIO driven, and AIN0-6 only pass through. If a VBAT divider is added, the
AM335x ADC input range is 0-1.8 V (reference GNDA, P9.34), so size the divider for
<= 1.8 V at maximum battery voltage and add a clamp. PGOOD (#10) could drive a
power-good LED.

### Low

### 33. Schematic hygiene — PARTLY DONE (2026-10-18: P8.40 no-connect, labels, title blocks; 2026-10-22: multiple_net_names fixed; ERC 62 items, 40 are label_dangling on unused headers, 2 pin_to_pin (#FLG0106 is the only GND driver, shares the net with U2/U4 SDx), rest lib_symbol_mismatch)
ERC 2026-10-12: 198 items, of which 48 `label_dangling` (mostly labels on unused
header pins, acceptable), 13 `unconnected_wire_endpoint` (12 EEPROM stubs, #4,
and a 19 mm horizontal wire at (361.95, 166.37)), P8.40 `pin_not_connected` (add a
no-connect flag like the other unused pins), 9 `multiple_net_names` (GPIO2/UART_RX,
GPIO3/UART_TX, GND/STB, plus those in #6, #9, #25), 44 `endpoint_off_grid`, 72
`lib_symbol_mismatch`. Title blocks (title, revision, date) are empty on both
sheets.

### 34. A6983 VBIAS tied to GND — DONE (2026-10-18: VBIAS on BUCK_OUT)
With VBIAS on AGND the quiescent current from VIN is 20-70 uA. With VBIAS on the
5 V output it is 1-6 uA (A6983 electrical characteristics). The pin tolerates up to VIN+0.3 V;
tie it to BUCK_OUT. Minor, matters only for standby drain.

### 35. Magnetometer placement — REVIEW (BMM350 CRST part obsolete, #38)
- IC4 is 12.5 mm from the CR2032 holder BT1. The cell's steel can is
  ferromagnetic and causes a fixed hard-iron offset; calibrate with the cell
  fitted, or move the magnetometer or the cell further apart.
- C39 (CRST, 2.2 uF) is a Samsung CL10A 0603 X5R; Bosch recommends a low-ESL part
  (TDK CGB4B3X7R0J225K055AB) for the 400 mA CRST reset pulses.

### 36. Routing on the In1.Cu GND plane — OPEN
In1.Cu is the reference plane, but it carries three signal/power nets:
VBUS/SYS_5V (0.5 mm, along the bottom edge at y ~ 99.55, 0.2 mm from the board
edge, only to TP34), `/Power/+24V_IN` (0.5 mm near F1) and the DS1307 SQW net. Move
them to another layer (or delete the VBUS test-point trace) so the GND plane is
solid under the buck and the header. B.Cu signals reference In2, which is split
into +5V and +1V8.

### 37. Design rules do not enforce fab limits on outer layers — DONE (2026-10-18: outer track 0.10 mm, edge clearance 0.3 mm, zone clearance 0.2 mm)
Project rules have min track 0.01 mm, min clearance 0, copper-to-edge 0.00127 mm.
The `.kicad_dru` outer-layer track rule is also 0.01 mm. 0.10 mm tracks exist
(fine for JLC 4-layer, 0.09 mm), but nothing would catch a narrower one. Set outer
min track to 0.09-0.1 mm and copper-to-edge to >= 0.3 mm. The +5V, BUCK_OUT and
+1V8 zones have a 0.05 mm zone clearance; the 0.2 mm netclass clearance wins today,
but set the zones to 0.2 mm explicitly.

### 38. IMU swap to LSM6DSV16X (SPI1) + IIS2MDC (I2C1) — schematic DONE; PCB placed and cleared, routing OPEN (2026-10-18)
Reason: no ArduPilot driver for the BHI360, the BMM350 was hidden behind it, 800 Hz
output cap, and BMM350/BHI360/ICM parts are broker-only. Both new parts are stocked by
authorized distributors (2026-10-12) and have ArduPilot drivers (LSM6DSV, IIS2MDC).

Schematic (root sheet):
- Removed: U2 BHI360, IC4 BMM350, U4 TLV75518 (+1V8 LDO), U5 PCA9306, U7/U8
  SN74LVC1T45, R16/R17/R20/R21/R27/R28, C3-C7, C19-C21, C33, C39-C43, TP17, TP18,
  TP22, and the DNP leftovers R14/R15/D4. The +1V8 rail no longer exists.
- Added U9 LSM6DSV16X (LGA-14L 2.5x3, `Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y`,
  MPN LSM6DSV16XTR): VDD/VDDIO +3V3 with C44/C45 100n; SPI1 4-wire, CS0 P9.28, SDO/SA0
  -> D0 P9.29 (MISO), SDA -> D1 P9.30 (MOSI), SCL -> SCLK P9.31; INT1 -> P9.14,
  INT2 -> P9.16 (TP23/TP24); SDx/SCx to GND (Qvar/analog hub unused, per DS13510
  Table 2); OCS_Aux/SDO_Aux left open.
- Added U10 IIS2MDC (LGA-12 2x2, `Package_LGA:LGA-12_2x2mm_P0.5mm`, MPN IIS2MDCTR,
  symbol copied from the pin-compatible LIS2MDL): Vdd/Vdd_IO +3V3 with C46/C47 100n;
  CS to +3V3 (I2C mode); SCL/SDA on I2C1; C1 pin -> C48 220n (needs low ESR, at
  pins 5/6); DRDY -> P9.15 (TP16). Address 0x1E (fixed).
- BMP390 (IC3) VDD/VDDIO/CSB moved from +1V8 to +3V3; it shares I2C1 with the
  IIS2MDC, pulled up by the existing R25/R26 4k7 to +3V3. Addresses: 0x1E mag, 0x76 baro.
- LED1 feed (R11/D2) moved from P9.30 to P9.23 (GPIO1_17) because P9.30 is now SPI1 D1.
- Symbols LSM6DSV16X and IIS2MDC added to `Cape_lib.kicad_sym`.

PCB (applied headlessly, same as Update PCB from Schematic):
- Removed footprints of the deleted parts and their orphaned copper (tracks and vias
  left dangling); the former +1V8 copper and In2 zone were renamed to +3V3.
- U9, U10, C44-C48 are staged **below the board outline** (x 0-35, y 108), not
  placed. U9/U10 have a 0.127 mm footprint clearance (0.5 mm pitch LGA vs the 0.2 mm
  netclass rule).
- To do in KiCad: refill zones, place U9 near the board centre / away from L1, BT1 and
  BZ1 (U10 the same, ideally >= 15 mm from the CR2032 and the servo power traces),
  route 40 unconnected items (SPI1, I2C1, INT/DRDY, LED1 to P9.23, decoupling), and
  delete the remaining short +3V3 stub at (158.54, 81.51). The +3V3 In2 zone (old +1V8
  pour) is only connected once a +3V3 via lands in it.
- DRC after the change: 0 clearance/shorts, 40 unconnected (routing), 1 dangling stub,
  2 isolated copper (the old #18 GND island), parity only the pre-existing #13 items.

Firmware/DT follow-ups: SPI1 pinmux (P9.28 cs0, P9.29 d0, P9.30 d1, P9.31 sclk, mode 3);
the LSM6DSV16X supports SPI mode 0 or 3, up to 10 MHz (D0 = MISO with the default McSPI pin direction). I2C1 pinmux P9.17/P9.18
mode 2; INT1/INT2/DRDY GPIOs (P9.14 GPIO1_18, P9.16 GPIO1_19, P9.15 GPIO1_16); LED1 is
now GPIO1_17. ArduPilot Linux hwdef: IMU LSM6DSV on SPI1.0, compass IIS2MDC and
baro BMP390 on I2C1. Fallback IMU: BMI270 (Mouser stock), different footprint (LGA-14
2.5x3, different pinout) — needs a symbol/footprint change, not a drop-in.

---

## Verified correct (no action)

- P9/P8 assignments match SRM Tables 10/11: UART2 (P9.21/22), DCAN1 (P9.24/26),
  SPI1 (P9.28/29/31), I2C1/I2C2 (P9.17-20), MMC1 (P8.3-25), LCD (P8.26-38),
  AIN0-6 (P9.33/35/36/37/38/39/40), GPIO numbering convention throughout.
- I2C1 1.8 V side: BHI360 + BMP390 + U5 A-side, 4k7 pull-ups to +1V8; 3.3 V side
  to P9.17/18 with 4k7 to +3V3; PCA9306 bias (VREF1 = +1V8, VREF2 = EN via R27
  200k to +3V3, C19 100n). Every device's abs max is respected.
- BHI360 aux I2C (M2, ASDX/ASCX) to BMM350 on +1V8 with 4k7 pull-ups (R16/R17);
  BHI360 HCSB high (I2C), HSDO low (address 0x28), RESV1/RESV2 and OCSB open, VREG
  220 nF (C33), BMM350 ADSEL low (0x14), BYPASS to GND, CRST 2.2 uF, VDD 1.8 V
  within its 1.72-1.98 V range.
- BMP390 pinout (VDDIO/SCK/SDI/SDO/CSB/INT/VDD) matches the datasheet; CSB high
  selects I2C.
- Decoupling: a cap sits within ~2-3 mm of every power pin on U2, IC3, IC4, U4,
  IC2 and IC1.
- A6983 setup follows the datasheet typical application: RFILT 100 ohm + 1 uF on
  VINLDO, 1 uF VCC, 100 nF BOOT, FSW 3.3k to GND = 500 kHz with 15 uH, PGOOD 1M.
  Exposed pad footprint (0.5 x 0.9 mm) matches the ST recommended land pattern.
- Ideal diode: LTC4412 VIN = BUCK_OUT, SENSE = +5V, CTL low, Q1 drain on BUCK_OUT;
  orientation correct.
- DS1307 with 32.768 kHz FC-135 (12.5 pF, as required), CR2032 on VBAT with C18.
- TLV75518 +1V8 LDO from +3V3 with 1 uF in/out; +3V3 comes from BBB P9.3/4
  (load well under the 250 mA budget).
- Board outline: 86.36 x 54.61 mm with the RJ45 and barrel-jack notches; mounting
  holes at the BBB positions (66.04 / 48.26 / 41.91 mm spacing); P8-P9 pitch
  48.25 mm. The PCB is now synced with the schematic (U7/U8, R28, C40-C43 placed and
  routed).

---

## Tooling state / caveats

- Edits were applied to the repo files directly while KiCad held the project
  open. Use **File -> Revert** in KiCad before saving; otherwise the in-memory copy
  can overwrite these changes.
- 2026-10-12: the PCB has since been synced from the schematic (DRC parity shows
  only the #13 footprint-field items). The 2026-10-12 review changed no design
  files, only this document.
- Backups of each step are under `~/.hermes/cache/scratch/bbcape/`
  (`pre-levelshift/`, `pre-silk/`, `pre-tp-silk/`, `pre-designator/`,
  `pre-pkg-silk/`, `pre-hide-J/`, `pre-buzzer/`, `pre-ledmove2/`). The 2026-10-12
  review outputs (netlist, ERC/DRC reports, layer renders) are in
  `~/sky-kicad/rev1012/`.
- ERC 2026-10-12: errors are 48 label_dangling, 6 power_pin_not_driven, 3
  pin_not_connected, 1 pin_not_driven (U1 A2), 1 hier_label_mismatch (PGOOD); see
  #33 for the warnings.
