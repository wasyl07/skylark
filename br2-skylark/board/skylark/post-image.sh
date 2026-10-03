#!/bin/bash
# Skylark post-image: boot.scr, sdcard.img, update.raucb, MANIFEST.json
set -euo pipefail
BOARD_DIR="$(dirname "$0")"
KEYDIR="${BOARD_DIR}/rauc-keys"
VERSION="${SKYLARK_VERSION:-$(cat "${BOARD_DIR}/../../../VERSION" 2>/dev/null || echo 0.0.0-dev)}"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

"${HOST_DIR}/bin/mkimage" -C none -A arm -T script \
    -d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

# genimage builds data.ext4 from an empty root dir
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
EMPTY_ROOT="$(mktemp -d)"
trap 'rm -rf "${EMPTY_ROOT}"' EXIT
rm -rf "${GENIMAGE_TMP}"
"${HOST_DIR}/bin/genimage" \
    --rootpath "${EMPTY_ROOT}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${BOARD_DIR}/genimage.cfg"
rm -rf "${GENIMAGE_TMP}"

# RAUC bundle (verity format)
BUNDLE_DIR="${BUILD_DIR}/rauc-bundle"
rm -rf "${BUNDLE_DIR}" "${BINARIES_DIR}/update.raucb"
mkdir -p "${BUNDLE_DIR}"
cat > "${BUNDLE_DIR}/manifest.raucm" << EOF
[update]
compatible=skylark-bbb
version=${VERSION}
build=${BUILD_DATE}

[bundle]
format=verity

[image.rootfs]
filename=rootfs.ext4
EOF
cp "${BINARIES_DIR}/rootfs.ext4" "${BUNDLE_DIR}/"
"${HOST_DIR}/bin/rauc" bundle \
    --cert="${KEYDIR}/development-1.cert.pem" \
    --key="${KEYDIR}/development-1.key.pem" \
    "${BUNDLE_DIR}" "${BINARIES_DIR}/update.raucb"
rm -rf "${BUNDLE_DIR}"

kver="$(sed -n 's/^BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION=.*linux-\(.*\)\.tar.*/\1/p' "${BR2_CONFIG}")"
uver="$(sed -n 's/^BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE="\(.*\)"/\1/p' "${BR2_CONFIG}")"
brver="${BR2_VERSION:-unknown}"
cat > "${BINARIES_DIR}/MANIFEST.json" << EOF
{
  "system_version": "${VERSION}",
  "build_date": "${BUILD_DATE}",
  "git": "$(git -C "${BOARD_DIR}" describe --always --dirty 2>/dev/null || echo unknown)",
  "buildroot_version": "${brver}",
  "components": {
    "kernel": "${kver}",
    "uboot": "${uver}"
  },
  "rootfs_sha256": "$(sha256sum "${BINARIES_DIR}/rootfs.ext4" | cut -d' ' -f1)",
  "sdcard_sha256": "$(sha256sum "${BINARIES_DIR}/sdcard.img" | cut -d' ' -f1)"
}
EOF

echo "SD card image: ${BINARIES_DIR}/sdcard.img"
echo "RAUC bundle:   ${BINARIES_DIR}/update.raucb"
echo "Manifest:      ${BINARIES_DIR}/MANIFEST.json"
