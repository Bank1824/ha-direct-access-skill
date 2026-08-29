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

## HomeKit-Friendly Fan Template (Inovelli VZM31-SN + Canopy)

The VZM31-SN dimmer in fan mode (paired with the Blue Fan/Light Canopy Module over Z2M) exposes a fan entity with `preset_modes`. HA's HomeKit Bridge renders any fan with `preset_modes` as an expanded tile that hides tap-to-toggle — the fan can only be turned off by dragging the slider to 0. The fix is a percentage-only template fan that wraps the canopy. HomeKit treats it as a simple fan tile: tap toggles on/off (resuming the last speed), long-press opens the slider for speed. Mirrors the Lutron Aurora UX. See HA core issue [#105179](https://github.com/home-assistant/core/issues/105179) for the upstream cause.

**Breeze / smart mode:** the canopy's wind-pattern mode is a Z2M `preset_mode`, so it cannot live on the fan tile without re-breaking tap-to-toggle. The pattern below exposes it as a separate HomeKit **switch** tile per fan (Step 3b). Turning the switch on enters the pattern; turning it off returns the fan to its last steady speed. The Z2M preset name varies across firmware/converter versions — common values are `smart`, `breeze`, `Breeze`, `breeze_1`. **Always discover the actual name from the entity's `preset_modes` attribute before writing the YAML** — see the query in Step 3b. The switch is named "Fan Breeze" in this skill regardless of the underlying preset name; rename if `smart` makes more sense in your home.

### Step 1 — Confirm canopy fan entity IDs

Before applying anything, confirm the actual canopy fan `entity_id`s — names below are illustrative. Use the GET states pattern from earlier in this skill:

```python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/states',
    headers={'Authorization': f'Bearer {TOKEN}'}
)
states = json.loads(urllib.request.urlopen(req).read())
[print(s['entity_id'], '->', s['state']) for s in states if s['entity_id'].startswith('fan.')]
"
```

Replace `fan.living_room_fan` / `fan.master_bedroom_fan` in the YAML below with whatever you find.

### Step 2 — Helpers (configuration.yaml)

```yaml
input_number:
  living_room_fan_last_speed:
    name: Living Room Fan Last Speed
    min: 33
    max: 100
    step: 33
    initial: 66
    icon: mdi:fan
  master_bedroom_fan_last_speed:
    name: Master Bedroom Fan Last Speed
    min: 33
    max: 100
    step: 33
    initial: 66
    icon: mdi:fan
```

### Step 3 — Template fans (configuration.yaml)

Deliberately omits `preset_modes` — that is what restores tap-to-toggle in HomeKit. `speed_count: 3` snaps the slider to 33/66/100 (low/med/high), matching the canopy module's discrete speeds.

```yaml
template:
  - fan:
      - name: "Living Room Fan"
        unique_id: living_room_fan_hk
        state: >
          {{ states('fan.living_room_fan') not in
             ['off', 'unavailable', 'unknown'] }}
        percentage: >
          {% set p = state_attr('fan.living_room_fan', 'percentage') | int(0) %}
          {% if p > 0 %}{{ p }}
          {% else %}{{ states('input_number.living_room_fan_last_speed') | int(66) }}
          {% endif %}
        speed_count: 3
        turn_on:
          - service: fan.set_percentage
            target:
              entity_id: fan.living_room_fan
            data:
              percentage: >
                {{ states('input_number.living_room_fan_last_speed')
                   | int(66) }}
        turn_off:
          - service: fan.turn_off
            target:
              entity_id: fan.living_room_fan
        set_percentage:
          - service: fan.set_percentage
            target:
              entity_id: fan.living_room_fan
            data:
              percentage: "{{ percentage }}"
          - if: "{{ percentage | int(0) > 0 }}"
            then:
              - service: input_number.set_value
                target:
                  entity_id: input_number.living_room_fan_last_speed
                data:
                  value: "{{ percentage }}"
      - name: "Master Bedroom Fan"
        unique_id: master_bedroom_fan_hk
        state: >
          {{ states('fan.master_bedroom_fan') not in
             ['off', 'unavailable', 'unknown'] }}
        percentage: >
          {% set p = state_attr('fan.master_bedroom_fan', 'percentage') | int(0) %}
          {% if p > 0 %}{{ p }}
          {% else %}{{ states('input_number.master_bedroom_fan_last_speed') | int(66) }}
          {% endif %}
        speed_count: 3
        turn_on:
          - service: fan.set_percentage
            target:
              entity_id: fan.master_bedroom_fan
            data:
              percentage: >
                {{ states('input_number.master_bedroom_fan_last_speed')
                   | int(66) }}
        turn_off:
          - service: fan.turn_off
            target:
              entity_id: fan.master_bedroom_fan
        set_percentage:
          - service: fan.set_percentage
            target:
              entity_id: fan.master_bedroom_fan
            data:
              percentage: "{{ percentage }}"
          - if: "{{ percentage | int(0) > 0 }}"
            then:
              - service: input_number.set_value
                target:
                  entity_id: input_number.master_bedroom_fan_last_speed
                data:
                  value: "{{ percentage }}"
```

### Step 3b — Breeze / smart switches (configuration.yaml)

One template switch per fan. `state` reflects whether the canopy is currently in the wind-pattern preset. `turn_on` invokes the canopy's `set_preset_mode`; `turn_off` exits the preset by setting a steady percentage equal to the remembered last speed.

**Before writing this block, discover the actual preset name and substitute it everywhere `breeze` appears below.** Run:

```python
python3 -c "
import urllib.request, json
TOKEN = '{{HA_TOKEN}}'
req = urllib.request.Request(
    'http://{{HA_IP}}:8123/api/states/fan.living_room_fan',
    headers={'Authorization': f'Bearer {TOKEN}'}
)
print(json.loads(urllib.request.urlopen(req).read())['attributes'].get('preset_modes'))
"
```

Pick the wind-pattern entry from that list (commonly `smart`, `breeze`, `Breeze`, or `breeze_1`) and use it as the `preset_mode:` value AND in the `state:` comparison. The two must match exactly, including case.

```yaml
template:
  - switch:
      - name: "Living Room Fan Breeze"
        unique_id: living_room_fan_breeze
        icon: mdi:weather-windy
        state: >
          {{ state_attr('fan.living_room_fan', 'preset_mode') == 'breeze' }}
        turn_on:
          - service: fan.set_preset_mode
            target:
              entity_id: fan.living_room_fan
            data:
              preset_mode: breeze
        turn_off:
          - service: fan.set_percentage
            target:
              entity_id: fan.living_room_fan
            data:
              percentage: >
                {{ states('input_number.living_room_fan_last_speed') | int(66) }}
      - name: "Master Bedroom Fan Breeze"
        unique_id: master_bedroom_fan_breeze
        icon: mdi:weather-windy
        state: >
          {{ state_attr('fan.master_bedroom_fan', 'preset_mode') == 'breeze' }}
        turn_on:
          - service: fan.set_preset_mode
            target:
              entity_id: fan.master_bedroom_fan
            data:
              preset_mode: breeze
        turn_off:
          - service: fan.set_percentage
            target:
              entity_id: fan.master_bedroom_fan
            data:
              percentage: >
                {{ states('input_number.master_bedroom_fan_last_speed') | int(66) }}
```

### Step 4 — HomeKit filter (homekitbridge.yaml)

Hide the raw canopy fan from HomeKit; expose only the template fan and the breeze switch. Otherwise Apple Home will show duplicate tiles.

```yaml
filter:
  exclude_entities:
    - fan.living_room_fan
    - fan.master_bedroom_fan
  include_entities:
    - fan.living_room_fan_hk
    - fan.master_bedroom_fan_hk
    - switch.living_room_fan_breeze
    - switch.master_bedroom_fan_breeze
```

### Step 5 — Apply

Reload in this order — no restart needed:

| Service | Why |
|---|---|
| `input_number/reload` | Picks up the new helpers |
| `template/reload` | Picks up the new template fans |
| `homekit/reload` | Re-publishes the HomeKit Bridge with the filter change |

Then run the standard QA — config check + `ha core check` — before closing the task.

### Step 6 — Verify in HomeKit

Confirm on the iPhone:

- Tap the fan tile → toggles on (at last speed) / off
- Long-press the fan tile → slider appears, speeds snap to low/med/high
- Toggling off then back on resumes the last speed (not 100%)
- Tap the **Fan Breeze** switch tile → fan enters breeze pattern
- Tap the breeze switch off → fan returns to the last steady speed
- Tapping the fan tile or moving the slider while breeze is active also exits breeze (because it sends a steady percentage to the canopy)

If tap still doesn't toggle, check that the template fan does **not** have `preset_modes` in its definition — that is the single most common regression.

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
