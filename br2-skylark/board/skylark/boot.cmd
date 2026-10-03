# Skylark A/B boot script (RAUC U-Boot bootchooser protocol)
# Variables BOOT_ORDER / BOOT_A_LEFT / BOOT_B_LEFT are shared with
# RAUC on Linux through fw_setenv (see /etc/fw_env.config).

echo "Skylark bootchooser"

test -n "${BOOT_ORDER}" || setenv BOOT_ORDER "A B"
test -n "${BOOT_A_LEFT}" || setenv BOOT_A_LEFT 3
test -n "${BOOT_B_LEFT}" || setenv BOOT_B_LEFT 3

setenv bootpart
setenv raucslot
for BOOT_SLOT in "${BOOT_ORDER}"; do
  if test "x${bootpart}" = "x" -a "x${BOOT_SLOT}" = "xA"; then
    if test ${BOOT_A_LEFT} -gt 0; then
      setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
      echo "Found valid slot A, ${BOOT_A_LEFT} attempts remaining"
      setenv bootpart 2
      setenv raucslot A
    fi
  elif test "x${bootpart}" = "x" -a "x${BOOT_SLOT}" = "xB"; then
    if test ${BOOT_B_LEFT} -gt 0; then
      setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
      echo "Found valid slot B, ${BOOT_B_LEFT} attempts remaining"
      setenv bootpart 3
      setenv raucslot B
    fi
  fi
done

if test -n "${bootpart}"; then
  saveenv
else
  echo "No valid slot found, resetting tries to 3"
  setenv BOOT_A_LEFT 3
  setenv BOOT_B_LEFT 3
  saveenv
  reset
fi

setenv fdtfile am335x-boneblack.dtb
setenv bootargs "console=ttyS0,115200n8 root=/dev/mmcblk0p${bootpart} rootfstype=ext4 rootwait rw rauc.slot=${raucslot}"

echo "Booting slot ${raucslot} (mmc 0:${bootpart})"
load mmc 0:${bootpart} ${kernel_addr_r} /boot/zImage || reset
load mmc 0:${bootpart} ${fdt_addr_r} /boot/${fdtfile} || reset

# Optional cape overlay (stored per slot so it is updated with the rootfs)
setenv overlay_addr_r 0x89000000
if load mmc 0:${bootpart} ${overlay_addr_r} /boot/overlays/skylark-cape.dtbo; then
  fdt addr ${fdt_addr_r}
  fdt resize 65536
  fdt apply ${overlay_addr_r} || echo "WARNING: skylark-cape.dtbo failed to apply"
fi

bootz ${kernel_addr_r} - ${fdt_addr_r}
echo "bootz failed"
reset
