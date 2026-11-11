-- Convert the 4.0.0 server schema without changing section IDs, enable intent,
-- credentials, custom JSON, or certificate paths. The caller backs up first.
local M = {}
local supported = { SS=true, SSR=true, ["SS-Rust"]=true, Xray=true,
    ["sing-box"]=true, Hysteria2=true }

local function values(value)
    if type(value) == "table" then return value end
    return value and value ~= "" and {value} or {}
end

function M.plan(sections)
    local occupied, servers, accounts = {}, {}, {}
    for _, section in ipairs(sections) do occupied[section[".name"]] = true end
    for _, section in ipairs(sections) do
        if section[".type"] == "user" and supported[section.type] then
            local id = assert(section[".name"])
            local update = { id=id, options={}, users={} }
            local options = update.options
            -- The former bind_local setting also controlled firewall exposure.
            options.firewall_allow = section.bind_local == "1" and "0" or "1"
            options.firewall_allow_src = "wan"
            local function account(uuid, password, username)
                local number = 1
                local prefix = "bw401_" .. id .. "_"
                while occupied[prefix .. number] do number = number + 1 end
                local name = prefix .. number
                occupied[name] = true
                local item = { id=name, options={
                    username=username or (id .. "_" .. number),
                    password=password or "", uuid=uuid
                } }
                accounts[#accounts + 1] = item
                update.users[#update.users + 1] = name
                return name
            end
            if section.type == "SS" or section.type == "SSR" or section.type == "SS-Rust" then
                options.user = account(nil, section.password, section.username)
            elseif section.type == "Xray" or section.type == "sing-box" then
                local protocol = section.protocol
                if protocol == "vmess" or protocol == "vless" then
                    for _, uuid in ipairs(values(section.uuid)) do account(uuid) end
                elseif protocol == "trojan" then
                    for _, password in ipairs(values(section.uuid)) do account(nil, password) end
                elseif protocol == "tuic" then
                    for _, uuid in ipairs(values(section.uuid)) do account(uuid, section.password) end
                elseif protocol == "hysteria2" then
                    if section.hysteria2_auth_password then account(nil, section.hysteria2_auth_password) end
                elseif protocol == "hysteria" then
                    if section.hysteria_auth_password then account(nil, section.hysteria_auth_password) end
                elseif protocol == "socks" or protocol == "http" or protocol == "mixed" then
                    if section.auth == "1" then account(nil, section.password, section.username) end
                elseif protocol == "shadowsocks" and section.type == "Xray" then
                    options.ss_method = section.method
                    options.ss_password = section.password
                elseif protocol == "dokodemo-door" and section.type == "Xray" then
                    options.protocol = "tunnel"
                end
            end
            if #update.users > 0 then options.users = update.users end
            servers[#servers + 1] = update
        end
    end
    return {servers=servers, accounts=accounts}
end

function M.read(cursor)
    local sections = {}
    cursor:foreach("passwall2_server", nil, function(section)
        sections[#sections + 1] = section
    end)
    return M.plan(sections)
end

function M.apply(cursor, plan)
    local config = "passwall2_server"
    for _, account in ipairs(plan.accounts) do
        assert(not cursor:get(config, account.id), "migration account collision")
        assert(cursor:section(config, "user", account.id, account.options), "cannot create migration account")
    end
    for _, server in ipairs(plan.servers) do
        assert(cursor:set(config, server.id, "server"), "cannot migrate server section")
        for key, value in pairs(server.options) do
            -- Native libuci's set accepts scalar and list values; set_list is
            -- a LuCI wrapper method and is absent from the boot-time cursor.
            assert(cursor:set(config, server.id, key, value), "cannot migrate server option")
        end
    end
    assert(cursor:save(config), "cannot save migrated server config")
    assert(cursor:commit(config), "cannot commit migrated server config")
    return #plan.servers
end

return M
