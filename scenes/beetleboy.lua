-- ── Scene: Beetleboy ────────────────────────────────────

local utils        = require("lib.utils")
local fmtNum       = utils.fmtNum
local fmtCooldown  = utils.fmtCooldown
local resetPalette = utils.resetPalette
local setPalette   = utils.setPalette
local GOLD         = utils.GOLD
local SOFT_WHITE   = utils.SOFT_WHITE
local SOFT_GRAY    = utils.SOFT_GRAY

local ui             = require("lib.ui")
local fill           = ui.fill
local centered       = ui.centered
local centerPos      = ui.centerPos
local drawButton     = ui.drawButton
local preciseDither  = ui.preciseDither
local hitTest        = ui.hitTest
local BACK_BTN       = ui.BACK_BTN
local drawBackBtn    = ui.drawBackBtn

local reminet        = require("lib.reminet")
local doBeetleAction = reminet.doBeetleAction

-- ── Config ──────────────

local SPRITE_W, SPRITE_H = 5, 7
local MAX_SPRITE_SCALE = 3
local MAX_HUNTS = 3
local spriteCache = {}

-- ── Helpers ─────────────

local function loadSprite(key)
  if spriteCache[key] then return spriteCache[key] end
  local path = fs.combine(BASE_DIR, "assets/nfp/" .. key .. ".nfp")
  if fs.exists(path) then
      spriteCache[key] = paintutils.loadImage(path)
  end
  return spriteCache[key]
end

local function buildReel(resultKey)
  local pool = {}
  for _, b in ipairs(BEETLES) do
      if b.key ~= "cheese" then pool[#pool + 1] = b.key end
  end
  if #pool == 0 then pool = { resultKey } end
  local function pick(last)
      if #pool == 1 then return pool[1] end
      local k
      repeat k = pool[math.random(#pool)] until k ~= last
      return k
  end
  local reel = {}
  for _ = 1, 40 do reel[#reel + 1] = pick(reel[#reel]) end
  reel[#reel + 1] = resultKey
  for _ = 1, 10 do reel[#reel + 1] = pick(reel[#reel]) end
  return reel
end

local function beetleActionState(d)
  local cd = d.cooldowns or {}

  local cheese_st = "ready"
  if cd.claimUBC and cd.claimUBC > 0 then cheese_st = fmtCooldown(cd.claimUBC) end

  local catch_st = "ready"
  if cd.catchBeetle and cd.catchBeetle > 0 then catch_st = fmtCooldown(cd.catchBeetle) end

  local hunt_st = "ready"
  local hunts = d.beetleHuntsUsed or 0
  if hunts >= MAX_HUNTS then
      local remain = (d.lastBeetleHuntDate or 0) + 90 * 60 * 1000 - os.epoch("utc")
      if remain > 0 then
          hunt_st = fmtCooldown(remain)
      else
          d.beetleHuntsUsed = 0
      end
  end

  return cheese_st, catch_st, hunt_st
end

-- ── Drawing ─────────────

local function drawSprite(img, x, y, scale)
  if not img then return end
  scale = scale or 1
  for row = 1, #img do
      for col = 1, #img[row] do
          local c = img[row][col]
          if c and c > 0 then
              mon.setBackgroundColor(c)
              local px = x + (col - 1) * scale
              local py = y + (row - 1) * scale
              for sy = 0, scale - 1 do
                  mon.setCursorPos(px, py + sy)
                  mon.write(string.rep(" ", scale))
              end
          end
      end
  end
end

local function drawBeetleInventory(d, y0)
  local inv = d.inventory or {}
  local items = {}
  for _, b in ipairs(BEETLES) do
      local count = inv[b.key] or 0
      if count > 0 and loadSprite(b.key) then
          items[#items + 1] = { key = b.key, count = count }
      end
  end
  if #items == 0 then return end

  local avail_h = H - y0
  local avail_w = W - 4
  local cols = #items
  local sc = math.floor(avail_w / (cols * (SPRITE_W + 2)))
  if sc < 1 then sc = 1 end
  local max_sc_h = math.floor((avail_h - 3) / SPRITE_H)
  if sc > max_sc_h then sc = max_sc_h end
  if sc > MAX_SPRITE_SCALE then sc = MAX_SPRITE_SCALE end

  local sw = SPRITE_W * sc
  local sh = SPRITE_H * sc
  local cell_w = sw + 2
  local total_w = cols * cell_w + (cols - 1) * 2
  if total_w > W - 2 then
      cols = math.floor((W - 2 + 2) / (cell_w + 2))
      if cols < 1 then cols = 1 end
      total_w = cols * cell_w + (cols - 1) * 2
  end
  local ox = centerPos(W, total_w)
  local cy_start = y0 + math.floor((avail_h - sh - 3) / 2)
  if cy_start < y0 then cy_start = y0 end

  for idx, item in ipairs(items) do
      local col = (idx - 1) % cols
      local row = math.floor((idx - 1) / cols)
      local cx = ox + col * (cell_w + 2)
      local cy = cy_start + row * (sh + 4)
      local img = loadSprite(item.key)
      if img then drawSprite(img, cx + 1, cy, sc) end
      centered(cx, cy + sh + 1, cell_w, BEETLES[item.key] or item.key, colors.gray, colors.white)
      centered(cx, cy + sh + 2, cell_w, tostring(item.count), colors.black, colors.white)
  end
end

local function drawBeetleReel(y0)
  local anim = S.beetle.anim
  if not anim.reel then return end

  local avail_h = H - y0
  local sc = math.floor((avail_h - 3) / SPRITE_H)
  sc = math.max(1, math.min(sc, MAX_SPRITE_SCALE))

  local sw = SPRITE_W * sc
  local sh = SPRITE_H * sc
  local slot_w = sw + 2
  local gap = 2
  local half = math.floor((W / 2) / (slot_w + gap)) + 2
  local center_x = math.floor(W / 2) + 1
  local frame_y = math.max(y0, y0 + math.floor((avail_h - sh - 3) / 2))

  for i = -half, half do
      local ri = ((anim.pos + i - 1) % #anim.reel) + 1
      local key = anim.reel[ri]
      local sx = center_x + i * (slot_w + gap) - math.floor(slot_w / 2)
      local sy = frame_y

      local img = loadSprite(key)
      if img then drawSprite(img, sx + math.floor((slot_w - sw) / 2), sy, sc) end
      centered(sx, sy + sh + 1, slot_w, BEETLES[key] or key, colors.gray, colors.white)

      if i == 0 then
          mon.setTextColor(colors.green)
          mon.setBackgroundColor(colors.white)
          for row = -1, sh + 2 do
              mon.setCursorPos(sx - 1, sy + row); mon.write("|")
              mon.setCursorPos(sx + slot_w, sy + row); mon.write("|")
          end
      end
  end
end

local function drawBeetleResult(y0)
  local anim = S.beetle.anim
  if not anim.key then return end

  local avail_h = H - y0
  local sc = math.max(1, math.min(math.floor((avail_h - 5) / SPRITE_H), MAX_SPRITE_SCALE))

  local sw = SPRITE_W * sc
  local sh = SPRITE_H * sc
  local img = loadSprite(anim.key)
  local label = BEETLES[anim.key] or anim.key
  local sx = centerPos(W, sw)
  local sy = math.max(y0, y0 + math.floor((avail_h - sh - 5) / 2))

  if img then drawSprite(img, sx, sy, sc) end

  mon.setTextColor(colors.green)
  mon.setBackgroundColor(colors.white)
  for row = 0, sh + 1 do
      mon.setCursorPos(sx - 2, sy - 1 + row); mon.write("| ")
      mon.setCursorPos(sx + sw, sy - 1 + row); mon.write(" |")
  end

  centered(1, sy + sh + 1, W, label, colors.black, colors.white)
  if anim.msg then
      centered(1, sy + sh + 3, W, anim.msg, colors.gray, colors.white)
  end
end

local function drawBeetleboyScene()
  resetPalette()
  setPalette({
      [colors.white]     = SOFT_WHITE, [colors.lightGray] = SOFT_GRAY,
      [colors.green]     = 0x4E8A3E,  [colors.lime]      = 0x6BB85C,
      [colors.yellow]    = GOLD,
  })
  preciseDither(1, 1, W, H, colors.white, colors.lightGray)
  drawBackBtn()
  centered(1, 2, W, "BEETLEBOY", colors.black, colors.white)

  if S.beetle.loading then
      centered(1, math.floor(H/2), W, "Loading...", colors.gray, colors.white)
      return
  end

  local d = S.beetle.data
  if not d then
      centered(1, math.floor(H/2), W, "No data", colors.gray, colors.white)
      return
  end

  local cheese = d.inventory and d.inventory.cheese or 0
  local sep = W > 80 and "  |  " or " | "
  local stats = table.concat({
      "LVL " .. (d.level or 0),
      "XP " .. fmtNum(d.xp or 0),
      "Streak " .. (d.UBCStreak or 0),
      "Beetles " .. fmtNum(d.beetle_count or 0),
      "Cheese " .. fmtNum(cheese),
  }, sep)
  if #stats > W - 4 then
      stats = table.concat({
          "L" .. (d.level or 0), "XP " .. fmtNum(d.xp or 0),
          "S" .. (d.UBCStreak or 0), "B" .. fmtNum(d.beetle_count or 0),
          "C" .. fmtNum(cheese),
      }, sep)
  end
  centered(1, 5, W, stats, colors.gray, colors.white)

  mon.setCursorPos(3, 6)
  mon.setTextColor(colors.lightGray)
  mon.setBackgroundColor(colors.white)
  mon.write(string.rep("-", W - 4))

  local cheese_st, catch_st, hunt_st = beetleActionState(d)

  local gap = math.max(2, math.floor(W * 0.03))
  local card_w = math.floor((W - 8 - gap * 2) / 3)
  local card_h = math.max(7, math.min(11, math.floor((H - 12) * 0.4)))
  local card_y = 8
  local start_x = centerPos(W, card_w * 3 + gap * 2)

  S.beetle.btns = {}

  local cards = {
      { title = "CLAIM CHEESE", state = cheese_st, action = "claimUBC", bg = colors.yellow },
      { title = "CATCH BEETLE", state = catch_st, action = "catchBeetle", bg = colors.blue },
      { title = "HUNT BEETLE (" .. (d.beetleHuntsUsed or 0) .. "/" .. MAX_HUNTS .. ")", state = hunt_st, action = "beetleHunt", bg = colors.blue },
  }

  for i, card in ipairs(cards) do
      local cx = start_x + (i - 1) * (card_w + gap)
      local ready = card.state == "ready"

      fill(cx, card_y, card_w, card_h, colors.gray)
      fill(cx + 1, card_y + 1, card_w - 2, card_h - 2, colors.white)
      centered(cx, card_y + math.max(1, math.floor(card_h * 0.2)), card_w, card.title, colors.black, colors.white)

      local btn_w = card_w - 6
      local btn_x = cx + 3
      local btn_h = math.max(1, math.min(3, card_h - 5))
      local btn_y = card_y + math.floor(card_h * 0.55)

      if ready then
          drawButton(btn_x, btn_y, btn_w, btn_h, card.title:match("^(%S+)"), colors.white, card.bg or colors.green)
          S.beetle.btns[#S.beetle.btns + 1] = {
              x = btn_x, y = btn_y, w = btn_w, h = btn_h, action = card.action
          }
      else
          drawButton(btn_x, btn_y, btn_w, btn_h, card.state, colors.gray, colors.lightGray)
      end
  end

  local bottom_y = card_y + card_h + 2
  local anim = S.beetle.anim

  local hide_msg = anim.state == "spinning" or anim.state == "decel"
  if S.beetle.result and not hide_msg then
      centered(1, bottom_y, W, "> " .. S.beetle.result, colors.black, colors.white)
  end

  local area_y = bottom_y + 2
  if anim.state == "spinning" or anim.state == "decel" then
      drawBeetleReel(area_y)
  elseif anim.state == "result" then
      drawBeetleResult(area_y)
  else
      drawBeetleInventory(d, area_y)
  end
end

-- ── Actions ─────────────

local function clearBeetleAnim()
  local a = S.beetle.anim
  a.state, a.key = nil, nil
  a.reel, a.pos, a.timer, a.msg = nil, 1, nil, nil
  S.beetle.result = nil
end

-- ── Input ───────────────

local function handleBeetleboyTouch(tx, ty)
  if hitTest(tx, ty, BACK_BTN) then
      S.scene = "home"
      S.beetle.timer = nil
      S.beetle.data = nil
      S.beetle.result = nil
      clearBeetleAnim()
      S.dirty = true
      return
  end

  local anim = S.beetle.anim
  if anim.state == "spinning" or anim.state == "decel" then return end
  if anim.state == "result" then clearBeetleAnim() end

  for _, btn in ipairs(S.beetle.btns) do
      if hitTest(tx, ty, btn) then

          S.beetle.result = "Processing..."
          drawBeetleboyScene()
          local result = doBeetleAction(btn.action)
          if result.user then S.beetle.data = result.user end
          S.beetle.result = result.msg

          if result.success and result.beetle_key then
              anim.key   = result.beetle_key
              anim.msg   = result.msg
              anim.reel  = buildReel(result.beetle_key)
              anim.pos   = 1
              anim.state = "spinning"
              anim.timer = os.startTimer(0.1)
          end

          S.dirty = true
          return
      end
  end
end

return {
  drawBeetleboyScene = drawBeetleboyScene,
  handleBeetleboyTouch = handleBeetleboyTouch,
  clearBeetleAnim = clearBeetleAnim,
}