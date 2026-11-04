-- Lua 5.1: lua tests/hysteria2-config.lua luasrc/passwall2/util_hysteria2.lua
-- Executes the real generator; UCI is synthetic and JSON serialization returns
-- its input table so field names/types can be asserted without a network/core.
local source = assert(arg[1], "provide util_hysteria2.lua path")
local node
package.preload["luci.passwall2.api"] = function()
  return {
    uci = { get_all = function(_, config, section)
      assert(config == "passwall2" and section == "fixture")
      return node
    end },
    jsonc = { stringify = function(value) return value end },
    is_ipv6 = function() return false end,
  }
end
dofile(source)
local generate = assert(package.loaded["luci.passwall2.util_hysteria2"].gen_config)
for _, case in ipairs({
  { label = "missing", enabled = false },
  { label = "empty", input = "", enabled = false },
  { label = "zero", input = "0", enabled = false },
  { label = "one", input = "1", enabled = true },
}) do
  node = {
    address = "192.0.2.10", port = "443", tls_serverName = "fixture.invalid",
    hysteria2_auth_password = "synthetic-only", fast_open = case.input,
    hysteria2_disable_mtu_discovery = case.input,
  }
  local config = generate({ node = "fixture", local_socks_address = "127.0.0.1", local_socks_port = "1080" })
  assert(config.fastOpen == case.enabled, case.label .. ": wrong fastOpen")
  assert(config.fast_open == nil, case.label .. ": unsupported snake_case output")
  assert(config.quic.disablePathMTUDiscovery == case.enabled, case.label .. ": wrong PMTU flag")
  assert(config.server == "192.0.2.10:443" and config.auth == "synthetic-only")
  assert(config.tls.sni == "fixture.invalid" and not config.tls.insecure)
  assert(config.socks5.listen == "127.0.0.1:1080")
  print("PASS hysteria2 generator " .. case.label)
end
