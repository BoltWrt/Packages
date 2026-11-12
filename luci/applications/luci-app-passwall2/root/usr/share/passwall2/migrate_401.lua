local migration = require "luci.passwall2.migrate_401"
local cursor = require("uci").cursor()
local plan = migration.read(cursor)
if #plan.manual > 0 then
    io.stderr:write("PassWall2: " .. #plan.manual .. " legacy nodes require manual reconfiguration for upstream-supported cores; their configuration is retained\n")
end
if arg[1] == "check" then os.exit(#plan.servers + #plan.clients > 0 and 0 or 2) end
assert(arg[1] == "apply", "expected check or apply")
local ok, count, clients = pcall(migration.apply, cursor, plan)
if not ok then
    cursor:revert("passwall2_server")
    cursor:revert("passwall2")
    io.stderr:write("PassWall2 migration failed; inspect configuration or restore your exported backup\n")
    os.exit(1)
end
print("PassWall2: migrated " .. count .. " legacy server sections and " .. clients .. " client sections")
