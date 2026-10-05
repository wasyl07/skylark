# skylark
Drone control board based on AM335 BeagleBone Black and Ardupilot

## Repository layout

- `BeagleBone-cape/` - KiCad project of the Skylark cape
- `br2-skylark/` - Buildroot external tree: A/B (RAUC) Linux image with systemd, see [docs/buildroot.md](docs/buildroot.md)
- `buildroot-2025.02.15/` - Buildroot itself (plus the legacy single-slot config, [docs/buildroot-legacy.md](docs/buildroot-legacy.md))
- `scripts/` - image checks (`verify-image.sh`, `check-defconfig.sh`)
- `ardupilot/` - ArduPilot (submodule)
- `docker/` - PRU toolchain container and PRU firmware
- `docs/` - documentation
  - [buildroot.md](docs/buildroot.md) - building, A/B updates, services, flashing, serial console, CAN, RTC/NTP
  - [FUNCTIONS.md](docs/FUNCTIONS.md) - requirements
  - [prus.md](docs/prus.md) - PRU usage

## Quick start

```sh
make setup && make                 # -> output/images/sdcard.img, update.raucb
sh scripts/verify-image.sh
```

## Quick reference

- Serial console: UART4, P9.11 (RX) / P9.13 (TX), 115200 8N1, 3.3 V
- Network: DHCP, `skylark.local` (mDNS), SSH as root
- Updates: `rauc install update.raucb` (A/B slots, automatic fallback after 3 failed boots)
- CAN: `can0` (DCAN1, P9.24/P9.26), 1 Mbit/s, up at boot
- RTC: DS1307 on I2C2 (`/dev/rtc1`), synced from NTP when online
