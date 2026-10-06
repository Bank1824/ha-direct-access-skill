# Setup Guide

Full prerequisites and configuration instructions for the ha-direct-access Claude skill.

---

## Prerequisites

### 1. Claude desktop app or Claude Code
- **Claude desktop app:** install the skill under Settings → Skills. Needs Desktop Commander (below) so Claude can reach your network.
- **Claude Code:** put the `ha-direct-access/` folder in `~/.claude/skills/`. Claude Code runs commands itself, so Desktop Commander isn't needed.

### 2. Desktop Commander (Claude desktop app only)
Desktop Commander gives Claude terminal and filesystem access on your local machine. Without it, Claude in the desktop app cannot reach your HA instance.

Install it by following the instructions at https://desktopcommander.app.

### 3. Python 3 + paramiko
Claude uses `paramiko` to SSH into HA. Python 3 must be on your local machine.

**Check:**
```bash
python3 --version
python3 -c "import paramiko; print('paramiko ok')"
```

**Install paramiko if missing:**
```bash
pip3 install paramiko
```

### 4. Terminal & SSH Add-on (key-based auth)
Exposes SSH access to your HA instance on port 22.

**On your machine** — create a key if you don't have one:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ha_key
cat ~/.ssh/ha_key.pub
```

**In HA:**
1. Settings → **Apps** (called Add-ons on older HA versions) → store → search **Terminal & SSH** → Install
2. Configuration tab → **Authorized Keys** → paste the `.pub` line → Save
3. Network tab → enable port **22** → Save
4. Start the add-on → enable **Start on boot**
5. Test from your machine: `ssh -i ~/.ssh/ha_key root@YOUR_HA_IP 'echo ok'`

> ⚠️ **The add-on will not start if both Authorized Keys and Password are empty.** If you're moving from a password to a key, add and test the key first, then clear the password.

Key-based auth means no SSH password is ever stored in this skill's files.
If your setup can't do key-based auth, the add-on also supports a
**Password** field in its Configuration tab — if you use that instead,
store the password only in your local `.secrets/connection.md` (see
Configuration below), never in `SKILL.md` itself.

### 5. HA Long-Lived Access Token
Lets Claude call the HA REST API for lightweight operations like reloads.

**Create one:**
1. HA → your profile (bottom-left) → Long-Lived Access Tokens → Create Token
2. Give it a descriptive name (e.g. the machine it's used from) → copy the token

### 6. Context7 MCP (optional but recommended)
Injects live HA documentation into Claude's context — prevents deprecated YAML syntax.

```bash
npx @upstash/context7-mcp
```
Connect the same way as Desktop Commander.

---

## Configuration

Your real HA IP, SSH key path and API token never go into `SKILL.md` — they live in a
gitignored `.secrets/connection.md` next to it, which Claude reads from
your local disk (via Desktop Commander) at runtime. This keeps them out of
both git history and the packaged `.skill` file you upload.

### Option A — Run the configure script

```bash
cd ha-direct-access/
chmod +x configure.sh
./configure.sh
```

Prompts for your HA IP, SSH private key path, an SSH password (only if you
can't use key-based auth), and API token, then writes them into `.secrets/connection.md` and fills in
`{{SKILL_PATH}}` in `SKILL.md` so Claude knows the absolute path to find it.

### Option B — Edit manually

```bash
cp ha-direct-access/.secrets.example/connection.md ha-direct-access/.secrets/connection.md
```

Then open `.secrets/connection.md` and fill in `{{HA_IP}}`, `{{SSH_KEY_PATH}}`
(absolute path — paramiko doesn't expand `~`) and `{{HA_TOKEN}}`.
In `SKILL.md`, replace `{{SKILL_PATH}}` with the full absolute path to your
`ha-direct-access/` folder on disk.

---

## Install the Skill

### Package
From the repo root:
```bash
python3 package.py
```
It skips `.secrets/`, `.secrets.example/`, `.git` and backup files, and aborts
if a token-shaped string is found anywhere in the skill — the packaged file
never contains your real IP, credentials, or token. Don't share the packaged `.skill` file with
anyone unless you're certain it was built this way, since older versions of
this script baked real values directly into `SKILL.md` before zipping.

### Install
- **Claude desktop app:** Settings → Skills → upload `ha-direct-access.skill` → make sure it's toggled on. To update, upload the new file so a new version replaces the old one (check the Contents tab).
- **Claude Code:** `ln -s "$PWD/ha-direct-access" ~/.claude/skills/ha-direct-access` — no packaging needed.

---

## Keeping the Skill Updated

At the end of any HA session, ask Claude:
> *"Update the skill with anything new we discovered today and repackage it."*

Claude will edit `SKILL.md` on your machine and regenerate the `.skill` file. Reinstall via Settings → Skills. Ask Claude to confirm it didn't write any real connection details into `SKILL.md` itself — those belong only in `.secrets/connection.md`.

---

## Troubleshooting

**SSH connection refused**
- Confirm the SSH add-on is running in HA. If its state is **error**, it usually means both Authorized Keys and Password are empty — add your public key and start it again
- Make sure port 22 is enabled in the add-on's Network tab
- Restart the add-on after any config change

**`paramiko` not found**
```bash
pip3 install paramiko
# or on some Linux systems:
pip3 install paramiko --break-system-packages
```

**Config check returns errors**
- The error message will point to the exact file and line — fix the YAML issue before reloading

**SSH asks for a password / permission denied (publickey)**
- The public key in the add-on must match the private key at `{{SSH_KEY_PATH}}`
- Re-save the add-on config after pasting the key, then restart the add-on

**Token returns 401 Unauthorized**
- Create a new long-lived token in HA and update `{{HA_TOKEN}}` in `.secrets/connection.md`

**Desktop Commander can't reach HA**
- Confirm your machine is on the same network as HA
- Test connectivity: `python3 -c "import urllib.request; print(urllib.request.urlopen('http://YOUR_HA_IP:8123').status)"`

**macOS home path has a trailing dot**
- On some macOS setups, `$HOME` returns `/Users/username./` (with trailing dot)
- Run `echo $HOME` to verify your exact path before writing files
