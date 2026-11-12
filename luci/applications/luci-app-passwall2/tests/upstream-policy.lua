local migration = dofile(assert(arg[1]))
local function node(id, kind, options)
    local value = {[".name"]=id, [".type"]="nodes", type=kind}
    for key, item in pairs(options or {}) do value[key] = item end
    return value
end
local nodes = {
    node("ss", "SS", {method="aes-128-gcm", password="keep", plugin="v2ray-plugin", plugin_opts="tls"}),
    node("hy", "Hysteria2", {port="443", hysteria2_auth_password="auth", hysteria2_obfs="obfs", hysteria2_hop="1000-2000,8443", tls_allowInsecure="0"}),
    node("pin", "Hysteria2", {hysteria2_tls_pinSHA256="must-not-drop"}),
    node("old-cipher", "SS", {method="aes-128-cfb", password="old"}),
    node("tuic", "TUIC", {password="keep"}),
    node("naive", "Naive", {password="keep"}),
    node("window", "Hysteria2", {hysteria2_recv_window="1048576"}),
}
local plan = migration.plan({}, nodes)
assert(#plan.clients == 2 and #plan.manual == 5)
assert(plan.clients[1].options.type == "SS-Rust")
assert(plan.clients[2].options.type == "sing-box" and plan.clients[2].options.protocol == "hysteria2")
assert(plan.clients[2].options.hysteria2_obfs_password == "obfs")
assert(plan.clients[2].options.hysteria2_hop == "443:443,1000:2000,8443:8443")
assert(nodes[1].type == "SS" and nodes[3].hysteria2_tls_pinSHA256 == "must-not-drop")
for _, update in ipairs(plan.clients) do
    for _, value in ipairs(nodes) do
        if value[".name"] == update.id then
            for key, item in pairs(update.options) do value[key] = item end
        end
    end
end
assert(#migration.plan({}, nodes).clients == 0)
assert(nodes[1].password == "keep" and nodes[1].plugin == "v2ray-plugin" and nodes[1].plugin_opts == "tls")
assert(nodes[2].hysteria2_auth_password == "auth" and nodes[2].tls_allowInsecure == "0")

local servers = {
    {[".name"]="ss", [".type"]="user", type="SS", method="aes-128-gcm", password="ss-pass", enable="0", bind_local="1"},
    {[".name"]="hy", [".type"]="user", type="Hysteria2", hysteria2_auth_password="hy-pass", hysteria2_obfs="obfs", hysteria2_ignoreClientBandwidth="1", tls_keyFile="/preserved.key"},
    {[".name"]="custom", [".type"]="user", type="Hysteria2", custom="1", config_str="native-json"},
    {[".name"]="udp-off", [".type"]="user", type="Hysteria2", hysteria2_udp="0"},
    {[".name"]="candidate", [".type"]="server", type="SS", method="aes-128-gcm", user="account", password="stale"},
    {[".name"]="account", [".type"]="user", password="current"},
}
plan = migration.plan(servers)
assert(#plan.servers == 3 and #plan.accounts == 1 and #plan.manual == 2)
assert(plan.servers[1].options.type == "sing-box" and plan.servers[1].options.protocol == "shadowsocks")
assert(plan.servers[1].options.ss_password == "ss-pass" and plan.servers[1].options.firewall_allow == "0")
assert(plan.servers[2].options.hysteria2_ignore_client_bandwidth == "1")
assert(plan.accounts[1].options.password == "hy-pass")
assert(plan.servers[3].options.ss_password == "current")
assert(servers[1].enable == "0" and servers[2].tls_keyFile == "/preserved.key" and servers[3].config_str == "native-json")
local fake = {foreach=function(self, config, kind, callback) for _, item in ipairs(nodes) do callback(item) end end}
assert(migration.needs_manual_review(fake, "passwall2"))
print("PASS upstream policy: equivalent SS/Hysteria2 conversion, primary hop port, credentials, idempotence; pins/custom/unsupported options retained for manual review")
