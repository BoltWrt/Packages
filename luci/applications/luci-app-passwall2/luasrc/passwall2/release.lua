local M = {}

function M.is_stable(release)
    if type(release) ~= "table" or release.prerelease or release.draft then return false end
    local tag = release.tag_name
    if type(tag) ~= "string" or not tag:match("%d+%.%d+%.%d+") then return false end
    tag = tag:lower()
    for _, marker in ipairs({"dev", "alpha", "beta", "rc", "nightly", "snapshot"}) do
        if tag:find(marker, 1, true) then return false end
    end
    return true
end

return M
