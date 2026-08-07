#!/usr/bin/env bash
# launch-gamescope.sh — Gamescope launcher optimized for RX 580 @ 1080p

SOUND_SYSTEM="/usr/local/bin/sound-system"

$SOUND_SYSTEM steam-launch

# Gamescope: native 1080p, 60fps cap, Wayland backend, MangoHud overlay
# --adaptive-sync  → VRR/FreeSync if your monitor supports it
# --mangoapp       → MangoHud embedded overlay
exec gamescope \
    -w 1920 -h 1080 \
    -r 60 \
    --backend wayland \
    --adaptive-sync \
    --mangoapp \
    -- steam -gamepadui
