-- Exercise the actual outbound generator. No network, core binary or UCI mock
-- is used to claim a handshake; the full-system fixture covers that separately.
local source=assert(arg[1])
local version="1.14.4"
package.preload["luci.passwall2.api"]=function()
    return {CACHE_PATH="/tmp",fs={},sys={},jsonc={},datatypes={hostname=function() return false end},
        get_app_version=function() return version end,
        compare_versions=function(a,operator,b)
            local function number(v)
                local x,y,z=v:match("^(%d+)%.(%d+)%.(%d+)")
                return tonumber(x)*1000000+tonumber(y)*1000+tonumber(z)
            end
            assert(operator==">=")
            return number(a)>=number(b)
        end,
        sha256_xray_sb=function(value) assert(value=="test-pin"); return "converted-pin" end,
    }
end
local function generate(options)
    local node={[".name"]="fixture",type="sing-box",protocol="trojan",address="192.0.2.1",port="443",tls="1",password="fixture-password"}
    for key,value in pairs(options or {}) do node[key]=value end
    return require("luci.passwall2.util_sing-box").gen_outbound("fixture",node)
end
dofile(source)
assert(generate().tls.insecure==false, "default TLS verification disabled")
assert(generate({tls_allowInsecure="1"}).tls.insecure==true, "explicit existing user choice changed")
local ok,err=pcall(generate,{tls_pinSHA256="test-pin"})
assert(not ok and err:find("requires Sing%-Box 1.15"), "unsupported pin silently weakened TLS")
version="1.15.0"
dofile(source)
local supported=generate({tls_pinSHA256="test-pin"})
assert(supported.tls.certificate_sha256[1]=="converted-pin")
assert(supported.tls.insecure==false)
print("PASS real Sing-Box generator: normal verification, explicit user choice, unsupported pin rejected, supported pin emitted")
