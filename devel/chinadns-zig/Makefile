# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk

PKG_NAME:=chinadns-zig
PKG_VERSION:=0.10.1
PKG_RELEASE:=1
PKG_HOST_ONLY:=1
PKG_LICENSE:=MIT

# The coroutine implementation in chinadns-ng requires Zig's 0.10.1 stage1.
# Keep this private toolchain in host staging; never install it on the host OS.
CHINADNS_ZIG_ARCH:=$(if $(filter arm64 aarch64,$(HOST_ARCH)),aarch64,$(HOST_ARCH))
ifeq ($(CHINADNS_ZIG_ARCH),x86_64)
  PKG_HASH:=6699f0e7293081b42428f32c9d9c983854094bd15fee5489f12c4cf4518cc380
else ifeq ($(CHINADNS_ZIG_ARCH),aarch64)
  PKG_HASH:=db0761664f5f22aa5bbd7442a1617dd696c076d5717ddefcc9d8b95278f71f5d
else
  PKG_HASH:=unsupported
endif

PKG_SOURCE:=zig-linux-$(CHINADNS_ZIG_ARCH)-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://ziglang.org/download/$(PKG_VERSION)
HOST_BUILD_DIR:=$(BUILD_DIR_HOST)/zig-linux-$(CHINADNS_ZIG_ARCH)-$(PKG_VERSION)

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk

define Package/chinadns-zig
  SECTION:=devel
  CATEGORY:=Development
  TITLE:=Pinned Zig toolchain for chinadns-ng (host only)
  BUILDONLY:=1
endef

define Host/Configure
	[ "$(HOST_OS)" = Linux ] || { echo 'chinadns-zig requires a Linux build container'; exit 1; }
	case "$(CHINADNS_ZIG_ARCH)" in x86_64|aarch64) ;; *) echo 'Unsupported chinadns-zig build host'; exit 1;; esac
endef

define Host/Compile
	$(HOST_BUILD_DIR)/zig version | grep -qx '$(PKG_VERSION)'
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/chinadns-zig
	$(CP) $(HOST_BUILD_DIR)/zig $(HOST_BUILD_DIR)/lib $(STAGING_DIR_HOSTPKG)/lib/chinadns-zig/
endef

define Host/Clean
	rm -rf $(STAGING_DIR_HOSTPKG)/lib/chinadns-zig
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,chinadns-zig))
