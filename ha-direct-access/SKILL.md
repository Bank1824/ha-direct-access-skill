---
name: ha-direct-access
description: >
  Direct access to your Home Assistant instance via Desktop Commander.
  Use this skill whenever making any change to Home Assistant — editing config files,
  writing automations, running CLI commands, calling the REST API, or performing QA checks.
  This skill is required for ALL Jamrock HA work. Always read it before touching anything
  in HA, including simple tasks like reloading automations or checking entity states.
---

# Home Assistant Direct Access — Jamrock

## Connection Details

| Parameter | Value |
|-----------|-------|
| Host | {{HA_IP}} |
| SSH Port | 22 |
| SSH User | root |
| SSH Password | {{SSH_PASSWORD}} |
| HA Web UI | http://{{HA_IP}}:8123 |
| Long-lived Token | {{HA_TOKEN}} |

---

## SSH Access via Paramiko

`sshpass` is not available on the Mac. Use Python `paramiko` instead — it is installed.

### Standard SSH command pattern

\`\`\`python
python3 -c "
import paramiko
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('{{HA_IP}}', port=22, username='root', password='{{SSH_PASSWORD}}')
stdin, stdout, stderr = client.exec_command('YOUR COMMAND HERE')
print(stdout.read().decode())
client.close()
"
\`\`\`

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
client.connect('{{HA_IP}}', port=22, username='root', password='{{SSH_PASSWORD}}')
stdin, stdout, stderr = client.exec_command('ha core check 2>&1')
print('Core check:', stdout.read().decode().strip())
client.close()
"
\`\`\`

Expected: `Command completed successfully.`

For visual confirmation ask Ore to screenshot Settings → Repairs in the HA UI.

---

## Entity Reference

> Fill this section in with your own entity IDs as you discover them during sessions.
> This eliminates repeated SSH state queries and keeps sessions fast.
> Ask Claude to update this section at the end of any HA session.

### Structure to follow

```
### Lights & Switches
| Entity | Device | Location |
|--------|--------|----------|
| `light.living_room` | Hue bulb | Living Room |

### Fans
| Entity | Device | Location |
|--------|--------|----------|
| `fan.living_room_fan` | Smart fan | Living Room |

### Temperature Sensors
| Entity | Location |
|--------|----------|
| `sensor.downstairs_temperature` | Thermostat |

### Locks & Doors
| Entity | Device |
|--------|--------|
| `lock.front_door` | Smart lock |
| `binary_sensor.front_door` | Door contact sensor |
| `binary_sensor.doorbell_button` | Doorbell press |

### Alarm
| Entity | States |
|--------|--------|
| `alarm_control_panel.alarmo` | disarmed, arming, armed_home, armed_away, armed_night, pending, triggered |

### Z2M Device Friendly Names (MQTT topics)
| Friendly Name | Device | Notes |
|---------------|--------|-------|
| `Your Device Name` | Device type | Case-sensitive, special chars matter |
```

MQTT topic format: `zigbee2mqtt/FRIENDLY_NAME/set`

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

### Full HA restart (confirm with Ore first — 60s downtime)
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
Aysha's Apple Home stays responsive during restart.

### Safe file editing — three methods

**Method 1 — Append via SFTP (preferred for new automations/scripts)**
Heredoc quoting breaks on YAML special characters. Always use SFTP:
```python
sftp = client.open_sftp()
with sftp.open('/homeassistant/automations.yaml', 'a') as f:
    f.write(yaml_block)
sftp.close()
```

**Method 2 — Delete lines by number**
```python
# Confirm line numbers first
stdin, stdout, stderr = client.exec_command('grep -n "target" /homeassistant/automations.yaml')
print(stdout.read().decode())
# Delete the range
client.exec_command('sed -i "START,ENDd" /homeassistant/automations.yaml')
```

**Method 3 — String replace via SFTP (safest — handles quotes, slashes, ampersands)**
```python
sftp = client.open_sftp()
with sftp.open('/homeassistant/automations.yaml', 'r') as f:
    content = f.read().decode()
content = content.replace('old_string', 'new_string', 1)
with sftp.open('/homeassistant/automations.yaml', 'w') as f:
    f.write(content)
sftp.close()
```
Always verify match count first: `grep -c "exact_string" /homeassistant/automations.yaml`

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

This skill lives at the path where you cloned the repo, e.g. `~/path/to/ha-direct-access-skill/ha-direct-access/SKILL.md`

At the **end of any HA work session**, update this file with new patterns, gotchas, or entity IDs discovered during the session. Then repackage (adjust `skill_dir` to your actual clone path):

```python
python3 -c "
import zipfile, os
skill_dir = os.path.expanduser('~/path/to/ha-direct-access-skill/ha-direct-access')
output = os.path.join(os.path.dirname(skill_dir), 'ha-direct-access.skill')
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(skill_dir):
        for file in files:
            filepath = os.path.join(root, file)
            arcname = os.path.relpath(filepath, os.path.dirname(skill_dir))
            zf.write(filepath, arcname)
print('Packaged:', output)
"
```

At the **start of any HA work session**, read this file first:
```python
# Use Desktop Commander read_file on ~/path/to/ha-direct-access-skill/ha-direct-access/SKILL.md
```

---

## Notes

- `sshpass` is NOT installed on the Mac — always use paramiko
- `requests` may not be available — always use `urllib.request`
- Z2M friendly names are case-sensitive; ampersands must be exact (`Living Room Fan & Light Switch`)
- VZM31-SN `duration: 255` effects persist until cleared — always send `clear_effect` after testing
- SSH add-on may need restart if connections refused (password not saved in add-on config)
- The Mac home path has a trailing dot: `/Users/truestorey./` — use this for all Desktop Commander file writes
