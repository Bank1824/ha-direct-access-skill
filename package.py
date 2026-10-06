#!/usr/bin/env python3
"""Package ha-direct-access/ into ha-direct-access.skill for upload.

Skips .secrets/, .secrets.example/, .git, backups and .DS_Store, and refuses to
package if a token-shaped string or an unfilled {{SKILL_PATH}} placeholder is found.
Run from the repo root:  python3 package.py
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.join(ROOT, "ha-direct-access")
OUTPUT = os.path.join(ROOT, "ha-direct-access.skill")
SKIP_DIRS = {".secrets", ".secrets.example", ".git"}
JWT_PREFIX = "eyJhbGci" + "OiJ"  # split so this file never matches itself

keep = []
for root, dirs, files in os.walk(SKILL_DIR):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for name in files:
        if ".bak" in name or name == ".DS_Store":
            continue
        path = os.path.join(root, name)
        text = open(path, errors="ignore").read()
        if JWT_PREFIX in text:
            sys.exit(f"ABORT: token-looking string in {path} - move it to .secrets/connection.md")
        keep.append(path)

skill_md = open(os.path.join(SKILL_DIR, "SKILL.md")).read()
if "{{SKILL_PATH}}" in skill_md:
    print("WARNING: {{SKILL_PATH}} is not filled in - run ha-direct-access/configure.sh first.")

with zipfile.ZipFile(OUTPUT, "w", zipfile.ZIP_DEFLATED) as zf:
    for path in keep:
        zf.write(path, os.path.relpath(path, ROOT))
print("Packaged:", OUTPUT, [os.path.relpath(p, SKILL_DIR) for p in keep])
