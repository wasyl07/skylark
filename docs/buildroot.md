# Skylark Linux image (Buildroot, A/B updates)

The primary image is built from the Buildroot external tree `br2-skylark/`
(defconfig `skylark_bbb_defconfig`) on top of the unmodified Buildroot in
`buildroot-2025.02.15/`. It boots from the SD card, has two root filesystem
slots (A/B) updated with [RAUC](https://rauc.io), uses systemd as init/service
manager and keeps persistent data on a separate partition.

The older single-slot image (`buildroot-2025.02.15/configs/beaglebone_defconfig`,
BusyBox init, see [buildroot-legacy.md](buildroot-legacy.md)) is kept only as a
fallback.

## Layout of `br2-skylark/`

| Path | Purpose |
|---|---|
| `configs/skylark_bbb_defconfig` | Buildroot configuration |
| `board/skylark/boot.cmd` | U-Boot boot script: A/B slot selection (RAUC bootchooser), cape overlay |
| `board/skylark/uboot.fragment` | U-Boot: env on raw SD, UART4 console, legacy `boot.scr` format |
| `board/skylark/patches/uboot/` | U-Boot patches (UART4 `stdout-path`) |
| `board/skylark/linux.fragment` | Kernel options (CAN, DS1307, overlays, ...) |
| `board/skylark/dts/skylark-cape.dts` | Cape device tree overlay (UART4, CAN1, DS1307) |
| `board/skylark/genimage.cfg` | SD card layout |
| `board/skylark/system.conf` | RAUC system config (slots, status file) |
| `board/skylark/rauc-keys/` | Development signing key (generated on first build, not committed) |
| `board/skylark/post-build.sh`, `post-image.sh` | Overlay compile, version stamp, `boot.scr`, RAUC bundle, manifest |
| `package/skylark-config/` | Board services: `/data`, first boot, RAUC mark-good, network, CAN, RTC, SSH |

## Building

```sh
make setup   # once: loads skylark_bbb_defconfig into output/.config
make         # full build -> output/images/
sh scripts/verify-image.sh   # offline check of the produced image
```

Results in `output/images/`:

| File | Use |
|---|---|
| `sdcard.img` | Complete SD card (boot, rootfs A, rootfs B, data) |
| `update.raucb` | Signed RAUC bundle for updating the inactive slot |
| `MANIFEST.json` | Version, git revision, component versions, checksums |

Useful targets: `make menuconfig`, `make savedefconfig`,
`make <pkg>-rebuild|-reconfigure|-dirclean`, `make uboot-reconfigure`.
`scripts/check-defconfig.sh` reports defconfig options that Buildroot dropped
(e.g. because of a missing dependency).

The toolchain is Bootlin armv7-eabihf glibc **bleeding-edge** (GCC 14, kernel
headers 5.15): systemd-networkd needs headers >= 5.4, the "stable" toolchain has
4.19.

Development root password: `skylark` (set in the defconfig; SYS-12 covers
production).

## SD card layout

| Offset / partition | Content |
|---|---|
| 1 MiB, 1.5 MiB | U-Boot environment + redundant copy (128 KiB each, raw) |
| p1 `BOOT` FAT 64 MiB | `MLO`, `u-boot.img`, `boot.scr` |
| p2 ext4 512 MiB | rootfs slot A |
| p3 ext4 512 MiB | rootfs slot B |
| p4 ext4 `data` | `/data`, grown to fill the card on first boot |

Kernel, DTB and cape overlay are stored in each slot (`/boot/...`), so they are
updated together with the rootfs.

## Boot flow and A/B selection

1. ROM loads `MLO` from the SD card (or from eMMC, see below).
2. U-Boot runs `boot.scr` from the FAT partition.
3. `boot.scr` walks `BOOT_ORDER` (default `A B`) and picks the first slot whose
   `BOOT_x_LEFT` counter is > 0, decrements it and saves the environment.
4. It loads `/boot/zImage` and the DTB from that slot, applies
   `/boot/overlays/skylark-cape.dtbo` (falls back to the plain DTB if the
   overlay fails) and boots with `root=/dev/mmcblk0p<2|3> rauc.slot=<A|B>`.
5. After `multi-user.target` is reached, `rauc-mark-good.service` marks the
   slot good, which resets its counter to 3.

A slot that fails to boot 3 times is skipped and the other slot boots
(verified: with slot A's kernel removed, U-Boot tried A three times and then
booted B). Inspect/modify from Linux:

```sh
rauc status
fw_printenv BOOT_ORDER BOOT_A_LEFT BOOT_B_LEFT
fw_setenv BOOT_ORDER "B A"
```

### eMMC on the BeagleBone Black

The ROM boots eMMC first when it has a valid `MLO`. To boot the A/B SD card
either hold S2 at power-on, or disable the eMMC boot loader once (keeps the rest
of the eMMC intact):

```sh
mount /dev/mmcblk1p1 /mnt && mv /mnt/MLO /mnt/MLO.disabled && umount /mnt
```

The A/B layout, `boot.scr` and RAUC config all use `mmc 0` / `/dev/mmcblk0`
(SD). Moving the A/B system to eMMC needs the env device and slot devices
changed.

## Updating (RAUC)

```sh
# from the PC (dropbear has no sftp-server, so scp does not work; use cat)
ssh root@skylark.local 'cat > /data/update.raucb' < output/images/update.raucb
ssh root@skylark.local 'rauc install /data/update.raucb && reboot'
```

`rauc install` verifies the signature (`/etc/rauc/keyring.pem`), writes the
inactive slot and puts it first in `BOOT_ORDER`. If the new slot does not reach
`multi-user.target` three times, the board falls back to the old slot.

The slot status is kept in `/data/rauc.status`.

## Services (systemd)

All board services are systemd units installed by the `skylark-config`
package. Add new services there: put the unit in
`package/skylark-config/src/`, install it in `skylark-config.mk`
(`SKYLARK_CONFIG_INSTALL_INIT_SYSTEMD`) and enable it with a `*.wants` link.
Use `Restart=on-failure` for daemons and `RequiresMountsFor=/data` for anything
storing state. Periodic jobs are systemd timers, not cron.

| Unit | Function |
|---|---|
| `skylark-growdata.service` | Grows p4 to the end of the card (first boot) |
| `data.mount` | Mounts `/data` |
| `skylark-firstboot.service` | Creates the `/data` directory structure once |
| `rauc-mark-good.service` | Marks the booted slot good |
| `systemd-networkd` | `eth0` DHCP + mDNS (`20-eth0.network`), `can0` (`80-can.*`) |
| `systemd-resolved` | DNS, mDNS (`skylark.local`) |
| `systemd-timesyncd` | NTP (`/etc/systemd/timesyncd.conf.d/skylark.conf`) |
| `skylark-rtc-restore.service` | Boot: system clock from DS1307; shutdown: save NTP time to DS1307 |
| `skylark-rtc-sync.timer` | Every 10 min: rewrite DS1307 from NTP time if it drifted |
| `dropbear.service` | SSH; host keys and `authorized_keys` on `/data` |

Logs: `journalctl -u <unit>`, failed units: `systemctl --failed`.

### Persistent state on `/data`

Each slot has its own rootfs, so anything that must survive an update lives on
`/data`:

| Path | Content |
|---|---|
| `/data/ssh/dropbear` (`/etc/dropbear`) | SSH host keys (same on both slots) |
| `/data/ssh/root` (`/root/.ssh`) | root's `authorized_keys` |
| `/data/rauc.status` | RAUC slot status |
| `/data/ardupilot/`, `/data/skylark/` | Application data, config |

`skylark-factory-reset` wipes `/data`.

## Serial console (UART4)

The boot console (SPL, U-Boot, kernel, login on `ttyS4`) is on **UART4**:

| Signal | Header pin | Adapter |
|---|---|---|
| UART4 RX | P9.11 | adapter TX |
| UART4 TX | P9.13 | adapter RX |
| GND | P9.1 / P9.2 | GND |

115200 8N1, 3.3 V levels only. P9.11/P9.13 are the only UART pins not used by
the cape (UART1 pins carry CAN1, UART2 goes to the MAVLink connector J13, UART5
shares pins with HDMI/eMMC). The AM335x ROM still uses UART0 (J1) for its UART
boot fallback.

Configuration: `CONFIG_CONS_INDEX=5` and patch
`0001-am335x-boneblack-console-on-uart4.patch` (U-Boot), `console=ttyS4` in
`boot.cmd`, `&uart4` pinmux in `skylark-cape.dts`.

## Network

`eth0` uses DHCP (`systemd-networkd`) and announces `skylark.local` over mDNS.

```sh
ssh root@skylark.local
networkctl status eth0
```

## CAN

DCAN1 on P9.24 (RX) / P9.26 (TX), connector J11. `systemd-networkd` brings
`can0` up at boot at 1 Mbit/s (DroneCAN/ArduPilot default), with automatic
bus-off restart after 100 ms and TX queue length 100 (the default of 10 drops
frames on bursts):

| File | Setting |
|---|---|
| `/etc/systemd/network/80-can.network` | `BitRate=1000000`, `RestartSec=100ms` |
| `/etc/systemd/network/80-can.link` | `TransmitQueueLength=100` |

```sh
ip -d link show can0          # state, bitrate (iproute2 is included)
candump can0
cansend can0 123#DEADBEEF
```

## RTC and network time

The cape has a DS1307 RTC (U3) on I2C2 at 0x68, declared in
`skylark-cape.dts`. It appears as `/dev/rtc1` (`rtc0` is the AM335x internal
RTC, which has no battery).

- **Boot** (`skylark-rtc-restore.service`, before `time-set.target`): if the
  DS1307 holds a valid time (>= 2025) that is newer than the system clock, the
  system clock is set from it. The clock is never moved backwards.
- **Online**: `systemd-timesyncd` synchronizes the system clock with NTP
  (`pool.ntp.org`, fallback Google/Cloudflare).
- **RTC correction** (`skylark-rtc-sync.timer`, 1 min after boot then every
  10 min): when NTP is synchronized and the DS1307 differs by more than
  `MAX_DRIFT` seconds (default 2), the DS1307 is rewritten.
- **Shutdown**: the NTP time is written to the DS1307 if NTP was synchronized
  during this boot.

Settings: `/etc/skylark/rtc.conf` (`RTC_NAME`, `MAX_DRIFT`). Status:

```sh
skylark-rtc status
journalctl -u skylark-rtc-restore -u skylark-rtc-sync
```

I2C reads of the DS1307 are retried 3 times (the first access after boot can
time out).

### Known hardware issue (cape rev 1)

The DS1307 oscillator stalls: after being set it runs a few seconds and stops.
Likely causes: missing/low coin cell (VBAT, TP25) or a crystal Y1 that is not
the 12.5 pF type the DS1307 needs. Until fixed, the RTC only has the right time
while NTP keeps correcting it. Also: the I2C2 pull-ups R22/R23 go to 5 V while
the AM335x pins are 3.3 V, and the CAT24C256 EEPROM (U1) does not answer.

## Flashing

### SD card from the PC

```sh
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M conv=fsync status=progress
```

### SD card over the network

When the board runs from eMMC (SD card not mounted), the SD card can be written
over SSH:

```sh
gzip -1 -c output/images/sdcard.img | \
  ssh root@<board> 'gunzip -c | dd of=/dev/mmcblk0 bs=4M conv=fsync'
# verify
md5sum output/images/sdcard.img
ssh root@<board> "head -c $(stat -c%s output/images/sdcard.img) /dev/mmcblk0 | md5sum"
```

Once the A/B system is running, update it with RAUC instead (above).

## Recovering a board that does not boot

1. Stop autoboot on the UART4 console (any key) and boot by hand, e.g. slot A:

   ```
   load mmc 0:2 ${kernel_addr_r} /boot/zImage
   load mmc 0:2 ${fdt_addr_r} /boot/am335x-boneblack.dtb
   setenv bootargs console=ttyS4,115200n8 root=/dev/mmcblk0p2 rootwait rw rauc.slot=A
   bootz ${kernel_addr_r} - ${fdt_addr_r}
   ```

2. Or re-enable the eMMC system: rename `MLO.disabled` back to `MLO` on
   `/dev/mmcblk1p1` (from the SD system), or hold S2 to choose the SD card.
3. Last resort: write `sdcard.img` to the SD card on the PC.
