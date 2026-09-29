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

**In HA (key-based auth — recommended):**
1. Settings → Add-ons → Add-on Store → search **Terminal & SSH** → Install
2. Configuration tab → add your **public key** (`~/.ssh/id_ed25519.pub` or similar) under `authorized_keys` → Save
3. Network tab → enable port **22** → Save
4. Start the add-on → enable **Start on boot**

Key-based auth means no SSH password is ever stored in this skill's files.
If your setup can't do key-based auth, the add-on also supports a
**Password** field in its Configuration tab — if you use that instead,
store the password only in your local `.secrets/connection.md` (see
Configuration below), never in `SKILL.md` itself.

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

Your real HA IP and API token never go into `SKILL.md` — they live in a
gitignored `.secrets/connection.md` next to it, which Claude reads from
your local disk (via Desktop Commander) at runtime. This keeps them out of
both git history and the packaged `.skill` file you upload.

### Option A — Run the configure script

```bash
cd ha-direct-access/
chmod +x configure.sh
./configure.sh
```

Prompts for your HA IP, SSH password (only if not using key-based auth),
and API token, then writes them into `.secrets/connection.md` and fills in
`{{SKILL_PATH}}` in `SKILL.md` so Claude knows the absolute path to find it.

### Option B — Edit manually

```bash
cp ha-direct-access/.secrets.example/connection.md ha-direct-access/.secrets/connection.md
```

Then open `.secrets/connection.md` and fill in `{{HA_IP}}` / `{{HA_TOKEN}}`.
In `SKILL.md`, replace `{{SKILL_PATH}}` with the full absolute path to your
`ha-direct-access/` folder on disk.

---

## Install the Skill

### Package
```bash
python3 -c "
import zipfile, os
zf = zipfile.ZipFile('ha-direct-access.skill', 'w', zipfile.ZIP_DEFLATED)
skip = {'.secrets', '.secrets.example'}
for r, d, files in os.walk('ha-direct-access'):
    d[:] = [x for x in d if x not in skip]
    for f in files:
        zf.write(os.path.join(r, f), os.path.relpath(os.path.join(r, f), '.'))
zf.close()
print('Done: ha-direct-access.skill')
"
```
`.secrets/` is deliberately excluded — the packaged file never contains your
real IP, credentials, or token. Don't share the packaged `.skill` file with
anyone unless you're certain it was built this way, since older versions of
this script baked real values directly into `SKILL.md` before zipping.

### Install
Claude.ai → Settings → Skills → upload `ha-direct-access.skill` → enable in your project.

---

## Keeping the Skill Updated

At the end of any HA session, ask Claude:
> *"Update the skill with anything new we discovered today and repackage it."*

Claude will edit `SKILL.md` on your machine and regenerate the `.skill` file. Reinstall via Settings → Skills. Ask Claude to confirm it didn't write any real connection details into `SKILL.md` itself — those belong only in `.secrets/connection.md`.

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
- Create a new long-lived token in HA and update `{{HA_TOKEN}}` in `.secrets/connection.md`

**Desktop Commander can't reach HA**
- Confirm your machine is on the same network as HA
- Test connectivity: `python3 -c "import urllib.request; print(urllib.request.urlopen('http://YOUR_HA_IP:8123').status)"`

**macOS home path has a trailing dot**
- On some macOS setups, `$HOME` returns `/Users/username./` (with trailing dot)
- Run `echo $HOME` to verify your exact path before writing files
