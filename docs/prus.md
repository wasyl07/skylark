# PRU usage and servo/ESC output firmware design

Status: design (not implemented). Roadmap: Phase 3.1 / 4.2 in [ROADMAP.md](ROADMAP.md).
Requirements covered: OUT-01..OUT-06 in [FUNCTIONS.md](FUNCTIONS.md).

## 1. Summary

| Core | Role | Notes |
|------|------|-------|
| PRU1 | Servo + ESC PWM (6 outputs) | Hard-wired by the cape: all PWM nets go to PRU1 R30 pins |
| PRU0 | Unassigned (spare) | No cape signal reaches a PRU0 pin |

CAN does not use a PRU. It runs on the hardware DCAN1 controller (P9.24/P9.26, TCAN3413,
`can0`, see [buildroot.md](buildroot.md)). The old plan for a bit-banged CAN controller on
PRU1 is dropped.

ArduPilot talks to the PRU the way it already does on BBBmini/BeagleBone Blue: it maps PRU1
data RAM through `/dev/mem` and writes pulse widths into the `RCOutput_AioPRU` memory layout.
The Skylark firmware keeps that layout and adds a failsafe/heartbeat block after it.

## 2. Servo pins go to PRU1, not PRU0

Checked against the cape netlist (`kicad-cli sch export netlist`, BeagleBone-cape.kicad_sch)
and the AM335x pinmux table (mode 5 of the `lcd_data` pads):

| ArduPilot output | Slot | Net | Connector | Header | Pad (conf_) | Mode 5 signal | SYSBOOT |
|------------------|------|-----|-----------|--------|-------------|---------------|---------|
| SERVO1 | 0 | SERVO_0 | J1  | P8_39 | 0x0B8 lcd_data6 | pr1_pru1_pru_r30_6 | 6 |
| SERVO2 | 1 | SERVO_1 | J3  | P8_42 | 0x0B4 lcd_data5 | pr1_pru1_pru_r30_5 | 5 |
| SERVO3 | 2 | SERVO_2 | J2  | P8_41 | 0x0B0 lcd_data4 | pr1_pru1_pru_r30_4 | 4 |
| SERVO4 | 3 | SERVO_3 | J4  | P8_44 | 0x0AC lcd_data3 | pr1_pru1_pru_r30_3 | 3 |
| SERVO5 | 4 | MOTOR_L | J9  | P8_43 | 0x0A8 lcd_data2 | pr1_pru1_pru_r30_2 | 2 |
| SERVO6 | 5 | MOTOR_R | J10 | P8_45 | 0x0A0 lcd_data0 | pr1_pru1_pru_r30_0 | 0 |

- These pads have no PRU0 function. PRU0 R30 outputs on the BBB headers are P9_31/29/30/28/27/25
  and P8_11/12. PRU0 could reach these pins only through the GPIO2 module over the OCP bus,
  which adds latency and jitter. That is not worth it, so the design uses PRU1. Moving to PRU0
  would need a cape respin.
- Pin to connector order is not monotonic: SERVO_1 goes to J3 and SERVO_2 to J2. The slot order
  above follows the net names. Check that this matches the silkscreen before writing the docs for
  the airframe setup.
- `docker/am335x-pru0-fw/` is TI's PRU0 GPIO-toggle example. It is a toolchain smoke test, not
  servo firmware, and it toggles PRU0 R30, which does not reach any cape output.

## 3. Communication with ArduPilot (existing mechanism)

ArduPilot already has `AP_HAL_Linux/RCOutput_AioPRU` (used by BBBmini, BeagleBone Blue and
PocketPilot). On AM335x it uses PRU1:

- data RAM at `0x4A302000` (PRU1 DRAM, local address 0x0000 on PRU1),
- control at `0x4A324000` and IRAM at `0x4A338000` (PRU1),
- 200 MHz ticks (5 ns), 12 channel slots, `{time_high, time_t}` per channel.

The Skylark firmware implements that same data-RAM layout, so ArduPilot keeps the same code path
and access method (`/dev/mem` mmap; `CONFIG_STRICT_DEVMEM` is off in our kernel). The differences
from stock AioPRU:

1. **Firmware is loaded by Linux remoteproc at boot, not by ArduPilot.** Stock AioPRU resets the
   PRU, copies a pasm binary into IRAM and starts it. With a new ArduPilot hwdef define
   (`AP_HAL_LINUX_AIOPRU_EXTERNAL_FW`), ArduPilot maps only the data RAM. It then checks the
   firmware magic and ABI version and refuses to start if the PRU is not running.
2. **Heartbeat + failsafe.** The firmware drives outputs to failsafe values when the host stops
   updating (OUT-06). Before the host ever writes, all outputs stay low (OUT-05).
3. **Commit mode (optional).** A sequence counter makes a `cork()/push()` group of channels take
   effect in the same PWM frame.

rpmsg was considered and rejected. ArduPilot has no rpmsg RCOutput backend, it adds a kernel
round trip per update, and shared memory is enough for a few 32-bit values per frame.

### 3.1 Shared memory ABI v1 (PRU1 data RAM)

ARM physical address = `0x4A302000 + offset`. PRU1 local address = `offset`. All fields are
little-endian `uint32_t`. Times are IEP ticks (5 ns).

AioPRU-compatible block (layout unchanged):

| Offset | Field | Writer | Meaning |
|--------|-------|--------|---------|
| 0x000 | `channelenable` | host | bit n = slot n enabled; disabled slot = output low |
| 0x004 + 8n | `time_high[n]` | host | pulse width, n = 0..11 (0 = no pulse) |
| 0x008 + 8n | `time_t[n]` | host | period (e.g. 4 000 000 = 50 Hz, 500 000 = 400 Hz) |
| 0x064 | `time` | PRU | current IEP count (AioPRU `TIME_OFFSET`) |
| 0x068 | `max_cycle_time` | PRU | worst main-loop iteration seen, ticks (AioPRU `MAX_CYCLE_TIME_OFFSET`) |

Skylark extension block (new):

| Offset | Field | Writer | Meaning |
|--------|-------|--------|---------|
| 0x100 | `magic` | PRU | `0x4C4B5953` ("SYKL"), written last during init |
| 0x104 | `abi_version` | PRU | 1 |
| 0x108 | `fw_version` | PRU | `major<<16 \| minor<<8 \| patch` |
| 0x10C | `status` | PRU | bit0 RUNNING, bit1 FAILSAFE, bit2 HOST_SEEN, bit3 COMMIT_MODE |
| 0x110 | `control` | host | bit0 COMMIT_MODE, bit1 FORCE_FAILSAFE (test only) |
| 0x114 | `heartbeat` | host | incremented on every `push()` / uncorked `write()` |
| 0x118 | `timeout_ticks` | host | failsafe timeout; 0 = default 100 000 000 (500 ms) |
| 0x11C | `commit_seq` | host | COMMIT_MODE: bump after writing `time_high[]` |
| 0x120 | `applied_seq` | PRU | last `commit_seq` taken into the shadow table |
| 0x124 | `failsafe_count` | PRU | number of failsafe entries since start |
| 0x128 | `slot_mask` | PRU | slots that have a pin on this board (0x3F) |
| 0x130 + 4n | `failsafe_high[n]` | host | pulse width in failsafe, n = 0..11 (0 = output low) |

Rules:
- Host writes are single 32-bit stores. Order: write values, `__sync_synchronize()`, then bump
  `heartbeat` / `commit_seq`.
- The PRU never writes host-owned fields and the host never writes PRU-owned fields.
- The ABI header (`skylark_pru_pwm_abi.h`) is the single source and is copied verbatim into the
  ArduPilot fork. Bump `abi_version` on any layout change.

## 4. PRU1 firmware design

### 4.1 Build and load

- C, TI PRU CGT 2.3.3 and pru-software-support 6.0.1. Both are already Buildroot packages
  (`host-ti-cgt-pru`, `pru-software-support`). Buildroot package `skylark-pru-firmware` in
  `br2-skylark/package/` builds the firmware. The docker container stays for standalone builds.
- Output `/lib/firmware/skylark-pru1-pwm.fw` (ELF with an empty remoteproc resource table, no
  rpmsg/virtio).
- Linux: `pru_rproc` (+ `pruss`, `pruss_intc`), all modules already in `linux.fragment`. The
  overlay sets `firmware-name = "skylark-pru1-pwm.fw"` on `&pru1`.
- `skylark-pru.service` (systemd, oneshot, RemainAfterExit) does the following:
  1. Finds the remoteproc whose `name` is `4a338000.pru`. Don't hard-code the `remoteprocN`
     number.
  2. Writes the firmware name and runs `echo start > state`.
  3. Waits for `state == running` and for the magic in data RAM.
  4. Runs before `ardupilot.service` (`Before=`, ArduPilot `Requires=` it).
  5. `ExecStop` stops the PRU only after ArduPilot is stopped.

Source layout (planned):
```
br2-skylark/package/skylark-pru-firmware/
├── Config.in
├── skylark-pru-firmware.mk
└── src/
    ├── Makefile
    ├── AM335x_PRU.cmd                 # linker map (from TI package)
    ├── include/skylark_pru_pwm_abi.h  # shared ABI (copied into ArduPilot)
    ├── pru1-pwm/
    │   ├── main.c                     # init, main loop, R30 write
    │   ├── pwm_core.c/.h              # scheduler + failsafe logic, no hardware access
    │   ├── board_skylark.h            # slot -> R30 bit table
    │   └── resource_table.c           # empty rsc table for remoteproc
    ├── tools/skylark-pwm.c            # target CLI: status/set/failsafe test without ArduPilot
    └── tests/test_pwm_core.c          # host unit tests of pwm_core with simulated time
```

### 4.2 Time base

- IEP counter (200 MHz, 32-bit, wraps every 21.47 s). All comparisons use wrap-safe
  `(int32_t)(now - deadline) >= 0`.
- The IEP is shared with PRU0. Firmware enables it only if it isn't already running
  (`GLB_CFG.CNT_ENABLE`, increment 1) and never resets the count.

### 4.3 Main loop (single polled loop, no interrupts)

Per slot n with a pin (`slot_mask`), the PRU keeps a private shadow
`{period, high, rise_at, pulse_on}` in PRU-local registers/RAM:

```
loop:
  now = IEP.COUNT
  for each slot n in slot_mask:
     if pulse_on[n] and now - rise_at[n] >= high[n]:   clear bit (falling edge)
     if now - rise_at[n] >= period[n]:                 period start:
          rise_at[n] += period[n]                      (no drift; resync if > 1 period late)
          latch period/high from shared RAM (or commit shadow / failsafe table)
          if enabled and high > 0: set bit, pulse_on = 1
  write R30 once (set/clear mask applied together)
  every ~1 ms: heartbeat / failsafe check, publish time, max_cycle_time, status
```

- **Glitch-free updates:** new `time_high`/`time_t` take effect only at a period start, so there
  are no runt or stretched pulses. `high` is clamped to `period - 2 µs`.
- **Accuracy/jitter:** edges are checked once per loop. With six slots the estimate is about
  60-100 cycles per loop, so worst-case edge error is about 0.5 µs (OUT-04 needs < 1 µs). The PRU
  has no caches, no interrupts and isn't affected by ARM load, so this is a hard bound. The
  firmware reports the measured `max_cycle_time` to confirm it.
- **Rates:** per-slot period, so servos can run 50 Hz and motors up to 400 Hz (OUT-03). Range
  checked: period 2.5 ms to 40 ms (25-400 Hz), pulse 0 or 400-2600 µs (OUT-02 extended range).
- **Commit mode:** when `control.COMMIT_MODE` is set, `time_high[]` is copied into a shadow table
  only when `commit_seq != applied_seq`. Each slot then latches from the shadow at its next period
  start, so channels updated in one `push()` never mix old and new frames. Without commit mode
  the firmware behaves like stock AioPRU.

### 4.4 Arming and failsafe (OUT-05, OUT-06)

State machine:

```
 RESET --(init done)--> WAIT_HOST --(first heartbeat change)--> RUN
                                                                |  ^
                                               heartbeat stale  |  | heartbeat changes
                                               > timeout_ticks  v  |
                                                              FAILSAFE
```

- WAIT_HOST: R30 bits for every slot held low, whatever `channelenable` says.
- RUN: normal output.
- FAILSAFE: each enabled slot outputs `failsafe_high[n]` at its own period. 0 means steady low.
  `status.FAILSAFE` is set and `failsafe_count` is incremented. The firmware returns to RUN when
  the heartbeat changes again (ArduPilot restarted or recovered). Motor safety while disarmed is
  ArduPilot's job (it outputs min throttle).
- Default `failsafe_high` = 0 for all slots, so pulses stop. ArduPilot fills real values through
  `set_failsafe_pwm()` (`SERVOx_TRIM` for surfaces, `SERVOx_MIN` or 0 for motors). See open
  question O-2.
- PRU halted (remoteproc stopped or crashed): R30 holds its last value, which may be a high level.
  `skylark-pru.service` stop is therefore ordered after ArduPilot. See risk R-4.

### 4.5 Pin mux / device tree (overlay `skylark-cape.dts`)

- Mux the six pads to mode 5, output, pull-down, receiver off: value `0x05`
  (`0x0A0, 0x0A8, 0x0AC, 0x0B0, 0x0B4, 0x0B8`).
- Apply the group as a pinmux **hog** on `&am33xx_pinmux` so it is set when the pinctrl driver
  probes. That is earlier than `pru_rproc`, which is a module.
- Disable `&tda19988` (HDMI encoder on I2C0) as well as `&lcdc`. Its `pinctrl-0` claims
  `lcd_data0..15` in mode 0, so leaving it enabled conflicts with the hog. The current overlay
  disables only `&lcdc`.
- `&pru1 { firmware-name = "skylark-pru1-pwm.fw"; };`. `&pruss_tm` is already `okay` in the BBB
  base tree (checked in the built DTB).

## 5. ArduPilot side (fork in `ardupilot/`)

- New board `libraries/AP_HAL_Linux/hwdef/skylark/hwdef.dat` and subtype
  `HAL_BOARD_SUBTYPE_LINUX_SKYLARK`. `HAL_Linux_Class.cpp` selects `RCOutput_AioPRU` for it (same
  addresses as BBBmini/BLUE: PRU1).
- `RCOutput_AioPRU` changes, behind `AP_HAL_LINUX_AIOPRU_EXTERNAL_FW`:
  - `init()`: map only data RAM, check `magic`/`abi_version`/`status.RUNNING`, panic with a clear
    message otherwise; no IRAM load, no ctrl write.
  - `push()` and uncorked `write()`: bump `heartbeat` (and `commit_seq` in commit mode).
  - `set_failsafe_pwm(chmask, us)`: write `failsafe_high[]`.
  - Fix the existing bug in `disable_ch()`: `channelenable &= !(1U << ch)` clears all channels
    and must be `&= ~(1U << ch)`.
- Channels 1-6 map to slots 0-5 (table in section 2). Slots 6-11 accept writes but have no pin.

## 6. Verification plan

| Check | Method | Requirement |
|-------|--------|-------------|
| Host unit tests of `pwm_core` | gcc on PC, simulated IEP, wrap at 2^32, period/width change mid-frame, failsafe entry/exit | — |
| Pins muxed | `/sys/kernel/debug/pinctrl/44e10800.pinmux-pinctrl-single/pins` shows mode 5 on the six pads | — |
| No pulses during boot | Logic analyser on all 6 outputs from power-on to ArduPilot start | OUT-05 |
| Boot mode unaffected | Boot 10x from eMMC and SD with servos and ESCs plugged in and powered (SYSBOOT pins) | R-1 |
| Width accuracy | `skylark-pwm set` 1000/1500/2000 µs, measure on scope | OUT-02 |
| Rates | 50 Hz on SERVO1-4, 400 Hz on SERVO5-6 at the same time | OUT-03 |
| Jitter | Scope persistence 60 s with `stress-ng --cpu 1 --io 2 --vm 1` | OUT-04 |
| Failsafe | `kill -STOP` ArduPilot, then `kill -CONT`; measure time to failsafe and recovery | OUT-06 |
| All outputs | Each output drives a reference servo / ESC | OUT-01, OUT-08 |

## 7. Risks and open questions

- **R-1 SYSBOOT strapping.** `lcd_data0..15` are the AM335x SYSBOOT pins, latched at power-on
  reset. All six outputs are SYSBOOT 0, 2, 3, 4, 5, 6, and SYSBOOT[4:0] selects the boot device
  order. An ESC or servo with a pull-up or low input impedance, powered before the BBB, can change
  the boot order. BBBmini uses the same pins and works in practice, but test it (section 6). A
  cape fix would add series resistors and/or buffers that are tri-stated until boot finishes.
- **R-2 Pin state before the overlay.** Between reset and the pinctrl hog, the pads are in mode 0
  (LCD) with the LCDC disabled. Expected: no pulses, possibly floating. Verify with the boot
  logic-analyser test.
- **R-3 HDMI pinctrl conflict.** Must disable `tda19988` (section 4.5) or the hog fails with "pin
  already requested".
- **R-4 Halted PRU latches R30.** Order the service stops and never stop the PRU under a running
  ArduPilot. A future option is a second-stage watchdog on PRU0 that forces the pads back to GPIO
  input (needs pinmux access from the PRU, not planned).
### Pending decisions (open, awaiting answers)

- [ ] **O-1 ESC protocol.** Is plain PWM (50-490 Hz) / OneShot125 enough for v1? DShot would
  need a separate bit-timing mode and is currently out of scope.
  Answer: _TBD_
- [ ] **O-2 Failsafe values per output.** Control surfaces = trim, and motors = no pulses
  (output low) or `SERVOx_MIN`?
  Answer: _TBD_
- [ ] **O-3 Connector order.** Net SERVO_1 goes to J3 and SERVO_2 to J2. Intended, or should it
  be swapped in software / on the next cape revision?
  Answer: _TBD_

### Notes

- **O-4** PRU0 is free. Possible future uses: RC input (needs a PRU0 pin, e.g. P9_25/P9_27 R31,
  cape change), ADC sampling, or the R-4 watchdog.

## 8. References

- AM335x TRM (SPRUH73), chapter 4 PRU-ICSS; chapter 9 control module (pad conf registers).
- AM335x datasheet (SPRS717) pin attributes / mux modes.
- ArduPilot `libraries/AP_HAL_Linux/RCOutput_AioPRU.{h,cpp}`,
  `Tools/Linux_HAL_Essentials/pru/aiopru/RcAioPRU.p` (BBBMINI uses the same PRU1 R30 bits).
- TI PRU software support package (resource table, `pru_iep.h`, `pru_cfg.h`).
