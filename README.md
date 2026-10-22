# BoltWrt Packages

## BoltWrt 4.0.0 / OpenWrt 25.12.6

本 feed 配合 OpenWrt `64900e756efa667774214f9c6b17c113222e01f7`，官方 packages 固定为
`093d551675b1119a06ef224d419905e8d6b2af1a`、LuCI 为
`75a306df84a020c57a631ef5b4c02ace56d93387`、routing 为
`48c808034414a2112cf9d5261a20a320e8d0d170`。

### 保留与官方替换

| 项目 | 处理与用途 |
| --- | --- |
| PassWall2 26.4.20 | 保留代理管理与现有 opkg/apk 双路径；无需批量重写安装检测。 |
| SmartDNS | 保留 gitlink `5cdbd394a29b8b24659c116c49e0565e98d78305`，LuCI gitlink `53c00a368f78cda75486d1551de536fc2e1884f1`。构建准备阶段将 Makefile 中唯一的 `include ../../lang/rust/rust-package.mk` 改为 `include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk`；不得移动整个官方 Rust 目录。 |
| Argon | 保留主题 gitlink `f075cb18cb83d0108a18f79b17888420e3d2d986`。 |
| Go | 移除本地 1.26.2 工具链覆盖，使用官方 Go 1.26.9。第三方源码要求：Xray 1.26；Sing-box 1.24.7；Hysteria 1.24.0 / toolchain 1.25.1；GeoView 1.24.0；xray-plugin 1.25；v2ray-plugin 1.25.5。 |
| Rust | 使用官方 1.96.0；Shadowsocks-rust 1.24.0 声明最低 1.88，ShadowTLS 0.2.25 使用 edition 2021。版本约束满足不代表已经完成交叉编译。 |
| Python | 移除未被两个目标配置选用、也未被本 feed 依赖的旧 PySocks / Unidecode 包，不覆盖官方 Python 基础设施。 |
| Aliyun DDNS | 移除 `ddns-scripts_aliyun`，目标配置使用官方 `ddns-scripts-aliyun`，避免重复拥有更新脚本与 JSON 服务定义。 |
| 其他代理组件 | 保留现有固定版本及校验和；`microsocks`、`sing-box`、`v2ray-geodata`、`xray-core`、`smartdns` 与官方提供者重叠，构建脚本必须明确选择 BoltWrt 提供者；LuCI SmartDNS 同理。 |

### Aliyun DDNS 配置核对

官方包仍使用 `service_name=aliyun.com`，`username` 为 AccessKey ID，`password` 为
AccessKey Secret，IPv4 / IPv6 JSON 均调用 `update_aliyun_com.sh`。
但是官方脚本只按 `@` 拆分域名：子域应填写 `home@example.com`，根域填写
`@example.com`。旧脚本能自动把 `home.example.com` 转换为带 `@` 的形式，官方没有该转换。
因此已有配置需核对 `domain` 后再迁移；尚无带真实账户的升级验收证据。

官方脚本固定使用 HTTPS，旧脚本的 HTTP / 忽略 CA 行为不应视为迁移保证。
旧包 postinst 对 `/etc/ddns/services`、`services_ipv6` 追加的记录不再由官方包维护，
应使用 `/usr/share/ddns/default/aliyun.com.json` 服务定义。

### 最少验证与边界

本次工具链裁决核对了上述固定官方 Makefile、第三方对应版本的 `go.mod` /
`Cargo.toml`、两个目标配置和 DDNS 安装路径。`git diff --check` 用于提交检查。
PassWall2 的包检测保留已有 `/lib/apk/packages/*.list` 和 `apk list` 分支。
源码核对不等于 APK 安装、交叉编译或路由器启动验收；这些运行证据应由构建与设备测试另行记录。
