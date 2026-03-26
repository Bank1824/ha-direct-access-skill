#!/bin/bash
# configure.sh — Fill in your HA connection details in SKILL.md

set -e

SKILL_FILE="$(cd "$(dirname "$0")" && pwd)/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "Error: SKILL.md not found at $SKILL_FILE"
  exit 1
fi

echo ""
echo "HA Direct Access Skill — Configuration"
echo "======================================="
echo "Writes your HA connection details into SKILL.md on your local machine only."
echo ""

read -p "HA IP address (e.g. 192.168.1.2): " HA_IP
read -s -p "SSH password (hidden): " SSH_PASSWORD
echo ""
read -s -p "Long-lived API token (hidden): " HA_TOKEN
echo ""

SKILL_PATH="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  HA IP:        $HA_IP"
echo "  SSH Password: [set]"
echo "  API Token:    [set]"
echo "  Skill path:   $SKILL_PATH"
echo ""
read -p "Confirm? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

sed -i.bak \
  -e "s|{{HA_IP}}|$HA_IP|g" \
  -e "s|{{SSH_PASSWORD}}|$SSH_PASSWORD|g" \
  -e "s|{{HA_TOKEN}}|$HA_TOKEN|g" \
  -e "s|{{SKILL_PATH}}|$SKILL_PATH|g" \
  "$SKILL_FILE"

rm -f "${SKILL_FILE}.bak"

echo ""
echo "Done. SKILL.md configured."
echo ""
echo "Next: package and install."
echo ""
echo "  python3 -c \""
echo "  import zipfile, os"
echo "  zf = zipfile.ZipFile('ha-direct-access.skill', 'w', zipfile.ZIP_DEFLATED)"
echo "  [zf.write(os.path.join(r,f), os.path.relpath(os.path.join(r,f), '.')) for r,d,files in os.walk('ha-direct-access') for f in files]"
echo "  zf.close(); print('Done')"
echo "  \""
echo ""
echo "Then upload ha-direct-access.skill to claude.ai → Settings → Skills."
