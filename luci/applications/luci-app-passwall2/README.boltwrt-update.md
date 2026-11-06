# BoltWrt PassWall2 compatibility update (2026-10-29)

## Version choice

Keep PassWall2 **26.4.20**, increment its package release to **2**, and backport
only the DNS generator changes needed by the selected Sing-box 1.14.4 core.
This is a downstream compatibility update, not a claim that all changes in
upstream 26.10.29 have been imported.

The inspected latest stable release,
[26.10.29-1](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases/tag/26.10.29-1),
is fixed at commit `b7ec339b373fed62e4963ca05bbf3f00f9274d34`, tree
`5f57e1fa920a3eff4a9abd969b2cad3ee4acad33`. Its source archive SHA256 is
`fed44f941f66016417cfef865389b15bb4135bbac8b7591231d972f79c073fd0`;
all 120 Git blobs and modes were compared with that tree.

A wholesale update would remove the currently selected Shadowsocks-libev
client selector, its `ss.lua` UI, and associated runtime paths. It also replaces
the old SingBox selector with a Basic Core choice and removes standalone
Hysteria/NaiveProxy/TUIC integration paths. SSR remains upstream, but that does
not compensate for losing the selected SS-libev backend. The narrow backport
avoids these removals and keeps existing saved node types and UI forms.

## Changes and fixed sources

Sing-box 1.14.4 rejects the old generator's configuration when DNS `query_type`
rules coexist with legacy per-rule `strategy` options. This is reproduced by
an old direct-IPv4 / proxy-IPv6 / FakeDNS generated configuration.

The DNS section is backported from the fixed 26.10.29 source above, including:

- [15ee1508550b2bebc0ae080fc2033a644e214677](https://github.com/Openwrt-Passwall/openwrt-passwall2/commit/15ee1508550b2bebc0ae080fc2033a644e214677):
  express single-stack DNS choices through ordered A/AAAA rules rather than
  legacy per-rule strategy fields.
- [7d6760f3775276cdbbf3a520a4cc72bc8f176852](https://github.com/Openwrt-Passwall/openwrt-passwall2/commit/7d6760f3775276cdbbf3a520a4cc72bc8f176852):
  keep the global DNS strategy dual-stack, so a proxy-only IPv4 choice does not
  also force direct domains to IPv4.
- The final fixed source's default-path filtering and non-address-query
  fallback are retained. Existing 26.4.20 TTL 30 is retained instead of importing
  the later UI option for configurable remote TTL or the later FakeDNS TTL 1.
- Remove the redundant, deprecated `independent_cache = false` option, following
  the [official migration guide](https://sing-box.sagernet.org/migration/).

Single-stack exclusions return an empty `NOERROR` answer before the matching
route. FakeDNS only handles the permitted address record family. Other record
types such as MX still reach the remote resolver. No rules, node types, backend
selectors, or user-facing options are deleted.

For inverted domain matches, the domain predicates and their `invert` flag are
kept inside a separate logical subrule, ANDed with the address-record family.
This prevents a flat inverted rule from negating the query-type restriction
along with the domain match. Direct and remote single-stack filters and FakeDNS
all use this composition; existing non-inverted output stays unchanged.

Upstream's Hysteria field renaming was also inspected and tested. The official
1.14.4 checker accepts the existing Hysteria fields; no rename is needed for
this update. Existing UCI keys and protocol generators remain unchanged.

## Existing feature mapping

All existing Makefile content except `PKG_RELEASE` is byte-identical to the
base. The following selected options retain their selectors, dependency
packages, UI forms and runtime code:

| Existing selected option | Backend / path retained |
| --- | --- |
| `Nftables_Transparent_Proxy` | Existing nftables runner and required socket/tproxy/nat selections |
| `INCLUDE_Haproxy` | `haproxy`, `root/usr/share/passwall2/haproxy.lua` and `app.sh` load-balancing launch path |
| `INCLUDE_Shadowsocks_Libev_Client` | `shadowsocks-libev-ss-local`, `ss-redir`; `client/type/ss.lua`, `util_shadowsocks.lua`, existing SS runner |
| `INCLUDE_Shadowsocks_Rust_Client` | `shadowsocks-rust-sslocal`; `client/type/ss-rust.lua`, existing Rust config and runner |
| `INCLUDE_ShadowsocksR_Libev_Client` | `shadowsocksr-libev-ssr-local`, `ssr-redir`; `client/type/ssr.lua`, SSR config and runner |
| `INCLUDE_Simple_Obfs` | `simple-obfs-client`; existing Shadowsocks plugin fields and runner |
| `INCLUDE_SingBox` | `sing-box`; same node UI and all existing protocol options; DNS generation corrected |
| `INCLUDE_V2ray_Plugin` | `v2ray-plugin`; existing Shadowsocks plugin fields and runner |
| Existing required Xray dependency | `xray-core`, `client/type/ray.lua`, `util_xray.lua` and existing launch paths |

All 102 other existing package files/symlinks are byte-identical to the base
`af74fe86ff3b8729b48d1977a9032ab7946014e2`. No main-repository configuration
symbol change is required. Unselected optional server and standalone backend
selectors are also preserved.

## Validation and limits

Evidence is under the parent workspace's
`.evidence/4.0.0/release-update-20261029/proxy-stack/`:

- `passwall-feature-preservation.json`: exact selector and package-file comparison.
- `test-passwall-compat.py`, `compat-generator-results.json`, `compat-fixtures/`:
  seven actual Lua generator cases with isolated UCI/sys API fixtures: dual-stack,
  mixed direct/proxy family restrictions, FakeDNS, and SS-libev / SS-rust / SSR /
  Xray-to-Sing-box relay configurations. Fixture system-call side effects are
  rejected, and `no_run` prevents backend launch.
- `compat-core-check.log`: all seven fixed full configurations pass official
  Sing-box 1.14.4 `check`; the old mixed-stack/FakeDNS configuration fails with
  the legacy DNS strategy diagnostic.
- `assert-passwall-dns.py`, `compat-dns-assertions.json`: generated rule-order
  assertions include 12 direct/proxy A/AAAA decisions plus blocked-domain and MX
  fallback behavior for the seven cases.
- `test-passwall-invert.py`, `compat-invert-results.json`, `invert-fixtures/`:
  two additional actual generator cases cover inverted direct IPv4 and inverted
  remote IPv6 with FakeDNS. An explicit logical/invert rule evaluator checks
  24 domain/record-family decisions (four matching or nonmatching domains times
  A/AAAA/MX for both cases). Both pre-fix negative controls reproduce wrong
  decisions; both corrected configurations pass the official core checker.
  Two existing non-inverted mixed-stack generated JSON outputs are identical
  to the earlier saved fixtures; the earlier core checks were not repeated.
- `test-passwall-protocols.py`, `compat-protocol-results.json`, `protocol-fixtures/`:
  actual unchanged outbound generators for Hysteria, Hysteria2 port hopping,
  TUIC, VLESS, VMess, Trojan and AnyTLS pass the official core checker. The
  baseline Hysteria alias fields also pass, so an experimental rename was not
  retained.

The checker is the official Linux arm64 CLI release, authenticated against its
GitHub API SHA256
`436441f76ee2f7fe21b5b2d426d3cb261a480455a704865789ad533e4273ec26`.
It reports version `1.14.4`, source revision
`c005f35300ce76427dc285481ec5695f5b179cd2`. It runs in a short-lived helper
with `--network none`, `--read-only`, dropped capabilities, a read-only evidence
mount and a private `/tmp` tmpfs. No existing build/runtime container or volume
was changed. The checker binary's embedded Go version does not change BoltWrt's
selected Go toolchain.

These are generated-configuration and source-preservation checks. The selected
firmware package must still be built with the actual target core feature tags,
and actual firmware packaging/manifest verification remains required. LuCI UI
interaction, subscription imports, real tunnel handshakes, live DNS, transparent
proxy traffic, Haproxy balancing, plugin execution and physical RAX board
operation are not established by these checks. Previously cancelled RAX board
testing is not reinstated as a blocker.
