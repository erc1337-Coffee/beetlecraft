local BASE = "https://raw.githubusercontent.com/erc1337-Coffee/beetlecraft/main"
local FILES = {
    ".env",
    "README.md",
    "VERSION",
    "assets/nfp/black_widow.nfp",
    "assets/nfp/bombardier.nfp",
    "assets/nfp/candycane.nfp",
    "assets/nfp/cheese.nfp",
    "assets/nfp/christmas.nfp",
    "assets/nfp/giraffe_weevil.nfp",
    "assets/nfp/gold.nfp",
    "assets/nfp/goliath.nfp",
    "assets/nfp/green.nfp",
    "assets/nfp/imperial_tortoise.nfp",
    "assets/nfp/ladybug.nfp",
    "assets/nfp/mars_rhino.nfp",
    "assets/nfp/monarch.nfp",
    "assets/nfp/pond.nfp",
    "assets/nfp/purple.nfp",
    "assets/nfp/sabertooth.nfp",
    "assets/nfp/skull.nfp",
    "assets/nfp/stag.nfp",
    "assets/nfp/sunset_moth.nfp",
    "assets/splash.nfp",
    "lib/auth.lua",
    "lib/chat_ws.lua",
    "lib/reminet.lua",
    "lib/ui.lua",
    "lib/updater.lua",
    "lib/utils.lua",
    "main.lua",
    "scenes/beetleboy.lua",
    "scenes/chat.lua",
    "scenes/home.lua",
    "scenes/profile.lua",
    "scenes/update.lua",
}

local function mkdirs(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do parts[#parts + 1] = part end
    local cur = ""
    for i = 1, #parts - 1 do
        cur = cur == "" and parts[i] or (cur .. "/" .. parts[i])
        if not fs.isDir(cur) then fs.makeDir(cur) end
    end
end

local ok, fail = 0, 0
for _, file in ipairs(FILES) do
    local url  = BASE .. "/" .. file
    local dest = "beetlecraft/" .. file
    mkdirs(dest)
    local res = http.get(url)
    if res then
        local h = fs.open(dest, "w")
        h.write(res.readAll())
        h.close()
        res.close()
        ok = ok + 1
        print("[ok] " .. file)
    else
        fail = fail + 1
        print("[FAIL] " .. file)
    end
end

-- Write startup to root so beetlecraft runs on boot
local su = fs.open("startup", "w")
su.write('shell.run("cd beetlecraft && main")')
su.close()
print("[ok] startup -> /beetlecraft/main")

-- Persist install origin for the updater
-- This way if you fork and use your own code, you won't fetch 
-- updates against the default repo but from yours
local mf = fs.open("beetlecraft/.install.meta", "w")
mf.write("BASE=" .. BASE .. "\n")
mf.close()
print("[ok] .install.meta")

print("")
print(ok .. " files installed, " .. fail .. " failed.")
if fail > 0 then
    print("Some files failed. Fix and rerun the installer.")
else
    print("Done! Rebooting...")
    sleep(1.5)
    os.reboot()
end
