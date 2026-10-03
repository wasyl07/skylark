#!/bin/sh
# Skylark post-build: runs with $1 = TARGET_DIR
set -eu
BOARD_DIR="$(dirname "$0")"
KEYDIR="${BOARD_DIR}/rauc-keys"

# Development RAUC signing key (generated once, never committed)
if [ ! -f "${KEYDIR}/development-1.key.pem" ]; then
    "${KEYDIR}/generate-keys.sh"
fi
install -D -m 0644 "${BOARD_DIR}/system.conf" "${TARGET_DIR}/etc/rauc/system.conf"
install -D -m 0644 "${KEYDIR}/development-1.cert.pem" "${TARGET_DIR}/etc/rauc/keyring.pem"

# Cape overlay (built from board/skylark/dts/skylark-cape.dts)
DTS="${BOARD_DIR}/dts/skylark-cape.dts"
if [ -f "${DTS}" ]; then
    mkdir -p "${TARGET_DIR}/boot/overlays"
    "${HOST_DIR}/bin/dtc" -@ -I dts -O dtb -q \
        -o "${TARGET_DIR}/boot/overlays/skylark-cape.dtbo" "${DTS}"
fi

# Version stamp
VERSION="${SKYLARK_VERSION:-$(cat "${BOARD_DIR}/../../../VERSION" 2>/dev/null || echo 0.0.0-dev)}"
GITREV="$(git -C "${BOARD_DIR}" describe --always --dirty 2>/dev/null || echo unknown)"
mkdir -p "${TARGET_DIR}/etc/skylark"
printf 'SKYLARK_VERSION=%s\nSKYLARK_GIT=%s\n' "${VERSION}" "${GITREV}" > "${TARGET_DIR}/etc/skylark/version"
