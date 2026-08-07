#!/bin/sh
# ws-switch.sh — focus a workspace and play the sound-system chime
# Usage: ws-switch.sh <workspace-number>
# Place at: ~/.config/wehttamsnaps/scripts/ws-switch.sh
# Make executable: chmod +x ~/.config/wehttamsnaps/scripts/ws-switch.sh

/usr/local/bin/sound-system workspace "$1"
niri msg action focus-workspace "$1"
