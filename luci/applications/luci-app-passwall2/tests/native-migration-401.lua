-- Run with real libuci, an isolated config directory and its empty state/
-- directory: lua native-migration-401.lua migrate_401.lua /tmp/test-directory
local migration = dofile(assert(arg[1]))
local directory = assert(arg[2])
local config = "passwall2_server"
local file = assert(io.open(directory .. "/" .. config, "w"))
file:write([[config global 'global'
 option enable '0'
config user 'legacy'
 option type 'Xray'
 option protocol 'vless'
 option enable '1'
 option bind_local '1'
 option tls_keyFile '/etc/config/ssl/preserved.key'
 list uuid '00000000-0000-4000-8000-000000000001'
 list uuid '00000000-0000-4000-8000-000000000002'
config user 'bw401_legacy_1'
 option username 'existing'
 option password 'must-not-overwrite'
config user 'native'
 option type 'Hysteria2'
 option enable '0'
 option hysteria2_auth_password 'preserve-native'
]])
file:close()
local client_file = assert(io.open(directory .. "/passwall2", "w"))
client_file:write([[config global 'global'
 option enabled '0'
 option node 'client'
config global_forwarding 'forward'
 option tcp_no_redir_ports 'disable'
 option udp_no_redir_ports 'disable'
 option tcp_redir_ports '22,80,443'
 option udp_redir_ports '1:65535'
config acl_rule 'inherited'
 option enabled '1'
 option node 'default'
 option sources '10.0.0.2 00:11:22:33:44:55'
 option tcp_no_redir_ports 'default'
 option udp_no_redir_ports 'disable'
config acl_rule 'explicit'
 option enabled '0'
 option node 'client'
 option remote_dns_protocol 'udp'
 option remote_dns '9.9.9.9:5353'
config acl_rule 'bypass'
 option enabled '1'
 option tcp_no_redir_ports '1:65535'
 option udp_no_redir_ports '1:65535'
config nodes 'client'
 option type 'Xray'
 option transport 'tcp'
 option uuid 'preserve-client-uuid'
 option tls_CertSha 'preserve-certificate-pin'
config nodes 'sb'
 option type 'sing-box'
 option transport 'tcp'
config nodes 'ss'
 option type 'sing-box'
 option protocol 'shadowsocks'
 option method 'aes-128-gcm'
config nodes 'ws'
 option type 'sing-box'
 option transport 'ws'
 option ws_path '/ws?token=a%2Fb'
 option ws_maxEarlyData '2048'
 option ws_earlyDataHeaderName 'Sec-WebSocket-Protocol'
]])
client_file:close()
local function cursor() return require("uci").cursor(directory, directory .. "/state") end
local c = cursor()
assert(migration.apply(c, migration.read(c)) == 2)
c = cursor() -- Require changes to survive a new native cursor and reload.
assert(c:get(config, "global", "enable") == "0")
assert(c:get(config, "legacy") == "server")
assert(c:get(config, "legacy", "enable") == "1")
assert(c:get(config, "legacy", "firewall_allow") == "0")
assert(c:get(config, "legacy", "tls_keyFile") == "/etc/config/ssl/preserved.key")
local users = c:get(config, "legacy", "users")
assert(type(users) == "table" and #users == 2 and users[1] == "bw401_legacy_2")
assert(c:get(config, users[1], "uuid") == "00000000-0000-4000-8000-000000000001")
assert(c:get(config, users[2], "uuid") == "00000000-0000-4000-8000-000000000002")
assert(c:get(config, "bw401_legacy_1", "password") == "must-not-overwrite")
assert(c:get(config, "native", "hysteria2_auth_password") == "preserve-native")
assert(c:get(config, "native", "enable") == "0")
assert(#migration.read(c).servers == 0)
assert(#migration.read(c).clients == 0)
assert(c:get("passwall2", "client", "transport") == "raw")
assert(c:get("passwall2", "client", "uuid") == "preserve-client-uuid")
assert(c:get("passwall2", "client", "tls_pinSHA256") == "preserve-certificate-pin")
assert(c:get("passwall2", "sb", "transport") == "tcp")
assert(c:get("passwall2", "ss", "ss_method") == "aes-128-gcm")
assert(c:get("passwall2", "ws", "ws_path") == "/ws?token=a%2Fb&ed=2048&eh=Sec-WebSocket-Protocol")
assert(c:get('passwall2','forward','tcp_no_redir_ports')==nil and c:get('passwall2','forward','udp_no_redir_ports')==nil)
assert(c:get('passwall2','global','enabled')=='0')
assert(c:get('passwall2','inherited','enabled')=='1' and c:get('passwall2','inherited','mode')=='2')
assert(c:get('passwall2','inherited','node')==nil and c:get('passwall2','inherited','boltwrt_401_legacy_acl')=='1')
assert(c:get('passwall2','inherited','tcp_redir_ports')=='22,80,443')
assert(c:get('passwall2','inherited','tcp_no_redir_ports')==nil and c:get('passwall2','inherited','udp_no_redir_ports')==nil)
local sources=c:get('passwall2','inherited','sources');assert(type(sources)=='table' and #sources==2 and sources[2]=='00:11:22:33:44:55')
local inherited=c:get('passwall2','inherited','boltwrt_401_inherit_ports');assert(type(inherited)=='table' and inherited[1]=='tcp_no_redir_ports')
assert(c:get('passwall2','explicit','mode')=='1' and c:get('passwall2','explicit','enabled')=='0')
assert(c:get('passwall2','explicit','node')=='client' and c:get('passwall2','explicit','remote_dns')=='9.9.9.9:5353')
assert(c:get('passwall2','explicit','remote_dns_query_strategy')=='UseIPv4')
assert(c:get('passwall2','bypass','mode')=='0')
print("PASS native libuci migration: fresh cursor, lists, schema, credentials, enabled intent, collision, idempotence")
