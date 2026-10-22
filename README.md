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
其 `root` 目录全部 shell 脚本通过宿主 `sh -n` 语法检查；版本管道分别使用
`luci-app-passwall2-26.4.20-r1 ... [installed]` 和
`luci-app-passwall2 - 26.4.20-r1` 人工样本，均解析出 `26.4.20-r1`。
样本检查仅证明现有文本解析，不证明实际 APK 数据库或 Lua 函数已经运行。
源码核对不等于 APK 安装、交叉编译或路由器启动验收；这些运行证据应由构建与设备测试另行记录。

### 下载完整性修复

主仓准备脚本必须从已锁定 feed 的 Git HEAD 读取并应用
`compat/openwrt-25.12.json`，同时保留已有 SmartDNS Rust include 修正。
该清单只针对 gitlink `5cdbd394a29b8b24659c116c49e0565e98d78305` 的 Makefile，
以完整旧行唯一匹配替换；不得直接修改子模块提交或接受未知文件变化。

SmartDNS WebUI 的 `Download` 块原来填写 `VERSION`，而 OpenWrt 25.12 下载器读取
`SOURCE_VERSION`。实际失败日志因此出现空 `--version` / 空 `git checkout`，
下载了滚动 main `1c06fee693434ec7c71f06010d3f87416baba9f0`，并非 recipe 声明的源码。
清单修正字段名，并锁定下表中经验证的归档散列；保留 WebUI 功能及原来声明的源码提交。

| 项目 | 固定源码和验证结果 |
| --- | --- |
| SmartDNS WebUI 1.0.0 | commit `3261c18b1b93d841e86d9e727557109ae71d71cd`；tree `190f76f34cfda865389b27e8f69887aa6a64edc3`；commit timestamp `1766583635`；归档 SHA256 `4401734712dd034eb1088ce440d1bc64d053dfcd6f63f66c08cd48ab68593042`。 |
| shadowsocksr-libev 2.5.6 | commit `d63ff863800a5645aca4309d5dd5962bd1e95543`；tree `072e78c57a169e3c5a39997150531e450b0e494c`；commit timestamp `1520404505`；`.tar.zst` SHA256 `42dab453a7d8b3737109110083513467bad1cf71a0aaf671452595797b2b59b0`。仅更新 MIRROR_HASH，版本、commit、patches 和内置 src/server 均保留。 |

WebUI 验证采用两条路径：浅抓取固定 Git commit、按 OpenWrt 25.12 rawgit 的
git archive / 固定时间 / 排序 / gzip 参数连续生成两次，散列一致；另外从 codeload
下载固定 commit，全部 109 个文件/链接的 Git blob SHA1 和模式与 GitHub REST 的
固定 tree 一致，归一化后的散列也相同。官方 25.12 `dl_github_archive.py` 使用固定
commit 和上述期望散列正常下载及校验通过。失败的滚动归档与正确导出有 14 项差异，
其 `88adb092...` 散列不被接受。

SSR 同样从固定 Git commit 按官方 rawgit 参数连续归档两次，散列一致；与现场失败文件
的 737 个内容/模式/链接条目完全相符。现场保留的原始 Git tar 元数据也确认同一 commit。
官方 25.12 `dl_github_archive.py` 使用相同固定 commit 和期望散列也正常校验通过。
原 `146fa451...` 散列不匹配当前规范归档，更新依据是固定源码的独立重生成，
不是直接信任失败下载产生的文件。OpenWrt 默认 Prepare 仍会将本包 `src/server` 复制到
解包目录，再应用已有补丁；该本地服务器实现来自原有 ywb94/shadowsocks-libev，
不是此次重新下载的源码，也未在此次修复中改动。

上述验证在临时隔离容器中进行，现有构建卷只读挂载，无 `skip` 校验或主现场改动。
这些结果证明源码身份和下载归档完整性，不代表组件已编译或设备运行通过。
