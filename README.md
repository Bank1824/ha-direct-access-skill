# ha-direct-access — Claude Skill for Home Assistant

> **For claude.ai users with Desktop Commander.** Not a Claude Code skill. Not an MCP server. No extra infrastructure.

Give Claude direct, autonomous access to your Home Assistant instance — read and edit config files, call the REST API, reload automations, run CLI commands, and perform QA checks — all from within a claude.ai chat, without you touching a terminal.

---

## Who This Is For

This skill is specifically designed for **claude.ai Projects users** who have [Desktop Commander](https://desktopcommander.app) connected as an MCP server.

If that's you, this skill gives Claude full HA access with zero additional infrastructure.

---

## How It's Different From Everything Else

| | This Skill | Claude Code Skills | HA MCP Server (official) | ha-mcp |
|---|---|---|---|---|
| **Interface** | claude.ai web/app | Claude Code CLI | Claude Desktop | Claude Desktop / API |
| **Requires Claude Code** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Requires server on HA** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Requires extra infra** | ❌ No | ❌ No | ✅ mcp-proxy | ✅ Docker/add-on |
| **Edits config files directly** | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| **Works in claude.ai Projects** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Self-updating skill file** | ✅ Yes | ❌ No | ❌ No | ❌ No |

**The gap this fills:** Every existing solution requires either Claude Code (a separate paid CLI tool), or a custom MCP server running on your network. This skill works with the claude.ai interface you already use, using Desktop Commander (which many claude.ai users already have) and Python's `paramiko` library to SSH directly into HA. Nothing else needed.

---

## What Claude Can Do With This Skill

- ✅ Edit `automations.yaml`, `scripts.yaml`, `configuration.yaml` directly
- ✅ Reload automations, scripts, templates, HomeKit Bridge — no full restarts
- ✅ Run config validity checks and scan for repairs before closing any task
- ✅ Debug automations using traces and HA logs
- ✅ Call any HA REST API service
- ✅ Query entity states
- ✅ Update and repackage the skill itself as your setup evolves

---

## Prerequisites

1. **claude.ai Pro** (Projects required)
2. **Desktop Commander** connected as an MCP server → [desktopcommander.app](https://desktopcommander.app)
3. **Python 3 + paramiko** on your local machine (`pip3 install paramiko`)
4. **HA SSH & Terminal add-on** installed and running in Home Assistant
5. **HA Long-lived access token** (created in your HA profile)
6. **Context7 MCP** (optional but recommended — prevents deprecated YAML syntax)

Full setup instructions: [SETUP.md](ha-direct-access/SETUP.md)

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Bank1824/ha-direct-access-skill.git
cd ha-direct-access-skill

# 2. Configure with your HA details
chmod +x ha-direct-access/configure.sh
./ha-direct-access/configure.sh

# 3. Package the skill
python3 -c "
import zipfile, os
zf = zipfile.ZipFile('ha-direct-access.skill', 'w', zipfile.ZIP_DEFLATED)
[zf.write(os.path.join(r,f), os.path.relpath(os.path.join(r,f), '.')) for r,d,files in os.walk('ha-direct-access') for f in files]
zf.close()
print('Done: ha-direct-access.skill')
"

# 4. Install
# Upload ha-direct-access.skill to claude.ai → Settings → Skills
```

---

## Keeping the Skill Up to Date

The skill is designed to grow with your setup. As you work with Claude on HA tasks, you'll discover new entity IDs, patterns, and gotchas. At the end of each session, ask Claude:

> *"Update the skill with anything new we discovered today and repackage it."*

Claude will edit `SKILL.md` on your machine and regenerate the `.skill` file automatically. Reinstall via Settings → Skills.

The `SKILL.md` on your machine is the source of truth. Claude reads it at the start of every session.

---

## Repo Structure

```
ha-direct-access-skill/
├── README.md
└── ha-direct-access/
    ├── SKILL.md        ← The skill (configure before installing)
    ├── SETUP.md        ← Full prerequisites and setup guide
    └── configure.sh    ← Interactive config script
```

---

## Contributing

Contributions welcome. If you've found patterns, gotchas, or entity structures worth sharing, open a PR against `SKILL.md`. The goal is a skill that covers the most common HA setups out of the box, with a clear extension pattern for setup-specific details.

---

## License

MIT
