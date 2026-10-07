#!/bin/sh
# Sanity-check a built Skylark SD image without root (no loop mounts).
set -u
cd "$(dirname "$0")/.."
O=output
I=$O/images
H=$O/host/bin
fail=0
ok()  { echo "  OK   $*"; }
bad() { echo "  FAIL $*"; fail=1; }

echo "== partition table"
"$O/host/sbin/sfdisk" -l "$I/sdcard.img" 2>/dev/null || fdisk -l "$I/sdcard.img"

echo "== boot partition (FAT)"
for f in MLO u-boot.img boot.scr; do
    MTOOLS_SKIP_CHECK=1 "$H/mdir" -i "$I/boot.vfat" "::$f" >/dev/null 2>&1 && ok "$f" || bad "$f missing"
done

echo "== rootfs (slot image)"
for f in /boot/zImage /boot/am335x-boneblack.dtb /boot/overlays/skylark-cape.dtbo \
         /etc/rauc/system.conf /etc/rauc/keyring.pem /etc/fw_env.config /etc/skylark/version \
         /usr/bin/rauc /usr/sbin/fw_setenv /usr/sbin/sfdisk /usr/sbin/resize2fs \
         /usr/lib/systemd/system/data.mount /usr/lib/systemd/system/rauc-mark-good.service \
         /usr/lib/systemd/system/local-fs.target.wants/data.mount \
         /usr/lib/systemd/system/multi-user.target.wants/rauc-mark-good.service \
         /usr/lib/skylark/growdata.sh /usr/bin/skylark-factory-reset /data \
         /usr/lib/skylark/rtc.sh /etc/skylark/rtc.conf \
         /usr/lib/systemd/system/sysinit.target.wants/skylark-rtc-restore.service \
         /usr/lib/systemd/system/timers.target.wants/skylark-rtc-sync.timer \
         /etc/systemd/network/20-eth0.network /etc/systemd/network/80-can.network \
         /etc/systemd/network/80-can.link /etc/systemd/timesyncd.conf.d/skylark.conf \
         /usr/lib/systemd/systemd-networkd /usr/lib/systemd/systemd-timesyncd /sbin/hwclock; do
    "$O/host/sbin/debugfs" -R "stat $f" "$I/rootfs.ext4" 2>/dev/null | grep -q Inode: && ok "$f" || bad "$f missing"
done

echo "== persistent SSH, no stale units"
for l in "/etc/dropbear /data/ssh/dropbear" "/root/.ssh /data/ssh/root"; do
    set -- $l
    "$O/host/sbin/debugfs" -R "stat $1" "$I/rootfs.ext4" 2>/dev/null | grep -q "Fast link dest: \"$2\"" \
        && ok "$1 -> $2" || bad "$1 is not a link to $2"
done
for f in /usr/lib/systemd/system/skylark-rtc-sync.path; do
    "$O/host/sbin/debugfs" -R "stat $f" "$I/rootfs.ext4" 2>/dev/null | grep -q Inode: && bad "$f stale" || ok "no $f"
done

echo "== U-Boot config"
UC=$(ls -d $O/build/uboot-*/.config)
for k in CONFIG_ENV_IS_IN_MMC=y CONFIG_SYS_REDUNDAND_ENVIRONMENT=y CONFIG_ENV_OFFSET=0x100000 \
         CONFIG_ENV_OFFSET_REDUND=0x180000 CONFIG_ENV_SIZE=0x20000 CONFIG_CMD_SETEXPR=y CONFIG_OF_LIBFDT_OVERLAY=y \
         CONFIG_LEGACY_IMAGE_FORMAT=y CONFIG_CONS_INDEX=5; do
    grep -qx "$k" "$UC" && ok "$k" || bad "$k ($(grep "${k%%=*}[= ]" "$UC"))"
done
grep -q '^# CONFIG_ENV_IS_IN_FAT is not set' "$UC" && ok "ENV not in FAT" || bad "ENV_IS_IN_FAT still set"
grep '^CONFIG_BOOTCOMMAND=' "$UC"

echo "== kernel config"
KC=$(ls -d $O/build/linux-custom/.config)
for k in CONFIG_BLK_DEV_LOOP CONFIG_SQUASHFS CONFIG_DM_VERITY CONFIG_IIO CONFIG_I2C_OMAP CONFIG_SPI_OMAP24XX \
         CONFIG_PRU_REMOTEPROC CONFIG_CAN_C_CAN_PLATFORM CONFIG_CGROUPS CONFIG_DEVTMPFS; do
    v=$(grep "^$k=" "$KC") && ok "$v" || bad "$k not set"
done

echo "== RAUC bundle"
"$H/rauc" info --keyring=br2-skylark/board/skylark/rauc-keys/development-1.cert.pem "$I/update.raucb" 2>&1 | grep -E "Compatible|Version|Bundle Format|Signature|Verified|rootfs" | head

echo "== MANIFEST.json"; cat "$I/MANIFEST.json"
[ $fail = 0 ] && echo "ALL CHECKS PASSED" || { echo "SOME CHECKS FAILED"; exit 1; }
