# BoltWrt Packages

本仓库提供 BoltWrt 固件使用的 OpenWrt 构建 feed。设备端安装使用与所刷固件及架构匹配的 APK。固件下载、安装和升级见主仓用户指南。 [BoltWrt](https://github.com/BoltWrt/BoltWrt)

## 构建与维护

BoltWrt 4.0.0 使用 OpenWrt 25.12.6。固件构建使用对应版本源码锁中的 Packages 提交、官方 feeds 和三个子模块 gitlink。发布版本的复现以标签中的锁为准。 [v4.0.0 源码锁](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/config/source-lock.json)

- 在固件构建树中使用 `scripts/boltwrt-prepare.py`。它按二进制包名优先选择 BoltWrt 的同名 provider，包括 SmartDNS、LuCI SmartDNS、Sing-box、Xray、规则数据和 microsocks。需要用本地候选时，先同步固件构建树中的锁与 feed 配置，再传入 `--local-feed` 指向包含候选提交的本地仓库。 [准备脚本](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/scripts/boltwrt-prepare.py)
- Argon、SmartDNS recipe 和 LuCI SmartDNS 以 gitlink 固定。单独检查 feed 时可用 `git submodule update --init` 检出子模块。变更 gitlink 时同步核对固件锁和兼容清单。4.0.0 所用 feed 的兼容清单未定义子模块替换，SmartDNS recipe 自身处理固定源码下载和 Rust include。 [子模块](.gitmodules) · [兼容清单](compat/openwrt-25.12.json)
- Aliyun DDNS 使用官方 `ddns-scripts-aliyun`，服务名为 `aliyun.com`。固件负责把支持的旧格式迁移到 `RR@DOMAIN`，例如 `home@example.com` 或 `@example.com`。 [固件迁移脚本](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/package/boltwrt-defaults/files/etc/uci-defaults/95-boltwrt-aliyun)
- Go 与 Rust 使用固件锁定的工具链。4.0.0 的准备脚本在官方 Go recipe 上应用 1.26.10 的固定更新。调整 Go 组件时按实际目标验证依赖、编译和产物 buildinfo。

## 组件文档

| 组件 | 维护入口 |
| --- | --- |
| PassWall 2 | [后端选择、配置兼容和回归测试](luci/applications/luci-app-passwall2/README.md) |
| Hysteria2 独立核心 | [固定来源、安全复核及实际依赖范围](net/hysteria/SECURITY-AUDIT.md) |
| v2ray-plugin | [gRPC、Go 工具链及安全复核](net/v2ray-plugin/SECURITY-AUDIT.md) |
| SmartDNS 与 Argon | [SmartDNS recipe](net/openwrt-smartdns) · [LuCI SmartDNS](luci/applications/luci-app-smartdns) · [Argon](luci/theme/luci-theme-argon) |

## 验证记录

按变更范围分别核对固定归档及散列、配置解析和 provider、目标 APK／镜像中的实际载荷，以及受影响的运行行为。记录实际输入与测试层级。归档校验、静态包检查和客体运行各自保留结果。 [4.0.0 双目标构建与运行原始记录](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/docs/4.0.0-hysteria-validation.md)

早期 SmartDNS／SSR 下载完整性、旧 provider 迁移和 2026-10-29 的安全更新仍可按原输入查阅。 [4.0.0 锁定 feed 的原 README](https://github.com/BoltWrt/Packages/blob/45ad2e027ad925eb084231421bb6a7576aa099e3/README.md) · [发布前包清单及兼容裁决](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/docs/4.0.0-release-readiness.md)
