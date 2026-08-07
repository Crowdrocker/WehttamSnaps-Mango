#!/usr/bin/env bash
# workspace-watcher.sh — Watches workspace changes and updates sound mode state
# Runs in background, started by 07-workspaces.conf

STATE_DIR="$HOME/.cache/wehttamsnaps"
WORKSPACE_FILE="$STATE_DIR/current-workspace.state"
SOUND_SYSTEM="/usr/local/bin/sound-system"

mkdir -p "$STATE_DIR"

# Gaming workspaces → iDroid auto-activates
GAMING_WORKSPACES=(3)
STREAMING_WORKSPACES=(4)

swaymsg -t subscribe '["workspace"]' | while read -r event; do
    # Get current workspace number
    WS=$(swaymsg -t get_workspaces | python3 -c \
        "import sys,json; ws=[w for w in json.load(sys.stdin) if w['focused']]; print(ws[0]['num'] if ws else 1)" \
        2>/dev/null || echo "1")

    echo "$WS" > "$WORKSPACE_FILE"

    # Trigger streaming sound when entering WS4
    if [[ "$WS" == "4" ]]; then
        $SOUND_SYSTEM streaming &
    fi
done
