# 独立 Hysteria2 核心

PassWall 2 的 `INCLUDE_Hysteria` 选择此包。独立节点类型为 `Hysteria2`，
使用 `/usr/bin/hysteria`，启动命令为 `hysteria -c CONFIG client`。
固件同时保留 Sing-box 的 Hysteria2 实现。 [包定义](Makefile)

## 固定来源与兼容

- 正式 [app/v2.13.0](https://github.com/HyNetworks/hysteria/releases/tag/app/v2.13.0)，
  tag object `7fa51f40bf657d62276fd525ed6dacad7a4eee5d`，
  commit `ca8fbd874fd6ca82413948de6dc5924405e103e1`。
- 官方源码归档 4,591,754 字节，SHA256
  `dfde427a93a0dc5ff65ddc1e239df3b1def54bf33f8b137c571daa7b27ecddd0`。
  已完整解码，329 个 Git blob 的内容及可执行／符号链接类型与该固定 commit 树一致。
- app/core/extras 三个模块及根 go.work 均要求 Go 1.26.0；沿用产品 Go 1.26.10，
  不升级工具链或改用 main／RC。包名、app/v2 构建目标、ca-bundle 依赖及安装路径不变。
  上游 `-c`、`client` 与 `Version:` 输出仍兼容 PassWall2 的调用和版本读取。
- PassWall2 r4 修复该后端的两个实际字段契约：输出 `fastOpen`，并仅将 UCI
  字符串 `"1"` 解释为关闭 PMTU 探测。缺省／空值／`"0"` 均为 false。
  四组 Lua 5.1 生成器回归使用合成 UCI 与 JSON 序列化器，实际核心与浏览器结果见下文。

## 安全更新边界

旧 2.8.1 位于官方服务端公告范围：[UDP ACL 绕过](https://github.com/HyNetworks/hysteria/security/advisories/GHSA-vgrc-hq28-p3xp)、
[DATAGRAM 导致崩溃](https://github.com/HyNetworks/hysteria/security/advisories/GHSA-qh5x-rfwf-rvfv)、
[HTTP sniff 内存耗尽](https://github.com/HyNetworks/hysteria/security/advisories/GHSA-jqc5-2p7q-fqfc)。
前三项给出的修复版本为 2.9.2，2.13.0 包含该正式安全更新；
[2.9.2 发布说明](https://github.com/HyNetworks/hysteria/releases/tag/app/v2.9.2)同时列出相关 ACL／sniff 修复。
[较早 QUIC sniff OOM 公告](https://github.com/HyNetworks/hysteria/security/advisories/GHSA-9fw6-xgg2-mq9q)
未标出修复版本；当前 2.13.0 已改用按实际数据长度验证的 CRYPTO 帧解析和有界包数，
这里只记录源码差异，不把它提升为完整服务端安全认证。
上述服务端条件不应机械套用为 PassWall2 client 调用已可被同样利用。

2.13.0 的 uTLS 1.8.2 已达到 [GO-2026-4512](https://pkg.go.dev/vuln/GO-2026-4512)、
[GO-2026-4509](https://pkg.go.dev/vuln/GO-2026-4509) 和
[GO-2025-3638](https://pkg.go.dev/vuln/GO-2025-3638) 的修复阈值。
保留上游固定依赖，不因模块版本告警无条件替换整个依赖树。
compress 1.17.9 的 [GO-2026-5841](https://pkg.go.dev/vuln/GO-2026-5841) 针对 `s2.NewDict`；
x/net 0.57.0 的 [GO-2026-6860](https://pkg.go.dev/vuln/GO-2026-6860)／
[GO-2026-6866](https://pkg.go.dev/vuln/GO-2026-6866) 针对 HTML Parse／Render。
这三项公告涉及 `github.com/klauspost/compress/s2` 和 `golang.org/x/net/html` 中的实现。

## 2026-11-06 产品验收

固件 `7d1c6614` 与 Packages `fbb14623` 的两个目标均完成 Go 1.26.10 构建及 APK／镜像核对。
实际 arm64 与 amd64 生产编译依赖图分别包含 543 和 546 个包，两者均未纳入上述 `s2` 与
`html` 实现。该结论限于这三项公告及所用构建配置。

RAX 的 ARM 用户态确认独立核心版本 `v2.13.0`，x86 的实际 LuCI／ubus 用例覆盖独立
Hysteria2 和 Sing-box 的节点持久化、配置生成及核心加载。结果限于本地软件测试。
[原始依赖、产物及运行记录](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/docs/4.0.0-hysteria-validation.md)
