-- ── Scene: Home ─────────────────────────────────────────

local utils        = require("lib.utils")
local colHex       = utils.colHex
local resetPalette = utils.resetPalette
local setPalette   = utils.setPalette
local saveUsers    = utils.saveUsers
local GOLD         = utils.GOLD
local SOFT_WHITE   = utils.SOFT_WHITE
local SOFT_GRAY    = utils.SOFT_GRAY

local ui            = require("lib.ui")
local fill          = ui.fill
local at            = ui.at
local centered      = ui.centered
local centerPos     = ui.centerPos
local drawButton    = ui.drawButton
local preciseDither = ui.preciseDither
local hitTest       = ui.hitTest
local roundCorners  = ui.roundCorners

-- ── Config ──────────────

local GRID_COLS = 4

local HOME_GRAD = {
  colors.orange, colors.magenta, colors.pink, colors.brown,
}

local CELL_DITHER = {
  [colors.green]     = colors.lime,
  [colors.lightBlue] = colors.cyan,
  [colors.lightGray] = colors.yellow,
  [colors.gray]      = colors.blue,
}

-- ── Helpers ─────────────

local function computeGrid()
  local margin   = 3
  local gap      = 3
  local title_h  = 4
  local footer_h = 3
  local grid_y   = title_h + 1
  local grid_h   = H - grid_y - footer_h

  local cell_w = math.floor((W - margin*2 - gap*(GRID_COLS - 1)) / GRID_COLS)
  local cell_h = math.floor(cell_w * 0.45)
  local step_x = cell_w + gap
  local step_y = cell_h + gap
  local vis    = math.floor((grid_h + gap) / step_y)

  return {
      margin = margin, gap = gap,
      grid_y = grid_y, grid_h = grid_h,
      cell_w = cell_w, cell_h = cell_h,
      step_x = step_x, step_y = step_y,
      vis = vis,
  }
end

-- ── Drawing ─────────────

local function drawHomeBg()
  local n = #HOME_GRAD
  local r0, g0, b0 = 0xF5, 0xF5, 0xF5
  local r1, g1, b1 = 0xC0, 0xC6, 0xD6

  for i = 1, n do
      local t = i / n
      local r = math.floor(r0 + (r1 - r0) * t + 0.5)
      local g = math.floor(g0 + (g1 - g0) * t + 0.5)
      local b = math.floor(b0 + (b1 - b0) * t + 0.5)
      mon.setPaletteColor(HOME_GRAD[i], r * 0x10000 + g * 0x100 + b)
  end

  local BAYER = {
      { 0/16,  8/16,  2/16, 10/16 },
      {12/16,  4/16, 14/16,  6/16 },
      { 3/16, 11/16,  1/16,  9/16 },
      {15/16,  7/16, 13/16,  5/16 },
  }
  local BSIZ  = 4
  local BLOCK = 1
  local blank_c  = string.rep(" ", W)
  local blank_fg = string.rep("0", W)

  for y = 1, H do
      local frac = (H > 1) and ((y - 1) / (H - 1)) or 0
      local pos  = frac * n
      local lo   = math.floor(pos)
      local hi   = math.min(lo + 1, n)
      local t    = pos - lo
      local col_a = lo == 0 and colors.white or HOME_GRAD[lo]
      local col_b = hi == 0 and colors.white or HOME_GRAD[hi]
      local ha, hb = colHex(col_a), colHex(col_b)
      local by = math.floor((y - 1) / BLOCK) % BSIZ
      local bg = {}
      for x = 1, W do
          local bx = math.floor((x - 1) / BLOCK) % BSIZ
          bg[x] = (t >= BAYER[by + 1][bx + 1]) and hb or ha
      end
      mon.setCursorPos(1, y)
      mon.blit(blank_c, blank_fg, table.concat(bg))
  end
end

local function drawHome()
  resetPalette()
  setPalette({
      [colors.white]     = SOFT_WHITE, [colors.lightGray] = SOFT_GRAY,
      [colors.red]       = GOLD,   [colors.purple]    = 0x7C4A1E,
      [colors.lime]      = 0x4A8F42,   [colors.cyan]      = 0x8AA0D8,
      [colors.yellow]    = 0xD0D0D0,   [colors.blue]      = 0x3A3A3A,
  })
  drawHomeBg()

  local G = computeGrid()
  S.grid = G

  local title = "BeetleCraft"
  local tw = #title + 4
  local tx = centerPos(W, tw)
  drawButton(tx, 1, tw, 3, title, colors.black, colors.white)

  local total = math.ceil(#S.entries / GRID_COLS)
  local maxs  = math.max(0, total - G.vis)
  S.scroll = math.max(0, math.min(S.scroll, maxs))

  S.cells = {}
  for row = 0, G.vis - 1 do
      for col = 0, GRID_COLS - 1 do
          local idx = (S.scroll + row) * GRID_COLS + col + 1
          local entry = S.entries[idx]
          if entry then
              local cx = G.margin + col * G.step_x + 1
              local cy = G.grid_y + row * G.step_y

              fill(cx, cy, G.cell_w, G.cell_h, colors.purple)
              roundCorners(cx, cy, G.cell_w, G.cell_h, 2, colors.red)
              local ix, iy = cx + 1, cy + 1
              local iw, ih = G.cell_w - 2, G.cell_h - 2
              local dith2 = CELL_DITHER[entry.bg] or entry.bg
              preciseDither(ix, iy, iw, ih, entry.bg, dith2)
              centered(cx, cy + math.floor(G.cell_h / 2), G.cell_w,
                       entry.label, entry.fg, entry.bg)

              S.cells[#S.cells+1] = {
                  x = cx, y = cy, w = G.cell_w, h = G.cell_h, idx = idx
              }
          end
      end
  end

  if S.scroll > 0 then
      centered(1, G.grid_y - 1, W, "[ ^ ]", colors.gray, colors.white)
  end
  if S.scroll + G.vis < total then
      centered(1, H - 1, W, "[ v ]", colors.gray, colors.white)
  end

  local ver = S.updater and S.updater.local_ver or "?"
  local mark = (S.updater and S.updater.hasUpdate) and "*" or ""
  local vtext = "v" .. ver .. mark
  local vx = W - #vtext
  at(vx, H, vtext, colors.gray, colors.white)
  S.version_hit = { x = vx, y = H, w = #vtext, h = 1 }
end

-- ── Input ───────────────

local function handleHomeTouch(tx, ty)
  local G = S.grid
  if not G then return end

  if hitTest(tx, ty, S.version_hit) then
      S.scene = "update"
      S.dirty = true
      return
  end

  if ty <= G.grid_y - 1 and S.scroll > 0 then
      S.scroll = S.scroll - 1
      S.dirty = true
      return
  end

  local total = math.ceil(#S.entries / GRID_COLS)
  if ty >= H - 1 and S.scroll + G.vis < total then
      S.scroll = S.scroll + 1
      S.dirty = true
      return
  end

  for _, c in ipairs(S.cells) do
      if hitTest(tx, ty, c) then
          local entry = S.entries[c.idx]
          if entry.type == "user" then
              S.scene    = "profile"
              S.selected = c.idx
              S.profile  = nil
          elseif entry.type == "beetleboy" then
              S.scene = "beetleboy"
              S.selected = c.idx
              S.beetle.data = nil
              S.beetle.loading = true
              S.beetle.result = nil
          elseif entry.type == "chat" then
              S.scene = "chat"
              S.chat.msgs = {}
              S.chat.last_id = 0
              S.chat.scroll = 99999 -- scroll to the bottom
              S.chat.input = ""
              S.chat.ws_init = true
          elseif entry.type == "add" then
              S.scene = "add"
              S.add.buf = ""
          elseif entry.type == "update" then
              S.scene = "update"
          end
          S.dirty = true
          return
      end
  end
end

-- ── Scene: Add Dialog ───────────────────────────────────

-- ── Drawing ─────────────

local function drawAddDialog()
  local dw = 50
  local dh = 9
  local dx = centerPos(W, dw)
  local dy = centerPos(H, dh)

  fill(dx, dy, dw, dh, colors.gray)
  fill(dx + 1, dy + 1, dw - 2, dh - 2, colors.lightGray)
  centered(dx, dy + 2, dw, "Enter username:", colors.black, colors.lightGray)

  local fw = dw - 8
  local fx = dx + 4
  local fy = dy + 4
  fill(fx, fy, fw, 1, colors.white)
  local display = S.add.buf .. "_"
  if #display > fw - 2 then display = display:sub(-(fw - 2)) end
  at(fx + 1, fy, display, colors.black, colors.white)

  local btn_y  = dy + 6
  local ok_x   = dx + math.floor(dw / 2) - 12
  local canc_x = dx + math.floor(dw / 2) + 3

  drawButton(ok_x, btn_y, 8, 1, "OK", colors.white, colors.green)
  drawButton(canc_x, btn_y, 10, 1, "Cancel", colors.white, colors.red)

  S.add.ok     = { x = ok_x,   y = btn_y, w = 8 }
  S.add.cancel = { x = canc_x, y = btn_y, w = 10 }
end

-- ── Actions ─────────────

local function submitAdd()
  if #S.add.buf > 0 then
      user_list[#user_list+1] = S.add.buf
      saveUsers(user_list)
      S.entries = buildEntries(user_list)
  end
  S.scene = "home"
  S.dirty = true
end

-- ── Input ───────────────

local function handleAddTouch(tx, ty)
  if hitTest(tx, ty, S.add.ok) then
      submitAdd()
      return
  end
  if hitTest(tx, ty, S.add.cancel) then
      S.scene = "home"
      S.dirty = true
  end
end

return {
  drawHome = drawHome,
  handleHomeTouch = handleHomeTouch,
  drawAddDialog = drawAddDialog,
  submitAdd = submitAdd,
  handleAddTouch = handleAddTouch,
}
