-- Convert the 4.0.0 server schema without changing section IDs, enable intent,
-- credentials, custom JSON, or certificate paths. The caller backs up first.
local M = {}
local supported = { SS=true, SSR=true, ["SS-Rust"]=true, Xray=true,
    ["sing-box"]=true, Hysteria2=true }

local function values(value)
    if type(value) == "table" then return value end
    return value and value ~= "" and {value} or {}
end

local function websocket_path(node)
    if node.type ~= "sing-box" or node.transport ~= "ws" or not tonumber(node.ws_maxEarlyData) then return nil end
    local path = node.ws_path or "/"
    local existing = {}
    for part in (path:match("%?(.*)$") or ""):gmatch("[^&]+") do
        local key = part:match("^([^=]+)") or ""
        key = key:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex,16)) end)
        existing[key] = true
    end
    local function append(key, value)
        local separator = path:find("?",1,true) and "&" or "?"
        path = path .. separator .. key .. "=" .. tostring(value):gsub("([^%w%-%._~])",function(char) return string.format("%%%02X",char:byte()) end)
    end
    if not existing.ed then append("ed", node.ws_maxEarlyData) end
    if not existing.eh and node.ws_earlyDataHeaderName and node.ws_earlyDataHeaderName ~= "" then append("eh",node.ws_earlyDataHeaderName) end
    return path ~= (node.ws_path or "/") and path or nil
end

function M.plan(sections, nodes)
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
                    account(nil, section.hysteria_auth_password)
                elseif protocol == "naive" or protocol == "anytls" then
                    account(nil, section.password, section.username)
                elseif protocol == "socks" or protocol == "http" or protocol == "mixed" then
                    if section.auth == "1" then account(nil, section.password, section.username) end
                elseif protocol == "shadowsocks" then
                    options.ss_method = section.method
                    options.ss_password = section.password
                elseif protocol == "dokodemo-door" and section.type == "Xray" then
                    options.protocol = "tunnel"
                end
                if section.type == "Xray" and section.transport == "tcp" then
                    options.transport = "raw"
                end
            end
            if #update.users > 0 then options.users = update.users end
            servers[#servers + 1] = update
        end
    end
    local clients = {}
    for _, node in ipairs(nodes or {}) do
        if node[".type"] == "nodes" and (node.type == "Xray" or node.type == "sing-box") then
            local options = {}
            if node.type == "Xray" and node.transport == "tcp" then options.transport = "raw" end
            if node.type == "Xray" and (not node.tls_pinSHA256 or node.tls_pinSHA256 == "") and node.tls_CertSha and node.tls_CertSha ~= "" then
                options.tls_pinSHA256 = node.tls_CertSha
            end
            local method = node.protocol == "shadowsocks" and "ss_method" or (node.protocol == "shadowsocksr" and "ssr_method")
            if method and (not node[method] or node[method] == "") and node.method then options[method] = node.method end
            options.ws_path = websocket_path(node)
            if next(options) then clients[#clients + 1] = { id=node[".name"], options=options } end
        end
    end
    -- 4.0.0 used literal disable/default sentinels and implicitly inherited
    -- global ACL settings. The new ACL builder expects real port expressions,
    -- list-valued sources and an explicit mode. Resolve the old semantics
    -- before it can generate nftables rules.
    local forwarding = {}
    for _, section in ipairs(nodes or {}) do
        if section[".type"] == "global_forwarding" and not forwarding[".name"] then forwarding = section end
    end
    local function inherited(rule, key)
        local value = rule[key]
        if not value or value == "" or value == "default" then value = forwarding[key] end
        if not value or value == "" or value == "default" then
            value = key:find("no_redir",1,true) and "disable" or "1:65535"
        end
        return value ~= "disable" and value or nil
    end
    local function all_ports(value)
        local ports = "," .. (value or ""):gsub("%s", ""):gsub(":", "-") .. ","
        return ports:find(",1-65535,",1,true) or ports:find(",0-65535,",1,true)
    end
    for _, section in ipairs(nodes or {}) do
        local options, remove = {}, {}
        local function change(key, value)
            if section[key] ~= value then
                if value == nil then remove[#remove+1] = key else options[key] = value end
            end
        end
        if section[".type"] == "global_forwarding" then
            for _, key in ipairs({"tcp_no_redir_ports", "udp_no_redir_ports"}) do
                if section[key] == "disable" then change(key, nil) end
            end
        elseif section[".type"] == "acl_rule" then
            if type(section.sources) == "string" and section.sources ~= "" then
                local sources = {}; for source in section.sources:gmatch("%S+") do sources[#sources+1] = source end
                options.sources = sources
            end
            if not section.mode or section.mode == "" then
                local inherit_ports = {}
                for _, key in ipairs({"tcp_no_redir_ports", "udp_no_redir_ports", "tcp_redir_ports", "udp_redir_ports"}) do
                    change(key, inherited(section, key))
                    if not section[key] or section[key] == "" or section[key] == "default" then inherit_ports[#inherit_ports+1] = key end
                end
                options.boltwrt_401_legacy_acl = "1"
                if #inherit_ports > 0 then options.boltwrt_401_inherit_ports = inherit_ports end
                local node = section.node
                if all_ports(section.tcp_no_redir_ports) and all_ports(section.udp_no_redir_ports) then
                    options.mode = "0"
                elseif not node or node == "" or node == "default" then
                    options.mode = "2"
                    change("node", nil)
                else
                    options.mode = "1"
                    local defaults = {direct_dns_query_strategy="UseIP",remote_dns_protocol="tcp",
                        remote_dns="1.1.1.1",remote_dns_doh="https://1.1.1.1/dns-query",
                        remote_dns_detour="remote",remote_fakedns="0",remote_dns_query_strategy="UseIPv4"}
                    for key, value in pairs(defaults) do
                        if not section[key] or section[key] == "" then options[key] = value end
                    end
                end
            end
        end
        if next(options) or #remove > 0 then
            clients[#clients+1] = {id=section[".name"], options=options, remove=remove}
        end
    end
    return {servers=servers, accounts=accounts, clients=clients}
end

function M.read(cursor)
    local sections = {}
    cursor:foreach("passwall2_server", nil, function(section)
        sections[#sections + 1] = section
    end)
    local nodes = {}
    cursor:foreach("passwall2", nil, function(node) nodes[#nodes + 1] = node end)
    return M.plan(sections, nodes)
end

function M.apply(cursor, plan)
    local config = "passwall2_server"
    for _, account in ipairs(plan.accounts) do
        assert(not cursor:get(config, account.id), "migration account collision")
        assert(cursor:set(config, account.id, "user"), "cannot create migration account")
        for key, value in pairs(account.options) do
            assert(cursor:set(config, account.id, key, value), "cannot migrate account option")
        end
    end
    for _, server in ipairs(plan.servers) do
        assert(cursor:set(config, server.id, "server"), "cannot migrate server section")
        for key, value in pairs(server.options) do
            -- Native libuci's set accepts scalar and list values; set_list is
            -- a LuCI wrapper method and is absent from the boot-time cursor.
            assert(cursor:set(config, server.id, key, value), "cannot migrate server option")
        end
    end
    if #plan.servers > 0 then
        assert(cursor:save(config), "cannot save migrated server config")
        assert(cursor:commit(config), "cannot commit migrated server config")
    end
    for _, client in ipairs(plan.clients) do
        for key,value in pairs(client.options) do
            assert(cursor:set("passwall2", client.id, key, value), "cannot migrate client setting")
        end
        for _, key in ipairs(client.remove or {}) do
            assert(cursor:delete("passwall2", client.id, key), "cannot remove obsolete client setting")
        end
    end
    if #plan.clients > 0 then
        assert(cursor:save("passwall2"), "cannot save migrated client config")
        assert(cursor:commit("passwall2"), "cannot commit migrated client config")
    end
    return #plan.servers, #plan.clients
end

return M
