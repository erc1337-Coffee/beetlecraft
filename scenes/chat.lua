-- ── Scene: Chat ─────────────────────────────────────────

local utils        = require("lib.utils")
local fmtTime      = utils.fmtTime
local resetPalette = utils.resetPalette
local setPalette   = utils.setPalette
local SOFT_WHITE   = utils.SOFT_WHITE

local ui            = require("lib.ui")
local fill          = ui.fill
local at            = ui.at
local centered      = ui.centered
local centerPos     = ui.centerPos
local drawButton    = ui.drawButton
local preciseDither = ui.preciseDither
local hitTest       = ui.hitTest
local BACK_BTN      = ui.BACK_BTN
local drawBackBtn   = ui.drawBackBtn
local drawBlit      = ui.drawBlit
local drawSplash    = ui.drawSplash

local reminet        = require("lib.reminet")
local fetchChatImage = reminet.fetchChatImage

local chat_ws = require("lib.chat_ws")

-- ── Config ──────────────

local MAX_CHAT_MSGS = 100

local NAME_COLORS = {
  colors.cyan, colors.orange, colors.magenta, colors.lightBlue,
  colors.yellow, colors.lime, colors.pink, colors.red,
}

local CHAT_CONT = 8
local WIN_TB = 3
local IMG_TAG = "[image]"

-- ── Helpers ─────────────

local function nameColor(name)
  local h = 0
  for i = 1, #name do h = (h * 31 + name:byte(i)) % 256 end
  return NAME_COLORS[(h % #NAME_COLORS) + 1]
end

local function wrapLine(lines, body, bw, cw, prefix)
  if #body <= bw or bw <= 0 then
      lines[#lines + 1] = prefix
      prefix.body = body
      return
  end
  prefix.body = body:sub(1, bw)
  lines[#lines + 1] = prefix
  local rest = body:sub(bw + 1)
  while #rest > cw do
      lines[#lines + 1] = {t = "c", body = rest:sub(1, cw)}
      rest = rest:sub(cw + 1)
  end
  if #rest > 0 then
      lines[#lines + 1] = {t = "c", body = rest}
  end
end

local function buildChatLines(msg_w)
  local lines = {}
  for _, msg in ipairs(S.chat.msgs) do
      local name = msg.name or "???"
      local body = msg.body or ""
      local ts   = fmtTime(msg.time)
      local col  = nameColor(msg.username or name)
      local img  = msg.image_url
      if img and body == IMG_TAG then body = "" end
      local plen = 6 + #name + 2
      local bw   = msg_w - plen
      if bw < 10 then bw = msg_w - CHAT_CONT end
      local cw = msg_w - CHAT_CONT

      if img and #body > 0 then
          wrapLine(lines, body, bw, cw, {t = "m", time = ts, name = name, col = col})
          lines[#lines + 1] = {t = "c", body = IMG_TAG, image_url = img}
      elseif img then
          lines[#lines + 1] = {t = "m", time = ts, name = name, body = IMG_TAG, col = col, image_url = img}
      else
          wrapLine(lines, body, bw, cw, {t = "m", time = ts, name = name, col = col})
      end
  end
  return lines
end

local function imgDialogPos(dw, dh)
  local v = S.chat.img_view
  if v and v.ox and v.oy then return v.ox, v.oy end
  return centerPos(W, dw), centerPos(H, dh)
end

-- ── Drawing ─────────────

local function drawWinFrame(title, dx, dy, dw, dh)
  local ty = dy + math.floor(WIN_TB / 2)
  fill(dx, dy, dw, WIN_TB, colors.blue)
  at(dx + 2, ty, title, colors.white, colors.blue)

  local cx = dx + dw - 4
  drawButton(cx, dy, 4, WIN_TB, "X", colors.white, colors.red)
  S.chat.img_close = {x = cx, y = dy, w = 4, h = WIN_TB}

  fill(dx, dy + WIN_TB, 1, dh - WIN_TB, colors.lightGray)
  fill(dx + dw - 1, dy + WIN_TB, 1, dh - WIN_TB, colors.lightGray)
  fill(dx, dy + dh - 1, dw, 1, colors.lightGray)
  fill(dx + 1, dy + WIN_TB, dw - 2, dh - WIN_TB - 1, colors.gray)
end

local function drawImageDialog()
  local v = S.chat.img_view
  if not v or v.loading then return end

  if v.error then
      local dw, dh = 30, WIN_TB + 4
      local dx, dy = imgDialogPos(dw, dh)
      drawWinFrame("Error", dx, dy, dw, dh)
      v.dw, v.dh, v.dx, v.dy = dw, dh, dx, dy
      centered(dx + 1, dy + WIN_TB + 1, dw - 2, "Failed to load image", colors.red, colors.gray)
      return
  end

  local blit = v.blit
  if not blit then return end

  local dw = blit.w + 2
  local dh = blit.h + WIN_TB + 1
  local dx, dy = imgDialogPos(dw, dh)
  v.dw, v.dh, v.dx, v.dy = dw, dh, dx, dy

  drawWinFrame("Image", dx, dy, dw, dh)

  if blit.lines and #blit.lines >= 3 then
      drawBlit(blit.lines, dx + 1, dy + WIN_TB, blit.h)
  end
end

local function drawChatScene()
  resetPalette()
  setPalette({
      [colors.lightGray] = 0xE8E8E8, [colors.gray] = 0xCCCCCC,
      [colors.white]     = SOFT_WHITE,
  })
  mon.setBackgroundColor(colors.white)
  mon.clear()

  preciseDither(1, 1, W, 3, colors.lightGray, colors.white)
  drawBackBtn()
  at(14, 2, "GLOBAL SHOUTBOX", colors.black, colors.lightGray)

  mon.setTextColor(colors.lightGray)
  mon.setBackgroundColor(colors.white)
  mon.setCursorPos(1, 4)
  mon.write(string.rep("-", W))

  local input_y = H - 4
  preciseDither(1, input_y, W, 5, colors.lightGray, colors.white)
  S.chat.send = nil
  local ifw = W - 18
  fill(3, input_y + 1, ifw, 3, colors.white)
  local disp = S.chat.input .. "_"
  if #disp > ifw - 4 then disp = disp:sub(-(ifw - 4)) end
  at(4, input_y + 2, ">", colors.gray, colors.white)
  at(6, input_y + 2, disp, colors.black, colors.white)

  local btn_x = W - 13
  drawButton(btn_x, input_y + 1, 12, 3, "Send", colors.white, colors.cyan)
  S.chat.send = {x = btn_x, y = input_y + 1, w = 12, h = 3}

  local msg_top = 5
  local msg_bot = input_y - 1
  local msg_h   = msg_bot - msg_top + 1
  local msg_w   = W - 3

  local lines = buildChatLines(msg_w)
  S.chat.img_hits = {}

  local max_scroll = math.max(0, #lines - msg_h)
  if S.chat.scroll > max_scroll then S.chat.scroll = max_scroll end
  if S.chat.scroll < 0 then S.chat.scroll = 0 end

  for i = 1, msg_h do
      local line = lines[S.chat.scroll + i]
      if line then
          local y = msg_top + i - 1
          if line.t == "m" then
              at(2, y, line.time, colors.lightGray, colors.white)
              at(8, y, line.name, line.col, colors.white)
              at(8 + #line.name, y, ": ", line.col, colors.white)
              if line.image_url then
                  at(10 + #line.name, y, IMG_TAG, colors.cyan, colors.white)
                  S.chat.img_hits[#S.chat.img_hits + 1] = {
                      x = 10 + #line.name, y = y, w = 7, h = 1, url = line.image_url,
                  }
              else
                  at(10 + #line.name, y, line.body, colors.black, colors.white)
              end
          elseif line.image_url then
              at(2 + CHAT_CONT, y, line.body, colors.cyan, colors.white)
              S.chat.img_hits[#S.chat.img_hits + 1] = {
                  x = 2 + CHAT_CONT, y = y, w = #line.body, h = 1, url = line.image_url,
              }
          else
              at(2 + CHAT_CONT, y, line.body, colors.gray, colors.white)
          end
      end
  end

  if S.chat.img_view then drawImageDialog() end
end

-- ── Actions ─────────────

local function appendMessages(msgs)
  local changed = false
  for _, msg in ipairs(msgs) do
      S.chat.msgs[#S.chat.msgs + 1] = msg
      if msg.id and msg.id > S.chat.last_id then
          S.chat.last_id = msg.id
      end
      changed = true
  end
  while #S.chat.msgs > MAX_CHAT_MSGS do
      table.remove(S.chat.msgs, 1)
  end
  if changed then
      S.chat.scroll = 99999 -- scroll to the bottom
      if S.scene == "chat" then drawChatScene() end
  end
end

local function initChat()
  if S.chat.reconnect_timer then
      os.cancelTimer(S.chat.reconnect_timer)
      S.chat.reconnect_timer = nil
  end
  local history = chat_ws.fetchHistory(100)
  if history then appendMessages(history) end
  chat_ws.connect()
end

local function onWsMessage(raw)
  local msgs = chat_ws.handleMessage(raw)
  if msgs then appendMessages(msgs) end
end

local function onWsClosed()
  local should_reconnect = chat_ws.onClosed()
  if not should_reconnect then return end
  local delay = chat_ws.getReconnectDelay()
  S.chat.reconnect_timer = os.startTimer(delay)
end

local function onReconnectTimer()
  chat_ws.connect()
end

local function sendChatMessage()
  if #S.chat.input == 0 then return end
  chat_ws.send(S.chat.input)
  S.chat.input = ""
  drawChatScene()
end

local function closeChat()
  if S.chat.reconnect_timer then
      os.cancelTimer(S.chat.reconnect_timer)
      S.chat.reconnect_timer = nil
  end
  chat_ws.close()
end

-- ── Input ───────────────

local function handleChatTouch(tx, ty)
  if S.chat.img_view then
      if hitTest(tx, ty, S.chat.img_close) then
          S.chat.img_view = nil
          S.chat.img_close = nil
          S.img_drag = nil
          drawChatScene()
          return
      end
      local v = S.chat.img_view
      if v.dx and v.dy and v.dw
         and ty >= v.dy and ty < v.dy + WIN_TB
         and tx >= v.dx and tx < v.dx + v.dw then
          S.img_drag = { off_x = tx - v.dx, off_y = ty - v.dy }
      end
      return
  end

  if hitTest(tx, ty, BACK_BTN) then
      closeChat()
      S.scene = "home"
      S.dirty = true
      return
  end
  if hitTest(tx, ty, S.chat.send) then
      sendChatMessage()
      return
  end
  for _, hit in ipairs(S.chat.img_hits) do
      if hitTest(tx, ty, hit) then
          S.chat.img_view = { loading = true }
          drawSplash("Loading image...")
          local blit = fetchChatImage(hit.url, math.floor(W * 0.75), math.floor(H * 0.75))
          S.chat.img_view = blit and { blit = blit } or { error = true }
          drawChatScene()
          return
      end
  end
end

return {
  drawChatScene = drawChatScene,
  initChat = initChat,
  onWsMessage = onWsMessage,
  onWsClosed = onWsClosed,
  onReconnectTimer = onReconnectTimer,
  sendChatMessage = sendChatMessage,
  handleChatTouch = handleChatTouch,
  closeChat = closeChat,
}
