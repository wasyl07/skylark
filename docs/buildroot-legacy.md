# Legacy single-slot image (fallback)

> The primary image is the A/B (RAUC, systemd) image from `br2-skylark/`, see
> [buildroot.md](buildroot.md). This single-slot BusyBox-init image is kept as a
> fallback / reference only.

The Linux image (MLO, U-Boot, kernel, device tree overlay, rootfs) is built with
Buildroot in `buildroot-2025.02.15/` using `configs/beaglebone_defconfig`.
All Skylark-specific files live in:

| Path (relative to `buildroot-2025.02.15/`) | Purpose |
|---|---|
| `configs/beaglebone_defconfig` | Buildroot configuration |
| `board/beagleboard/beaglebone/skylark-overlay.dts` | Cape device tree overlay (CAN1, UART4 console, DS1307, HDMI/CAN0 off) |
| `board/beagleboard/beaglebone/uboot-console-uart4.fragment` | U-Boot/SPL console on UART4 |
| `board/beagleboard/beaglebone/patches/uboot/` | U-Boot patches (UART4 `stdout-path`) |
| `board/beagleboard/beaglebone/busybox-ntp.fragment` | BusyBox `ntpd` + `timeout` |
| `board/beagleboard/beaglebone/extlinux.conf` | Boot entry (kernel args, overlay) |
| `board/beagleboard/beaglebone/genimage.cfg` | SD/eMMC image layout |
| `board/beagleboard/beaglebone/post-build.sh` | Copies extlinux, DTB and overlay to `output/images` |
| `overlays/` | Rootfs overlay (init scripts, network, CAN and time-sync config) |

## Building

```sh
cd buildroot-2025.02.15
make beaglebone_defconfig     # only on a fresh checkout / to reset .config
make
```

Result: `output/images/sdcard.img` (FAT boot partition + 512 MB ext4 rootfs).

After changing kernel/overlay or U-Boot inputs, rebuild the affected package:

```sh
make linux-rebuild all        # overlay .dts, kernel config
make uboot-dirclean all       # U-Boot fragment or patches
make busybox-reconfigure all  # BusyBox fragment
```

The root password is not part of the committed defconfig; set
`BR2_TARGET_GENERIC_ROOT_PASSWD` locally (`make menuconfig` -> System
configuration) or use SSH keys.

## Boot flow

1. ROM loads `MLO` (SPL) from the FAT partition of eMMC, or of the SD card when
   the S2 button is held at power-on.
2. U-Boot (distro boot) scans `mmc0` (SD) then `mmc1` (eMMC) for
   `/extlinux/extlinux.conf`.
3. extlinux loads `zImage`, `am335x-boneblack.dtb` and applies
   `skylark-overlay.dtbo`.
4. The kernel mounts `root=PARTUUID=534b594c-02`. The image has a fixed MBR
   disk signature (`0x534b594c`, set in `genimage.cfg`), so the same image works
   from SD and eMMC.

`uEnv.txt` is still installed but is not used by the default boot command.

Note: if both SD and eMMC carry this image, the root PARTUUID is identical on
both; remove/disable the one you don't want to boot (see below).

## Serial console (UART4)

The boot console (SPL, U-Boot, kernel, login) is on **UART4**, not on the J1
debug header:

| Signal | Header pin | Adapter |
|---|---|---|
| UART4 RX | P9.11 | adapter TX |
| UART4 TX | P9.13 | adapter RX |
| GND | P9.1 / P9.2 | GND |

115200 8N1, 3.3 V levels only. Linux device: `/dev/ttyS4`.
P9.11/P9.13 are unused on the cape (UART1 pins carry CAN1, UART2 pins go to the
MAVLink connector J13, UART5 shares pins with HDMI/eMMC).

The AM335x boot ROM still uses UART0 (J1) for its own UART boot fallback, so
keep J1 for recovering a board with a broken MLO.

Configuration:
- SPL/U-Boot: `CONFIG_CONS_INDEX=5` (pinmux and clocks of UART4), U-Boot DT
  `stdout-path = &uart4` (patch `0001-am335x-boneblack-console-on-uart4.patch`).
- Kernel: `console=ttyS4,115200n8` in `extlinux.conf`; the overlay enables
  `&uart4` with pinmux 0x070=0x26 (RX), 0x074=0x0e (TX).
- Login: `getty` on `console` (inittab), follows the kernel console.

Magic SysRq over serial is enabled: a serial BREAK followed by `b` resets a
hung board.

## CAN

CAN1 (DCAN1) is on P9.24 (RX) / P9.26 (TX) to the cape transceiver (IC2).
`/etc/init.d/S41can` brings it up at boot. Settings in `/etc/default/can`:

```sh
CAN_IFACES="can0"
CAN_BITRATE=1000000     # DroneCAN default
CAN_TXQUEUELEN=100      # default 10 overflows on bursts (ENOBUFS)
CAN_RESTART_MS=100      # auto recovery from bus-off
```

Verified against a PEAK PCAN-USB at 1 Mbit/s in both directions with standard
and extended IDs, no bus errors.

Quick test (PC side needs root):

```sh
# PC
sudo ip link set can0 up type can bitrate 1000000 restart-ms 100
candump can0
# board
cansend can0 123#DEADBEEF
```

## RTC and network time

The cape has a DS1307 (U3) on I2C2 (P9.19/P9.20) at address 0x68, declared in
the overlay (`dallas,ds1307`), registered as `/dev/rtc1` (`rtc0` is the
AM335x internal RTC, which is not battery backed on the BBB).

- `/etc/init.d/S05rtc` sets the system clock from the DS1307 at boot (skipped
  when the RTC holds no valid time), and on shutdown writes the system time back
  if it was NTP-synced during this boot.
- `/etc/init.d/S45timesync` runs `/usr/sbin/rtc-ntp-sync`. When a default
  route exists it queries NTP (`ntpd -q`), sets the system clock, and rewrites
  the DS1307 only when it differs from NTP by more than `MAX_DRIFT` seconds or
  is invalid. Every update is logged to syslog with tag `rtc-ntp-sync`.
- Settings in `/etc/default/timesync`:

```sh
RTC_NAME="rtc-ds1307"
NTP_SERVERS="0.pool.ntp.org 1.pool.ntp.org time.google.com"
MAX_DRIFT=2          # seconds
SYNC_INTERVAL=3600   # after a successful sync
RETRY_INTERVAL=60    # while offline
NTP_TIMEOUT=15
```

One-shot sync: `rtc-ntp-sync --once`.

DNS: `eth0` is static (192.168.1.12/24, gw 192.168.1.1);
`/etc/network/interfaces` writes `nameserver 192.168.1.1` to
`/etc/resolv.conf` when the interface comes up.

### Known hardware issue (cape rev 1)

The DS1307 responds on I2C and accepts writes, but its oscillator stops after a
few seconds (the RTC does not advance). Likely causes: VBAT (BT1, TP25) missing
or below ~2 V, or Y1 not a 12.5 pF 32.768 kHz crystal. Also note the I2C2
pull-ups R22/R23 go to +5 V while the AM335x I2C pins are 3.3 V only; they
should be pulled to 3.3 V. The cape EEPROM (U1, CAT24C256) does not answer at
0x54-0x57.

Until fixed, the time is only correct after NTP sync.

## Flashing

### SD card (from the PC)

```sh
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Boot from SD by holding S2 at power-on.

### eMMC over the network

The board runs dropbear on 192.168.1.12. Install an SSH key first
(`/root/.ssh/authorized_keys`). The target device must not hold the running
rootfs: flash the eMMC while booted from SD, or the SD while booted from eMMC.

```sh
cd buildroot-2025.02.15/output/images
gzip -1 -c sdcard.img | ssh root@192.168.1.12 \
    "gunzip -c | dd of=/dev/mmcblk1 bs=1M conv=fsync"
# verify
ssh root@192.168.1.12 "head -c $(stat -c%s sdcard.img) /dev/mmcblk1 | md5sum"
md5sum sdcard.img
```

Linux device names: `mmcblk0` = SD card, `mmcblk1` = eMMC.

When only the boot partition changed (kernel, DTB, overlay, extlinux, MLO,
U-Boot), it can be updated on the running medium by writing the first
32769 sectors (MBR + boot partition) of the image:

```sh
head -c $((32769*512)) sdcard.img | ssh root@192.168.1.12 \
    "umount /dev/mmcblk1p1 2>/dev/null; dd of=/dev/mmcblk1 bs=512 conv=fsync"
```

To make U-Boot skip a medium (e.g. keep the SD card as a fallback but boot
eMMC), rename its `/extlinux/extlinux.conf`:

```sh
mount /dev/mmcblk0p1 /mnt && mv /mnt/extlinux/extlinux.conf /mnt/extlinux/extlinux.conf.disabled && umount /mnt
```

Booting the SD then still works by restoring the file, or manually from the
U-Boot prompt (stop autoboot on the UART4 console):

```
load mmc 0:1 ${loadaddr} zImage
load mmc 0:1 ${fdtaddr} am335x-boneblack.dtb
load mmc 0:1 ${fdtoverlay_addr_r} skylark-overlay.dtbo
fdt addr ${fdtaddr}; fdt resize 65536; fdt apply ${fdtoverlay_addr_r}
setenv bootargs console=ttyS4,115200n8 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
bootz ${loadaddr} - ${fdtaddr}
```

(use `mmc 1:1` / `mmcblk1p2` for eMMC).
