std = "lua51"
max_line_length = false

-- ComputerCraft / CraftOS-PC globals
read_globals = {
    "colors", "colours", "term", "peripheral", "fs", "http",
    "textutils", "paintutils", "os", "sleep", "shell",
    "keys", "math", "string", "table", "tonumber", "tostring",
    "type", "pairs", "ipairs", "pcall", "require", "error",
    "print", "write",
}

-- Our own cross-module globals (set in main.lua, read everywhere)
globals = {
    "mon", "W", "H", "S",
    "BEETLES", "SPLASH_BLIT", "BASE_DIR",
    "user_list", "buildEntries",
}
