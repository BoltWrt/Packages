# v2ray-plugin 5.49.0 security review (2026-10-30)

The 5.49.0-r1 artifacts contain gRPC 1.80.0. In plugin `mode=grpc`
server mode, its native HTTP/2 transport exposes the Rapid Reset mitigation
bypass and fragmented DATA receive-buffer exhaustion described below.
Release 2 pins gRPC 1.83.2 and its minimum module graph while retaining
plugin/core 5.49.0. The Go standard-library remediation is a separate
build-toolchain change: release 2 must be rebuilt with Go 1.26.10 or newer
in the 1.26 series before the TLS finding can be closed.

## Inputs and evidence

- Packages baseline: `e5303e0e051660a43afa8cca62ce9c346ead77af`.
- Plugin source: `v5.49.0`, source archive SHA256
  `7a634a79d9715a899d52366949e09443376715ec86f76cbcfc8b6fb3af0cef53`.
- Original Go toolchain: **go1.26.9**, established from each final binary's
  build information, rather than the upstream release's Go version.
- Original RAX FIT SHA256:
  `0181bfb34fbdd2600bd6840b562540910f152202bcd4278b356e5965ea79fdea`.
- Original x86 squashfs rootfs gzip SHA256:
  `71a9f9c8711caf8af91d59b27e180f5f3c2b862cfbad29ed86d24a37436ead37`.
- Binary bytes extracted from each image match the SHA256 file digest in
  that platform's final `v2ray-plugin-5.49.0-r1.apk`. RAX payload:
  `6f8952f6867d3f923b603436d4008b3d8b58165a6b945720f398dbc2672aa4ab`;
  x86 payload:
  `e879b2045c40fd6ac05fa1dbbfbeb5d3cfcdec6fee989df857556072e5e95657`.
- Private workspace evidence:
  `.evidence/4.0.0/security-browser-20261030/v2ray/`. This includes the
  complete 143-module MVS inventory, 445-package Linux/arm64 import graph,
  Linux/amd64 import graph, both final buildinfo records, all scanner JSON,
  the 40 baseline module-version advisory matches and their scan levels,
  candidate module files, commands, resource counters and original failures.
- Scanner: existing `govulncheck v1.1.4`; official Go vulnerability database
  snapshot last modified `2026-10-27T21:16:18Z`. Source and binary scanning
  are supporting evidence; a symbol match alone does not establish runtime
  reachability or successful exploitation.

## Final-artifact module inventory

Both platforms link the same 15 non-main modules. The complete MVS graph
also includes development, test and other-platform modules; those are not
all linked into the delivered plugin.

| Module | Original version | Release 2 version |
| --- | --- | --- |
| github.com/adrg/xdg | v0.5.3 | unchanged |
| github.com/golang/protobuf | v1.5.4 | unchanged |
| github.com/gorilla/websocket | v1.5.3 | unchanged |
| github.com/miekg/dns | v1.1.72 | unchanged |
| github.com/pires/go-proxyproto | v0.11.0 | unchanged |
| github.com/quic-go/quic-go | v0.59.0 | unchanged |
| github.com/shirou/gopsutil/v4 | v4.26.3 | unchanged |
| github.com/v2fly/v2ray-core/v5 | v5.49.0 | unchanged |
| golang.org/x/crypto | v0.50.0 | v0.55.0 |
| golang.org/x/net | v0.53.0 | v0.58.0 |
| golang.org/x/sys | v0.43.0 | v0.47.0 |
| golang.org/x/text | v0.36.0 | v0.41.0 |
| google.golang.org/genproto/googleapis/rpc | v0.0.0-20260120221211-b8f7ae30c516 | v0.0.0-20260526163538-3dc84a4a5aaa |
| google.golang.org/grpc | v1.80.0 | v1.83.2 |
| google.golang.org/protobuf | v1.36.11 | unchanged |

Module-graph-only changes also raise `x/mod` to 0.38.0, `x/sync` to
0.22.0 and `x/tools` to 0.48.0. The patch includes actual `go.sum` values
generated with Go's checksum validation enabled. gRPC 1.83.2 requires
Go 1.25.0, compatible with the locked Go 1.26 build line.

## Advisory reachability

| Advisory | Plugin client | Plugin server | Resolution |
| --- | --- | --- | --- |
| [GO-2026-6061 / GHSA-hrxh-6v49-42gf](https://github.com/grpc/grpc-go/security/advisories/GHSA-hrxh-6v49-42gf) | The Rapid Reset server attack is not a client vulnerability. | `mode=grpc` creates `grpc.NewServer` and calls `Serve`, reaching the affected native transport. Its xDS policy subissues are unused. | gRPC 1.83.2 contains the 1.82.1 fix. |
| [GO-2026-6348 / CVE-2026-84304](https://github.com/grpc/grpc-go/security/advisories/GHSA-vp52-pcj8-j9qc) | gRPC uses the shared receive-buffer transport; keep the fixed version for client operation too. No malicious-peer test was performed. | `mode=grpc` accepts streaming DATA into the affected receive buffers. The unauthenticated remote-server attack described by the maintainer applies to this mode when exposed. | gRPC 1.83.2 contains the 1.83.1 receive-buffer compaction fix. |
| [GO-2026-6809 / CVE-2026-111943](https://pkg.go.dev/vuln/GO-2026-6809) | TLS WebSocket, TLS gRPC and mandatory-TLS QUIC perform server certificate verification. Exposure requires a chain through one of the distrusted intermediate keys and a trust configuration accepting that chain. | The plugin does not enable `VerifyClientCertificate`; its own server TLS handshake does not authenticate client certificates. | Requires all delivered Go binaries to be rebuilt with Go 1.26.10. This package patch alone does not fix the original artifacts. |
| [GO-2026-6443 / GHSA-2v4p-qf9q-27wj](https://github.com/grpc/grpc-go/security/advisories/GHSA-2v4p-qf9q-27wj) | Not an xDS server. | The plugin uses ordinary `grpc.NewServer`, without `xds.NewGRPCServer` or its routing interceptor. The reported panic requires that interceptor. | Not reachable in this product configuration; 1.83.2 nevertheless includes the fix. |
| [GO-2026-6441](https://pkg.go.dev/vuln/GO-2026-6441) | No xDS RBAC. | No xDS RBAC policy engine. | Not reachable; updated gRPC removes the version match. |
| [GO-2026-5676 / CVE-2026-40898](https://github.com/quic-go/quic-go/security/advisories/GHSA-vvgj-x9jq-8cj9) | QUIC transport uses `quic.Transport.Dial` and raw bidirectional streams. | Uses `quic.Transport.Listen` and `AcceptStream`, not an HTTP/3 server. | The HTTP/3 QPACK trailer decoder is not selected by any plugin mode. Retain quic-go 0.59.0; this is not a general claim that that version is vulnerability-free. |
| [GO-2026-6603](https://pkg.go.dev/vuln/GO-2026-6603), [6611](https://pkg.go.dev/vuln/GO-2026-6611), [6612](https://pkg.go.dev/vuln/GO-2026-6612), [6617](https://pkg.go.dev/vuln/GO-2026-6617) | Source traces flag common `x/net/http2.Framer` APIs, which gRPC uses with its own transport. The affected standalone x/net client/server state machines are not selected. | Uses the gRPC native transport, not `http2.Server.ServeConn`. WebSocket uses standard-library HTTP, whose corresponding fixes are already present in Go 1.26.9. | Retained as implementation-level exclusions, not called exploitable just from the broad symbol matches. TLS ECH DoH is also inactive: plugin-generated TLS configs leave `EchConfig` and `Ech_DOHserver` empty. |

Remaining baseline version matches concern SSH/agent/knownhosts, OpenPGP,
Windows APIs, HTML parsing/rendering, DNS SVCB parsing, IDNA or text
normalization. The TSV matrix preserves every GO ID and whether its package
is imported or a source call trace exists. SSH, OpenPGP, Windows, HTML and
the affected x/net DNS parser are not in the actual Linux plugin import
graph. IDNA/text package presence is distinguished from calls to the
affected operations; the gRPC-required module graph also updates IDNA/text
past those baseline fixes. Arbitrary full v2ray-core JSON configurations,
ECH options, HTTP/3 transports and xDS configuration are not plugin inputs.

## Validation and remaining work

- Patch applies to the hash-locked source with `--fuzz=0`; patched
  `go.mod`/`go.sum` equal the reviewed candidate files byte for byte.
- Baseline and candidate cached module content pass `go mod verify`.
  Candidate runtime modules were explicitly downloaded with checksum
  validation enabled. Earlier verification attempts rejected symlink module
  directories in the isolated cache; those harness failures remain recorded.
- Candidate compiles for Linux/arm64 and Linux/amd64 with Go 1.26.9 and
  `CGO_ENABLED=0`; native arm64 `-version` works. These are API compatibility
  builds, not the production musl/CGO build or replacement APKs.
- Ten native arm64, network-disabled cases start their local TCP/UDP
  listener and exit on SIGINT: WebSocket and gRPC client/server with TLS
  off/on, plus QUIC client/server with mandatory TLS. No connections,
  payload exchange, peer, WAN, wireless or physical-board checks were run.
- Candidate source scan removes all gRPC findings. It retains the four
  standalone x/net HTTP/2 exclusions above and the expected Go 1.26.9 TLS
  finding pending the separate toolchain rebuild.
- Required downstream: production builds for both targets, r2 APK/root/image
  binding, actual Go 1.26.10 buildinfo, final dependency and advisory review.
  All selected Go programs require rebuilding to replace the old standard
  library. Existing r1 artifacts remain historical and unmodified.
