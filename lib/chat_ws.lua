local auth = require("lib.auth")

local WS_URL    = "wss://boards.miladychan.org/api/socket"
local REST_URL  = "https://boards.miladychan.org/json/chat/beetle/201346/"
local IMG_BASE = "https://boards.miladychan.org/assets/images/src"

local ws = nil
local RECONNECT_BASE = 2
local RECONNECT_MAX  = 30
local reconnect_delay = RECONNECT_BASE
local intentional_close = false

local FILE_TYPE_EXT = {
    [0] = "jpg", [1] = "png", [2] = "gif", [16] = "avif",
}

local function chatImageUrl(image)
    if not image then return nil end
    local sha1 = image.sha1
    local ft = image.file_type
    if not sha1 or ft == nil then return nil end
    local ext = FILE_TYPE_EXT[ft]
    if not ext then return nil end
    return IMG_BASE .. "/" .. sha1 .. "." .. ext
end

local function parseMessage(raw)
    if not raw or #raw < 3 then return nil end
    local opcode = raw:sub(1, 2)
    local payload = raw:sub(3)
    return opcode, payload
end

local function parseChatPost(obj)
    if not obj then return nil end
    local img_url = chatImageUrl(obj.image)
    local user = obj.user
    return {
        id       = obj.id or obj.no or 0,
        name     = obj.name or "???",
        username = user and user.username or obj.name or "???",
        body     = img_url and "[image]" or (obj.body or obj.com or ""),
        time     = obj.time or 0,
        image_url = img_url,
    }
end

local function connect()
    local token = auth.getToken()
    if not token then return false end

    local ok, handle = pcall(http.websocket, WS_URL, {
        ["Origin"] = "https://www.remilia.net",
    })
    if not ok or not handle then return false end
    ws = handle

    local auth_msg = "30" .. textutils.serializeJSON({
        board = "beetle",
        thread = "201346",
        shoutboxtoken = token,
        multisync = false,
    })
    ws.send(auth_msg)
    reconnect_delay = RECONNECT_BASE
    return true
end

local function close()
    intentional_close = true
    if ws then
        pcall(ws.close)
        ws = nil
    end
end

local function onClosed()
    ws = nil
    if intentional_close then
        intentional_close = false
        return false
    end
    return true
end

local function send(text)
    if not ws then return false end
    local msg = "01" .. textutils.serializeJSON({
        password = "abcdefgh",
        open = true,
        sage = false,
        body = text,
        name = "",
    })
    local ok = pcall(ws.send, msg)
    if ok then
        pcall(ws.send, "05")
    end
    return ok
end

local function safeJSON(str)
    local ok, val = pcall(textutils.unserializeJSON, str)
    if ok then return val end
    return nil
end

local function handleMessage(raw)
    local opcode, payload = parseMessage(raw)
    if not opcode then return nil end

    if opcode == "01" then
        local msg = parseChatPost(safeJSON(payload))
        if msg then return { msg } end

    elseif opcode == "33" then
        local arr = safeJSON(payload)
        if type(arr) ~= "table" then return nil end
        local msgs = {}
        for _, item in ipairs(arr) do
            local inner_op, inner_payload = parseMessage(item)
            if inner_op == "01" then
                local msg = parseChatPost(safeJSON(inner_payload))
                if msg then msgs[#msgs + 1] = msg end
            end
        end
        if #msgs > 0 then return msgs end
    end

    return nil
end

local function fetchHistory(last_count)
    local token = auth.getToken()
    if not token then return nil end
    local url = REST_URL .. token .. "?last=" .. (last_count or 100)
    local ok, res = pcall(http.get, url)
    if not ok or not res then return nil end
    local body = res.readAll(); res.close()
    local parsed = safeJSON(body)
    if not parsed or not parsed.posts then return nil end
    local msgs = {}
    for _, obj in ipairs(parsed.posts) do
        local msg = parseChatPost(obj)
        if msg then msgs[#msgs + 1] = msg end
    end
    return msgs
end

local function getReconnectDelay()
    local d = reconnect_delay
    reconnect_delay = math.min(reconnect_delay * 2, RECONNECT_MAX)
    return d
end

return {
    connect = connect,
    close = close,
    onClosed = onClosed,
    send = send,
    handleMessage = handleMessage,
    fetchHistory = fetchHistory,
    getReconnectDelay = getReconnectDelay,
}
