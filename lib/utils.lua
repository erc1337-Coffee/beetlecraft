-- ── Utilities ───────────────────────────────────────────

local function loadUsers()
  local path = fs.combine(BASE_DIR, "users.txt")
  if not fs.exists(path) then
      local f = fs.open(path, "w")
      f.close()
  end
  local f = fs.open(path, "r")
  local data = f.readAll()
  f.close()
  local users = {}
  for line in data:gmatch("[^\n]+") do
      users[#users + 1] = line
  end
  if #users == 0 then return {"charlottefang"} end
  return users
end

local function saveUsers(users)
  local f = fs.open(fs.combine(BASE_DIR, "users.txt"), "w")
  f.write(table.concat(users, "\n"))
  f.close()
end

-- Colors

local GOLD           = 0xFFD700
local SOFT_WHITE     = 0xF5F5F5
local SOFT_GRAY      = 0xE0E0E0

local CC_DEFAULTS = {
    [colors.white]     = 0xF0F0F0, [colors.orange]    = 0xF2B233,
    [colors.magenta]   = 0xE57FD8, [colors.lightBlue] = 0x99B2F2,
    [colors.yellow]    = 0xDEDE6C, [colors.lime]      = 0x7FCC19,
    [colors.pink]      = 0xF2B2CC, [colors.gray]      = 0x4C4C4C,
    [colors.lightGray] = 0x999999, [colors.cyan]      = 0x4C99B2,
    [colors.purple]    = 0xB266E5, [colors.blue]      = 0x3366CC,
    [colors.brown]     = 0x7F664C, [colors.green]     = 0x57A64E,
    [colors.red]       = 0xCC4C4C, [colors.black]     = 0x191919,
}

local function resetPalette()
  for col, hex in pairs(CC_DEFAULTS) do
      mon.setPaletteColor(col, hex)
  end
end

local function setPalette(overrides)
  for col, hex in pairs(overrides) do
      mon.setPaletteColor(col, hex)
  end
end

local function hslToHex(h, s, l)
  local c  = (1 - math.abs(2*l - 1)) * s
  local hp = h / 60
  local x  = c * (1 - math.abs(hp % 2 - 1))
  local r1, g1, b1
  if     hp < 1 then r1,g1,b1 = c,x,0
  elseif hp < 2 then r1,g1,b1 = x,c,0
  elseif hp < 3 then r1,g1,b1 = 0,c,x
  elseif hp < 4 then r1,g1,b1 = 0,x,c
  elseif hp < 5 then r1,g1,b1 = x,0,c
  else               r1,g1,b1 = c,0,x
  end
  local m = l - c/2
  return math.floor((r1+m)*255+.5) * 0x10000
       + math.floor((g1+m)*255+.5) * 0x100
       + math.floor((b1+m)*255+.5)
end

local function nfpToColor(ch)
  return 2 ^ tonumber(ch, 16)
end

local function colHex(c)
  local v, k = c, 0
  while v > 1 do v = v / 2; k = k + 1 end
  return string.format("%x", k)
end

-- Formatting
local function fmtNum(n)
  local s = tostring(n)
  local pos = #s % 3
  if pos == 0 then pos = 3 end
  local parts = { s:sub(1, pos) }
  for i = pos + 1, #s, 3 do
      parts[#parts+1] = s:sub(i, i+2)
  end
  return table.concat(parts, " ")
end

local function fmtCooldown(ms)
  if not ms or ms <= 0 then return nil end
  local sec = math.floor(ms / 1000)
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then return string.format("%dh %02dm", h, m)
  elseif m > 0 then return string.format("%dm %02ds", m, s)
  end
  return string.format("%ds", s)
end

local function fmtTime(epoch)
  if not epoch or epoch == 0 then return "     " end
  local s = epoch % 86400
  return string.format("%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60)
end

local function urlencode(s)
  return s:gsub("[^%w%-%.%_%~]", function(c)
      return string.format("%%%02X", c:byte())
  end)
end

-- Image parsing
local function parseBlit(body)
  local lines = {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
      lines[#lines + 1] = line
  end
  local free_str = lines[1] and lines[1]:match("^free:(.*)$")
  if free_str then table.remove(lines, 1) end
  local free_colors = {}
  if free_str then
      for i = 1, #free_str do
          free_colors[i] = nfpToColor(free_str:sub(i, i))
      end
  end
  return lines, free_colors
end

return {
  loadUsers = loadUsers,
  saveUsers = saveUsers,
  resetPalette = resetPalette,
  setPalette = setPalette,
  hslToHex = hslToHex,
  colHex = colHex,
  fmtNum = fmtNum,
  fmtCooldown = fmtCooldown,
  fmtTime = fmtTime,
  urlencode = urlencode,
  parseBlit = parseBlit,
  GOLD = GOLD,
  SOFT_WHITE = SOFT_WHITE,
  SOFT_GRAY = SOFT_GRAY,
}