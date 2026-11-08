# PassWall 2 维护说明

BoltWrt 4.0.0 使用下游 `26.4.20-r4`，保留原有节点类型、配置选项和后端。2026-10-29 评估的上游 `26.10.29-1` 移除了 Shadowsocks-libev 客户端选择，以及独立 Hysteria、NaiveProxy 和 TUIC 接入路径，因此在 26.4.20 上回迁所需变更。 [版本与依赖](Makefile) · [当时的上游对比和回归记录](https://github.com/BoltWrt/Packages/blob/45ad2e027ad925eb084231421bb6a7576aa099e3/luci/applications/luci-app-passwall2/README.boltwrt-update.md)

## 固件使用的后端

以下选项是 `CONFIG_PACKAGE_luci-app-passwall2_` 后缀，实际选用以固件公共配置为准。 [v4.0.0 公共配置](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/config/common.txt)

| 选项 | 后端或行为 |
| --- | --- |
| `Nftables_Transparent_Proxy` | nftables、ChinaDNS-NG、dnsmasq-full 及透明代理所需模块 |
| `INCLUDE_Haproxy` | PassWall 2 按需调用 HAProxy 进行负载均衡 |
| `INCLUDE_Hysteria` | 独立 `hysteria` APK 及 `Hysteria2` 节点类型 |
| `INCLUDE_SingBox` | Sing-box 及其协议实现，包括 Sing-box Hysteria2 |
| `INCLUDE_Shadowsocks_Libev_Client` | Shadowsocks-libev 的 `ss-local` 和 `ss-redir` |
| `INCLUDE_Shadowsocks_Rust_Client` | Shadowsocks-rust 的 `sslocal` |
| `INCLUDE_ShadowsocksR_Libev_Client` | ShadowsocksR-libev 的 `ssr-local` 和 `ssr-redir` |
| `INCLUDE_Simple_Obfs`、`INCLUDE_V2ray_Plugin` | Shadowsocks 插件 |

`xray-core` 由 LuCI 包直接依赖。固件 APK 路径与原 opkg 兼容路径共存于组件代码中，实际执行时取决于设备上的包管理器。 [后端定义](Makefile) · [组件检测实现](luasrc/passwall2/api.lua)

## 下游兼容修订

- **r2，Sing-box 1.14.4 DNS**。生成有序 A／AAAA 规则来表达各自的直连和代理地址族，维持全局双栈与非地址记录回退。FakeDNS 只处理允许的地址族。反向域名匹配放入独立的逻辑子规则，再与查询类型相交，避免反转地址族约束。 [Sing-box 生成器](luasrc/passwall2/util_sing-box.lua)
- **r3，节点持久化与 FakeDNS**。新增节点在原 rpcd 会话的 UCI cursor 上提交，失败向界面报告。分流选项异步加载后刷新 FakeDNS 依赖和控件状态。 [节点控制器](luasrc/controller/passwall2.lua) · [分流控件](luasrc/view/passwall2/include/shunt_options.htm)
- **r4，独立 Hysteria2 2.13.0**。生成器使用 `fastOpen`，并仅在 UCI 值为字符串 `"1"` 时设置 `quic.disablePathMTUDiscovery=true`。Sing-box 节点沿用其独立生成器。 [Hysteria2 生成器](luasrc/passwall2/util_hysteria2.lua) · [独立核心复核](../../../net/hysteria/SECURITY-AUDIT.md)

## 验证

在组件目录用 Lua 5.1 运行独立 Hysteria2 字段回归。该用例使用合成 UCI 与 JSON 替身，验证实际 Lua 生成器输出。

```sh
lua tests/hysteria2-config.lua luasrc/passwall2/util_hysteria2.lua
```

修改 DNS 生成器时用目标版本 Sing-box 的 `check` 核对生成配置，并覆盖直连／代理单栈、反向匹配、FakeDNS 和非地址查询。验证持久化时从浏览器提交，再用新的页面请求和实际 ubus 读取核对。4.0.0 发布前的 x86 结果覆盖节点新增、编辑、删除、FakeDNS 界面依赖、组件检测及两种 Hysteria2 后端的生产配置生成和核心加载。该次使用本地受控节点。 [4.0.0 浏览器与生产 ubus 记录](https://github.com/BoltWrt/BoltWrt/blob/v4.0.0/docs/4.0.0-hysteria-validation.md)
