#
# Copyright (C) 2017-2020 Yousong Zhou <yszhou4tech@gmail.com>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

# Checklist when bumping versions
#
# - update cipher list by checking src/crypto.c:crypto_init()
# - check if default mode has changed from being tcp_only
#
PKG_NAME:=shadowsocks-libev
PKG_VERSION:=3.3.6
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/shadowsocks/shadowsocks-c/releases/download/v$(PKG_VERSION)
PKG_HASH:=ee83b43b36d6a51cfbee72254b6088d4b625feadf06cc2f0bcb810c8236438a5

PKG_MAINTAINER:=Yousong Zhou <yszhou4tech@gmail.com>

PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:shadowsocks:shadowsocks-libev

PKG_INSTALL:=1
PKG_BUILD_FLAGS:=no-mips16 lto
PKG_BUILD_PARALLEL:=1
PKG_BUILD_DEPENDS:=c-ares pcre2

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

# The official source asset omits its Git submodules. Pin the exact gitlinks
# from v3.3.6 rather than resolving moving dependency branches at build time.
LIBCORK_COMMIT:=074e074b26e9e372e90e6ade215217763c8644aa
LIBIPSET_COMMIT:=3ea7fe30adf4b39b27d932e5a70a2ddce4adb508
LIBBLOOM_COMMIT:=437e1add5a2b9a87797d8c648df7cf5f3ee155a8

define Download/ss-libcork
  FILE:=libcork-$(LIBCORK_COMMIT).tar.gz
  URL:=https://codeload.github.com/shadowsocks/libcork/tar.gz/$(LIBCORK_COMMIT)?
  HASH:=f8e4b637f35bbe0bc5d893164e439aefa61d2b6fe58b0a79c30e42f5f54f08e0
endef
define Download/ss-libipset
  FILE:=libipset-$(LIBIPSET_COMMIT).tar.gz
  URL:=https://codeload.github.com/shadowsocks/ipset/tar.gz/$(LIBIPSET_COMMIT)?
  HASH:=89be31c635814948c0887f660d2a98f4bc4b1dc6691a57d653c2466a8098f887
endef
define Download/ss-libbloom
  FILE:=libbloom-$(LIBBLOOM_COMMIT).tar.gz
  URL:=https://codeload.github.com/shadowsocks/libbloom/tar.gz/$(LIBBLOOM_COMMIT)?
  HASH:=6e0131faa238c5dd15da4b43931d2f628590ba07e1177a47ead8e4dd18752459
endef
$(eval $(call Download,ss-libcork))
$(eval $(call Download,ss-libipset))
$(eval $(call Download,ss-libbloom))

define Package/shadowsocks-libev/Default
  define Package/shadowsocks-libev-$(1)
    SECTION:=net
    CATEGORY:=Network
    SUBMENU:=Web Servers/Proxies
    TITLE:=shadowsocks-libev $(1)
    URL:=https://github.com/shadowsocks/shadowsocks-libev
    DEPENDS:=+libev +libmbedtls +libpthread +libsodium $(DEPENDS_$(1))
  endef

  define Package/shadowsocks-libev-$(1)/install
	$$(INSTALL_DIR) $$(1)/usr/bin
	$$(INSTALL_BIN) $$(PKG_INSTALL_DIR)/usr/bin/$(1) $$(1)/usr/bin
  endef

endef

DEPENDS_ss-local = +libpcre2
DEPENDS_ss-server = +libcares +libpcre2

SHADOWSOCKS_COMPONENTS:=ss-local ss-redir ss-tunnel ss-server
define shadowsocks-libev/templates
  $(foreach component,$(SHADOWSOCKS_COMPONENTS),
    $(call Package/shadowsocks-libev/Default,$(component))
  )
endef
$(eval $(call shadowsocks-libev/templates))

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/libcork $(PKG_BUILD_DIR)/libipset $(PKG_BUILD_DIR)/libbloom
	$(TAR) -C $(PKG_BUILD_DIR)/libcork --strip-components=1 -xzf $(DL_DIR)/libcork-$(LIBCORK_COMMIT).tar.gz
	$(TAR) -C $(PKG_BUILD_DIR)/libipset --strip-components=1 -xzf $(DL_DIR)/libipset-$(LIBIPSET_COMMIT).tar.gz
	$(TAR) -C $(PKG_BUILD_DIR)/libbloom --strip-components=1 -xzf $(DL_DIR)/libbloom-$(LIBBLOOM_COMMIT).tar.gz
endef

CMAKE_OPTIONS += \
	-DWITH_STATIC=OFF \
	-DWITH_EMBEDDED_SRC=ON \
	-DWITH_SS_MANAGER=OFF \
	-DWITH_SS_REDIR=ON \
	-DCMAKE_BUILD_TYPE=Release

TARGET_LDFLAGS += -Wl,--gc-sections,--as-needed

$(foreach component,$(SHADOWSOCKS_COMPONENTS), \
  $(eval $(call BuildPackage,shadowsocks-libev-$(component))) \
)
