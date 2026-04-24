-- ── Scene: Update ───────────────────────────────────────

local utils        = require("lib.utils")
local resetPalette = utils.resetPalette

local ui            = require("lib.ui")
local fill          = ui.fill
local centered      = ui.centered
local centerPos     = ui.centerPos
local drawButton    = ui.drawButton
local preciseDither = ui.preciseDither
local hitTest       = ui.hitTest
local drawBackBtn   = ui.drawBackBtn
local BACK_BTN      = ui.BACK_BTN
local drawSplash    = ui.drawSplash

local updater       = require("lib.updater")

-- ── Helpers ─────────────

local function statusLine()
    local u = S.updater
    if u.error == "no meta" then
        return "No install metadata. Reinstall manually.", colors.red
    end
    if u.error then
        return "Check failed: " .. u.error, colors.red
    end
    if not u.remote then
        return "Checking...", colors.gray
    end
    if u.hasUpdate then
        return "Update available: " .. u.local_ver .. " -> " .. u.remote, colors.orange
    end
    return "Up to date.", colors.green
end

-- ── Drawing ─────────────

local function drawUpdateScene()
    resetPalette()
    mon.setBackgroundColor(colors.white)
    mon.clear()
    preciseDither(1, 1, W, H, colors.white, colors.lightGray)
    drawBackBtn()

    local dw = math.min(60, W - 8)
    local dh = 13
    local dx = centerPos(W, dw)
    local dy = centerPos(H, dh)

    fill(dx, dy, dw, dh, colors.gray)
    fill(dx + 1, dy + 1, dw - 2, dh - 2, colors.lightGray)

    centered(dx, dy + 2, dw, "BEETLECRAFT UPDATER", colors.black, colors.lightGray)

    local u = S.updater
    local local_v  = u.local_ver or "?"
    local remote_v = u.remote or "?"
    centered(dx, dy + 4, dw, "Installed: v" .. local_v, colors.black, colors.lightGray)
    centered(dx, dy + 5, dw, "Latest:    v" .. remote_v, colors.black, colors.lightGray)

    local msg, col = statusLine()
    centered(dx, dy + 7, dw, msg, col, colors.lightGray)

    local btn_y   = dy + dh - 3
    local bw      = 16
    local check_x = dx + math.floor(dw / 2) - bw - 2
    local upd_x   = dx + math.floor(dw / 2) + 2

    drawButton(check_x, btn_y, bw, 1, "Check Again", colors.white, colors.blue)
    S.updater.check_btn = { x = check_x, y = btn_y, w = bw, h = 1 }

    local can_update = u.hasUpdate and u.base ~= nil
    local upd_bg = can_update and colors.green or colors.lightGray
    local upd_fg = can_update and colors.white or colors.gray
    drawButton(upd_x, btn_y, bw, 1, "Update Now", upd_fg, upd_bg)
    S.updater.update_btn = can_update and { x = upd_x, y = btn_y, w = bw, h = 1 } or nil
end

-- ── Actions ─────────────

local function doCheck()
    S.updater.remote = nil
    S.updater.error  = nil
    drawUpdateScene()
    updater.check()
    drawUpdateScene()
end

local function doUpdate()
    if not S.updater.hasUpdate then return end
    drawSplash("Updating to v" .. (S.updater.remote or "?") .. "...")
    local ok, err = updater.runUpdate()
    if not ok then
        S.updater.error = err or "update failed"
        drawUpdateScene()
    end
end

-- ── Input ───────────────

local function handleUpdateTouch(tx, ty)
    if hitTest(tx, ty, BACK_BTN) then
        S.scene = "home"
        S.dirty = true
        return
    end
    if hitTest(tx, ty, S.updater.check_btn) then
        doCheck()
        return
    end
    if hitTest(tx, ty, S.updater.update_btn) then
        doUpdate()
        return
    end
end

return {
    drawUpdateScene = drawUpdateScene,
    handleUpdateTouch = handleUpdateTouch,
}
