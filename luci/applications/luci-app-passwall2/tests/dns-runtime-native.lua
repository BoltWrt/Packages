-- Native libuci smoke test. All configuration writes stay in a supplied /tmp fixture.
local helper, directory = assert(arg[1]), assert(arg[2])
assert(directory:match("^/tmp/passwall2%-dns%-test%.[%w]+$"), "isolated fixture directory required")
local native = require "uci"
assert(os.execute("mkdir -p " .. directory .. "/config " .. directory .. "/saved") == 0)
local function write(name, data)
	local file = assert(io.open(directory .. "/config/" .. name, "w"))
	assert(file:write(data))
	file:close()
end
write("passwall2", "config global 'main'\n")
write("dhcp", "config dnsmasq 'main'\n list server '127.0.0.1#6053'\n list server '/lan/10.0.0.1'\n option noresolv '1'\n")
local function cursor() return native.cursor(directory .. "/config", directory .. "/saved") end
local function equal(actual, expected)
	assert(type(actual) == "table" and #actual == #expected)
	for index, value in ipairs(expected) do assert(actual[index] == value) end
end
local restarts = 0
local function forbidden() error("runtime DNS called RPC UCI") end
local api = setmetatable({
	c_config = "passwall2", get_cache_var = function() return "127.0.0.1#6053" end,
	log = function(_, message) error(message) end,
	sys = {call = function(command)
		assert(command == "/etc/init.d/dnsmasq restart >/dev/null 2>&1")
		restarts = restarts + 1
		local external = cursor()
		equal(external:get("dhcp", "@dnsmasq[0]", "server"), {"/lan/10.0.0.1"})
		equal(external:get("passwall2", "@global[0]", "dnsmasq_servers"),
			{"127.0.0.1#6053", "/lan/10.0.0.1"})
		assert(external:set("dhcp", "@dnsmasq[0]", "server", {"/lan/10.0.0.1", "/new/10.0.0.2"}))
		assert(external:commit("dhcp"))
		return 0
	end}
}, {__index = function(_, name)
	if name:match("^uci_") then return forbidden end
end})
local env = setmetatable({arg = {}}, {__index = _G})
env._G = env
env.require = function(name)
	if name == "luci.passwall2.api" then return api end
	if name == "uci" then return {cursor = cursor} end
	error("unexpected require " .. name)
end
setfenv(assert(loadfile(helper)), env)()
env.logic_restart({})
local result = cursor()
equal(result:get("dhcp", "@dnsmasq[0]", "server"),
	{"/lan/10.0.0.1", "/new/10.0.0.2", "127.0.0.1#6053"})
assert(result:get("passwall2", "@global[0]", "dnsmasq_servers") == nil)
assert(result:get("dhcp", "@dnsmasq[0]", "noresolv") == "1" and restarts == 1)
print("PASS native libuci: isolated upstream backup, temporary filtering, concurrent update, restore and cleanup")
