# Connection Secrets (local only — never commit the real `.secrets/` folder)

Copy this whole `.secrets.example/` directory to `.secrets/` (sibling
directory, same level) and fill in your own instance's values.
`.secrets/` is gitignored; `SKILL.md` reads from it at the start of any HA
session instead of hardcoding these values inline.

| Parameter | Value |
|-----------|-------|
| Host | {{HA_IP}} |
| SSH Port | 22 |
| SSH User | root |
| SSH Key | `~/.ssh/haos_access` |
| SSH Alias | `ssh haos` (via `~/.ssh/config`) |
| HA Web UI | http://{{HA_IP}}:8123 |
| Long-lived Token | {{HA_TOKEN}} |
