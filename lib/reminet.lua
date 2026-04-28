local utils = require("lib.utils")
local auth  = require("lib.auth")

local REMILIA_BASE = "https://www.remilia.net"
local CDN_BASE   = "https://cdn.goulag.dev"

local function httpGetJSON(url)
    local ok, res = pcall(http.get, url)
    if not ok or not res then return nil end
    local body = res.readAll(); res.close()
    return textutils.unserializeJSON(body)
end

local function fetchProfile(username)
    local res, err = http.get(REMILIA_BASE .. "/api/profile/~" .. username)
    if not res then return nil, (err or "request failed") end
    local body = res.readAll()
    res.close()
    local parsed = textutils.unserializeJSON(body)
    if not parsed or not parsed.user then return nil, "unexpected response" end
    local u = parsed.user
    return {
        username          = u.username,
        displayName       = u.displayName,
        pfpUrl            = u.pfpUrl,
        bio               = u.bio,
        color             = u.color,
        location          = u.location,
        friendCount       = u.friendCount,
        achievementsCount = u.achievementsCount,
        pageViews         = u.pageViews,
        pokes             = u.pokes,
        beetles           = u.beetles,
        socialCreditScore = u.socialCredit and u.socialCredit.score,
        pfpProject        = u.pfp and u.pfp.project,
    }
end

-- External dependency; ranks aren't computed on reminet yet
local function fetchRanks(username)
    local parsed = httpGetJSON("https://api.remistats.net/users?minimal=true&usernames=" .. username)
    if not parsed or not parsed.users then return nil end
    local u = parsed.users[username]
    if not u then return nil end
    return {
        globalRank   = u.globalRank,
        totalUsers   = parsed.totalUsers,
        projectRank  = u.projectRank,
        projectTotal = u.projectTotal,
    }
end

local function fetchBeetleUser()
    local res = auth.authGet(REMILIA_BASE .. "/api/beetle/user")
    if not res then return nil end
    local body = res.readAll(); res.close()
    return textutils.unserializeJSON(body)
end

local function doBeetleAction(action)
    local res = auth.authPost(REMILIA_BASE .. "/api/beetle/action/" .. action, "{}")
    if not res then return { success = false, msg = "REQUEST FAILED" } end
    local body = res.readAll(); res.close()
    local parsed = textutils.unserializeJSON(body)
    if not parsed then return { success = false, msg = "BAD RESPONSE" } end
    local user = parsed.user
    local result = parsed.result or parsed
    if not parsed.success and not result.success then
        return { success = false, msg = result.error or "FAILED", user = user }
    end
    if result.cheese then
        local msg = "+" .. result.cheese .. " CHEESE"
        if result.streak then msg = msg .. " Streak: " .. result.streak end
        return { success = true, msg = msg, user = user }
    elseif result.beetleCard then
        local msg = result.beetleCard.beetle_name or "?"
        if result.xp then msg = msg .. " +" .. result.xp .. " XP" end
        if result.secondaryItemDrops then
            for _, drop in ipairs(result.secondaryItemDrops) do
                if drop.beetle_name then msg = msg .. "  +" .. drop.beetle_name end
            end
        end
        return { success = true, msg = msg, beetle_key = result.beetleCard.beetle, user = user }
    else
        local msg = "OK!"
        if result.xp then msg = msg .. " +" .. result.xp .. " XP" end
        return { success = true, msg = msg, user = user }
    end
end

local function cdnConvert(img_url, opts)
    local form = "url=" .. utils.urlencode(img_url)
    if opts then
        for k, v in pairs(opts) do
            form = form .. "&" .. k .. "=" .. utils.urlencode(tostring(v))
        end
    end
    local ok, res = pcall(http.post, CDN_BASE .. "/convert", form, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
    })
    if not ok or not res then return nil end
    local body = res.readAll(); res.close()
    local parsed = textutils.unserializeJSON(body)
    if not parsed or not parsed.code then return nil end
    return parsed
end

-- the cdn allows downloading each frames but for the beetleboy we always only care about the first one
local function cdnFetchNFP(code)
    local ok, res = pcall(http.get, CDN_BASE .. "/asset/" .. code .. "/1")
    if not ok or not res then return nil end
    local body = res.readAll(); res.close()
    if not body or #body == 0 then return nil end
    return body
end

local function fetchAvatarBlit(pfp_url, av_w, av_h)
    local abs_pfp = pfp_url
    if abs_pfp:sub(1, 1) == "/" then
        abs_pfp = REMILIA_BASE .. abs_pfp
    end

    local result = cdnConvert(abs_pfp, {
        w = av_w, h = av_h,
        mode = "square", reserve = 4,
    })
    if not result then return nil, "cdn convert failed" end

    local nfp = cdnFetchNFP(result.code)
    if not nfp then return nil, "cdn fetch failed" end

    local lines, free_colors = utils.parseBlit(nfp)
    if #free_colors == 0 then return nil, "bad response" end
    return { lines = lines, free = free_colors }
end

local function fetchChatImage(img_url, max_w, max_h)
    local result = cdnConvert(img_url, {
        w = max_w, h = max_h,
        mode = "fit",
    })
    if not result then return nil end

    local meta = result.meta or {}
    local blit_w = meta.width or max_w
    local blit_h = meta.height or max_h

    local nfp = cdnFetchNFP(result.code)
    if not nfp then return nil end

    local lines = utils.parseBlit(nfp)
    return { lines = lines, w = blit_w, h = blit_h }
end

return {
    fetchProfile = fetchProfile,
    fetchRanks = fetchRanks,
    fetchAvatarBlit = fetchAvatarBlit,
    fetchBeetleUser = fetchBeetleUser,
    doBeetleAction = doBeetleAction,
    fetchChatImage = fetchChatImage,
}
