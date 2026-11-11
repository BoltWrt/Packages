local migration = dofile(assert(arg[1]))
local sections = {
    { [".name"]="native", [".type"]="user", type="Hysteria2", enable="0", bind_local="1", hysteria2_auth_password="unchanged" },
    { [".name"]="vless", [".type"]="user", type="Xray", protocol="vless", enable="1", uuid={"uuid-a", "uuid-b"} },
    { [".name"]="ss", [".type"]="user", type="SS", password="keep-password" },
    { [".name"]="anonymous", [".type"]="user", type="Xray", protocol="socks", auth="0" },
    { [".name"]="authenticated", [".type"]="user", type="sing-box", protocol="socks", auth="1", username="keep-name", password="keep-auth" },
    { [".name"]="trojan", [".type"]="user", type="Xray", protocol="trojan", uuid={"secret-a", "secret-b"} },
    { [".name"]="new-user", [".type"]="user", username="existing", password="untouched" },
    { [".name"]="bw401_vless_1", [".type"]="user", username="collision", password="untouched" },
    { [".name"]="new-server", [".type"]="server", type="Xray", protocol="vless", users={"new-user"} },
    { [".name"]="unknown", [".type"]="user", type="Unknown", password="untouched" },
}
local plan = migration.plan(sections)
assert(#plan.servers == 6 and #plan.accounts == 6)
assert(plan.servers[1].options.firewall_allow == "0")
assert(plan.servers[1].options.users == nil)
assert(plan.servers[2].options.firewall_allow == "1")
assert(plan.servers[2].users[1] == "bw401_vless_2")
assert(plan.accounts[1].options.uuid == "uuid-a")
assert(plan.accounts[2].options.uuid == "uuid-b")
assert(plan.accounts[3].options.password == "keep-password")
assert(plan.servers[4].options.users == nil, "anonymous auth intent changed")
assert(plan.accounts[4].options.username == "keep-name" and plan.accounts[4].options.password == "keep-auth")
assert(plan.accounts[5].options.password == "secret-a" and plan.accounts[6].options.password == "secret-b")
-- The original input remains unchanged; enabled intent, IDs and TLS/custom
-- options stay on the existing sections when only their schema is changed.
assert(sections[1][".type"] == "user" and sections[2].enable == "1")
local after = {}
for _, section in ipairs(sections) do
    local copy = {}
    for key, value in pairs(section) do copy[key] = value end
    for _, server in ipairs(plan.servers) do
        if server.id == copy[".name"] then copy[".type"] = "server" end
    end
    after[#after + 1] = copy
end
assert(#migration.plan(after).servers == 0, "migration is not idempotent")
assert(#migration.plan({}).servers == 0)
print("PASS legacy server migration: credentials, anonymous auth, collision, idempotence, unknown/new schemas")

local protocols = migration.plan({
    { [".name"]="sb-ss", [".type"]="user", type="sing-box", protocol="shadowsocks", method="aes-128-gcm", password="ss-password" },
    { [".name"]="naive", [".type"]="user", type="sing-box", protocol="naive", username="naive-user", password="naive-password" },
    { [".name"]="anytls", [".type"]="user", type="sing-box", protocol="anytls", password="anytls-password" },
    { [".name"]="hy", [".type"]="user", type="sing-box", protocol="hysteria", hysteria_auth_type="base64", hysteria_auth_password="YWJjAA==" },
    { [".name"]="raw", [".type"]="user", type="Xray", protocol="vless", transport="tcp", uuid={"uuid-c"} },
}, {
    { [".name"]="client", [".type"]="nodes", type="Xray", protocol="vless", transport="tcp", tls_CertSha="old-cert-pin" },
    { [".name"]="sb-client", [".type"]="nodes", type="sing-box", protocol="vless", transport="tcp" },
    { [".name"]="current", [".type"]="nodes", type="Xray", transport="raw", tls_CertSha="old", tls_pinSHA256="current-pin" },
})
assert(protocols.servers[1].options.ss_method == "aes-128-gcm")
assert(protocols.servers[1].options.ss_password == "ss-password")
assert(protocols.accounts[1].options.username == "naive-user" and protocols.accounts[1].options.password == "naive-password")
assert(protocols.accounts[2].options.password == "anytls-password")
assert(protocols.accounts[3].options.password == "YWJjAA==", "binary auth was decoded or changed during migration")
assert(protocols.servers[5].options.transport == "raw")
assert(#protocols.clients == 1 and protocols.clients[1].id == "client")
assert(protocols.clients[1].options.tls_pinSHA256 == "old-cert-pin")
assert(protocols.clients[1].options.transport == "raw")
print("PASS Sing-Box SS/Naive/AnyTLS/Hysteria credentials and Xray RAW transport migration")

local client_settings=migration.plan({}, {
    {[".name"]="ss",[".type"]="nodes",type="sing-box",protocol="shadowsocks",method="aes-128-gcm"},
    {[".name"]="ssr",[".type"]="nodes",type="sing-box",protocol="shadowsocksr",method="aes-128-cfb"},
    {[".name"]="ws",[".type"]="nodes",type="sing-box",transport="ws",ws_path="/ws?token=a%2Fb",ws_maxEarlyData="2048",ws_earlyDataHeaderName="Sec-WebSocket-Protocol"},
    {[".name"]="current",[".type"]="nodes",type="sing-box",protocol="shadowsocks",method="old",ss_method="current",transport="ws",ws_path="/ws?ed=1024&eh=Current",ws_maxEarlyData="2048",ws_earlyDataHeaderName="Old"},
})
assert(#client_settings.clients==3)
assert(client_settings.clients[1].options.ss_method=="aes-128-gcm")
assert(client_settings.clients[2].options.ssr_method=="aes-128-cfb")
assert(client_settings.clients[3].options.ws_path=="/ws?token=a%2Fb&ed=2048&eh=Sec-WebSocket-Protocol")
assert(#migration.plan({}, {{[".name"]="ws",[".type"]="nodes",type="sing-box",transport="ws",ws_path=client_settings.clients[3].options.ws_path,ws_maxEarlyData="2048",ws_earlyDataHeaderName="Sec-WebSocket-Protocol"}}).clients==0)
print("PASS client cipher fields and WebSocket early data, preserving query bytes and newer settings")
