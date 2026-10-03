# Skylark build wrapper around Buildroot
BUILDROOT_DIR := $(CURDIR)/buildroot-2025.02.15
OUTPUT_DIR    := $(CURDIR)/output
BR2_EXTERNAL  := $(CURDIR)/br2-skylark
DEFCONFIG     := skylark_bbb_defconfig
BR_MAKE       := $(MAKE) -C $(BUILDROOT_DIR) O=$(OUTPUT_DIR) BR2_EXTERNAL=$(BR2_EXTERNAL)

.PHONY: all setup menuconfig linux-menuconfig uboot-menuconfig savedefconfig clean distclean help flash

all: $(OUTPUT_DIR)/.config
	$(BR_MAKE)

$(OUTPUT_DIR)/.config:
	$(BR_MAKE) $(DEFCONFIG)

setup:
	$(BR_MAKE) $(DEFCONFIG)

menuconfig linux-menuconfig uboot-menuconfig busybox-menuconfig: $(OUTPUT_DIR)/.config
	$(BR_MAKE) $@

savedefconfig:
	$(BR_MAKE) savedefconfig BR2_DEFCONFIG=$(BR2_EXTERNAL)/configs/$(DEFCONFIG)

%-rebuild %-reconfigure %-dirclean:
	$(BR_MAKE) $@

clean:
	$(BR_MAKE) clean

distclean:
	rm -rf $(OUTPUT_DIR)

# make flash DEV=/dev/sdX
flash:
	@test -n "$(DEV)" || (echo "usage: make flash DEV=/dev/sdX"; exit 1)
	sudo dd if=$(OUTPUT_DIR)/images/sdcard.img of=$(DEV) bs=4M conv=fsync status=progress

help:
	@echo "make            build output/images/sdcard.img + update.raucb"
	@echo "make setup      (re)apply $(DEFCONFIG)"
	@echo "make menuconfig | linux-menuconfig | uboot-menuconfig | savedefconfig"
	@echo "make <pkg>-rebuild"
	@echo "make flash DEV=/dev/sdX"
