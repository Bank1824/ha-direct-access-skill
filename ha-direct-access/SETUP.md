# Setup Guide

Full prerequisites and configuration instructions for the ha-direct-access Claude skill.

---

## Prerequisites

### 1. claude.ai Pro with Projects
You need a claude.ai account with Projects enabled (Pro tier or above). This skill is installed per-project via Settings → Skills.

### 2. Desktop Commander MCP
Desktop Commander gives Claude terminal and filesystem access on your local machine. Without it, Claude cannot reach your HA instance.

**Install:**
```bash
npx @desktopcommander/mcp
```
Then connect it: Claude.ai → Settings → Developer → Add MCP Server → follow Desktop Commander instructions at https://desktopcommander.app

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

### 4. HA SSH & Terminal Add-on
Exposes SSH access to your HA instance on port 22.

**In HA:**
1. Settings → Add-ons → Add-on Store → search **Terminal & SSH** → Install
2. Start the add-on → enable **Start on boot**
3. Configuration tab → set a **Password** → Save
4. Network tab → enable port **22** → Save
5. Restart the add-on

### 5. HA Long-Lived Access Token
Lets Claude call the HA REST API for lightweight operations like reloads.

**Create one:**
1. HA → your profile (bottom-left) → Long-Lived Access Tokens → Create Token
2. Name it `Desktop Commander` → copy the token

### 6. Context7 MCP (optional but recommended)
Injects live HA documentation into Claude's context — prevents deprecated YAML syntax.

```bash
npx @upstash/context7-mcp
```
Connect the same way as Desktop Commander.

---

## Configuration

### Option A — Run the configure script

```bash
cd ha-direct-access/
chmod +x configure.sh
./configure.sh
```

Prompts for your HA IP, SSH password, and API token, then writes them into `SKILL.md`.

### Option B — Edit manually

Open `SKILL.md` and replace every `{{PLACEHOLDER}}`:

| Placeholder | Value |
|-------------|-------|
| `{{HA_IP}}` | Your HA IP (e.g. `192.168.1.2`) |
| `{{SSH_PASSWORD}}` | Password set in the SSH add-on |
| `{{HA_TOKEN}}` | Your long-lived access token |
| `{{SKILL_PATH}}` | Full path to the `ha-direct-access/` folder on your machine |

---

## Install the Skill

### Package
```bash
python3 -c "
import zipfile, os
zf = zipfile.ZipFile('ha-direct-access.skill', 'w', zipfile.ZIP_DEFLATED)
[zf.write(os.path.join(r,f), os.path.relpath(os.path.join(r,f), '.')) for r,d,files in os.walk('ha-direct-access') for f in files]
zf.close()
print('Done: ha-direct-access.skill')
"
```

### Install
Claude.ai → Settings → Skills → upload `ha-direct-access.skill` → enable in your project.

---

## Keeping the Skill Updated

At the end of any HA session, ask Claude:
> *"Update the skill with anything new we discovered today and repackage it."*

Claude will edit `SKILL.md` on your machine and regenerate the `.skill` file. Reinstall via Settings → Skills.

---

## Troubleshooting

**SSH connection refused**
- Confirm the SSH add-on is running in HA
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

**Token returns 401 Unauthorized**
- Create a new long-lived token in HA and update `{{HA_TOKEN}}` in `SKILL.md`

**Desktop Commander can't reach HA**
- Confirm your machine is on the same network as HA
- Test connectivity: `python3 -c "import urllib.request; print(urllib.request.urlopen('http://YOUR_HA_IP:8123').status)"`

**macOS home path has a trailing dot**
- On some macOS setups, `$HOME` returns `/Users/username./` (with trailing dot)
- Run `echo $HOME` to verify your exact path before writing files
