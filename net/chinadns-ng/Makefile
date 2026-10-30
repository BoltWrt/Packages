include $(TOPDIR)/rules.mk

PKG_NAME:=chinadns-ng
PKG_VERSION:=2025.08.09
PKG_RELEASE:=2
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/zfl9/chinadns-ng/tar.gz/refs/tags
PKG_SOURCE_URL_FILE:=$(PKG_VERSION)
PKG_HASH:=b7c76725e1635a047f1cfda31df3cc2702ae2abca55ed96e52da3fc979a107be
PKG_BUILD_DEPENDS:=chinadns-zig/host
PKG_BUILD_PARALLEL:=0

WOLFSSL_VERSION:=5.9.4
WOLFSSL_SOURCE:=wolfssl-$(WOLFSSL_VERSION).zip
CHINADNS_ZIG:=$(STAGING_DIR_HOSTPKG)/lib/chinadns-zig/zig
CHINADNS_NOASM:=false

ifeq ($(ARCH),aarch64)
  ifeq ($(BOARD),rockchip)
    CHINADNS_TARGET:=aarch64-linux-musl
    CHINADNS_CPU:=generic+v8a
  else
    CHINADNS_TARGET:=aarch64-linux-musl
    CHINADNS_CPU:=generic+v8a
    CHINADNS_NOASM:=true
  endif
else ifeq ($(ARCH),arm)
  ifeq ($(CONFIG_arm_v6),y)
    CHINADNS_TARGET:=arm-linux-musleabi
    CHINADNS_CPU:=generic+v6+soft_float
  else ifeq ($(CONFIG_arm_v7),y)
    ifeq ($(CONFIG_HAS_FPU),y)
      CHINADNS_TARGET:=arm-linux-musleabihf
      CHINADNS_CPU:=generic+v7a
    else
      CHINADNS_TARGET:=arm-linux-musleabi
      CHINADNS_CPU:=generic+v6+soft_float
    endif
  else
    CHINADNS_TARGET:=arm-linux-musleabi
    CHINADNS_CPU:=generic+v5te+soft_float
  endif
else ifeq ($(ARCH),mips)
  CHINADNS_TARGET:=mips-linux-musl
  CHINADNS_CPU:=mips32+soft_float
else ifeq ($(ARCH),mipsel)
  ifeq ($(CONFIG_HAS_FPU),)
    CHINADNS_TARGET:=mipsel-linux-musl
    CHINADNS_CPU:=mips32+soft_float
  else
    CHINADNS_TARGET:=mipsel-linux-musl
    CHINADNS_CPU:=mips32
  endif
else ifeq ($(ARCH),mips64)
  CHINADNS_TARGET:=mips64-linux-musl
  CHINADNS_CPU:=mips64+soft_float
else ifeq ($(ARCH),mips64el)
  CHINADNS_TARGET:=mips64el-linux-musl
  CHINADNS_CPU:=mips64+soft_float
else ifeq ($(ARCH),i386)
  ifneq ($(CONFIG_TARGET_x86_geode)$(CONFIG_TARGET_x86_legacy),)
    CHINADNS_TARGET:=i386-linux-musl
    CHINADNS_CPU:=i686
  else
    CHINADNS_TARGET:=i386-linux-musl
    CHINADNS_CPU:=pentium4
  endif
else ifeq ($(ARCH),x86_64)
  CHINADNS_TARGET:=x86_64-linux-musl
  CHINADNS_CPU:=x86_64
else ifeq ($(ARCH),riscv64)
  CHINADNS_TARGET:=riscv64-linux-musl
  CHINADNS_CPU:=baseline_rv64
endif

PKG_LICENSE:=AGPL-3.0-only GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE dep/wolfssl-$(WOLFSSL_VERSION)-stable/COPYING dep/wolfssl-$(WOLFSSL_VERSION)-stable/LICENSING
PKG_MAINTAINER:=sbwml <admin@cooluc.com>

include $(INCLUDE_DIR)/package.mk

define Download/chinadns-wolfssl
  FILE:=$(WOLFSSL_SOURCE)
  URL:=https://www.wolfssl.com
  HASH:=9cd0d69d208d025b16836c177658cc0deebc2a85c4b60898c9bc546bc6cbdf18
endef
$(eval $(call Download,chinadns-wolfssl))

define Package/chinadns-ng
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=ChinaDNS next generation, refactoring with epoll and ipset.
  URL:=https://github.com/zfl9/chinadns-ng
  DEPENDS:=@(aarch64||arm||i386||mips||mipsel||mips64||mips64el||x86_64||riscv64)
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/dep
	unzip -q $(DL_DIR)/$(WOLFSSL_SOURCE) -d $(PKG_BUILD_DIR)/dep
	$(MV) $(PKG_BUILD_DIR)/dep/wolfssl-$(WOLFSSL_VERSION) $(PKG_BUILD_DIR)/dep/wolfssl-$(WOLFSSL_VERSION)-stable
endef

define Build/Configure
	[ -n "$(CHINADNS_TARGET)" ] || { echo 'Unsupported chinadns-ng target'; exit 1; }
	printf '%s\n' \
		'include_dir=$(TOOLCHAIN_DIR)/include' \
		'sys_include_dir=$(TOOLCHAIN_DIR)/include' \
		'crt_dir=$(TOOLCHAIN_DIR)/lib' \
		'msvc_lib_dir=' 'kernel32_lib_dir=' 'gcc_dir=' \
		> $(PKG_BUILD_DIR)/openwrt-musl.conf
endef

# The upstream build only uses Zig and libc. Explicit --libc makes both Zig
# objects use the locked OpenWrt target musl, never Zig's bundled one.
# wolfSSL uses OpenWrt GCC without GCC LTO, then links as one exact static archive.
# Dependency archives are supplied by OpenWrt Download with fixed SHA-256 values;
# the patched Zig build fails closed if an archive is missing.
define Build/Compile
	cd $(PKG_BUILD_DIR) && \
		ZIG_LOCAL_CACHE_DIR=$(PKG_BUILD_DIR)/zig-cache \
		ZIG_GLOBAL_CACHE_DIR=$(PKG_BUILD_DIR)/zig-cache \
		CHINADNS_WOLFSSL_CC="$(TARGET_CC) $(filter-out -flto% -fuse-linker-plugin,$(TARGET_CFLAGS))" \
		CHINADNS_WOLFSSL_CPPFLAGS="$(TARGET_CPPFLAGS)" \
		CHINADNS_WOLFSSL_AR="$(TARGET_AR)" \
		CHINADNS_WOLFSSL_RANLIB="$(TARGET_RANLIB)" \
		$(if $(filter mips mipsel,$(ARCH)),MIPS_M_ARCH=mips32 MIPS_SOFT_FP=$(if $(CONFIG_HAS_FPU),0,1)) \
		$(CHINADNS_ZIG) build \
			--libc $(PKG_BUILD_DIR)/openwrt-musl.conf \
			-Dtarget=$(CHINADNS_TARGET) -Dcpu=$(CHINADNS_CPU) \
			-Dwolfssl=true -Dwolfssl-noasm=$(CHINADNS_NOASM) \
			-Dmode=fast -Dlto=true -Dname=chinadns-ng
endef

define Package/chinadns-ng/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/zig-out/bin/chinadns-ng $(1)/usr/bin
endef

$(eval $(call BuildPackage,chinadns-ng))
