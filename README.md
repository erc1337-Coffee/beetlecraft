# BeetleCraft

BeetleBoy running on ComputerCraft.

Claim your Universal Basic Cheese, hunt beetles, showcase Remilia profiles, and chat with other angels.

Requires a monitor peripheral (falls back to `term`).

## Install

In the ComputerCraft terminal:

```
wget run https://raw.githubusercontent.com/erc1337-coffee/beetlecraft/main/installer/install.lua
```

The installer downloads everything, writes a `startup` file so BeetleCraft runs on boot, and reboots.

## Updating

Tap the version string in the bottom-right of the home screen (a `*` appears when an update is available), or open the `UPDATE` tile. Hit `Update Now` to re-run the installer.

The updater checks the repo the installer was built from, so forks stay on their own release track.

## Auth

`.env` ships with a shared refresh token (Echoes of MiladyCraft). To use your own account, edit the file:

```
REFRESH_TOKEN=<your_refresh_token>
```

Grab your token from your browser cookies on `remilia.net`.

## User list

User cards on the home screen come from `users.txt`, one username per line. Use the `+` tile on the home screen or edit the file directly.

## Regenerating the installer

After changing source files:

```
python3 installer/build.py --repo <user>/<repo>
```

## Structure

```
main.lua            Entry point and main loop
VERSION             Release version string
lib/auth.lua        Token storage, refresh, authenticated requests
lib/reminet.lua     All HTTP calls (profiles, beetles, images, chat)
lib/chat_ws.lua     WebSocket client for the miladychan shoutbox
lib/ui.lua          Drawing primitives and hit testing
lib/utils.lua       Persistence, palette, formatting
lib/updater.lua     Version check and self-update
scenes/             One file per screen (home, profile, beetleboy, chat, update)
assets/             Beetle sprites (png/nfp) and splash screen
installer/          build.py generates install.lua
```

## Dependencies

- `remilia.net` - profiles, auth, beetle API
- `cdn.goulag.dev` - PNG to NFP image conversion (avatars, chat images)
- `remistats.net` - global and project ranks
- `miladychan.com` - WebSocket shoutbox
