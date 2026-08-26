---
name: ha-direct-access
description: >
  Direct access to your Home Assistant instance via Desktop Commander.
  Use this skill whenever making any change to Home Assistant — editing config files,
  writing automations, running CLI commands, calling the REST API, or performing QA checks.
  This skill is required for all HA work on your instance. Always read it before touching
  anything in HA, including simple tasks like reloading automations or checking entity states.
---

# Home Assistant Direct Access

## Connection Details

Real connection details (host, SSH creds, API token) live in
`{{SKILL_PATH}}/.secrets/connection.md` — a folder that's gitignored, never
committed, and never packaged into the `.skill` upload. Read that file
first (via Desktop Commander / filesystem access) and substitute its values
for every `{{HA_IP}}`/`{{HA_TOKEN}}` placeholder in the commands below. If
`.secrets/` doesn't exist yet, run `configure.sh` or copy
`.secrets.example/` to `.secrets/` and fill it in by hand.

---

## Prefer the Home Assistant MCP server — SSH/REST is a fallback

If a `home-assistant` MCP server (`mcp__home-assistant__*` tools) is
connected, use it first for anything it covers: reading/setting entity
state, calling services, managing automations/scripts/scenes/dashboards,
getting logs, history, device/area info, backups, add-ons, etc. It never
requires putting the bearer token in a visible command, and it validates
inputs before touching HA.

Only drop to the raw SSH/REST methods in this file when the task genuinely
needs them — things the MCP server doesn't expose, such as:
- Direct edits to YAML files outside the config entities MCP manages (e.g.
  `homekitbridge.yaml`, raw `.storage/*` repair)
- Tailing/grepping `home-assistant.log` for a specific pattern
- Running arbitrary HA CLI commands (`ha core check`, `ha ... `) over SSH
- MQTT publish for testing device-specific payloads
- Anything the MCP server errors on or doesn't support yet

When falling back to SSH/REST, still keep the token out of shell history
where practical (e.g. read it from `.secrets/connection.md` into a Python
variable rather than pasting it into a bare `curl` command line).

---

## SSH Access

This is a **Linux host** — key-based SSH only (`~/.ssh/haos_access`).

### Standard SSH command (preferred)

```bash
ssh haos 'YOUR COMMAND HERE'
```

> Uses `~/.ssh/config` alias (`haos` → `root@{{HA_IP}}` with `~/.ssh/haos_access` key).

### Multi-command / SFTP via Python (use ha-mcp virtualenv python)

```python
~/.local/share/uv/tools/ha-mcp/bin/python3 -c "
import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('{{HA_IP}}', port=22, username='root', key_filename='~/.ssh/haos_access')
stdin, stdout, stderr = client.exec_command('ha core check 2>&1')
print('Core check:', stdout.read().decode().strip())
client.close()
"
```

> **Note:** paramiko IS available inside the ha-mcp virtualenv at
> `~/.local/share/uv/tools/ha-mcp/bin/python3`, useful for
> `exec_command` (multi-command sessions, structured output). **Do NOT use
> `open_sftp()` against `haos`** — confirmed 2026-08-06 that HAOS's SSH
> server has no `sftp` subsystem; `open_sftp()` fails with `Channel closed`
> even though plain SSH exec works fine. For file writes, use the
> local-write + `ssh haos 'cat > target' < localfile` pattern below instead
> of SFTP, despite what the "Safe file editing" section further down says.

### Key files on HA

| File | Purpose |
|------|---------|
| `/homeassistant/automations.yaml` | All automations |
| `/homeassistant/scripts.yaml` | All scripts |
| `/homeassistant/configuration.yaml` | Core config, template entities |
| `/homeassistant/homekitbridge.yaml` | HomeKit Bridge filter config |
| `/homeassistant/secrets.yaml` | Passwords, tokens (never read aloud) |

---

## REST API Access

Use `urllib.request` (stdlib, always available). Do NOT use `requests` — it may not be installed.

### GET states

\`\`\`python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/states',
    headers={'Authorization': f'Bearer {TOKEN}'}
)
resp = urllib.request.urlopen(req)
states = json.loads(resp.read())
[print(s['entity_id'], s['state']) for s in states if 'keyword' in s['entity_id']]
"
\`\`\`

### POST service call

\`\`\`python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/services/DOMAIN/SERVICE',
    data=json.dumps({}).encode(),
    headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
print('Status:', resp.status)
"
\`\`\`

---
## Targeted Reloads (no restart needed)

Always prefer targeted reloads over full HA restarts. Full restarts only required when adding a new integration or platform to `configuration.yaml`.

| What changed | Service to call |
|---|---|
| automations.yaml | `automation/reload` |
| scripts.yaml | `script/reload` |
| configuration.yaml templates | `template/reload` |
| homekitbridge.yaml | `homekit/reload` |
| All of the above | Call each in sequence |

### Reload all reloadable components

\`\`\`python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
BASE = 'http://{{HA_IP}}:8123/api/services'
HEADERS = {'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'}
services = [
    'automation/reload', 'script/reload', 'scene/reload', 'template/reload',
    'homekit/reload', 'input_boolean/reload', 'input_number/reload',
    'input_select/reload', 'input_text/reload', 'input_datetime/reload',
    'timer/reload', 'counter/reload', 'schedule/reload', 'zone/reload'
]
for svc in services:
    req = urllib.request.Request(f'{BASE}/{svc}', data=b'{}', headers=HEADERS, method='POST')
    try:
        resp = urllib.request.urlopen(req)
        print(f'OK {svc}')
    except Exception as e:
        print(f'FAIL {svc}: {e}')
"
\`\`\`

---

## QA — Required Before Closing Any Task

**A task is not complete until both checks pass clean.**

### 1. Config check

\`\`\`python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/config/core/check_config',
    data=b'{}',
    headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'},
    method='POST'
)
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
print(result.get('result'), result.get('errors', 'none'))
"
\`\`\`

Expected: `valid None`

### 2. Core check via SSH

The repairs API is WebSocket-only — use HA CLI over SSH instead:

\`\`\`python
python3 -c "
import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('{{HA_IP}}', port=22, username='root', key_filename='~/.ssh/haos_access')
stdin, stdout, stderr = client.exec_command('ha core check 2>&1')
print('Core check:', stdout.read().decode().strip())
client.close()
"
\`\`\`

Expected: `Command completed successfully.`

For visual confirmation ask a household member to screenshot Settings → Repairs in the HA UI.

---

## Entity Reference

> Fill this section in with your own entity IDs as you discover them during sessions.
> This eliminates repeated SSH state queries and keeps sessions fast.
> Ask Claude to update this section at the end of any HA session.

### Structure to follow

```
### Electricity
| Entity | Description |
|--------|-------------|
| `sensor.example_price` | Current price per kWh |
| `sensor.example_tariff` | Current tariff (`day`/`night`) |
| `automation.example_sync_tariff` | Syncs tariff to utility meters |

### Presence
| Entity | Description |
|--------|-------------|
| `person.example` | Presence (`home`/`not_home`) |
| `binary_sensor.everyone_home` | Template: `on` when someone tracked is home |

### Buttons / Remotes
| Entity | Description |
|--------|-------------|
| `event.example_button` | Fires `click`/`double_click`/`press` events |

### Watering / Irrigation
| Entity | Description |
|--------|-------------|
| `binary_sensor.watering_skip_today` | `on` if rain expected or rained yesterday |
| `automation.watering_zone_morning` | Scheduled zone watering trigger |
| `script.water_zone` | Zone watering script |

### Updates & Monitoring
| Entity | Description |
|--------|-------------|
| `sensor.updates_available_count` | Count of `update.*` entities in `on` state |
| `update.home_assistant_core_update` | HA Core update |

### Backup
| Entity | Description |
|--------|-------------|
| `sensor.backup_backup_manager_state` | `idle` / `create_backup` / ... |
| `automation.scheduled_backup` | Scheduled backup trigger (uses `backup.create_automatic`) |

### Batteries
| Entity | Description |
|--------|-------------|
| `sensor.example_device_battery` | Battery % for a given device |
```

Fill in your own instance's real entities in place of the examples above — don't paste this section verbatim into a shared/public copy of the skill, since entity names and layout reveal your home's device inventory.

### MQTT topic format: `zigbee2mqtt/FRIENDLY_NAME/set`

---

## VZM31-SN LED Reference

MQTT set topics:
- `zigbee2mqtt/Living Room Fan & Light Switch/set`
- `zigbee2mqtt/Master Bedroom Fan & Light Switch/set`

### LED effect payload
```json
{"led_effect": {"effect": "EFFECT_NAME", "color": COLOR_NUMBER, "level": 40, "duration": DURATION_SECONDS}}
```
`duration: 255` = persistent. Always follow with a clear after testing.

### Color numbers
| Color | Number |
|-------|--------|
| Red | 0 |
| Orange | 21 |
| Yellow | 42 |
| Green | 85 |
| Cyan | 127 |
| Blue | 170 |
| Violet | 212 |
| Pink | 234 |
| White | 255 |

### Effect names
| Effect | Use case |
|--------|----------|
| `solid` | Persistent armed states |
| `slow_blink` | Arming, door open/unlocked |
| `fast_blink` | Entry delay (pending) |
| `chase` | Triggered alarm |
| `clear_effect` | Reset LED to off |

### Clear payload
```json
{"led_effect": {"effect": "clear_effect", "color": 0, "level": 0, "duration": 0}}
```

### Kill default blue
```json
{"led_intensity_when_on": 0, "led_intensity_when_off": 0}
```

---

## Common Patterns

### Read large files via SSH (use sed ranges, not cat)
```python
client.exec_command('wc -l /homeassistant/automations.yaml')
client.exec_command('sed -n "100,200p" /homeassistant/automations.yaml')
```

### Full HA restart (confirm with other household members first — 60s downtime)
```python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/services/homeassistant/restart',
    data=b'{}',
    headers={'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'},
    method='POST'
)
print('Restart sent:', urllib.request.urlopen(req).status)
"
```
Other household members' Apple Home/HomeKit clients stay responsive during restart.

### CRITICAL: Never use `cat file | ssh haos 'cat > target'` to write files

This pattern **silently corrupts files** — if the SSH connection drops or pipe fails mid-transfer, the target file is truncated to 0 bytes. HA then marks the storage as corrupt and renames it, breaking entities.

**Instead, always use one of these safe methods.** (SFTP is NOT an option here
— confirmed 2026-08-06 that HAOS's SSH server has no `sftp` subsystem;
`open_sftp()` fails with `Channel closed`. Don't use `sftp.open(...)`
anywhere against `haos` despite older advice suggesting it.)

1. **Write locally first, then copy via SSH heredoc (preferred — works for
   any file, JSON or YAML):**
   ```bash
   # Pull the current file to a local scratch copy first if editing in place
   ssh haos 'cat /homeassistant/.storage/target' > /tmp/target.json
   # Edit /tmp/target.json locally (Edit tool, or python json load/dump)
   # Then write it back the same safe way:
   ssh haos 'cat > /homeassistant/.storage/target' < /tmp/target.json
   ```
   Always validate before writing back: `python3 -c "import json; json.load(open('/tmp/target.json'))"`
   for JSON storage files, or `ha core check` after writing for YAML config.

2. **`scp` with a real path** (not piped stdin) is a fallback if method 1's
   heredoc has issues, but hasn't been reliably tested against HAOS's SSH
   subsystem — prefer method 1.

**If a storage file is corrupted:** check for `.corrupt.*` backup, restore it, delete the corrupt marker, and restart HA.

---

### Safe file editing — local-write + heredoc, three patterns

All three pull the file locally first (`ssh haos 'cat /path/to/file' > /tmp/local.copy`),
edit the local copy, then push back with `ssh haos 'cat > /path/to/file' < /tmp/local.copy`.

**Pattern 1 — Append (new automations/scripts)**
```bash
ssh haos 'cat /homeassistant/automations.yaml' > /tmp/automations.yaml
cat new_block.yaml >> /tmp/automations.yaml
python3 -c "import yaml; yaml.safe_load(open('/tmp/automations.yaml'))"  # validate first
ssh haos 'cat > /homeassistant/automations.yaml' < /tmp/automations.yaml
```

**Pattern 2 — Delete lines by number**
```bash
ssh haos 'grep -n "target" /homeassistant/automations.yaml'   # confirm line numbers first
ssh haos 'cat /homeassistant/automations.yaml' > /tmp/automations.yaml
sed -i 'START,ENDd' /tmp/automations.yaml
ssh haos 'cat > /homeassistant/automations.yaml' < /tmp/automations.yaml
```

**Pattern 3 — String replace (safest for targeted edits — handles quotes, slashes, ampersands)**
```bash
ssh haos 'cat /homeassistant/automations.yaml' > /tmp/automations.yaml
python3 -c "
with open('/tmp/automations.yaml') as f:
    content = f.read()
assert content.count('old_string') == 1  # verify match count first
content = content.replace('old_string', 'new_string', 1)
with open('/tmp/automations.yaml', 'w') as f:
    f.write(content)
"
ssh haos 'cat > /homeassistant/automations.yaml' < /tmp/automations.yaml
```
Always verify match count before replacing, and run `ha core check` after writing back.

### HA log access
```python
client.exec_command('tail -100 /homeassistant/home-assistant.log')
client.exec_command('grep -i "keyword" /homeassistant/home-assistant.log | tail -50')
```

### Automation trace (why did/didn't it fire?)
```python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/trace/automation/AUTOMATION_ENTITY_ID',
    headers={'Authorization': f'Bearer {TOKEN}'}
)
traces = json.loads(urllib.request.urlopen(req).read())
if traces:
    t = traces[0]
    print('Last run:', t.get('timestamp'))
    print('Trigger:', json.dumps(t.get('trigger'), indent=2))
"
```
Replace AUTOMATION_ENTITY_ID with e.g. `automation.chime_front_door_open`.

### MQTT publish (testing Z2M effects)
```python
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
HEADERS = {'Authorization': f'Bearer {TOKEN}', 'Content-Type': 'application/json'}
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/services/mqtt/publish',
    data=json.dumps({
        'topic': 'zigbee2mqtt/Living Room Fan & Light Switch/set',
        'payload': json.dumps({'led_effect': {'effect': 'slow_blink', 'color': 21, 'level': 40, 'duration': 10}})
    }).encode(),
    headers=HEADERS, method='POST'
)
urllib.request.urlopen(req)
```

### Get Z2M friendly names
```python
client.exec_command('mosquitto_sub -h localhost -t "zigbee2mqtt/bridge/devices" -C 1 | python3 -c "import json,sys; [print(d[\'friendly_name\']) for d in json.load(sys.stdin)]"')
```

---

## Context7 — Always Use for HA Syntax

Context7 is connected as an MCP server. Use it proactively before writing any HA config to avoid deprecated syntax errors.

**Always use Context7 before writing:**
- Automation/script YAML (triggers, conditions, actions)
- Template entity definitions
- Integration-specific service calls (Z-Wave JS, Zigbee2MQTT, Reolink, Alarmo)

### How to query
```
# Step 1
resolve-library-id: "home-assistant"

# Step 2
query-docs: "your question here"
  library_id: /home-assistant/core
```

**Common queries to always run through Context7:**
- "parallel action syntax in automations"
- "template fan entity modern syntax"
- "zwave_js.set_value service parameters"
- "homekit filter include_domains syntax"
- "mqtt.publish service payload format"

Do not rely on training memory for HA YAML syntax — always verify via Context7 first.

---

## Skill Update Workflow

If you keep a local working copy of this skill (e.g. under
`~/.agents/skills/ha-direct-access/`) separate from this repo checkout,
update the local copy at the **end of any HA work session** with anything
new discovered — that's what gets auto-loaded at the start of the next
session.

**When syncing changes back to this repo, never copy your local copy's
`.secrets/` folder or any file containing real host/token/credential
values into the tracked tree.** Only sync the structural/procedural
content (SSH patterns, QA steps, reload logic, etc.) — keep entity
references and connection details in the local, gitignored copy or in
`.secrets/`.

---

## Reference File

A quick-reference summary can also live in your project's `AGENTS.md` root
file. It covers connection details, access methods, integrations, and
Context7 usage. Agents that support `AGENTS.md` will read it automatically
— keep the same secrets-separation rule in mind there too.

---

## Notes

- **Linux host** — key-based SSH via `ssh haos` alias (or `~/.ssh/haos_access` directly); paramiko is available inside the ha-mcp venv (`~/.local/share/uv/tools/ha-mcp/bin/python3`)
- `requests` may not be available on system Python — always use `urllib.request`
- If HA runs in a VM (e.g. under KVM/libvirt) on a separate network segment from
  your LAN devices, some `command_line`/network-based sensors may be unreachable
  from the VM depending on routing — record your own topology in `.secrets/connection.md`
  or a local notes file. Do NOT treat `unknown` as a YAML/entity bug without first
  checking network reachability from the HA host/VM.
- Z2M friendly names are case-sensitive; ampersands must be exact (e.g. `Living Room Fan & Light Switch`)
- VZM31-SN `duration: 255` effects persist until cleared — always send `clear_effect` after testing
- ha-mcp MCP server is already configured in Claude Code at `~/.local/bin/ha-mcp`
- WebSocket supervisor API available via `ws://{{HA_IP}}:8123/api/websocket`
- **A Fedora host reboot cold-boots the HAOS VM, not a graceful HA restart.** Distinguish
  the two: an HA-only restart (`homeassistant.restart` or `ha_restart`) leaves the VM
  `running` the whole time (`sudo virsh domstate homeassistant` stays `running`); a host
  reboot shows up as `op=start reason=booted` in the host's libvirt audit log
  (`journalctl` on the Fedora host, not `haos`) and a fresh kernel boot in
  `ssh haos 'journalctl -b 0'`. Use `journalctl --list-boots` **on the Fedora host** to see
  host reboot history when something looks HA-restart-related but the timing feels off — do
  this before assuming it's an HA/integration bug. `libvirt-guests.service` is enabled
  (2026-08-25) so *graceful* host reboots now resume the VM instead of cold-booting it, but
  hard power loss/manual resets still cold-boot regardless.
- **A restart/reload can make a `button.*` entity's state change look like a real press —
  check `context.user_id`/`context.parent_id` before treating it as one.** A genuine press
  (via UI, service call, or automation) always has a populated context; a state reset from
  an integration reload has `user_id: null, parent_id: null`. Log any such false-positive
  incidents you catch in your own local changelog/notes so future sessions don't rediscover it.
- **Before assuming a device's "missing" capability is a bug in a custom integration,
  check the raw API data first.** `ha_get_integration(entry_id=..., include_diagnostics=True,
  device_id=...)` returns the vendor API's actual capability dict for a device — if a key
  the integration's code references (e.g. a switch type) is absent there, the vendor
  genuinely doesn't expose it for that model, and patching the integration to force-create
  the entity will just crash on the next state read.
