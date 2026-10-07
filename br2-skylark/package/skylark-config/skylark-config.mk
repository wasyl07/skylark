################################################################################
#
# skylark-config
#
################################################################################

SKYLARK_CONFIG_VERSION = 0.1.0
SKYLARK_CONFIG_SITE = $(BR2_EXTERNAL_SKYLARK_PATH)/package/skylark-config/src
SKYLARK_CONFIG_SITE_METHOD = local
SKYLARK_CONFIG_LICENSE = GPL-3.0
# installed after dropbear: replaces /etc/dropbear with a link to /data
SKYLARK_CONFIG_DEPENDENCIES = $(if $(BR2_PACKAGE_DROPBEAR),dropbear)

define SKYLARK_CONFIG_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/skylark-growdata.sh $(TARGET_DIR)/usr/lib/skylark/growdata.sh
	$(INSTALL) -D -m 0755 $(@D)/skylark-firstboot.sh $(TARGET_DIR)/usr/lib/skylark/firstboot.sh
	$(INSTALL) -D -m 0755 $(@D)/skylark-factory-reset $(TARGET_DIR)/usr/bin/skylark-factory-reset
	$(INSTALL) -D -m 0755 $(@D)/skylark-rtc.sh $(TARGET_DIR)/usr/lib/skylark/rtc.sh
	ln -sf ../lib/skylark/rtc.sh $(TARGET_DIR)/usr/bin/skylark-rtc
	$(INSTALL) -D -m 0644 $(@D)/skylark-rtc.conf $(TARGET_DIR)/etc/skylark/rtc.conf
	$(INSTALL) -D -m 0644 $(@D)/20-eth0.network $(TARGET_DIR)/etc/systemd/network/20-eth0.network
	$(INSTALL) -D -m 0644 $(@D)/80-can.network $(TARGET_DIR)/etc/systemd/network/80-can.network
	$(INSTALL) -D -m 0644 $(@D)/80-can.link $(TARGET_DIR)/etc/systemd/network/80-can.link
	$(INSTALL) -D -m 0644 $(@D)/timesyncd-skylark.conf $(TARGET_DIR)/etc/systemd/timesyncd.conf.d/skylark.conf
	$(INSTALL) -D -m 0644 $(@D)/resolved-mdns.conf $(TARGET_DIR)/etc/systemd/resolved.conf.d/skylark-mdns.conf
	$(INSTALL) -d $(TARGET_DIR)/data
	$(INSTALL) -D -m 0644 $(@D)/dropbear-skylark.conf \
		$(TARGET_DIR)/usr/lib/systemd/system/dropbear.service.d/skylark.conf
	rm -rf $(TARGET_DIR)/etc/dropbear $(TARGET_DIR)/root/.ssh
	ln -sfn /data/ssh/dropbear $(TARGET_DIR)/etc/dropbear
	ln -sfn /data/ssh/root $(TARGET_DIR)/root/.ssh
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
	$(foreach u,skylark-rtc-restore.service skylark-rtc-sync.service skylark-rtc-sync.timer, \
		$(INSTALL) -D -m 0644 $(@D)/$(u) $(TARGET_DIR)/usr/lib/systemd/system/$(u)$(sep))
	mkdir -p $(TARGET_DIR)/usr/lib/systemd/system/sysinit.target.wants \
		$(TARGET_DIR)/usr/lib/systemd/system/timers.target.wants
	ln -sf ../skylark-rtc-restore.service $(TARGET_DIR)/usr/lib/systemd/system/sysinit.target.wants/skylark-rtc-restore.service
	ln -sf ../skylark-rtc-sync.timer $(TARGET_DIR)/usr/lib/systemd/system/timers.target.wants/skylark-rtc-sync.timer
endef

$(eval $(generic-package))
