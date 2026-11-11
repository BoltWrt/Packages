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
