-- ── Scene: Profile ──────────────────────────────────────

local utils        = require("lib.utils")
local resetPalette = utils.resetPalette
local hslToHex     = utils.hslToHex
local fmtNum       = utils.fmtNum

local ui            = require("lib.ui")
local fill          = ui.fill
local at            = ui.at
local centered      = ui.centered
local centerPos     = ui.centerPos
local arrowline     = ui.arrowline
local preciseDither = ui.preciseDither
local roundCorners  = ui.roundCorners
local drawBackBtn   = ui.drawBackBtn
local drawBlit      = ui.drawBlit
local drawSplash    = ui.drawSplash

local reminet         = require("lib.reminet")
local fetchProfile    = reminet.fetchProfile
local fetchRanks      = reminet.fetchRanks
local fetchAvatarBlit = reminet.fetchAvatarBlit

local CARD = {
  border = 2, foot_h = 5,
  card_w = 95, card_h = 40,
  av_w = 0.36, char_ratio = 0.70,
  card_s = 0.50, card_l = 0.88,
  av_s   = 0.45, av_l   = 0.72,
  div_s  = 0.40, div_l  = 0.55,
}

local PAL = {
  bg = colors.lightGray, border = colors.gray,
  card = colors.lime, footer = colors.white,
  avatar = colors.green, title = colors.black,
  label = colors.gray, value = colors.black,
  divider = colors.cyan, foot = colors.gray,
  badge = colors.gray, sale = colors.black,
}

-- ── Helpers ─────────────

local function scaled(val, scale, min)
  return math.max(min, math.floor(val * scale + 0.5))
end

local function computeLayout()
  local b  = CARD.border
  local bw = math.min(CARD.card_w, W - 2)
  local bh = math.min(CARD.card_h, H - 2)
  local bx = centerPos(W, bw)
  local by = centerPos(H, bh)
  local sw = bw / CARD.card_w
  local sh = bh / CARD.card_h
  local fh = math.max(1, math.floor(CARD.foot_h * sh))
  local iw     = bw - b * 2
  local body_h = math.max(4, bh - b * 2 - fh - 1)
  return {
      box   = { x = bx, y = by, w = bw, h = bh },
      inner = { x = bx + b, y = by + b, w = iw, body_h = body_h },
      foot  = { y = by + b + body_h + 1, h = fh },
      sw = sw, sh = sh,
  }
end

-- ── Drawing ─────────────

local function renderCard(user)
  PAL.card    = colors.lime
  PAL.avatar  = colors.green
  PAL.divider = colors.cyan
  resetPalette()
  mon.setPaletteColor(colors.lightGray, 0xC0C0C0)

  local L = computeLayout()

  local av_w = math.floor(L.inner.w * CARD.av_w)
  local av_h = math.floor(av_w * CARD.char_ratio)
  av_h = math.min(av_h, L.inner.body_h - scaled(5, L.sh, 2) - 2)

  local blit = fetchAvatarBlit(user.pfpUrl, av_w, av_h)

  if blit and blit.free and #blit.free >= 3 then
      PAL.card    = blit.free[1]
      PAL.avatar  = blit.free[2]
      PAL.divider = blit.free[3]
      if blit.free[4] then PAL.border = blit.free[4] end
  end

  mon.setPaletteColor(PAL.card,    hslToHex(user.color, CARD.card_s, CARD.card_l))
  mon.setPaletteColor(PAL.avatar,  hslToHex(user.color, CARD.av_s,   CARD.av_l))
  mon.setPaletteColor(PAL.divider, hslToHex(user.color, CARD.div_s,  CARD.div_l))
  if blit and blit.free and blit.free[4] then
      mon.setPaletteColor(PAL.border, 0xA8A8A8)
  end

  -- frame
  preciseDither(1, 1, W, H, PAL.bg, colors.white)
  fill(L.box.x, L.box.y, L.box.w, L.box.h, PAL.border)
  roundCorners(L.box.x, L.box.y, L.box.w, L.box.h, 2, PAL.bg)
  fill(L.inner.x, L.inner.y, L.inner.w, L.inner.body_h, PAL.card)
  fill(L.inner.x, L.foot.y,  L.inner.w, L.foot.h,       PAL.footer)

  -- title
  centered(L.inner.x, L.inner.y + scaled(1, L.sh, 1),
           L.inner.w, "REMILIA", PAL.title, PAL.card)

  -- avatar
  local pad_x = scaled(2, L.sw, 1)
  local pad_y = scaled(5, L.sh, 2)
  local av = {
      x = L.inner.x + pad_x, y = L.inner.y + pad_y,
      w = av_w, h = av_h,
  }
  fill(av.x, av.y, av.w, av.h, PAL.avatar)

  if blit and blit.lines and #blit.lines >= 3 then
      drawBlit(blit.lines, av.x, av.y, av.h)
  else
      centered(av.x, av.y + math.floor(av.h/2), av.w, "no image", colors.red, PAL.avatar)
  end

  local badge_y = av.y + av.h + 1
  if badge_y <= L.inner.y + L.inner.body_h then
      at(av.x, badge_y, "(c)Remilia.Corp:2K5", PAL.badge, PAL.card)
      at(av.x + scaled(21, L.sw, 1), badge_y,
         "[NOT FOR SALE]", PAL.sale, PAL.card)
  end

  -- info panel
  local gap = scaled(5, L.sw, 2)
  local margin_r = scaled(2, L.sw, 1)
  local ix = av.x + av.w + gap
  local iw = L.inner.x + L.inner.w - ix - margin_r
  if iw >= 10 then
      local iy = av.y
      local c2 = ix + math.floor(iw * 0.55)
      local proj = user.pfpProject or "?"

      centered(ix, iy,     iw, "~" .. user.username, PAL.value, PAL.card)
      centered(ix, iy + 2, iw, proj,                 PAL.value, PAL.card)
      arrowline(ix, iy + 3, iw, PAL.divider, PAL.card)

      local stats = {
          { "Global Rank",  "#" .. fmtNum(user.globalRank or 0) .. " / " .. fmtNum(user.totalUsers or 0) },
          { "Project Rank", "#" .. fmtNum(user.projectRank or 0) .. " / " .. fmtNum(user.projectTotal or 0) },
          { "", "" },
          { "Score",        fmtNum(user.socialCreditScore or 0) },
          { "Beetles",      fmtNum(user.beetles or 0) },
          { "Achievements", fmtNum(user.achievementsCount or 0) },
          { "", "" },
          { "Friends",      fmtNum(user.friendCount or 0) },
          { "Pokes",        fmtNum(user.pokes or 0) },
          { "Views",        fmtNum(user.pageViews or 0) },
      }

      local avail_h = L.inner.body_h - (iy - L.inner.y) - 4
      local row_step = math.min(1.65, avail_h / #stats)
      if row_step < 1 then row_step = 1 end

      for i, r in ipairs(stats) do
          local y = iy + 4 + math.floor((i - 1) * row_step)
          if y > L.inner.y + L.inner.body_h then break end
          at(ix + 1, y, r[1], PAL.label, PAL.card)
          at(c2,     y, r[2], PAL.value, PAL.card)
      end
  end

  -- footer
  local mid = L.foot.y + math.floor(L.foot.h / 2)
  centered(L.inner.x, mid, L.inner.w, user.bio or "", PAL.foot, PAL.footer)
end

local function drawProfileScene()
  if not S.profile then return end
  renderCard(S.profile)
  drawBackBtn()
end

-- ── Actions ─────────────

local function loadProfile()
  local entry = S.entries[S.selected]
  if not entry then S.scene = "home" return end

  drawSplash("Loading ~" .. entry.label .. "...")

  local user, err = fetchProfile(entry.label)
  if not user then
      mon.setBackgroundColor(colors.white)
      mon.clear()
      centered(1, math.floor(H/2), W,
               "Error: " .. tostring(err), colors.red, colors.white)
      drawBackBtn()
      return
  end
  local ranks = fetchRanks(entry.label)
  if ranks then
      user.globalRank   = ranks.globalRank
      user.totalUsers   = ranks.totalUsers
      user.projectRank  = ranks.projectRank
      user.projectTotal = ranks.projectTotal
  end
  S.profile = user
end

return {
  drawProfileScene = drawProfileScene,
  loadProfile = loadProfile,
}
