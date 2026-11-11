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
client_file:write([[config nodes 'client'
 option type 'Xray'
 option transport 'tcp'
 option uuid 'preserve-client-uuid'
config nodes 'sb'
 option type 'sing-box'
 option transport 'tcp'
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
assert(c:get("passwall2", "sb", "transport") == "tcp")
print("PASS native libuci migration: fresh cursor, lists, schema, credentials, enabled intent, collision, idempotence")
