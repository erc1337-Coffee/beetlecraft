local TOKEN_URL = "https://www.remilia.net/oidc/realms/remilia/protocol/openid-connect/token"

local access_token  = nil
local refresh_token = nil

local function envPath()
    return fs.combine(BASE_DIR, ".env")
end

local function loadRefreshToken()
    local path = envPath()
    if not fs.exists(path) then return end
    local f = fs.open(path, "r")
    if not f then return end
    local data = f.readAll()
    f.close()
    for line in data:gmatch("[^\n]+") do
        local k, v = line:match("^(%S+)=(.+)$")
        if k == "REFRESH_TOKEN" then refresh_token = v end
    end
end

local function saveRefreshToken()
    local path = envPath()
    local lines, found = {}, false
    if fs.exists(path) then
        local rf = fs.open(path, "r")
        if rf then
            local data = rf.readAll()
            rf.close()
            for line in (data .. "\n"):gmatch("([^\n]*)\n") do
                if line:match("^REFRESH_TOKEN=") then
                    lines[#lines + 1] = "REFRESH_TOKEN=" .. (refresh_token or "")
                    found = true
                else
                    lines[#lines + 1] = line
                end
            end
            if lines[#lines] == "" then lines[#lines] = nil end
        end
    end
    if not found then
        lines[#lines + 1] = "REFRESH_TOKEN=" .. (refresh_token or "")
    end
    local f = fs.open(path, "w")
    if not f then return end
    f.write(table.concat(lines, "\n") .. "\n")
    f.close()
end

local function getToken()
    return access_token
end

local function refresh()
    if not refresh_token then return false end
    local body = "grant_type=refresh_token"
        .. "&refresh_token=" .. textutils.urlEncode(refresh_token)
        .. "&client_id=profile"
    local ok, res = pcall(http.post, TOKEN_URL, body, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Origin"] = "https://www.remilia.net",
        ["User-Agent"] = "I am a computer, a real one, trust me",
    })
    if not ok or not res then return false end
    local raw = res.readAll(); res.close()
    local jok, parsed = pcall(textutils.unserializeJSON, raw)
    if not jok or not parsed or not parsed.access_token then return false end
    access_token = parsed.access_token
    if parsed.refresh_token then
        refresh_token = parsed.refresh_token
        saveRefreshToken()
    end
    return true
end

local function authHeaders(extra)
    local h = {
        ["Accept"] = "application/json",
        ["Content-Type"] = "application/json",
        ["Origin"] = "https://www.remilia.net",
        ["Referer"] = "https://www.remilia.net/home?cartridge=beetle",
        ["User-Agent"] = "I am a computer, a real one, trust me",
    }
    if access_token then
        h["Cookie"] = "authToken=" .. access_token
    end
    if extra then
        for k, v in pairs(extra) do h[k] = v end
    end
    return h
end

local function authGet(url, extra_headers)
    local hdrs = authHeaders(extra_headers)
    local ok, res = pcall(http.get, url, hdrs)
    if not ok or not res then return nil end
    local code = res.getResponseCode()
    if code == 401 then
        res.close()
        if not refresh() then return nil end
        hdrs = authHeaders(extra_headers)
        ok, res = pcall(http.get, url, hdrs)
        if not ok or not res then return nil end
    end
    return res
end

local function authPost(url, body, extra_headers)
    local hdrs = authHeaders(extra_headers)
    local ok, res = pcall(http.post, url, body, hdrs)
    if not ok or not res then return nil end
    local code = res.getResponseCode()
    if code == 401 then
        res.close()
        if not refresh() then return nil end
        hdrs = authHeaders(extra_headers)
        ok, res = pcall(http.post, url, body, hdrs)
        if not ok or not res then return nil end
    end
    return res
end

loadRefreshToken()
refresh()

return {
    getToken = getToken,
    refresh = refresh,
    authGet = authGet,
    authPost = authPost,
    authHeaders = authHeaders,
}
