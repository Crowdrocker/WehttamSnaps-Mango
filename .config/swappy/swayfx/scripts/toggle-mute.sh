#!/usr/bin/env bash
# toggle-mute.sh — Mute/unmute with adaptive J.A.R.V.I.S. or iDroid feedback

SOUND_SYSTEM="/usr/local/bin/sound-system"
FLAG="$HOME/.cache/wehttamsnaps/gaming-mode.active"

# Toggle mute
pactl set-sink-mute @DEFAULT_SINK@ toggle

# Check new mute state
if pactl get-sink-mute @DEFAULT_SINK@ | grep -q "yes"; then
    $SOUND_SYSTEM audio-mute
else
    $SOUND_SYSTEM audio-unmute
fi
