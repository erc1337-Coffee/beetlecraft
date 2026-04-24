-- ── Drawing Primitives ──────────────────────────────────

local utils        = require("lib.utils")

local function fill(x, y, w, h, bg)
  if w <= 0 or h <= 0 then return end
  mon.setBackgroundColor(bg)
  for row = y, y + h - 1 do
      mon.setCursorPos(x, row)
      mon.write(string.rep(" ", w))
  end
end

local function at(x, y, text, fg, bg)
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x, y)
  mon.write(text)
end

local function ulen(s)
  local n = 0
  for _ in s:gmatch("[%z\1-\127\194-\253][\128-\191]*") do n = n + 1 end
  return n
end

local function centered(x, y, w, text, fg, bg)
  at(x + math.max(0, math.floor((w - ulen(text)) / 2)), y, text, fg, bg)
end

local function centerPos(outer, inner)
  return math.floor((outer - inner) / 2) + 1
end

local function drawButton(x, y, w, h, label, fg, bg)
  fill(x, y, w, h, bg)
  centered(x, y + math.floor(h / 2), w, label, fg, bg)
end

local function arrowline(x, y, w, fg, bg)
  if w < 2 then return end
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x, y)
  mon.write("<" .. string.rep("-", w - 2) .. ">")
end

local function preciseDither(x, y, w, h, colA, colB)
  local row_str = string.rep(string.char(127), w)
  mon.setBackgroundColor(colA)
  mon.setTextColor(colB)
  for row = 0, h - 1 do
      mon.setCursorPos(x, y + row)
      mon.write(row_str)
  end
end

local function drawBlit(lines, x, y, h)
  if not lines or #lines < 3 then return end
  for row = 0, h - 1 do
      local base = row * 3 + 1
      if lines[base] and lines[base+1] and lines[base+2] then
          mon.setCursorPos(x, y + row)
          mon.blit(lines[base], lines[base+1], lines[base+2])
      end
  end
end

local function hitTest(tx, ty, box)
  if not box then return false end
  local h = box.h or 1
  return tx >= box.x and tx < box.x + box.w
     and ty >= box.y and ty < box.y + h
end

local function roundCorners(bx, by, bw, bh, r, bg)
  for i = 0, r - 1 do
      local inset = r - i
      mon.setBackgroundColor(bg)
      mon.setCursorPos(bx, by + i)
      mon.write(string.rep(" ", inset))
      mon.setCursorPos(bx + bw - inset, by + i)
      mon.write(string.rep(" ", inset))
      mon.setCursorPos(bx, by + bh - 1 - i)
      mon.write(string.rep(" ", inset))
      mon.setCursorPos(bx + bw - inset, by + bh - 1 - i)
      mon.write(string.rep(" ", inset))
  end
end

local function drawBackBtn()
  drawButton(2, 2, 8, 3, "< Back", colors.black, colors.lightGray)
end

local BACK_BTN = {x = 2, y = 2, w = 8, h = 3}

local function drawSplash(message)
  utils.resetPalette()
  mon.setBackgroundColor(colors.white)
  mon.clear()
  if SPLASH_BLIT then
      local bw, bh = SPLASH_BLIT.w, SPLASH_BLIT.h
      local ox = centerPos(W, bw)
      local oy = centerPos(H, bh)
      local skip_x = ox < 1 and (1 - ox) or 0
      local draw_w = math.min(bw - skip_x, W)
      for row = 0, bh - 1 do
          local dy = oy + row
          if dy >= 1 and dy <= H then
              local base = row * 3 + 1
              local c, fg, bg = SPLASH_BLIT.lines[base], SPLASH_BLIT.lines[base+1], SPLASH_BLIT.lines[base+2]
              if c and fg and bg then
                  local len = math.min(#c, #fg, #bg) - skip_x
                  len = math.min(len, draw_w)
                  if len > 0 then
                      mon.setCursorPos(math.max(1, ox), dy)
                      mon.blit(c:sub(skip_x+1, skip_x+len),
                               fg:sub(skip_x+1, skip_x+len),
                               bg:sub(skip_x+1, skip_x+len))
                  end
              end
          end
      end
  end
  if message then
      local tw = #message + 4
      local tx = centerPos(W, tw)
      local ty = centerPos(H, 3)
      drawButton(tx, ty, tw, 3, message, colors.black, colors.white)
  end
end

return {
  fill = fill,
  at = at,
  centered = centered,
  centerPos = centerPos,
  drawButton = drawButton,
  arrowline = arrowline,
  preciseDither = preciseDither,
  drawBlit = drawBlit,
  hitTest = hitTest,
  roundCorners = roundCorners,
  drawBackBtn = drawBackBtn,
  BACK_BTN = BACK_BTN,
  drawSplash = drawSplash,
}