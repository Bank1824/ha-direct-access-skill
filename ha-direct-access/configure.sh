#!/bin/bash
# configure.sh — Write your HA connection details into a local, gitignored
# .secrets/connection.md instead of into the shared SKILL.md. SKILL.md keeps
# {{HA_IP}}/{{HA_TOKEN}} placeholders and an absolute path to this file so
# Claude (via Desktop Commander) reads real values from disk at runtime,
# never from the packaged .skill artifact.

set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"
SECRETS_DIR="$SKILL_DIR/.secrets"
SECRETS_FILE="$SECRETS_DIR/connection.md"
EXAMPLE_FILE="$SKILL_DIR/.secrets.example/connection.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "Error: SKILL.md not found at $SKILL_FILE"
  exit 1
fi

echo ""
echo "HA Direct Access Skill — Configuration"
echo "======================================="
echo "Writes your HA connection details into $SECRETS_FILE"
echo "(gitignored, local only — never committed, never zipped into the .skill artifact)."
echo ""

read -p "HA IP address (e.g. 192.168.1.2): " HA_IP
read -s -p "SSH password, if using password auth (leave blank for key-based): " SSH_PASSWORD
echo ""
read -s -p "Long-lived API token (hidden): " HA_TOKEN
echo ""

echo ""
echo "  HA IP:        $HA_IP"
echo "  SSH Password: ${SSH_PASSWORD:+[set]}${SSH_PASSWORD:-[not set — using key-based auth]}"
echo "  API Token:    [set]"
echo "  Secrets file: $SECRETS_FILE"
echo ""
read -p "Confirm? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

mkdir -p "$SECRETS_DIR"
cp "$EXAMPLE_FILE" "$SECRETS_FILE"

sed -i.bak \
  -e "s|{{HA_IP}}|$HA_IP|g" \
  -e "s|{{HA_TOKEN}}|$HA_TOKEN|g" \
  "$SECRETS_FILE"

if [ -n "$SSH_PASSWORD" ]; then
  printf '| SSH Password | %s |\n' "$SSH_PASSWORD" >> "$SECRETS_FILE"
fi

rm -f "${SECRETS_FILE}.bak"

# Point SKILL.md's fallback instructions at the absolute path of this
# skill's .secrets directory (used by claude.ai + Desktop Commander, which
# has no relative-path context of its own).
sed -i.bak "s|{{SKILL_PATH}}|$SKILL_DIR|g" "$SKILL_FILE"
rm -f "${SKILL_FILE}.bak"

echo ""
echo "Done. Wrote $SECRETS_FILE and set {{SKILL_PATH}} in SKILL.md."
echo ""
echo "IMPORTANT: $SECRETS_DIR is gitignored — verify it's never committed or"
echo "included when you package/share the .skill file."
echo ""
echo "Next: package and install."
echo ""
echo "  python3 -c \""
echo "  import zipfile, os"
echo "  zf = zipfile.ZipFile('ha-direct-access.skill', 'w', zipfile.ZIP_DEFLATED)"
echo "  skip = {'.secrets', '.secrets.example'}"
echo "  for r, d, files in os.walk('ha-direct-access'):"
echo "      d[:] = [x for x in d if x not in skip]"
echo "      for f in files: zf.write(os.path.join(r, f), os.path.relpath(os.path.join(r, f), '.'))"
echo "  zf.close(); print('Done')"
echo "  \""
echo ""
echo "Then upload ha-direct-access.skill to claude.ai → Settings → Skills."
