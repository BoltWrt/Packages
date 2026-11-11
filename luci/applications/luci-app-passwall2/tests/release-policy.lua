local release = dofile(assert(arg[1]))
for _, tag in ipairs({"v26.11.9", "app/v2.13.0", "v1.14.4", "0.2.9"}) do
    assert(release.is_stable({tag_name=tag, prerelease=false}), tag)
end
for _, tag in ipairs({"v2.0.0-dev10", "v1.15.0-alpha.1", "v1.15.0-beta.1", "v1.15.0-rc.1", "snapshot", "nightly-2026.11.11", "unknown"}) do
    assert(not release.is_stable({tag_name=tag, prerelease=false}), tag)
end
assert(not release.is_stable({tag_name="v1.14.5", prerelease=true}))
assert(not release.is_stable({tag_name="v1.14.5", draft=true}))
assert(not release.is_stable({}))
assert(not release.is_stable(nil))
print("PASS stable release policy including falsely non-prerelease development tags")
