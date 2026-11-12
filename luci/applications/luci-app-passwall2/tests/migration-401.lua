local migration = dofile(assert(arg[1]))
local sections = {
    { [".name"]="native", [".type"]="user", type="Hysteria2", enable="0", bind_local="1", hysteria2_auth_password="unchanged" },
    { [".name"]="vless", [".type"]="user", type="Xray", protocol="vless", enable="1", uuid={"uuid-a", "uuid-b"} },
    { [".name"]="ss", [".type"]="user", type="SS", method="aes-128-gcm", password="keep-password" },
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
assert(plan.servers[1].options.type == "sing-box" and plan.servers[1].options.protocol == "hysteria2")
assert(plan.servers[2].options.firewall_allow == "1")
assert(plan.servers[2].users[1] == "bw401_vless_2")
assert(plan.accounts[1].options.password == "unchanged")
assert(plan.accounts[2].options.uuid == "uuid-a")
assert(plan.accounts[3].options.uuid == "uuid-b")
assert(plan.servers[3].options.ss_password == "keep-password")
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
        if server.id == copy[".name"] then
            copy[".type"] = "server"
            for key, value in pairs(server.options) do copy[key] = value end
        end
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

local forwarding = {
    {[".name"]="forward",[".type"]="global_forwarding",tcp_no_redir_ports="80,443",udp_no_redir_ports="disable",tcp_redir_ports="22,80,443",udp_redir_ports="1:65535"},
    {[".name"]="inherited",[".type"]="acl_rule",enabled="1",node="default",sources="10.0.0.2 00:11:22:33:44:55",tcp_no_redir_ports="default",udp_no_redir_ports="disable"},
    {[".name"]="explicit",[".type"]="acl_rule",enabled="0",node="client",tcp_no_redir_ports="disable",tcp_redir_ports="443",remote_dns_protocol="tls",remote_dns="9.9.9.9:853"},
    {[".name"]="bypass",[".type"]="acl_rule",enabled="1",node="client",tcp_no_redir_ports="1:65535",udp_no_redir_ports="1-65535"},
    {[".name"]="new",[".type"]="acl_rule",enabled="1",mode="1",node="new-client",sources={"10.0.0.3"},tcp_redir_ports="8443"},
}
local acl_plan=migration.plan({},forwarding)
local updates={};for _,item in ipairs(acl_plan.clients) do updates[item.id]=item end
assert(#acl_plan.clients==4 and not updates.new)
assert(updates.forward.remove[1]=="udp_no_redir_ports")
assert(updates.inherited.options.mode=="2" and updates.inherited.options.boltwrt_401_legacy_acl=="1")
assert(updates.inherited.options.sources[1]=="10.0.0.2" and updates.inherited.options.sources[2]=="00:11:22:33:44:55")
assert(updates.inherited.options.tcp_no_redir_ports=="80,443" and updates.inherited.options.tcp_redir_ports=="22,80,443")
assert(updates.inherited.options.boltwrt_401_inherit_ports[1]=="tcp_no_redir_ports")
assert(updates.explicit.options.mode=="1" and updates.explicit.options.remote_dns_protocol==nil and updates.explicit.options.remote_dns==nil)
assert(updates.explicit.options.remote_dns_query_strategy=="UseIPv4" and updates.explicit.options.enabled==nil)
assert(updates.bypass.options.mode=="0" and updates.bypass.options.node==nil)
local converted={}
for _,section in ipairs(forwarding) do
    local copy={};for key,value in pairs(section) do copy[key]=value end
    local update=updates[section[".name"]]
    if update then
        for key,value in pairs(update.options) do copy[key]=value end
        for _,key in ipairs(update.remove or {}) do copy[key]=nil end
    end
    converted[#converted+1]=copy
end
assert(#migration.plan({},converted).clients==0,'ACL migration is not idempotent')
assert(forwarding[1].udp_no_redir_ports=='disable' and forwarding[2].node=='default','plan changed its input')
print('PASS legacy ACL modes, inherited port expressions, source lists, explicit DNS, disabled intent and idempotence')
