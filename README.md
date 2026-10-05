# skylark
Drone control board based on AM335 BeagleBone Black and Ardupilot

## Repository layout

- `BeagleBone-cape/` - KiCad project of the Skylark cape
- `buildroot-2025.02.15/` - Linux image (U-Boot, kernel, rootfs), see [docs/buildroot.md](docs/buildroot.md)
- `ardupilot/` - ArduPilot (submodule)
- `docker/` - PRU toolchain container and PRU firmware
- `docs/` - documentation
  - [buildroot.md](docs/buildroot.md) - building, flashing (SD / eMMC over network), serial console, CAN, RTC/NTP
  - [prus.md](docs/prus.md) - PRU usage

## Quick reference

- Serial console: UART4, P9.11 (RX) / P9.13 (TX), 115200 8N1, 3.3 V
- Network: 192.168.1.12 (static), SSH as root
- CAN: `can0` (DCAN1, P9.24/P9.26), 1 Mbit/s, up at boot
- RTC: DS1307 on I2C2 (`/dev/rtc1`), synced from NTP when online
