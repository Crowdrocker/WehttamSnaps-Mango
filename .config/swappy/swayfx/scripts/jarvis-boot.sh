#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  jarvis-boot.sh — J.A.R.V.I.S. Boot Sequence                   ║
# ║  Plays time-aware greeting on SwayFX login                      ║
# ╚══════════════════════════════════════════════════════════════════╝

SOUND_SYSTEM="/usr/local/bin/sound-system"

# Wait for audio to be ready
sleep 2

# Play startup chime first
$SOUND_SYSTEM startup

# Wait for startup to finish, then play time-of-day greeting
sleep 3
HOUR=$(date +%H)

if (( HOUR >= 5 && HOUR < 12 )); then
    $SOUND_SYSTEM morning
elif (( HOUR >= 12 && HOUR < 17 )); then
    $SOUND_SYSTEM afternoon
else
    $SOUND_SYSTEM evening
fi
