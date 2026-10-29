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
| SmartDNS 48.4 | recipe 固定上游 gitlink `1db3543cfaa397cd1115b0479416f73062711a63`，LuCI 固定 `581e5e816d92d3a663b1b2e331e3f21685968cf1`（1.2026.48.2-r2）。core 使用正式 `Release48.4`，Rust include 和固定 codeload 下载已由上游修复；增加 core 必需的 zlib 依赖。 |
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
其 `root` 目录全部 shell 脚本通过宿主 `sh -n` 语法检查；版本管道分别使用
`luci-app-passwall2-26.4.20-r1 ... [installed]` 和
`luci-app-passwall2 - 26.4.20-r1` 人工样本，均解析出 `26.4.20-r1`。
样本检查仅证明现有文本解析，不证明实际 APK 数据库或 Lua 函数已经运行。
源码核对不等于 APK 安装、交叉编译或路由器启动验收；这些运行证据应由构建与设备测试另行记录。

### 下载完整性修复

主仓准备脚本继续从已锁定 feed 的 Git HEAD 读取
`compat/openwrt-25.12.json`。该清单当前为空：新版 SmartDNS 上游 recipe 已修正
Rust include 和 core / WebUI 固定源码下载，不再应用旧 gitlink 的精确替换。
主仓需同步更新 source-lock 中本 feed、recipe / LuCI gitlink，并移除或按版本限定
旧 `SMARTDNS_PATCH` Rust include 替换；否则准备阶段会因为旧行不存在而拒绝继续。

SmartDNS core 使用正式 `Release48.4`（2026-08-05 发布，非 nightly / 预发布），
tag 固定至下表 commit。47 之后包含 use-after-free、HTTP/2 拒绝服务、CA 验证和
HTTP/3 边界处理修复；这里采用完整正式版本，不单独拼接安全补丁。
recipe 与 LuCI 没有正式 GitHub Release，因此采用上述已公开的固定兼容提交。
LuCI 保留原配置和调用路径，新增 DDR 配置及 UDP / QUIC / HTTP3 的 SOCKS5 校验。
两产品继续选择 `smartdns`、`luci-app-smartdns`，不选择 `smartdns-ui`；
WebUI 下载仍准备且必须校验，不能因当前未选用而关闭散列检查。

| 项目 | 固定源码和验证结果 |
| --- | --- |
| SmartDNS core 48.4 | tag `Release48.4`；commit `21c940edc65520849ba03544c5cf8d9cf326e680`；codeload SHA256 `f4cb3ec5d2c49bf9752f717cfa1ae2e393df0a001de7ab626b9039cc0bf3ef52`。 |
| SmartDNS WebUI | commit `1c06fee693434ec7c71f06010d3f87416baba9f0`；codeload SHA256 `7a698dd4826750869429e83d91ce99a4e474d0809588a7f4124ef86875be9b1f`；保留独立解包目录和可选编译功能。 |
| shadowsocksr-libev 2.5.6 | commit `d63ff863800a5645aca4309d5dd5962bd1e95543`；tree `072e78c57a169e3c5a39997150531e450b0e494c`；commit timestamp `1520404505`；`.tar.zst` SHA256 `42dab453a7d8b3737109110083513467bad1cf71a0aaf671452595797b2b59b0`。仅更新 MIRROR_HASH，版本、commit、patches 和内置 src/server 均保留。 |

SmartDNS 的新归档直接使用固定 commit 的 codeload URL，与旧 rawgit 规范归档
属于不同格式，不能混用 SHA256。实际下载的 core / WebUI 归档 SHA256 均与
上游 recipe 一致，并逐项核对归档文件、链接、可执行模式的 Git blob 身份。
LuCI JavaScript 通过 `node --check`，原 `smartdns-call` 通过 `sh -n`。
证据保存在项目 `.evidence/4.0.0/release-update-20261029/smartdns`。
以下 SSR 验证保持前次结论，本次没有改动 SSR。

SSR 同样从固定 Git commit 按官方 rawgit 参数连续归档两次，散列一致；与现场失败文件
的 737 个内容/模式/链接条目完全相符。现场保留的原始 Git tar 元数据也确认同一 commit。
官方 25.12 `dl_github_archive.py` 使用相同固定 commit 和期望散列也正常校验通过。
原 `146fa451...` 散列不匹配当前规范归档，更新依据是固定源码的独立重生成，
不是直接信任失败下载产生的文件。OpenWrt 默认 Prepare 仍会将本包 `src/server` 复制到
解包目录，再应用已有补丁；该本地服务器实现来自原有 ywb94/shadowsocks-libev，
不是此次重新下载的源码，也未在此次修复中改动。

前次 SSR 验证在临时隔离容器中进行；本次 SmartDNS 仅下载固定源码和静态核对，没有修改现有容器、卷、构建现场或缓存。
这些结果证明源码身份和下载归档完整性，不代表组件已编译或设备运行通过。

本次尚待统一完成 x86_64 与 ARM 两平台实际 prepare / download / 交叉编译及运行验收；
尤其需确认 OpenSSL 3.5、zlib、HTTP/2 / DoQ / DoH3 链接与 DNS 转发启动。
未选择的 WebUI 仅认证源码与准备路径，未执行 npm / Cargo 构建，也不表示 Rust 插件运行通过。
