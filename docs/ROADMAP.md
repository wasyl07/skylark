# Skylark Project Roadmap

Drone flight controller platform based on BeagleBone Black (AM335x) with ArduPilot,
custom cape hardware, and PRU-based real-time peripherals.

## Project Architecture Overview

```
+------------------------------------------------------------------+
|                        SKYLARK SYSTEM                            |
+------------------------------------------------------------------+
|                                                                  |
|  +------------------+    +------------------+    +-------------+ |
|  |   ArduPilot      |    |   Linux Kernel   |    |  PRU        | |
|  |   (Copter/Plane) |    |   (Buildroot)    |    |  Firmware   | |
|  |                  |    |                  |    |             | |
|  |  - IIO backend   |<-->|  - BHI360 driver |    |  - Servo    | |
|  |  - PRU servo HAL |    |  - BMM350 driver |    |  - CAN      | |
|  |                  |    |  - IIO subsystem |    |             | |
|  +------------------+    +------------------+    +-------------+ |
|           |                      |                     |         |
|           +----------------------+---------------------+         |
|                                  |                               |
|  +------------------+    +------------------+    +-------------+ |
|  |   U-Boot         |    |   SD Card        |    |  Cape HW    | |
|  |   (A/B boot)     |    |   (A/B + data)   |    |  (KiCad)    | |
|  +------------------+    +------------------+    +-------------+ |
|                                                                  |
+------------------------------------------------------------------+
```

---

## Build System: Buildroot

Skylark uses **Buildroot** as the Linux build system for:
- Faster build times vs Yocto
- Simpler configuration (single defconfig + fragments)
- Native RAUC support since 2017.08
- Easier customization for small teams

Reference projects:
- [br2rauc](https://github.com/cdsteinkuehler/br2rauc) - Buildroot + RAUC for RPi CM4
- [bbb-buildroot](https://github.com/smalinux/bbb-buildroot) - BeagleBone Black with RAUC

---

## Versioning Strategy

### Component Versioning (SemVer)

Each major component maintains independent semantic versioning:

| Component           | Format          | Example       | Repository Tag         |
|---------------------|-----------------|---------------|------------------------|
| Cape Hardware       | HW-X.Y          | HW-1.2        | hw/v1.2                |
| Linux Kernel        | K-X.Y.Z         | K-6.6.32      | kernel/v6.6.32         |
| BHI360/BMM350 Driver| DRV-X.Y.Z       | DRV-1.0.0     | drivers/v1.0.0         |
| PRU Firmware        | PRU-X.Y.Z       | PRU-1.0.0     | pru/v1.0.0             |
| ArduPilot Fork      | AP-X.Y.Z-skyN   | AP-4.5.0-sky1 | ardupilot/v4.5.0-sky1  |
| Buildroot External  | BR2-X.Y.Z       | BR2-1.0.0     | br2-skylark/v1.0.0     |
| System Image        | SYS-X.Y.Z       | SYS-1.0.0     | release/v1.0.0         |

### System Image Version (Release Bundle)

The final deployable image uses a manifest-based version lock:

```
skylark-SYS-1.0.0
├── MANIFEST.json
│   {
│     "system_version": "1.0.0",
│     "build_date": "2026-10-01T12:00:00Z",
│     "buildroot_version": "2024.02.x",
│     "components": {
│       "cape_hw": "HW-1.2",
│       "kernel": "K-6.6.32",
│       "drivers": "DRV-1.0.0",
│       "pru_firmware": "PRU-1.0.0",
│       "ardupilot": "AP-4.5.0-sky1"
│     },
│     "rootfs_hash": "sha256:abc123...",
│     "compatible_hw": ["HW-1.0", "HW-1.1", "HW-1.2"]
│   }
├── sdcard.img
└── update.raucb
```

### Version Compatibility Matrix

| System Version | Min HW | Kernel     | ArduPilot     | Notes                    |
|----------------|--------|------------|---------------|--------------------------|
| SYS-1.0.x      | HW-1.0 | K-6.6.x    | AP-4.5.0-sky* | Initial release          |
| SYS-1.1.x      | HW-1.1 | K-6.6.x    | AP-4.5.x-sky* | BHI360 interrupt support |
| SYS-2.0.x      | HW-2.0 | K-6.10.x   | AP-4.6.x-sky* | Breaking HW changes      |

---

## Phase 1: Foundation (Weeks 1-8)

### 1.1 Buildroot BSP Setup (Weeks 1-3)

**Goal**: Bootable minimal Linux for BeagleBone Black with A/B partitioning.

**Deliverables**:
- [ ] BR2_EXTERNAL tree `br2-skylark` created
- [ ] Board defconfig `skylark_bbb_defconfig`
- [ ] U-Boot with A/B bootchooser logic
- [ ] A/B partition layout via genimage
- [ ] Boot tested on hardware

**Partition Layout** (8GB+ SD card):

```
+--------+--------+--------+--------+
| boot   | rootA  | rootB  | data   |
| 64MB   | 512MB  | 512MB  | 4GB+   |
| FAT32  | ext4   | ext4   | ext4   |
+--------+--------+--------+--------+
  p1       p2       p3       p4
  MLO      Active   Standby  Persistent
  u-boot   rootfs   rootfs   storage
  boot.scr
  DTBs
```

**BR2_EXTERNAL Directory Structure**:
```
br2-skylark/
├── external.desc                    # BR2_EXTERNAL descriptor
├── external.mk                      # Auto-include all package/*.mk
├── Config.in                        # Top-level Kconfig menu
├── configs/
│   └── skylark_bbb_defconfig        # Main board configuration
├── board/skylark/
│   ├── genimage.cfg                 # Partition layout
│   ├── boot.cmd                     # U-Boot boot script (A/B logic)
│   ├── uboot.fragment               # U-Boot config additions
│   ├── linux.fragment               # Kernel config additions
│   ├── busybox.fragment             # BusyBox config additions
│   ├── system.conf                  # RAUC system configuration
│   ├── post-build.sh                # Rootfs post-build hooks
│   ├── post-image.sh                # Image generation + RAUC bundle
│   ├── rauc-keys/
│   │   ├── development-1.cert.pem
│   │   └── development-1.key.pem
│   ├── rootfs-overlay/
│   │   └── etc/
│   │       ├── fw_env.config        # U-Boot env access
│   │       └── rauc/
│   │           └── system.conf      # -> ../../../system.conf
│   └── patches/                     # Per-package patches
├── package/
│   ├── skylark-ardupilot/
│   ├── skylark-pru-firmware/
│   └── skylark-config/
└── kmodules/
    ├── kmod-bhi360/
    └── kmod-bmm350/
```

**defconfig** (`configs/skylark_bbb_defconfig`):
```makefile
# Architecture
BR2_arm=y
BR2_cortex_a8=y
BR2_ARM_FPU_NEON=y

# Toolchain (external for faster builds)
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_BOOTLIN=y
BR2_TOOLCHAIN_EXTERNAL_BOOTLIN_ARMV7_EABIHF_GLIBC_STABLE=y

# System
BR2_INIT_SYSTEMD=y
BR2_ROOTFS_DEVICE_CREATION_DYNAMIC_EUDEV=y
BR2_TARGET_GENERIC_HOSTNAME="skylark"
BR2_TARGET_GENERIC_ISSUE="Skylark Flight Controller"
BR2_TARGET_GENERIC_ROOT_PASSWD="skylark"

# Kernel
BR2_LINUX_KERNEL=y
BR2_LINUX_KERNEL_CUSTOM_VERSION=y
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6.32"
BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark/linux.fragment"
BR2_LINUX_KERNEL_DTS_SUPPORT=y
BR2_LINUX_KERNEL_INTREE_DTS_NAME="am335x-boneblack"

# U-Boot
BR2_TARGET_UBOOT=y
BR2_TARGET_UBOOT_BUILD_SYSTEM_KCONFIG=y
BR2_TARGET_UBOOT_CUSTOM_VERSION=y
BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE="2024.04"
BR2_TARGET_UBOOT_BOARD_DEFCONFIG="am335x_evm"
BR2_TARGET_UBOOT_CONFIG_FRAGMENT_FILES="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark/uboot.fragment"
BR2_TARGET_UBOOT_SPL=y
BR2_TARGET_UBOOT_SPL_NAME="MLO"

# Filesystem
BR2_TARGET_ROOTFS_EXT2=y
BR2_TARGET_ROOTFS_EXT2_4=y
BR2_TARGET_ROOTFS_EXT2_SIZE="512M"

# RAUC
BR2_PACKAGE_RAUC=y
BR2_PACKAGE_RAUC_DBUS=y
BR2_PACKAGE_RAUC_NETWORK=y
BR2_PACKAGE_RAUC_JSON=y
BR2_PACKAGE_HOST_RAUC=y

# Required for RAUC
BR2_PACKAGE_SQUASHFS=y
BR2_PACKAGE_OPENSSL=y

# U-Boot tools (fw_printenv/fw_setenv)
BR2_PACKAGE_UBOOT_TOOLS=y
BR2_PACKAGE_UBOOT_TOOLS_FWPRINTENV=y

# IIO tools
BR2_PACKAGE_LIBIIO=y
BR2_PACKAGE_IIO_UTILS=y

# CAN tools
BR2_PACKAGE_CAN_UTILS=y
BR2_PACKAGE_LIBSOCKETCAN=y

# Networking
BR2_PACKAGE_DROPBEAR=y
BR2_PACKAGE_DHCPCD=y

# Post-build/image scripts
BR2_ROOTFS_OVERLAY="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark/rootfs-overlay"
BR2_ROOTFS_POST_BUILD_SCRIPT="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark/post-build.sh"
BR2_ROOTFS_POST_IMAGE_SCRIPT="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark/post-image.sh"
BR2_ROOTFS_POST_SCRIPT_ARGS="$(BR2_EXTERNAL_SKYLARK_PATH)/board/skylark"

# Image generation
BR2_PACKAGE_HOST_GENIMAGE=y
BR2_PACKAGE_HOST_DOSFSTOOLS=y
BR2_PACKAGE_HOST_MTOOLS=y
```

**Kernel Config Fragment** (`board/skylark/linux.fragment`):
```
# IIO Subsystem (required for BHI360/BMM350)
CONFIG_IIO=y
CONFIG_IIO_BUFFER=y
CONFIG_IIO_TRIGGERED_BUFFER=y
CONFIG_IIO_KFIFO_BUF=y
CONFIG_IIO_TRIGGER=y

# RAUC requirements
CONFIG_BLK_DEV_LOOP=y
CONFIG_SQUASHFS=y
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_CRYPTO_SHA256=y

# PRU-ICSS
CONFIG_PRUSS=y
CONFIG_PRUSS_REMOTEPROC=y
CONFIG_RPMSG_PRU=y

# I2C/SPI for sensors
CONFIG_I2C=y
CONFIG_I2C_OMAP=y
CONFIG_SPI=y
CONFIG_SPI_OMAP24XX=y

# CAN
CONFIG_CAN=y
CONFIG_CAN_C_CAN=y
CONFIG_CAN_C_CAN_PLATFORM=y

# GPIO
CONFIG_GPIOLIB=y
CONFIG_GPIO_OMAP=y
```

**U-Boot Config Fragment** (`board/skylark/uboot.fragment`):
```
# Environment on MMC (redundant for atomic updates)
CONFIG_ENV_IS_IN_MMC=y
CONFIG_ENV_OFFSET=0x100000
CONFIG_ENV_OFFSET_REDUND=0x180000
CONFIG_SYS_REDUNDAND_ENVIRONMENT=y
CONFIG_ENV_SIZE=0x20000

# SquashFS support (for rescue partition if needed)
CONFIG_FS_SQUASHFS=y

# setexpr for boot counter math
CONFIG_CMD_SETEXPR=y
```

**Boot Script** (`board/skylark/boot.cmd`):
```bash
# Skylark A/B Boot Script (RAUC bootchooser protocol)
# Compile with: mkimage -C none -A arm -T script -d boot.cmd boot.scr

echo "Skylark bootchooser starting..."

# Initialize boot state if missing
if test -z "${BOOT_ORDER}"; then
    echo "First boot: initializing RAUC bootchooser state"
    setenv BOOT_ORDER "A B"
    setenv BOOT_A_LEFT 3
    setenv BOOT_B_LEFT 3
    saveenv
fi

echo "BOOT_ORDER=${BOOT_ORDER}"
echo "BOOT_A_LEFT=${BOOT_A_LEFT} BOOT_B_LEFT=${BOOT_B_LEFT}"

# Default kernel args
setenv bootargs_default "console=ttyO0,115200n8 rootwait"
setenv bootpart ""
setenv rauc_slot ""

# Try each slot in BOOT_ORDER
for slot in ${BOOT_ORDER}; do
    if test "x${slot}" = "xA" -a ${BOOT_A_LEFT} -gt 0; then
        echo "Trying slot A (${BOOT_A_LEFT} attempts left)"
        setexpr BOOT_A_LEFT ${BOOT_A_LEFT} - 1
        saveenv
        setenv bootpart 2
        setenv rauc_slot A
    elif test "x${slot}" = "xB" -a ${BOOT_B_LEFT} -gt 0; then
        echo "Trying slot B (${BOOT_B_LEFT} attempts left)"
        setexpr BOOT_B_LEFT ${BOOT_B_LEFT} - 1
        saveenv
        setenv bootpart 3
        setenv rauc_slot B
    fi
    
    if test -n "${bootpart}"; then
        break
    fi
done

# Fallback if no valid slot
if test -z "${bootpart}"; then
    echo "ERROR: No bootable slot found! Resetting counters..."
    setenv BOOT_A_LEFT 3
    setenv BOOT_B_LEFT 3
    setenv bootpart 2
    setenv rauc_slot A
    saveenv
fi

echo "Booting slot ${rauc_slot} from partition ${bootpart}"

# Load kernel and DTB from selected rootfs partition
# Kernel and DTB are stored in /boot on the rootfs
ext4load mmc 0:${bootpart} ${kernel_addr_r} /boot/zImage
ext4load mmc 0:${bootpart} ${fdt_addr_r} /boot/am335x-boneblack.dtb

# Check for uEnv.txt overrides on rootfs
if ext4load mmc 0:${bootpart} ${loadaddr} /boot/uEnv.txt; then
    env import -t ${loadaddr} ${filesize}
fi

# Construct final bootargs
if test -n "${bootargs_force}"; then
    setenv bootargs "${bootargs_force}"
elif test -n "${bootargs_extra}"; then
    setenv bootargs "${bootargs_default} ${bootargs_extra}"
else
    setenv bootargs "${bootargs_default}"
fi

# Append root device and RAUC slot
setenv bootargs "${bootargs} root=/dev/mmcblk0p${bootpart} rauc.slot=${rauc_slot}"

echo "bootargs: ${bootargs}"
bootz ${kernel_addr_r} - ${fdt_addr_r}

# If we get here, boot failed
echo "Boot failed!"
reset
```

**Tasks**:
1. Clone Buildroot (2024.02.x LTS branch)
2. Create br2-skylark external tree structure
3. Write defconfig with BeagleBone Black settings
4. Create U-Boot boot script with A/B logic
5. Configure genimage for partition layout
6. Test boot on hardware

**Build Commands**:
```bash
# Initial setup
git clone --depth 1 --branch 2024.02.x https://git.busybox.net/buildroot/
git clone <skylark-repo> br2-skylark

# Configure
make -C buildroot BR2_EXTERNAL=../br2-skylark O=../output skylark_bbb_defconfig

# Build
cd output
make

# Output: output/images/sdcard.img, output/images/update.raucb
```

### 1.2 Atomic Update System with RAUC (Weeks 3-5)

**Goal**: RAUC-based atomic OTA update mechanism.

**Deliverables**:
- [ ] RAUC system.conf configured
- [ ] Signing keys generated
- [ ] Update bundle (.raucb) generated in post-image.sh
- [ ] Local update via USB/SD tested
- [ ] Rollback on boot failure working

**RAUC System Configuration** (`board/skylark/system.conf`):
```ini
[system]
compatible=skylark-bbb
bootloader=uboot
mountprefix=/mnt/rauc

[keyring]
path=/etc/rauc/keyring.pem

[handlers]
post-install=/usr/lib/rauc/post-install.sh

[slot.rootfs.0]
device=/dev/mmcblk0p2
type=ext4
bootname=A

[slot.rootfs.1]
device=/dev/mmcblk0p3
type=ext4
bootname=B
```

**Partition Layout** (`board/skylark/genimage.cfg`):
```
image boot.vfat {
    vfat {
        files = {
            "MLO",
            "u-boot.img",
            "boot.scr",
            "am335x-boneblack.dtb"
        }
    }
    size = 64M
}

image sdcard.img {
    hdimage {
        partition-table-type = "gpt"
    }

    partition boot {
        partition-type-uuid = C12A7328-F81F-11D2-BA4B-00A0C93EC93B
        image = "boot.vfat"
        bootable = true
    }

    partition rootfsA {
        partition-type-uuid = 0FC63DAF-8483-4772-8E79-3D69D8477DE4
        image = "rootfs.ext4"
        size = 512M
    }

    partition rootfsB {
        partition-type-uuid = 0FC63DAF-8483-4772-8E79-3D69D8477DE4
        image = "rootfs.ext4"
        size = 512M
    }

    partition data {
        partition-type-uuid = 0FC63DAF-8483-4772-8E79-3D69D8477DE4
        size = 4096M
    }
}
```

**Post-Image Script** (`board/skylark/post-image.sh`):
```bash
#!/bin/bash
set -e

BOARD_DIR="$1"
BINARIES_DIR="${BINARIES_DIR:-output/images}"
HOST_DIR="${HOST_DIR:-output/host}"

# Version from environment or default
VERSION="${SKYLARK_VERSION:-1.0.0}"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Skylark Post-Image Script ==="
echo "Version: ${VERSION}"
echo "Board dir: ${BOARD_DIR}"

# Generate boot.scr from boot.cmd
${HOST_DIR}/bin/mkimage -C none -A arm -T script \
    -d ${BOARD_DIR}/boot.cmd \
    ${BINARIES_DIR}/boot.scr

# Run genimage to create SD card image
${HOST_DIR}/bin/genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${BINARIES_DIR}/genimage.tmp" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${BOARD_DIR}/genimage.cfg"

rm -rf "${BINARIES_DIR}/genimage.tmp"

# Create RAUC update bundle
echo "=== Creating RAUC bundle ==="
BUNDLE_DIR="${BINARIES_DIR}/rauc-bundle"
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}"

# Create manifest
cat > "${BUNDLE_DIR}/manifest.raucm" << EOF
[update]
compatible=skylark-bbb
version=${VERSION}
build=${BUILD_DATE}

[image.rootfs]
filename=rootfs.ext4
EOF

# Copy rootfs image
cp "${BINARIES_DIR}/rootfs.ext4" "${BUNDLE_DIR}/"

# Sign and create bundle
${HOST_DIR}/bin/rauc bundle \
    --cert="${BOARD_DIR}/rauc-keys/development-1.cert.pem" \
    --key="${BOARD_DIR}/rauc-keys/development-1.key.pem" \
    "${BUNDLE_DIR}/" \
    "${BINARIES_DIR}/update.raucb"

rm -rf "${BUNDLE_DIR}"

# Create MANIFEST.json
cat > "${BINARIES_DIR}/MANIFEST.json" << EOF
{
    "system_version": "${VERSION}",
    "build_date": "${BUILD_DATE}",
    "buildroot_version": "$(cat ${HOST_DIR}/../build/buildroot-config/auto.conf 2>/dev/null | grep BR2_VERSION | cut -d'"' -f2 || echo 'unknown')",
    "components": {
        "kernel": "$(cat ${BINARIES_DIR}/../build/linux-*/.version 2>/dev/null || echo 'unknown')",
        "uboot": "$(cat ${BINARIES_DIR}/../build/uboot-*/.version 2>/dev/null || echo 'unknown')"
    }
}
EOF

echo "=== Build complete ==="
echo "SD card image: ${BINARIES_DIR}/sdcard.img"
echo "RAUC bundle:   ${BINARIES_DIR}/update.raucb"
echo "Manifest:      ${BINARIES_DIR}/MANIFEST.json"
```

**Post-Build Script** (`board/skylark/post-build.sh`):
```bash
#!/bin/bash
set -e

BOARD_DIR="$1"
TARGET_DIR="${TARGET_DIR}"

echo "=== Skylark Post-Build Script ==="

# Install RAUC system.conf
mkdir -p "${TARGET_DIR}/etc/rauc"
cp "${BOARD_DIR}/system.conf" "${TARGET_DIR}/etc/rauc/system.conf"

# Install RAUC keyring (public cert only)
cp "${BOARD_DIR}/rauc-keys/development-1.cert.pem" "${TARGET_DIR}/etc/rauc/keyring.pem"

# Create rauc-mark-good systemd service
mkdir -p "${TARGET_DIR}/etc/systemd/system"
cat > "${TARGET_DIR}/etc/systemd/system/rauc-mark-good.service" << 'EOF'
[Unit]
Description=Mark RAUC slot as good after successful boot
After=multi-user.target
ConditionKernelCommandLine=rauc.slot

[Service]
Type=oneshot
ExecStart=/usr/bin/rauc status mark-good
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf ../rauc-mark-good.service \
    "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/rauc-mark-good.service"

# Create data partition mount
mkdir -p "${TARGET_DIR}/data"
cat >> "${TARGET_DIR}/etc/fstab" << 'EOF'
/dev/mmcblk0p4  /data  ext4  defaults,noatime  0  2
EOF

# Create persistent directories structure
mkdir -p "${TARGET_DIR}/data/ardupilot/logs"
mkdir -p "${TARGET_DIR}/data/ardupilot/terrain"
mkdir -p "${TARGET_DIR}/data/skylark/config"

echo "Post-build complete"
```

**Generate Signing Keys** (`board/skylark/rauc-keys/generate-keys.sh`):
```bash
#!/bin/bash
# Generate development signing keys for RAUC
# For production, use HSM-backed keys

KEYDIR="$(dirname "$0")"
DAYS=3650  # 10 years

# Generate CA key and certificate
openssl req -x509 -newkey rsa:4096 \
    -keyout "${KEYDIR}/development-1.key.pem" \
    -out "${KEYDIR}/development-1.cert.pem" \
    -days ${DAYS} -nodes \
    -subj "/O=Skylark/CN=Skylark Development Signing Key"

echo "Keys generated in ${KEYDIR}/"
echo "  - development-1.key.pem (KEEP SECRET)"
echo "  - development-1.cert.pem (install on target as keyring)"
```

**Tasks**:
1. Generate development signing keys
2. Create system.conf for RAUC slots
3. Write post-build.sh for rootfs customization
4. Write post-image.sh for bundle generation
5. Configure genimage.cfg for partition layout
6. Test update cycle: `rauc install /tmp/update.raucb`
7. Test rollback: force boot failure, verify auto-switch

**Update Workflow**:
```bash
# On host: build new image
cd output
make
# Creates: output/images/update.raucb

# Deploy to target
scp output/images/update.raucb root@skylark:/tmp/

# On target: install update
rauc install /tmp/update.raucb
reboot

# After reboot, verify new version
rauc status
# Should show new slot as "booted" and "good"
```

### 1.3 Data Partition & Persistence (Week 5-6)

**Goal**: Persistent data survives updates and rollbacks.

**Deliverables**:
- [ ] Data partition auto-mounted at `/data`
- [ ] Bind mounts for critical paths
- [ ] First-boot initialization script
- [ ] Factory reset capability

**Persistent Paths**:
```
/data/
├── ardupilot/
│   ├── logs/                    # Flight logs
│   ├── terrain/                 # Terrain data
│   └── params.parm              # Vehicle parameters
├── skylark/
│   ├── config.json              # System configuration
│   ├── network/                 # WiFi credentials, etc.
│   └── keys/                    # Device certificates
└── lost+found/
```

**First-Boot Service** (`/etc/systemd/system/skylark-firstboot.service`):
```ini
[Unit]
Description=Skylark First Boot Initialization
ConditionPathExists=!/data/.initialized
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/lib/skylark/firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**First-Boot Script** (`/usr/lib/skylark/firstboot.sh`):
```bash
#!/bin/bash
set -e

echo "Skylark first boot initialization..."

# Format data partition if needed
if ! blkid /dev/mmcblk0p4 | grep -q ext4; then
    echo "Formatting data partition..."
    mkfs.ext4 -L skylark-data /dev/mmcblk0p4
fi

# Mount data partition
mount /data || true

# Create directory structure
mkdir -p /data/ardupilot/{logs,terrain}
mkdir -p /data/skylark/{config,network,keys}

# Initialize default config
if [ ! -f /data/skylark/config.json ]; then
    cat > /data/skylark/config.json << 'EOF'
{
    "hostname": "skylark",
    "vehicle_type": "copter",
    "first_boot": true
}
EOF
fi

# Mark initialization complete
touch /data/.initialized

echo "First boot complete"
```

**Factory Reset Script** (`/usr/bin/skylark-factory-reset`):
```bash
#!/bin/bash
echo "WARNING: This will erase all configuration and flight logs!"
read -p "Type 'RESET' to confirm: " confirm
if [ "$confirm" = "RESET" ]; then
    # Keep device keys, wipe everything else
    rm -rf /data/ardupilot/*
    rm -rf /data/skylark/config/*
    rm -rf /data/skylark/network/*
    rm /data/.initialized
    echo "Factory reset complete. Reboot to reinitialize."
else
    echo "Cancelled"
fi
```

**Tasks**:
1. Create first-boot systemd service
2. Write initialization script
3. Add factory reset capability
4. Test persistence across A/B updates
5. Test factory reset flow

---

## Phase 2: Kernel & Drivers (Weeks 6-14)

### 2.1 Kernel Configuration (Weeks 6-7)

**Goal**: Custom kernel with IIO, PRU, and required subsystems.

**Kernel Version Target**: 6.6.x LTS

The kernel config fragment (`board/skylark/linux.fragment`) was defined in Phase 1.

Additional required options for IIO sensors:
```
# IIO triggered buffer (for high-rate sensor sampling)
CONFIG_IIO_BUFFER_CB=y
CONFIG_IIO_BUFFER_DMA=y
CONFIG_IIO_BUFFER_DMAENGINE=y
CONFIG_IIO_BUFFER_HW_CONSUMER=y

# IIO software triggers
CONFIG_IIO_HRTIMER_TRIGGER=y
CONFIG_IIO_INTERRUPT_TRIGGER=y
CONFIG_IIO_SYSFS_TRIGGER=y

# Existing Bosch drivers (for reference patterns)
CONFIG_BMI160=m
CONFIG_BMI160_I2C=m
CONFIG_BMI160_SPI=m
CONFIG_BMM150=m
CONFIG_BMM150_I2C=m
CONFIG_BMM150_SPI=m
```

**Tasks**:
1. Update linux.fragment with full IIO support
2. Build kernel with `make linux-menuconfig` for verification
3. Test IIO subsystem with existing sensors
4. Verify PRU remoteproc loads correctly

### 2.2 BHI360 Linux IIO Driver (Weeks 7-11)

**Goal**: Kernel driver for Bosch BHI360 Smart Sensor with IIO interface.

**Sensor Characteristics**:
- BHI360: 6-axis IMU (accel + gyro) with programmable sensor hub
- Interface: SPI (primary) or I2C
- Features: On-chip sensor fusion, FIFO, interrupt-driven

**Driver Architecture**:
```
+------------------+     +------------------+
|   Userspace      |     |   ArduPilot      |
|   (libiio)       |     |   IIO Backend    |
+--------+---------+     +--------+---------+
         |                        |
         v                        v
+------------------------------------------+
|           IIO Subsystem                  |
|  /sys/bus/iio/devices/iio:deviceN/       |
+------------------------------------------+
         |
         v
+------------------------------------------+
|         bhi360-iio.ko                    |
|  - IIO device registration               |
|  - Triggered buffer support              |
|  - Virtual sensor channels               |
+------------------------------------------+
         |
         v
+------------------------------------------+
|         bhi360-core.ko                   |
|  - Firmware upload                       |
|  - Command/status interface              |
|  - FIFO management                       |
|  - Interrupt handling                    |
+------------------------------------------+
         |
    SPI / I2C
         |
         v
+------------------------------------------+
|              BHI360 Hardware             |
+------------------------------------------+
```

**IIO Channels to Expose**:
```c
/* Accelerometer */
IIO_CHAN(IIO_ACCEL, X, "accel_x", 0)
IIO_CHAN(IIO_ACCEL, Y, "accel_y", 1)
IIO_CHAN(IIO_ACCEL, Z, "accel_z", 2)

/* Gyroscope */
IIO_CHAN(IIO_ANGL_VEL, X, "anglvel_x", 3)
IIO_CHAN(IIO_ANGL_VEL, Y, "anglvel_y", 4)
IIO_CHAN(IIO_ANGL_VEL, Z, "anglvel_z", 5)

/* Timestamps */
IIO_CHAN_TIMESTAMP(6)

/* Virtual sensors (from BHI360 fusion) */
IIO_CHAN(IIO_ROT, QUAT_W, "rot_quaternion_w", 7)
IIO_CHAN(IIO_ROT, QUAT_X, "rot_quaternion_x", 8)
IIO_CHAN(IIO_ROT, QUAT_Y, "rot_quaternion_y", 9)
IIO_CHAN(IIO_ROT, QUAT_Z, "rot_quaternion_z", 10)
```

**Out-of-Tree Module Package** (`kmodules/kmod-bhi360/`):
```
kmodules/kmod-bhi360/
├── Config.in
├── kmod-bhi360.mk
└── src/
    ├── Kbuild
    ├── bhi360-core.c
    ├── bhi360-core.h
    ├── bhi360-spi.c
    ├── bhi360-i2c.c
    ├── bhi360-iio.c
    ├── bhi360-fifo.c
    └── bhi360-firmware.c
```

**Buildroot Package** (`kmodules/kmod-bhi360/kmod-bhi360.mk`):
```makefile
################################################################################
#
# kmod-bhi360
#
################################################################################

KMOD_BHI360_VERSION = 1.0.0
KMOD_BHI360_SITE = $(BR2_EXTERNAL_SKYLARK_PATH)/kmodules/kmod-bhi360/src
KMOD_BHI360_SITE_METHOD = local
KMOD_BHI360_LICENSE = GPL-2.0
KMOD_BHI360_LICENSE_FILES = COPYING

$(eval $(kernel-module))
$(eval $(generic-package))
```

**Device Tree Binding Example**:
```dts
&spi0 {
    bhi360: imu@0 {
        compatible = "bosch,bhi360";
        reg = <0>;
        spi-max-frequency = <10000000>;
        interrupt-parent = <&gpio1>;
        interrupts = <28 IRQ_TYPE_EDGE_RISING>;
        vdd-supply = <&vdd_3v3>;
        vddio-supply = <&vdd_1v8>;
        firmware-name = "bhi360.fw";
    };
};
```

**Tasks**:
1. Obtain BHI360 datasheet and register map (Bosch NDA may be required)
2. Study existing Bosch sensor drivers (bmi160, bma400) for patterns
3. Implement core driver with SPI transport
4. Add IIO device registration with basic channels
5. Implement FIFO and triggered buffer
6. Add firmware upload mechanism
7. Write Device Tree binding documentation
8. Test with `iio_info` and `iio_readdev` tools

### 2.3 BMM350 Linux IIO Driver (Weeks 11-13)

**Goal**: Kernel driver for Bosch BMM350 magnetometer with IIO interface.

**Sensor Characteristics**:
- BMM350: 3-axis magnetometer
- Interface: I2C or SPI
- Features: Low noise, high resolution

**IIO Channels**:
```c
IIO_CHAN(IIO_MAGN, X, "magn_x", 0)
IIO_CHAN(IIO_MAGN, Y, "magn_y", 1)
IIO_CHAN(IIO_MAGN, Z, "magn_z", 2)
IIO_CHAN_TIMESTAMP(3)
```

**Package Structure** (`kmodules/kmod-bmm350/`):
```
kmodules/kmod-bmm350/
├── Config.in
├── kmod-bmm350.mk
└── src/
    ├── Kbuild
    ├── bmm350.c
    ├── bmm350.h
    ├── bmm350-i2c.c
    └── bmm350-spi.c
```

**Tasks**:
1. Obtain BMM350 datasheet
2. Implement driver following existing bmm150 pattern
3. Add IIO triggered buffer support
4. Test magnetic field readings

### 2.4 Device Tree Overlay for Cape (Weeks 13-14)

**Goal**: Complete Device Tree configuration for Skylark cape.

**Deliverables**:
- [ ] Main DT overlay for cape
- [ ] Pin mux configuration
- [ ] PRU node configuration
- [ ] Sensor nodes

**Overlay Structure** (`board/skylark/dts/skylark-cape.dts`):
```dts
// skylark-cape.dts
/dts-v1/;
/plugin/;

&{/} {
    compatible = "ti,beaglebone-black";
    
    /* Cape identification */
    skylark_cape {
        compatible = "skylark,cape";
        version = "HW-1.2";
    };
};

/* Pin Mux */
&am33xx_pinmux {
    skylark_pins: skylark_pins {
        pinctrl-single,pins = <
            /* PRU0 outputs (servo PWM) */
            AM33XX_IOPAD(0x990, PIN_OUTPUT | MUX_MODE5)  /* P9_31 pru0_pru_r30_0 */
            AM33XX_IOPAD(0x994, PIN_OUTPUT | MUX_MODE5)  /* P9_29 pru0_pru_r30_1 */
            /* ... more servo pins ... */
            
            /* SPI0 for BHI360 */
            AM33XX_IOPAD(0x950, PIN_INPUT | MUX_MODE0)   /* P9_22 spi0_sclk */
            AM33XX_IOPAD(0x954, PIN_OUTPUT | MUX_MODE0)  /* P9_21 spi0_d0 */
            AM33XX_IOPAD(0x958, PIN_INPUT | MUX_MODE0)   /* P9_18 spi0_d1 */
            AM33XX_IOPAD(0x95c, PIN_OUTPUT | MUX_MODE0)  /* P9_17 spi0_cs0 */
            
            /* I2C2 for BMM350 */
            AM33XX_IOPAD(0x978, PIN_INPUT | MUX_MODE3)   /* P9_24 i2c2_sda */
            AM33XX_IOPAD(0x97c, PIN_INPUT | MUX_MODE3)   /* P9_26 i2c2_scl */
            
            /* BHI360 interrupt */
            AM33XX_IOPAD(0x878, PIN_INPUT | MUX_MODE7)   /* P9_12 gpio1_28 */
        >;
    };
};

/* SPI0 with BHI360 */
&spi0 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&skylark_pins>;
    
    bhi360: imu@0 {
        compatible = "bosch,bhi360";
        reg = <0>;
        spi-max-frequency = <10000000>;
        interrupt-parent = <&gpio1>;
        interrupts = <28 IRQ_TYPE_EDGE_RISING>;
    };
};

/* I2C2 with BMM350 */
&i2c2 {
    status = "okay";
    clock-frequency = <400000>;
    
    bmm350: magnetometer@14 {
        compatible = "bosch,bmm350";
        reg = <0x14>;
    };
};

/* PRU configuration */
&pruss {
    status = "okay";
};

&pru0 {
    status = "okay";
    firmware-name = "skylark-pru0-servo.fw";
};

&pru1 {
    status = "okay";
    firmware-name = "skylark-pru1-can.fw";
};
```

---

## Phase 3: PRU Firmware (Weeks 10-16)

### 3.1 PRU0 Servo PWM Firmware (Weeks 10-13)

**Goal**: Real-time PWM generation for up to 8 servo channels.

**Requirements**:
- 50Hz update rate (20ms period)
- 1-2ms pulse width range
- < 1µs jitter
- Shared memory interface for position updates

**Shared Memory Layout**:
```c
// Shared RAM at 0x00010000
struct pru_servo_shared {
    uint32_t magic;              // 0x00: 'SERV' validation
    uint32_t version;            // 0x04: Protocol version
    uint32_t flags;              // 0x08: Control flags
    uint32_t update_counter;     // 0x0C: Incremented by ARM on update
    uint32_t ack_counter;        // 0x10: Incremented by PRU on read
    uint32_t pulse_us[8];        // 0x14-0x30: Pulse widths (1000-2000µs)
    uint32_t failsafe_us[8];     // 0x34-0x50: Failsafe positions
    uint32_t timeout_ms;         // 0x54: Failsafe timeout (default 500ms)
    uint32_t last_update_time;   // 0x58: Timestamp of last ARM update
} __attribute__((packed));

// Flags
#define FLAG_ARMED      (1 << 0)
#define FLAG_FAILSAFE   (1 << 1)
```

**PRU Firmware Package** (`package/skylark-pru-firmware/`):
```
package/skylark-pru-firmware/
├── Config.in
├── skylark-pru-firmware.mk
└── src/
    ├── Makefile
    ├── servo/
    │   ├── main.c
    │   └── resource_table.h
    └── can/
        ├── main.c
        └── resource_table.h
```

**Tasks**:
1. Define shared memory interface
2. Implement PRU0 firmware in C
3. Create Linux userspace library for servo control
4. Add systemd service for PRU firmware loading
5. Test with oscilloscope for timing accuracy
6. Integrate with ArduPilot servo HAL

### 3.2 PRU1 CAN Interface (Weeks 13-16)

**Goal**: Software CAN controller on PRU1 for DroneCAN/UAVCAN.

**Note**: This is complex; consider using hardware DCAN if available on cape.

**Shared Memory Layout**:
```c
struct pru_can_shared {
    uint32_t magic;              // 'CAN1'
    uint32_t version;
    uint32_t bitrate;            // CAN bitrate (500000, 1000000)
    uint32_t status;             // CAN controller status
    
    // TX ring buffer
    uint32_t tx_head;
    uint32_t tx_tail;
    struct can_frame tx_buf[32];
    
    // RX ring buffer
    uint32_t rx_head;
    uint32_t rx_tail;
    struct can_frame rx_buf[32];
} __attribute__((packed));
```

**Tasks**:
1. Study CAN 2.0B protocol timing requirements
2. Implement bit-banged CAN TX on PRU
3. Implement CAN RX with bit stuffing
4. Create SocketCAN-compatible interface on Linux side
5. Test with CAN analyzer
6. Integrate with DroneCAN node

---

## Phase 4: ArduPilot Integration (Weeks 14-20)

### 4.1 IIO Sensor Backend (Weeks 14-17)

**Goal**: ArduPilot backend using Linux IIO for IMU/Mag sensors.

**Backend Architecture**:
```
ArduPilot
    |
    v
AP_InertialSensor_IIO  /  AP_Compass_IIO
    |
    v
libiio (userspace)
    |
    v
/sys/bus/iio/devices/iio:deviceX/
    |
    v
BHI360 / BMM350 kernel drivers
    |
    v
Hardware
```

**New Files in ArduPilot**:
```
libraries/AP_InertialSensor/
├── AP_InertialSensor_IIO.h
├── AP_InertialSensor_IIO.cpp
libraries/AP_Compass/
├── AP_Compass_IIO.h
├── AP_Compass_IIO.cpp
```

**ArduPilot Package** (`package/skylark-ardupilot/`):
```makefile
################################################################################
#
# skylark-ardupilot
#
################################################################################

SKYLARK_ARDUPILOT_VERSION = 4.5.0-sky1
SKYLARK_ARDUPILOT_SITE = $(call github,wasyl07,ardupilot,$(SKYLARK_ARDUPILOT_VERSION))
SKYLARK_ARDUPILOT_LICENSE = GPL-3.0
SKYLARK_ARDUPILOT_DEPENDENCIES = libiio python3

define SKYLARK_ARDUPILOT_CONFIGURE_CMDS
    cd $(@D) && ./waf configure --board skylark
endef

define SKYLARK_ARDUPILOT_BUILD_CMDS
    cd $(@D) && ./waf copter
endef

define SKYLARK_ARDUPILOT_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/build/skylark/bin/arducopter \
        $(TARGET_DIR)/usr/bin/arducopter
endef

$(eval $(generic-package))
```

**Tasks**:
1. Fork ArduPilot from upstream
2. Create AP_InertialSensor_IIO backend
3. Create AP_Compass_IIO backend
4. Add Skylark board definition to hwdef.dat
5. Create Buildroot package for ArduPilot
6. Test sensor readings vs reference IMU
7. Calibrate sensor offsets and scales

### 4.2 PRU Servo HAL (Weeks 17-19)

**Goal**: ArduPilot HAL for PRU-based servo output.

**New Files**:
```
libraries/AP_HAL_Linux/
├── RCOutput_PRU.h
├── RCOutput_PRU.cpp
```

**Tasks**:
1. Implement RCOutput_PRU class
2. Add to Skylark board HAL
3. Test servo response to RC input
4. Verify failsafe behavior

### 4.3 Board Definition & Configuration (Weeks 19-20)

**Goal**: Complete ArduPilot board support for Skylark.

**hwdef.dat for Skylark**:
```
# Skylark board definition

# MCU class (Linux)
BOARD_VENDOR    Skylark
BOARD_NAME      BeagleBoneBlack
BOARD_CLASS     LINUX

# IMU
IMU_BACKEND     IIO

# Compass
COMPASS_BACKEND IIO

# Servo output
RCOUTPUT_BACKEND PRU

# Serial ports
SERIAL_ORDER     UART0 UART1 UART2 UART4
UART0_DEVICE     /dev/ttyO0   # Console
UART1_DEVICE     /dev/ttyO1   # GPS
UART2_DEVICE     /dev/ttyO2   # Telemetry
UART4_DEVICE     /dev/ttyO4   # RC input (SBUS)

# CAN
CAN_BACKEND      PRU

# Default parameters
define DEFAULT_SERIAL0_BAUD     115200
define DEFAULT_SERIAL1_BAUD     115200
define DEFAULT_SERIAL2_BAUD     57600
```

**Tasks**:
1. Create hwdef.dat
2. Configure default parameters
3. Build Copter/Plane for Skylark
4. Test basic flight functionality
5. Tune PID loops on test rig

---

## Phase 5: Integration & Testing (Weeks 18-24)

### 5.1 System Image Build (Weeks 18-20)

**Goal**: Complete Buildroot image with all components.

**Final defconfig additions**:
```makefile
# Skylark packages
BR2_PACKAGE_KMOD_BHI360=y
BR2_PACKAGE_KMOD_BMM350=y
BR2_PACKAGE_SKYLARK_PRU_FIRMWARE=y
BR2_PACKAGE_SKYLARK_ARDUPILOT=y
BR2_PACKAGE_SKYLARK_CONFIG=y
```

**Makefile wrapper** (project root):
```makefile
# Skylark Build System
# Wraps Buildroot for convenience

BUILDROOT_DIR := buildroot
OUTPUT_DIR := output
BR2_EXTERNAL := $(CURDIR)/br2-skylark
DEFCONFIG := skylark_bbb_defconfig

.PHONY: all menuconfig linux-menuconfig uboot-menuconfig clean help

all:
	$(MAKE) -C $(OUTPUT_DIR)

menuconfig:
	$(MAKE) -C $(OUTPUT_DIR) menuconfig

linux-menuconfig:
	$(MAKE) -C $(OUTPUT_DIR) linux-menuconfig

uboot-menuconfig:
	$(MAKE) -C $(OUTPUT_DIR) uboot-menuconfig

busybox-menuconfig:
	$(MAKE) -C $(OUTPUT_DIR) busybox-menuconfig

# Save config changes back to defconfig
savedefconfig:
	$(MAKE) -C $(OUTPUT_DIR) savedefconfig
	cp $(OUTPUT_DIR)/defconfig $(BR2_EXTERNAL)/configs/$(DEFCONFIG)

# Initial setup
setup:
	$(MAKE) -C $(BUILDROOT_DIR) BR2_EXTERNAL=$(BR2_EXTERNAL) O=$(CURDIR)/$(OUTPUT_DIR) $(DEFCONFIG)

clean:
	$(MAKE) -C $(OUTPUT_DIR) clean

distclean:
	rm -rf $(OUTPUT_DIR)

# Package rebuild shortcuts
%-rebuild:
	$(MAKE) -C $(OUTPUT_DIR) $@

%-dirclean:
	$(MAKE) -C $(OUTPUT_DIR) $@

# Deploy to target
deploy:
	./scripts/deploy.sh $(BOARD)

bundle:
	$(MAKE) -C $(OUTPUT_DIR)
	@echo "Bundle: $(OUTPUT_DIR)/images/update.raucb"

help:
	@echo "Skylark Build System"
	@echo ""
	@echo "  make setup          - Initial Buildroot configuration"
	@echo "  make                - Build full system image"
	@echo "  make menuconfig     - Configure Buildroot"
	@echo "  make linux-menuconfig - Configure kernel"
	@echo "  make savedefconfig  - Save config to br2-skylark/configs/"
	@echo "  make deploy BOARD=<ip> - Deploy RAUC bundle to target"
	@echo "  make clean          - Clean build"
	@echo "  make distclean      - Remove output directory"
```

**Deploy Script** (`scripts/deploy.sh`):
```bash
#!/bin/bash
set -e

BOARD="${1:-${BOARD_IP}}"
BUNDLE="output/images/update.raucb"

if [ -z "$BOARD" ]; then
    echo "Usage: $0 <board-ip>"
    echo "   or: BOARD_IP=x.x.x.x $0"
    exit 1
fi

echo "=== Building ==="
make

echo "=== Deploying to ${BOARD} ==="
scp -O "${BUNDLE}" root@${BOARD}:/tmp/update.raucb

echo "=== Installing ==="
ssh root@${BOARD} "rauc install /tmp/update.raucb && reboot"

echo "=== Done ==="
echo "Board will reboot. Verify with: ssh root@${BOARD} rauc status"
```

**Tasks**:
1. Finalize defconfig with all packages
2. Create Makefile wrapper for convenience
3. Write deploy script
4. Test complete build cycle
5. Verify all components work together

### 5.2 CI/CD Pipeline (Weeks 20-22)

**Goal**: Automated build and test infrastructure.

**GitHub Actions** (`.github/workflows/build.yml`):
```yaml
name: Skylark Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  release:
    types: [published]

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/skylark/buildroot-builder:latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Setup Buildroot
        run: make setup
      
      - name: Build
        run: make
        env:
          SKYLARK_VERSION: ${{ github.ref_name }}
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: skylark-images
          path: |
            output/images/sdcard.img
            output/images/update.raucb
            output/images/MANIFEST.json
      
      - name: Release artifacts
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v1
        with:
          files: |
            output/images/sdcard.img
            output/images/update.raucb
            output/images/MANIFEST.json

  test-qemu:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: skylark-images
      
      - name: Run QEMU tests
        run: |
          # Boot in QEMU and run smoke tests
          # (BeagleBone Black doesn't have great QEMU support,
          #  so this may be limited to basic userspace tests)
          echo "QEMU tests placeholder"
```

**Docker Builder Image** (`docker/Dockerfile.builder`):
```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    cpio \
    unzip \
    rsync \
    bc \
    libncurses-dev \
    python3 \
    python3-pip \
    file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
```

**Tasks**:
1. Create Docker builder image
2. Set up GitHub Actions workflow
3. Add artifact upload/download
4. Configure release automation
5. Add basic smoke tests

### 5.3 Hardware-in-Loop Testing (Weeks 22-24)

**Goal**: Validate flight controller behavior.

**Test Categories**:
1. **Unit Tests**
   - Driver I/O correctness
   - PRU firmware timing
   - IIO data integrity

2. **Integration Tests**
   - ArduPilot + IIO sensor chain
   - ArduPilot + PRU servo output
   - Update/rollback cycle

3. **HIL Tests**
   - SITL with hardware sensors
   - Motor response curves
   - Failsafe triggers

**Test Framework** (`tests/`):
```
tests/
├── conftest.py           # pytest fixtures
├── env.yaml              # labgrid environment
├── test_boot.py          # Basic boot tests
├── test_rauc.py          # Update/rollback tests
├── test_iio.py           # IIO sensor tests
├── test_pru.py           # PRU servo tests
└── test_ardupilot.py     # ArduPilot integration
```

**Tasks**:
1. Create test harness hardware
2. Write pytest-based test suite
3. Set up labgrid for hardware testing
4. Integrate with CI pipeline
5. Document test procedures

---

## Phase 6: Production Readiness (Weeks 24-28)

### 6.1 Security Hardening

**Tasks**:
- [ ] Secure boot chain (signed U-Boot, kernel)
- [ ] Encrypted data partition (LUKS)
- [ ] RAUC bundle signing with production keys
- [ ] Disable debug interfaces in production
- [ ] Firewall configuration (iptables/nftables)
- [ ] Read-only rootfs (optional)

### 6.2 Documentation

**Deliverables**:
- [ ] Hardware assembly guide
- [ ] Software build instructions
- [ ] Configuration reference
- [ ] API documentation
- [ ] Troubleshooting guide

### 6.3 Release Process

**Release Checklist**:
```markdown
## Pre-Release
- [ ] All CI tests passing
- [ ] Version numbers updated (MANIFEST.json)
- [ ] CHANGELOG.md updated
- [ ] Documentation reviewed

## Release
- [ ] Tag git repositories
- [ ] Build release image
- [ ] Sign RAUC bundle with production keys
- [ ] Upload to release server
- [ ] Update compatibility matrix

## Post-Release
- [ ] Announce release
- [ ] Monitor for issues
- [ ] Update upgrade path documentation
```

---

## Timeline Summary

```
Week  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
      |-------- Phase 1: Foundation --------|
                        |---------- Phase 2: Kernel & Drivers ----------|
                                    |-------- Phase 3: PRU Firmware --------|
                                                |-------- Phase 4: ArduPilot --------|
                                                            |---- Phase 5: Integration ----|
                                                                                |-- Phase 6 --|
```

---

## Risk Register

| Risk                                   | Impact | Probability | Mitigation                                    |
|----------------------------------------|--------|-------------|-----------------------------------------------|
| BHI360 NDA delays datasheet access     | High   | Medium      | Start with public info; parallel BMI160 work  |
| PRU CAN timing too tight               | Medium | Medium      | Fall back to hardware DCAN on cape            |
| ArduPilot IIO latency issues           | High   | Low         | Profile early; use kernel-side buffering      |
| A/B update brick scenario              | High   | Low         | Extensive rollback testing; recovery SD image |
| Hardware revision incompatibility      | Medium | Medium      | Version detection in DT; compatibility matrix |

---

## Open Questions

1. **BHI360 Firmware**: Does Bosch provide a pre-built firmware blob, or does custom
   sensor hub programming require additional tooling?

2. **PRU-CAN vs DCAN**: Is bit-banged CAN on PRU reliable enough for DroneCAN, or
   should the cape include a dedicated CAN transceiver with hardware controller?

3. **IIO Trigger Source**: Use hardware interrupt from BHI360 FIFO watermark, or
   software hrtimer trigger at fixed rate?

4. **Secure Boot**: Is secure boot required for target use case? Adds complexity
   to U-Boot and kernel signing.

5. **OTA Delivery**: Local-only updates (USB/SD), or remote OTA server? Affects
   RAUC configuration and network requirements.

---

## Appendix A: Repository Structure (Target)

```
skylark/
├── README.md
├── Makefile                      # Top-level build wrapper
├── CHANGELOG.md
├── VERSION                       # Current system version
├── buildroot/                    # Buildroot submodule
├── br2-skylark/                  # BR2_EXTERNAL tree
│   ├── external.desc
│   ├── external.mk
│   ├── Config.in
│   ├── configs/
│   │   └── skylark_bbb_defconfig
│   ├── board/skylark/
│   │   ├── genimage.cfg
│   │   ├── boot.cmd
│   │   ├── system.conf
│   │   ├── linux.fragment
│   │   ├── uboot.fragment
│   │   ├── post-build.sh
│   │   ├── post-image.sh
│   │   ├── rauc-keys/
│   │   └── rootfs-overlay/
│   ├── package/
│   │   ├── skylark-ardupilot/
│   │   ├── skylark-pru-firmware/
│   │   └── skylark-config/
│   └── kmodules/
│       ├── kmod-bhi360/
│       └── kmod-bmm350/
├── ardupilot/                    # ArduPilot fork (submodule)
├── BeagleBone-cape/              # KiCad hardware design
├── docs/
│   ├── ROADMAP.md                # This document
│   ├── prus.md                   # PRU documentation
│   ├── hardware/
│   └── software/
├── scripts/
│   ├── deploy.sh
│   ├── flash-sd.sh
│   └── generate-keys.sh
├── tests/
│   ├── conftest.py
│   ├── env.yaml
│   └── test_*.py
└── output/                       # Build output (gitignored)
    └── images/
        ├── sdcard.img
        ├── update.raucb
        └── MANIFEST.json
```

---

## Appendix B: Component Version File Locations

| Component       | Version Source                                    | Format      |
|-----------------|---------------------------------------------------|-------------|
| Cape HW         | BeagleBone-cape/version.txt                       | HW-X.Y      |
| Kernel          | BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE             | K-X.Y.Z     |
| BHI360 Driver   | kmodules/kmod-bhi360/src/bhi360-core.c VERSION    | DRV-X.Y.Z   |
| PRU Firmware    | package/skylark-pru-firmware/VERSION              | PRU-X.Y.Z   |
| ArduPilot       | ardupilot/ArduCopter/version.h                    | AP-X.Y.Z-skyN |
| Buildroot Ext   | br2-skylark/external.desc                         | BR2-X.Y.Z   |
| System Image    | /etc/skylark/MANIFEST.json                        | SYS-X.Y.Z   |

---

## Appendix C: Buildroot Quick Reference

```bash
# Initial setup
git clone --depth 1 --branch 2024.02.x https://git.busybox.net/buildroot/
make setup                         # Configure with skylark_bbb_defconfig

# Build
make                               # Full incremental build
make bundle                        # Build + show output paths

# Configure
make menuconfig                    # Buildroot packages
make linux-menuconfig              # Kernel config
make uboot-menuconfig              # U-Boot config
make busybox-menuconfig            # BusyBox applets
make savedefconfig                 # Save changes to defconfig

# Package operations
make <pkg>-rebuild                 # Recompile + reinstall one package
make <pkg>-dirclean                # Wipe package build dir
make linux-rebuild                 # Rebuild kernel

# Deploy
make deploy BOARD=192.168.1.100    # Build + upload + install + reboot

# On target
rauc status                        # Show slot states
rauc status mark-good              # Mark current slot as good
fw_printenv BOOT_ORDER             # Check boot slot order
fw_setenv BOOT_ORDER "A B"         # Force slot A next boot
```

---

*Document Version: 2.0.0*
*Last Updated: 2026-10-01*
*Build System: Buildroot 2024.02.x*
