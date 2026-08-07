#!/bin/bash

BORDER_SIZE="$1"
CONFIG_FILE="$HOME/.config/hypr/hyprland/general.lua"

if [ -z "$BORDER_SIZE" ]; then
    echo "Usage: $0 <border_size>"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "hl.config({" > "$CONFIG_FILE"
    echo "    general = {" >> "$CONFIG_FILE"
    echo "        border_size = $BORDER_SIZE," >> "$CONFIG_FILE"
    echo "    }," >> "$CONFIG_FILE"
    echo "})" >> "$CONFIG_FILE"
    hyprctl reload >/dev/null 2>&1 || true
    echo "Created $CONFIG_FILE with border_size = ${BORDER_SIZE}"
    exit 0
fi

python3 - <<PY
import re, os
path = os.path.expanduser('$CONFIG_FILE')
size = '$BORDER_SIZE'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()
pat = re.compile(r'^\s*border_size\s*=')
replaced = False
for i, line in enumerate(lines):
    if pat.match(line.strip()):
        lines[i] = re.sub(r'(\s*border_size\s*=\s*).*', r'\1' + size + ',', line)
        replaced = True
        break
if not replaced:
    for i, line in enumerate(lines):
        if line.strip().startswith('general') and '{' in line:
            lines.insert(i + 1, '    border_size = ' + size + ',')
            break
with open(path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
PY

hyprctl reload >/dev/null 2>&1 || true

echo "Updated Hyprland border size to ${BORDER_SIZE}px"