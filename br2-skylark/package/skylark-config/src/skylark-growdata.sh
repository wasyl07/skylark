#!/bin/sh
# Grow partition 4 (data) to the end of the SD card and resize its ext4.
# Idempotent: does nothing once the partition already fills the disk.
set -eu
DISK=/dev/mmcblk0
PART=${DISK}p4
NUM=4

disk_sectors=$(cat /sys/block/mmcblk0/size)
start=$(cat /sys/block/mmcblk0/mmcblk0p4/start)
size=$(cat /sys/block/mmcblk0/mmcblk0p4/size)
end=$((start + size))
# leave slack for rounding (1 MiB)
if [ $((disk_sectors - end)) -le 2048 ]; then
    echo "growdata: ${PART} already fills ${DISK}"
    exit 0
fi

echo "growdata: growing ${PART} (${size} -> $((disk_sectors - start)) sectors)"
echo ", +" | sfdisk --no-reread --no-tell-kernel -N ${NUM} ${DISK}
partx -u -n ${NUM} ${DISK}
e2fsck -fy ${PART} || [ $? -le 1 ]
resize2fs ${PART}
# partx/resize2fs generate change uevents for the disk and p4; let udev finish
# them before data.mount starts, otherwise systemd may see the by-label device
# flap later and stop (unmount) /data again.
udevadm settle --timeout=30 || true
echo "growdata: done"
