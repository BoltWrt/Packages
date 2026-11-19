-- Run with Lua 5.1 and the shipped helper_dnsmasq.lua path.
local helper = assert(arg[1], "helper_dnsmasq.lua is required")
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copy(item) end
	return result
end
local function equal(actual, expected)
	if type(expected) ~= "table" then
		assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
		return
	end
	assert(type(actual) == "table")
	for key, value in pairs(expected) do equal(actual[key], value) end
	for key in pairs(actual) do assert(expected[key] ~= nil, "unexpected key " .. tostring(key)) end
end

local function load_helper(options)
	options = options or {}
	local disk = {
		dhcp = {server = copy(options.servers), noresolv = options.noresolv},
		passwall2 = {dnsmasq_servers = copy(options.backup)}
	}
	local pending, commits, logs = {}, {}, {}
	local restarts = 0
	local cursor = {}
	local function config(name)
		if not pending[name] then pending[name] = copy(disk[name]) end
		return pending[name]
	end
	function cursor:get(name, section, option) return copy(config(name)[option]) end
	function cursor:set(name, section, option, value)
		config(name)[option] = copy(value)
		return true
	end
	function cursor:delete(name, section, option)
		local exists = config(name)[option] ~= nil
		config(name)[option] = nil
		return exists
	end
	function cursor:commit(name)
		commits[#commits + 1] = name
		if options.fail_commit and options.fail_commit(name, #commits, restarts) then return false end
		disk[name] = copy(config(name))
		return true
	end
	function cursor:unload(name) pending[name] = nil end
	local function forbidden() error("runtime DNS state used RPC UCI (config.change reload risk)") end
	local api = {
		c_config = "passwall2", log = function(_, message) logs[#logs + 1] = message end,
		i18n = {translate = function(message) return message end},
		get_cache_var = function()
			if options.default_dns ~= false then return "127.0.0.1#6053" end
		end,
		uci_get = function(name, section, option) return cursor:get(name, section, option) end,
		uci_get_c = function(section, option) return cursor:get("passwall2", section, option) end,
		uci_set = forbidden, uci_set_c = forbidden, uci_del = forbidden, uci_del_c = forbidden,
		uci_save = forbidden, uci_save_c = forbidden,
		sys = {call = function(command)
			assert(command == "/etc/init.d/dnsmasq restart >/dev/null 2>&1")
			restarts = restarts + 1
			if options.on_restart then options.on_restart(disk) end
			return options.restart_status or 0
		end}
	}
	local env = setmetatable({arg = {}, io = {open = function(path)
		assert(path == "/tmp/resolv.conf.d/resolv.conf.auto")
		if options.resolv_size == nil then return nil end
		return {seek = function() return options.resolv_size end, close = function() end}
	end}}, {__index = _G})
	env._G = env
	env.require = function(name)
		if name == "luci.passwall2.api" then return api end
		if name == "uci" then return {cursor = function() return cursor end} end
		error("unexpected require " .. name)
	end
	setfenv(assert(loadfile(helper)), env)()
	return env, disk, logs, function() return restarts end, commits
end

local count = 0
local function test(name, run)
	run()
	count = count + 1
	print("PASS " .. name)
end

test("restart preserves global/domain upstreams without RPC writes", function()
	local original = {"127.0.0.1#6053", "/lan/10.0.0.1", "1.1.1.1"}
	local env, disk, logs, restarts = load_helper({servers = original, on_restart = function(state)
		equal(state.dhcp.server, {"/lan/10.0.0.1"})
		equal(state.passwall2.dnsmasq_servers, original)
	end})
	env.logic_restart({LOG = "1"})
	equal(disk.dhcp.server, {"/lan/10.0.0.1", "127.0.0.1#6053", "1.1.1.1"})
	assert(disk.passwall2.dnsmasq_servers == nil and restarts() == 1 and #logs == 1)
	-- A second invocation must neither lose servers nor accumulate duplicates.
	local env2, disk2 = load_helper({servers = disk.dhcp.server})
	env2.logic_restart({})
	equal(disk2.dhcp.server, disk.dhcp.server)
end)

test("scalar upstream is preserved and removed only during restart", function()
	local env, disk = load_helper({servers = "1.1.1.1", on_restart = function(state)
		assert(state.dhcp.server == nil)
		equal(state.passwall2.dnsmasq_servers, {"1.1.1.1"})
	end})
	env.logic_restart({})
	equal(disk.dhcp.server, {"1.1.1.1"})
end)

test("domain-only and absent upstreams require no configuration commits", function()
	for _, options in ipairs({{servers = {"/lan/10.0.0.1"}}, {}}) do
		local env, disk, logs, restarts, commits = load_helper(options)
		env.logic_restart({})
		assert(#commits == 0 and #logs == 0 and restarts() == 1)
	end
end)

test("interrupted backup and concurrent DHCP updates survive restoration", function()
	local env, disk = load_helper({servers = {"1.1.1.1", "/lan/10.0.0.1"},
		backup = {"8.8.8.8", "1.1.1.1"}, on_restart = function(state)
			state.dhcp.server = {"/new/10.0.0.2", "/lan/10.0.0.1"}
		end})
	env.logic_restart({})
	equal(disk.dhcp.server, {"/new/10.0.0.2", "/lan/10.0.0.1", "1.1.1.1", "8.8.8.8"})
	assert(disk.passwall2.dnsmasq_servers == nil)
end)

test("failed backup commit aborts before touching DHCP or restarting", function()
	local env, disk, logs, restarts = load_helper({servers = {"1.1.1.1"},
		fail_commit = function(name) return name == "passwall2" end})
	env.logic_restart({})
	equal(disk.dhcp.server, {"1.1.1.1"})
	assert(disk.passwall2.dnsmasq_servers == nil and restarts() == 0 and #logs == 1)
end)

test("failed DHCP preparation retains the durable backup and aborts restart", function()
	local env, disk, logs, restarts = load_helper({servers = {"1.1.1.1"},
		fail_commit = function(name) return name == "dhcp" end})
	env.logic_restart({})
	equal(disk.dhcp.server, {"1.1.1.1"})
	equal(disk.passwall2.dnsmasq_servers, {"1.1.1.1"})
	assert(restarts() == 0 and #logs == 1)
end)

test("failed restore retains the backup for the next invocation", function()
	local env, disk, logs = load_helper({servers = {"1.1.1.1"},
		fail_commit = function(name, _, restarts) return name == "dhcp" and restarts > 0 end})
	env.logic_restart({})
	equal(disk.passwall2.dnsmasq_servers, {"1.1.1.1"})
	assert(#logs == 1 and logs[1]:find("restore"))
	local retry, restored = load_helper({backup = disk.passwall2.dnsmasq_servers})
	retry.logic_restart({})
	equal(restored.dhcp.server, {"1.1.1.1"})
	assert(restored.passwall2.dnsmasq_servers == nil)
end)

test("failed dnsmasq restart still restores upstreams and reports failure", function()
	local env, disk, logs = load_helper({servers = {"1.1.1.1"}, restart_status = 1})
	env.logic_restart({LOG = "1"})
	equal(disk.dhcp.server, {"1.1.1.1"})
	assert(disk.passwall2.dnsmasq_servers == nil and #logs == 1 and logs[1]:find("Failed"))
end)

test("no DEFAULT_DNS leaves upstreams untouched", function()
	local env, disk, _, restarts, commits = load_helper({servers = {"1.1.1.1"}, default_dns = false})
	env.logic_restart({})
	equal(disk.dhcp.server, {"1.1.1.1"})
	assert(restarts() == 1 and #commits == 0)
end)

test("stretch respects global upstreams in current state or interrupted backup", function()
	for _, options in ipairs({{servers = "1.1.1.1", noresolv = "1"},
		{servers = {"/lan/10.0.0.1"}, backup = {"1.1.1.1"}, noresolv = "1"}}) do
		local env, disk, _, _, commits = load_helper(options)
		env.stretch()
		assert(disk.dhcp.noresolv == "1" and #commits == 0)
	end
end)

test("stretch selects a valid resolver fallback without RPC writes", function()
	for _, size in ipairs({false, 0, 12}) do
		local env, disk = load_helper({servers = {"/lan/10.0.0.1"}, noresolv = "1",
			resolv_size = size ~= false and size or nil})
		env.stretch()
		assert(disk.dhcp.noresolv == nil)
		assert(disk.dhcp.resolvfile == (size and size > 0 and
			"/tmp/resolv.conf.d/resolv.conf.auto" or "/tmp/resolv.conf.auto"))
	end
end)

print("PASS " .. count .. " DNS runtime regression cases")
