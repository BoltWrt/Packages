local migration = require "luci.passwall2.migrate_401"
local cursor = require("uci").cursor()
local plan = migration.read(cursor)
if arg[1] == "check" then os.exit(#plan.servers + #plan.clients > 0 and 0 or 2) end
assert(arg[1] == "apply", "expected check or apply")
local ok, count, clients = pcall(migration.apply, cursor, plan)
if not ok then
    cursor:revert("passwall2_server")
    cursor:revert("passwall2")
    io.stderr:write("PassWall2 server migration failed; original config backup retained\n")
    os.exit(1)
end
print("PassWall2: migrated " .. count .. " legacy server sections and " .. clients .. " Xray transports")
