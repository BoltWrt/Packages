-- Load the real API; only its platform bindings and binary Base64 primitive
-- are supplied here. Fixed vectors include NUL and all-high-bit bytes.
local encoded="AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="
local raw=""; local hex=""
for byte=0,31 do raw=raw .. string.char(byte); hex=hex .. string.format("%02X",byte) end
local high=string.rep(string.char(255),32)
local high64="//////////////////////////////////////////8="
package.preload["nixio"]=function() return {bin={
    b64decode=function(value) if value==encoded then return raw elseif value==high64 then return high end end,
    b64encode=function(value) if value==raw then return encoded elseif value==high then return high64 end; error("unexpected binary vector") end,
}} end
for _,name in ipairs({"luci.passwall2.com","nixio.util","nixio.fs","luci.sys","luci.util","luci.cbi.datatypes","luci.jsonc"}) do
    package.preload[name]=function() return {} end
end
package.preload["luci.model.uci"]=function() return {cursor=function() return {get=function() return "en" end} end} end
package.preload["luci.i18n"]=function() return {setlanguage=function() end} end
dofile(assert(arg[1]))
local api=require("luci.passwall2.api")
assert(api.sha256_sb_xray(encoded)==hex, "NUL bytes were removed from the digest")
assert(api.sha256_xray_sb(hex)==encoded)
assert(api.sha256_xray_sb(encoded)==encoded)
assert(api.sha256_sb_xray(high64)==string.rep("FF",32))
assert(api.sha256_sb_xray(high64:gsub("/","_"):gsub("=+$",""))==string.rep("FF",32))
assert(api.sha256_xray_sb(high64)==high64)
assert(api.sha256_sb_xray("invalid-pin")=="invalid-pin")
print("PASS real certificate pin conversions: NUL/high-bit bytes, hex/Base64 roundtrip and URL-safe Base64")
