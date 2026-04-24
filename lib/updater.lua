-- ── Updater ─────────────────────────────────────────────
-- Checks the repo the installer was built from for a newer VERSION.
-- Meta file is written by installer/install.lua at install time.

local function metaPath()    return fs.combine(BASE_DIR, ".install.meta") end
local function versionPath() return fs.combine(BASE_DIR, "VERSION")       end
local function tmpInstaller() return "/install.lua"                       end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function readMeta()
    local path = metaPath()
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    local meta = {}
    for line in data:gmatch("[^\n]+") do
        local k, v = line:match("^(%S+)=(.+)$")
        if k and v then meta[k] = trim(v) end
    end
    return meta
end

local function getLocal()
    local path = versionPath()
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    return trim(data)
end

local function getRemote(base)
    if not base then return nil, "no BASE" end
    local ok, res = pcall(http.get, base .. "/VERSION")
    if not ok or not res then return nil, "request failed" end
    local code = res.getResponseCode and res.getResponseCode() or 200
    local body = res.readAll()
    res.close()
    if code ~= 200 or not body or #body == 0 then
        return nil, "http " .. tostring(code)
    end
    return trim(body)
end

local function check()
    S.updater.local_ver = getLocal()
    local meta = readMeta()
    S.updater.base = meta and meta.BASE or nil
    if not S.updater.base then
        S.updater.error = "no meta"
        S.updater.hasUpdate = false
        return
    end
    local remote, err = getRemote(S.updater.base)
    if not remote then
        S.updater.error = err
        S.updater.remote = nil
        S.updater.hasUpdate = false
        return
    end
    S.updater.error  = nil
    S.updater.remote = remote
    S.updater.hasUpdate = (S.updater.local_ver ~= remote)
end

local function runUpdate()
    if not S.updater.base then return false, "no BASE" end
    local url = S.updater.base .. "/installer/install.lua"
    local ok, res = pcall(http.get, url)
    if not ok or not res then return false, "download failed" end
    local body = res.readAll(); res.close()
    if not body or #body == 0 then return false, "empty installer" end

    local dest = tmpInstaller()
    local f = fs.open(dest, "w")
    if not f then return false, "write failed" end
    f.write(body)
    f.close()

    shell.run("install")
    return true
end

return {
    check = check,
    runUpdate = runUpdate,
}
