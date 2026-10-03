################################################################################
#
# skylark-config
#
################################################################################

SKYLARK_CONFIG_VERSION = 0.1.0
SKYLARK_CONFIG_SITE = $(BR2_EXTERNAL_SKYLARK_PATH)/package/skylark-config/src
SKYLARK_CONFIG_SITE_METHOD = local
SKYLARK_CONFIG_LICENSE = GPL-3.0

define SKYLARK_CONFIG_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/skylark-growdata.sh $(TARGET_DIR)/usr/lib/skylark/growdata.sh
	$(INSTALL) -D -m 0755 $(@D)/skylark-firstboot.sh $(TARGET_DIR)/usr/lib/skylark/firstboot.sh
	$(INSTALL) -D -m 0755 $(@D)/skylark-factory-reset $(TARGET_DIR)/usr/bin/skylark-factory-reset
	$(INSTALL) -d $(TARGET_DIR)/data
endef

define SKYLARK_CONFIG_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/skylark-growdata.service $(TARGET_DIR)/usr/lib/systemd/system/skylark-growdata.service
	$(INSTALL) -D -m 0644 $(@D)/skylark-firstboot.service $(TARGET_DIR)/usr/lib/systemd/system/skylark-firstboot.service
	$(INSTALL) -D -m 0644 $(@D)/data.mount $(TARGET_DIR)/usr/lib/systemd/system/data.mount
	$(INSTALL) -D -m 0644 $(@D)/rauc-mark-good.service $(TARGET_DIR)/usr/lib/systemd/system/rauc-mark-good.service
	mkdir -p $(TARGET_DIR)/usr/lib/systemd/system/local-fs.target.wants \
		$(TARGET_DIR)/usr/lib/systemd/system/multi-user.target.wants
	ln -sf ../data.mount $(TARGET_DIR)/usr/lib/systemd/system/local-fs.target.wants/data.mount
	ln -sf ../skylark-firstboot.service $(TARGET_DIR)/usr/lib/systemd/system/multi-user.target.wants/skylark-firstboot.service
	ln -sf ../rauc-mark-good.service $(TARGET_DIR)/usr/lib/systemd/system/multi-user.target.wants/rauc-mark-good.service
endef

$(eval $(generic-package))
