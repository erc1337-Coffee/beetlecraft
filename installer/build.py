#!/usr/bin/env python3
"""
Generates install.lua from the current beetlecraft file tree.

Usage:
    python build.py [--repo user/repo] [--dest beetlecraft]

The output install.lua is written next to this script.
CC users install with:
    wget run https://raw.githubusercontent.com/erc1337-coffee/beetlecraft/main/beetlecraft/installer/install.lua
"""

import argparse
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

SKIP_DIRS = {"installer", "__pycache__", ".git"}
SKIP_EXTS = {".png", ".py", ".pyc"}
SKIP_FILES = {".luacheckrc", ".gitignore", ".DS_Store", "startup", "users.txt"}


def collect_files():
    files = []
    for root, dirs, filenames in os.walk(PROJECT_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(filenames):
            if f in SKIP_FILES or os.path.splitext(f)[1] in SKIP_EXTS:
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, PROJECT_DIR)
            files.append(rel.replace(os.sep, "/"))
    return sorted(files)


def generate_lua(repo):
    files = collect_files()
    base_url = f"https://raw.githubusercontent.com/{repo}/main"

    lines = []
    lines.append(f'local BASE = "{base_url}"')
    lines.append("local FILES = {")
    for f in files:
        lines.append(f'    "{f}",')
    lines.append("}")
    lines.append("")
    lines.append(LUA_BODY)
    return "\n".join(lines) + "\n"


LUA_BODY = """\
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
su.write('shell.run("cd beetlecraft")')
su.write('shell.run("main")')
su.close()
print("[ok] startup -> /beetlecraft/main")

-- Persist install origin for the updater
-- This way if you fork and use your own code, you won't fetch 
-- updates against the default repo but from yours
local mf = fs.open("beetlecraft/.install.meta", "w")
mf.write("BASE=" .. BASE .. "\\n")
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
end"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate beetlecraft install.lua")
    parser.add_argument("--repo", default="erc1337-Coffee/beetlecraft", help="GitHub user/repo (default: erc1337-Coffee/beetlecraft)")
    args = parser.parse_args()

    lua = generate_lua(args.repo)
    out = os.path.join(SCRIPT_DIR, "install.lua")
    with open(out, "w") as f:
        f.write(lua)

    count = lua.count('    "')
    print(f"Wrote {out} ({count} files)")
