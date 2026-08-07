#!/usr/bin/env bash
# temp-monitor.sh — CPU/GPU temperature monitor with J.A.R.V.I.S. warnings
# Runs as background daemon, checks every 60 seconds

SOUND_SYSTEM="/usr/local/bin/sound-system"
CPU_THRESHOLD=80  # °C
GPU_THRESHOLD=85  # °C (RX 580 runs warmer)
CHECK_INTERVAL=60 # seconds

warned_cpu=false
warned_gpu=false

while true; do
    # ── CPU Temperature (lm_sensors) ─────────────────────────────────
    if command -v sensors &>/dev/null; then
        CPU_TEMP=$(sensors 2>/dev/null | awk '/Package id 0:/{gsub(/[+°C]/,"",$4); print int($4)}')
        if [[ -n "$CPU_TEMP" ]] && (( CPU_TEMP > CPU_THRESHOLD )); then
            if [[ "$warned_cpu" == false ]]; then
                $SOUND_SYSTEM warning &
                notify-send -u critical "J.A.R.V.I.S. Warning" \
                    "CPU temperature critical: ${CPU_TEMP}°C (threshold: ${CPU_THRESHOLD}°C)" \
                    -i dialog-warning
                warned_cpu=true
            fi
        else
            warned_cpu=false
        fi
    fi

    # ── AMD RX 580 GPU Temperature ────────────────────────────────────
    GPU_HWMON=$(ls /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
    if [[ -n "$GPU_HWMON" ]]; then
        GPU_TEMP=$(( $(cat "$GPU_HWMON") / 1000 ))
        if (( GPU_TEMP > GPU_THRESHOLD )); then
            if [[ "$warned_gpu" == false ]]; then
                $SOUND_SYSTEM warning &
                notify-send -u critical "J.A.R.V.I.S. Warning" \
                    "GPU temperature critical: ${GPU_TEMP}°C (threshold: ${GPU_THRESHOLD}°C)" \
                    -i dialog-warning
                warned_gpu=true
            fi
        else
            warned_gpu=false
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
