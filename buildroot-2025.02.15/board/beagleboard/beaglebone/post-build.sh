#!/bin/sh
set -eu
BOARD_DIR="$(dirname "$0")"

# Copy uEnv.txt and update fdt resize to 65536 (64KB)
sed 's/fdt resize [0-9]*/fdt resize 65536/' "$BOARD_DIR/uEnv.txt" | \
    install -m 0644 -D /dev/stdin "$BINARIES_DIR/uEnv.txt"

# Copy extlinux.conf
install -m 0644 -D "$BOARD_DIR/extlinux.conf" "$BINARIES_DIR/extlinux/extlinux.conf"

# Copy DTB from new subdirectory location (Linux 6.12+)
find "${BUILD_DIR}/linux-"* -path "*/dts/ti/omap/am335x-boneblack.dtb" \
    -exec cp {} "${BINARIES_DIR}/am335x-boneblack.dtb" \;

# Copy device tree overlay: the kernel build compiles skylark-overlay.dts
# (from BR2_LINUX_KERNEL_CUSTOM_DTS_DIR) as skylark-overlay.dtb (with -@).
OVL=$(find "${BUILD_DIR}"/linux-* -path "*/boot/dts/skylark-overlay.dtb" ! -path "*linux-headers*" | head -n1)
[ -n "$OVL" ] || { echo "skylark-overlay.dtb not built" >&2; exit 1; }
install -m 0644 -D "$OVL" "${BINARIES_DIR}/skylark-overlay.dtbo"
