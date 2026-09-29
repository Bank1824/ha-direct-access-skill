# ha-direct-access — Claude Skill for Home Assistant

A Claude skill that gives Claude direct, hands-on access to your Home Assistant configuration — edit YAML, call the REST and WebSocket APIs, reload what changed, run `ha core check`, and read logs — without you touching a terminal.

Works in the **Claude desktop app** (with [Desktop Commander](https://desktopcommander.app)) and in **Claude Code**.

---

## ⚠️ Security notice — if you set this up before September 2026

Older versions of `configure.sh` wrote your **real HA IP, SSH password and long-lived token into `SKILL.md`**, and every `.skill` file you packaged carried them. If you set the skill up before this change:

1. Pull the latest version and re-run `configure.sh`. Real values now live in a gitignored `.secrets/connection.md`, never in `SKILL.md`.
2. **Rotate your HA token:** create a new one, update `.secrets/connection.md`, then delete the old token in HA (Profile → Security → Long-lived access tokens).
3. **Switch SSH to key-based auth** (see Quick Start) and clear the add-on's password.
4. Re-package with `python3 package.py` and re-upload the `.skill` file, replacing the old one.
5. If you forked this repo or synced your `SKILL.md` anywhere, check it for real values.

Thanks to [@ftsachev](https://github.com/ftsachev) for flagging this and proposing the fix.

---

## Who This Is For

- **Claude desktop app users** with Desktop Commander connected. Install the skill under Settings → Skills.
- **Claude Code users.** Put the `ha-direct-access/` folder in `~/.claude/skills/` (or your project's `.claude/skills/`).

Either way, Claude reaches Home Assistant from your own machine over SSH and HTTP. Nothing extra runs on HA beyond the official Terminal & SSH add-on.

---

## How It Compares to the Official HA MCP Server

Home Assistant ships a built-in [Model Context Protocol Server](https://www.home-assistant.io/integrations/mcp_server/) integration. It's great for controlling devices from chat, but it works through the Assist API, so it can't touch configuration.

| | This skill | HA MCP Server (built-in integration) |
|---|---|---|
| **Runs in** | Claude desktop app + Desktop Commander, or Claude Code | Any MCP client that supports remote servers (others via `mcp-proxy`) |
| **Needs on HA** | Terminal & SSH add-on | Enable the integration |
| **Control and read exposed entities** | ✅ | ✅ |
| **Edit YAML config files** | ✅ | ❌ |
| **Registry, dashboard and Alarmo changes** | ✅ via WebSocket/REST | ❌ |
| **`ha core check`, logs, automation traces** | ✅ | ❌ |
| **Best for** | Config work, debugging, bulk changes | Day-to-day device control from chat |

They work well together: `SKILL.md` tells Claude to use a connected HA MCP server for whatever it covers, and fall back to SSH/REST for the rest.

---

## What Claude Can Do With This Skill

- ✅ Edit `automations.yaml`, `scripts.yaml`, `configuration.yaml` directly
- ✅ Reload automations, scripts, templates and HomeKit Bridge — no full restarts
- ✅ Run config validity checks before closing any task
- ✅ Debug automations using traces and HA logs
- ✅ Call any HA REST API service and query entity states
- ✅ Rename entities safely: registry, dashboards and Alarmo through their APIs (never by editing `.storage`), with collision-safe swaps and HomeKit accessories preserved
- ✅ Update and repackage the skill itself as your setup evolves

---

## Prerequisites

1. **Claude desktop app with Desktop Commander**, or **Claude Code**
2. **Python 3 + paramiko** on your machine (`pip3 install paramiko`)
3. **Terminal & SSH add-on** in Home Assistant, with **your SSH public key** in its Authorized Keys
   > ⚠️ The add-on **will not start** if both Authorized Keys and Password are empty. Add your key *before* clearing a password.
4. **HA long-lived access token** (created in your HA profile)
5. **Context7 MCP** (optional, recommended — prevents deprecated YAML syntax)

Full setup instructions: [SETUP.md](ha-direct-access/SETUP.md)

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Bank1824/ha-direct-access-skill.git
cd ha-direct-access-skill

# 2. Create an SSH key if you don't have one, then add the .pub contents to
#    HA → Settings → Apps (Add-ons on older HA) → Terminal & SSH → Configuration → Authorized Keys → Save → Start
ssh-keygen -t ed25519 -f ~/.ssh/ha_key
cat ~/.ssh/ha_key.pub

# 3. Configure (writes to the gitignored ha-direct-access/.secrets/)
chmod +x ha-direct-access/configure.sh
./ha-direct-access/configure.sh

# 4. Package (skips .secrets/ and aborts if a token slipped into the skill)
python3 package.py

# 5. Install
#    Claude desktop app: Settings → Skills → upload ha-direct-access.skill
#    Claude Code:        ln -s "$PWD/ha-direct-access" ~/.claude/skills/ha-direct-access
```

---

## Keeping the Skill Up to Date

The skill is designed to grow with your setup. At the end of each session, ask Claude:

> *"Update the skill with anything new we discovered today and repackage it."*

Claude edits `SKILL.md` on your machine and regenerates the `.skill` file; re-upload it in Settings → Skills (Claude Code picks up changes directly).

Real connection details never belong in `SKILL.md` — they live in the gitignored `.secrets/connection.md`, so `SKILL.md` stays safe to share or sync back to this repo.

---

## Repo Structure

```
ha-direct-access-skill/
├── README.md
├── package.py                ← Builds ha-direct-access.skill safely
└── ha-direct-access/
    ├── SKILL.md              ← The skill (generic — no real secrets)
    ├── SETUP.md              ← Full prerequisites and setup guide
    ├── configure.sh          ← Interactive config script
    ├── .secrets.example/     ← Tracked template for connection details
    └── .secrets/             ← Your real values (gitignored, created by configure.sh)
```

---

## Contributing

Contributions welcome — patterns, gotchas and structures that help most HA setups. Open a PR against `SKILL.md`.

Please keep PRs generic: **no real hosts, tokens, passwords, MAC addresses or entity inventories**, and no machine-specific paths. Put setup-specific details in your own local copy.

---

## License

MIT
