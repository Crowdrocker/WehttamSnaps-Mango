#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  toggle-gamemode.sh — Gaming Mode Toggle (Noctalia Edition)     ║
# ║  Disables SwayFX AND Noctalia blur/effects for max FPS          ║
# ╚══════════════════════════════════════════════════════════════════╝

SOUND_SYSTEM="/usr/local/bin/sound-system"
FLAG="$HOME/.cache/wehttamsnaps/gaming-mode.active"

mkdir -p "$HOME/.cache/wehttamsnaps"

if [[ -f "$FLAG" ]]; then
    # ── GAMING MODE OFF ──────────────────────────────────────────────
    rm -f "$FLAG"

    $SOUND_SYSTEM gamemode-off

    # Re-enable SwayFX visual effects
    swaymsg corner_radius 8
    swaymsg blur enable
    swaymsg shadows enable
    swaymsg default_dim_inactive 0.15

    # Re-enable Noctalia blur via IPC
    qs ipc call noctalia-shell setBlur true 2>/dev/null || true

    # Reset CPU governor
    echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true

    notify-send "J.A.R.V.I.S." "Normal operation restored. Welcome back, Matthew." \
        -i audio-speakers -t 3000

else
    # ── GAMING MODE ON ───────────────────────────────────────────────
    touch "$FLAG"

    $SOUND_SYSTEM gamemode-on

    # Disable SwayFX visual effects
    swaymsg corner_radius 0
    swaymsg blur disable
    swaymsg shadows disable
    swaymsg default_dim_inactive 0

    # Disable Noctalia blur via IPC
    qs ipc call noctalia-shell setBlur false 2>/dev/null || true

    # Set CPU to performance governor
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true

    notify-send "iDroid" "Combat systems online. Gaming mode activated." \
        -i applications-games -t 3000
fi
