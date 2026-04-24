-- main.lua - Remilia Terminal
-- Wii-style home menu with profile cards, beetle game, and chat

BASE_DIR = fs.getDir(shell.getRunningProgram())

local utils     = require("lib.utils")
local loadUsers = utils.loadUsers
local parseBlit = utils.parseBlit

local ui        = require("lib.ui")
local drawSplash = ui.drawSplash
local hitTest    = ui.hitTest
local BACK_BTN   = ui.BACK_BTN

local reminet        = require("lib.reminet")
local fetchBeetleUser = reminet.fetchBeetleUser

local home      = require("scenes.home")
local drawHome          = home.drawHome
local handleHomeTouch   = home.handleHomeTouch
local drawAddDialog     = home.drawAddDialog
local submitAdd         = home.submitAdd
local handleAddTouch    = home.handleAddTouch

local profile   = require("scenes.profile")
local drawProfileScene = profile.drawProfileScene
local loadProfile      = profile.loadProfile

local beetle    = require("scenes.beetleboy")
local drawBeetleboyScene   = beetle.drawBeetleboyScene
local handleBeetleboyTouch = beetle.handleBeetleboyTouch
local clearBeetleAnim      = beetle.clearBeetleAnim

local chat      = require("scenes.chat")
local drawChatScene       = chat.drawChatScene
local initChat            = chat.initChat
local onWsMessage         = chat.onWsMessage
local onWsClosed          = chat.onWsClosed
local onReconnectTimer    = chat.onReconnectTimer
local sendChatMessage     = chat.sendChatMessage
local handleChatTouch     = chat.handleChatTouch

local update   = require("scenes.update")
local drawUpdateScene   = update.drawUpdateScene
local handleUpdateTouch = update.handleUpdateTouch

local updater  = require("lib.updater")


-- ── Config ──────────────────────────────────────────────

local SPIN_INTERVAL = 0.08

-- Dynamically loads beetles based on the existing sprites
-- Allows adding/removing any beetle by without touching the code
BEETLES = (function()
    local dir = fs.combine(BASE_DIR, "assets/nfp")
    local t = {}
    for _, file in ipairs(fs.list(dir)) do
        local key = file:match("^(.+)%.nfp$")
        if key then
            local label = key:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b)
                return a:upper() .. b
            end)
            t[#t + 1] = { key = key, label = label }
            t[key] = label
        end
    end
    table.sort(t, function(a, b) return a.key < b.key end)
    return t
end)()

-- ── Splash Screen ───────────────────────────────────────

do
    local f = fs.open(fs.combine(BASE_DIR, "assets/splash.nfp"), "r")
    if f then
        local raw = f.readAll()
        f.close()
        local lines = parseBlit(raw)
        while #lines > 0 and lines[#lines] == "" do
            table.remove(lines)
        end
        if #lines >= 3 then
            SPLASH_BLIT = { lines = lines, w = #lines[1], h = #lines / 3 }
        end
    end
end

-- ── State ───────────────────────────────────────────────

function buildEntries(users)
    local e = {
        {type="beetleboy", label="BEETLEBOY", bg=colors.green,    fg=colors.black},
        {type="chat",      label="CHAT",     bg=colors.lightBlue, fg=colors.black},
    }
    for _, u in ipairs(users) do
        e[#e+1] = {type="user", label=u, bg=colors.lightGray, fg=colors.black}
    end
    e[#e+1] = {type="add",    label="+",      bg=colors.lightGray, fg=colors.black}
    return e
end

user_list = loadUsers()

S = {
    scene    = "home",
    scroll   = 0,
    selected = nil,
    dirty    = true,
    entries  = buildEntries(user_list),
    profile  = nil,
    cells    = {},
    grid     = nil,

    add = { buf = "", ok = nil, cancel = nil },

    chat = {
        msgs = {}, last_id = 0, scroll = 0, input = "",
        send = nil, reconnect_timer = nil,
        ws_init = nil,
        img_hits = {}, img_view = nil, img_close = nil,
    },
    img_drag = nil,

    beetle = {
        data = nil, loading = false, timer = nil,
        result = nil, btns = {},
        anim = {
            state = nil, key = nil,
            reel = nil, pos = 1, timer = nil, msg = nil,
        },
    },

    updater = {
        local_ver = nil, remote = nil, base = nil,
        hasUpdate = false, error = nil,
        check_btn = nil, update_btn = nil,
    },
}


-- ── Main Loop ───────────────────────────────────────────

mon = peripheral.find("monitor") or term
if mon.setTextScale then mon.setTextScale(0.5) end
W, H = mon.getSize()

drawSplash("Welcome to the Remilia Corporation...")
sleep(1.5)

updater.check()

while true do
    if S.dirty then
        if S.scene == "home" then
            drawHome()
        elseif S.scene == "beetleboy" then
            if S.beetle.loading then
                drawBeetleboyScene()
                S.beetle.data = fetchBeetleUser()
                S.beetle.loading = false
                S.beetle.timer = os.startTimer(1)
            end
            drawBeetleboyScene()
        elseif S.scene == "chat" then
            if S.chat.ws_init then
                S.chat.ws_init = nil
                initChat()
            end
            drawChatScene()
        elseif S.scene == "profile" then
            if not S.profile then loadProfile() end
            drawProfileScene()
        elseif S.scene == "add" then
            drawHome()
            drawAddDialog()
        elseif S.scene == "update" then
            drawUpdateScene()
        end
        S.dirty = false
    end

    local ev = { os.pullEvent() }

    if ev[1] == "timer" and S.scene == "beetleboy" and ev[2] == S.beetle.timer then
        if S.beetle.data and S.beetle.data.cooldowns then
            local cd = S.beetle.data.cooldowns
            if cd.claimUBC then cd.claimUBC = cd.claimUBC - 1000 end
            if cd.catchBeetle then cd.catchBeetle = cd.catchBeetle - 1000 end
        end
        drawBeetleboyScene()
        S.beetle.timer = os.startTimer(1)

    elseif ev[1] == "timer" and S.scene == "beetleboy" and ev[2] == S.beetle.anim.timer then
        local anim = S.beetle.anim
        anim.pos  = anim.pos + 1

        local target_pos = #(anim.reel or {}) - 10

        if anim.state == "spinning" then
            if anim.pos >= target_pos - 12 then anim.state = "decel" end
            anim.timer = os.startTimer(SPIN_INTERVAL)
        elseif anim.state == "decel" then
            local remaining = target_pos - anim.pos
            if remaining <= 0 then
                anim.pos = target_pos
                anim.state = "result"
                anim.timer = os.startTimer(5)
            else
                anim.timer = os.startTimer(SPIN_INTERVAL + (1.0 - remaining / 12) * 0.5)
            end
        elseif anim.state == "result" then
            clearBeetleAnim()
        end
        drawBeetleboyScene()

    elseif ev[1] == "timer" and ev[2] == S.chat.reconnect_timer then
        onReconnectTimer()

    elseif ev[1] == "websocket_message" then
        onWsMessage(ev[3])

    elseif ev[1] == "websocket_closed" then
        onWsClosed()

    elseif ev[1] == "monitor_touch" or ev[1] == "mouse_click" then
        local tx, ty = ev[3], ev[4]
        if S.scene == "home" then
            handleHomeTouch(tx, ty)
        elseif S.scene == "beetleboy" then
            handleBeetleboyTouch(tx, ty)
        elseif S.scene == "profile" and hitTest(tx, ty, BACK_BTN) then
            S.scene  = "home"
            S.profile = nil
            S.dirty  = true
        elseif S.scene == "add" then
            handleAddTouch(tx, ty)
        elseif S.scene == "chat" then
            handleChatTouch(tx, ty)
        elseif S.scene == "update" then
            handleUpdateTouch(tx, ty)
        end

    elseif ev[1] == "mouse_drag" then
        if S.scene == "chat" and S.chat.img_view and S.img_drag then
            local tx, ty = ev[3], ev[4]
            S.chat.img_view.ox = tx - S.img_drag.off_x
            S.chat.img_view.oy = ty - S.img_drag.off_y
            drawChatScene()
        end

    elseif ev[1] == "mouse_up" then
        S.img_drag = nil

    elseif ev[1] == "mouse_scroll" then
        if S.scene == "home" then
            S.scroll = S.scroll + ev[2]
            S.dirty  = true
        elseif S.scene == "chat" and not S.chat.img_view then
            S.chat.scroll = S.chat.scroll + ev[2]
            drawChatScene()
        end

    elseif ev[1] == "char" then
        if S.scene == "add" then
            S.add.buf = S.add.buf .. ev[2]
            drawAddDialog()
        elseif S.scene == "chat" and not S.chat.img_view then
            S.chat.input = S.chat.input .. ev[2]
            drawChatScene()
        end

    elseif ev[1] == "key" then
        if S.scene == "add" then
            if ev[2] == keys.enter then
                submitAdd()
            elseif ev[2] == keys.backspace then
                S.add.buf = S.add.buf:sub(1, -2)
                drawAddDialog()
            end
        elseif S.scene == "chat" then
            if S.chat.img_view and ev[2] == keys.backspace then
                S.chat.img_view = nil
                S.chat.img_close = nil
                drawChatScene()
            elseif ev[2] == keys.enter then
                sendChatMessage()
            elseif ev[2] == keys.backspace then
                S.chat.input = S.chat.input:sub(1, -2)
                drawChatScene()
            end
        end

    elseif ev[1] == "peripheral" or ev[1] == "peripheral_detach" then
        S.dirty = true
    end
end
