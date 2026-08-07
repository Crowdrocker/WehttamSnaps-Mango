#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   WehttamSnaps — Gaming Mode Toggle                             ║
# ║   Author : Matthew (GitHub: Crowdrocker)                        ║
# ║   Keybind : Super+G  →  niri config calls sound-system          ║
# ║             which calls this script                             ║
# ║                                                                  ║
# ║   What this does ON:                                            ║
# ║     • CPU governor  → performance (all 8 cores)                 ║
# ║     • Niri animations → disabled via niri msg                   ║
# ║     • GameMode daemon → started                                 ║
# ║     • Gamescope → optional (pass --gamescope flag)              ║
# ║     • iDroid sounds → activated                                 ║
# ║     • Status bar → updated                                      ║
# ║     • Notify → iDroid-style alert                               ║
# ║                                                                  ║
# ║   What this does OFF:                                           ║
# ║     • CPU governor  → schedutil (balanced)                      ║
# ║     • Niri animations → re-enabled                              ║
# ║     • GameMode daemon → stopped                                 ║
# ║     • JARVIS sounds → re-activated                              ║
# ║     • Status bar → updated                                      ║
# ║     • Notify → JARVIS confirmation                              ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Usage:
#   toggle-gamemode.sh              toggle on/off
#   toggle-gamemode.sh on           force on
#   toggle-gamemode.sh off          force off
#   toggle-gamemode.sh status       print current state
#   toggle-gamemode.sh gamescope    toggle + launch gamescope
#   toggle-gamemode.sh steam        toggle + launch steam
#   toggle-gamemode.sh --help       show this help

set -uo pipefail

# ══════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════

FLAG="$HOME/.cache/wehttamsnaps/gaming-mode.active"
STATE_DIR="$HOME/.cache/wehttamsnaps"
LOG_FILE="$STATE_DIR/gaming-mode.log"
SOUND="/usr/local/bin/sound-system"
NIRI_CFG="$HOME/.config/niri/config.kdl"
NIRI_GAMING_OVERLAY="$HOME/.config/niri/gaming-mode.kdl"

# RX 580 / i7-4790 specific
CPU_COUNT=8
GPU_CARD=$(ls /sys/class/drm/ | grep -E '^card[0-9]+$' | head -1)
GPU_HWMON=$(ls /sys/class/drm/${GPU_CARD}/device/hwmon/ 2>/dev/null | head -1)

# Gamescope defaults for 1920x1080 @ 60Hz RX 580
GAMESCOPE_ARGS="-w 1920 -h 1080 -r 60 -f --force-grab-cursor"

# ── Colours ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PINK='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════

mkdir -p "$STATE_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo -e "${CYAN}${msg}${NC}"
}

is_on() { [[ -f "$FLAG" ]]; }

get_cpu_governor() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
}

get_cpu_freq_mhz() {
    local freq
    freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
    echo $(( freq / 1000 ))
}

get_gpu_temp() {
    if [[ -n "$GPU_HWMON" ]]; then
        local raw
        raw=$(cat "/sys/class/drm/${GPU_CARD}/device/hwmon/${GPU_HWMON}/temp1_input" 2>/dev/null || echo 0)
        echo $(( raw / 1000 ))
    else
        echo "N/A"
    fi
}

get_ram_free_gb() {
    awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}

notify() {
    local summary="$1"
    local body="$2"
    local urgency="${3:-normal}"
    local icon="${4:-input-gaming}"
    command -v notify-send &>/dev/null && \
        notify-send -u "$urgency" -t 4000 -i "$icon" "$summary" "$body" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════
# CPU GOVERNOR
# ══════════════════════════════════════════════════════════════════

set_cpu_governor() {
    local gov="$1"
    local success=0

    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if echo "$gov" | sudo tee "$cpu" > /dev/null 2>&1; then
            (( success++ )) || true
        fi
    done

    if [[ $success -eq 0 ]]; then
        # Fallback: try cpupower if sudo tee failed
        if command -v cpupower &>/dev/null; then
            sudo cpupower frequency-set -g "$gov" &>/dev/null && success=1
        fi
    fi

    if [[ $success -gt 0 ]]; then
        log "CPU governor → $gov (${success} cores)"
    else
        log "CPU governor change failed — may need sudoers rule"
        log "Run: sudo visudo -f /etc/sudoers.d/wehttamsnaps-gamemode"
    fi
}

# ══════════════════════════════════════════════════════════════════
# NIRI ANIMATIONS
# ══════════════════════════════════════════════════════════════════

disable_niri_animations() {
    # Niri supports hot-reload — write a minimal overlay KDL that
    # sets all animation durations to 0, then reload config.
    # The main config.kdl uses `include` so this file is always loaded.
    cat > "$NIRI_GAMING_OVERLAY" << 'KDL'
// WehttamSnaps — Gaming Mode Animation Override
// Auto-generated by toggle-gamemode.sh — do not edit manually
// Removed on gaming mode OFF

animations {
    workspace-switch {
        spring damping-ratio=1.0 stiffness=9999 epsilon=0.0001
    }
    window-open {
        duration-ms 0
        curve "linear"
    }
    window-close {
        duration-ms 0
        curve "linear"
    }
    window-movement {
        spring damping-ratio=1.0 stiffness=9999 epsilon=0.0001
    }
    window-resize {
        spring damping-ratio=1.0 stiffness=9999 epsilon=0.0001
    }
    horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=9999 epsilon=0.0001
    }
    config-notification-open-close {
        spring damping-ratio=1.0 stiffness=9999 epsilon=0.0001
    }
}
KDL

    # Add include line to config.kdl if not already present
    if ! grep -q "gaming-mode.kdl" "$NIRI_CFG" 2>/dev/null; then
        echo "" >> "$NIRI_CFG"
        echo "// Gaming mode animation override (auto-managed)" >> "$NIRI_CFG"
        echo "include \"$NIRI_GAMING_OVERLAY\"" >> "$NIRI_CFG"
    fi

    # Hot-reload niri config
    niri msg action reload-config 2>/dev/null && \
        log "Niri animations → disabled (hot-reloaded)" || \
        log "Niri reload failed — restart niri to apply"
}

enable_niri_animations() {
    # Remove the overlay file and remove the include line from config
    rm -f "$NIRI_GAMING_OVERLAY"

    # Remove include line from config.kdl
    if [[ -f "$NIRI_CFG" ]]; then
        sed -i '/gaming-mode\.kdl/d' "$NIRI_CFG"
        sed -i '/Gaming mode animation override/d' "$NIRI_CFG"
    fi

    # Hot-reload
    niri msg action reload-config 2>/dev/null && \
        log "Niri animations → restored (hot-reloaded)" || \
        log "Niri reload failed — restart niri to apply"
}

# ══════════════════════════════════════════════════════════════════
# GAMEMODE DAEMON
# ══════════════════════════════════════════════════════════════════

start_gamemode() {
    if command -v gamemoded &>/dev/null; then
        # gamemoded auto-starts when a game requests it via libgamemode
        # but we can also request manually
        gamemoded 2>/dev/null || true
        log "GameMode daemon → started"
    else
        log "gamemoded not found — install: paru -S gamemode"
    fi
}

stop_gamemode() {
    if command -v gamemoded &>/dev/null; then
        gamemoded -r 2>/dev/null || true
        log "GameMode daemon → stopped"
    fi
}

# ══════════════════════════════════════════════════════════════════
# GAMESCOPE
# ══════════════════════════════════════════════════════════════════

launch_gamescope() {
    local inner_cmd="${1:-steam}"

    if ! command -v gamescope &>/dev/null; then
        log "gamescope not found — install: paru -S gamescope"
        notify "gamescope not found" "Install: paru -S gamescope" "critical"
        return 1
    fi

    log "Launching gamescope: $GAMESCOPE_ARGS -- $inner_cmd"
    # shellcheck disable=SC2086
    gamescope $GAMESCOPE_ARGS -- $inner_cmd &
    log "Gamescope PID: $!"
    echo $! > "$STATE_DIR/gamescope.pid"
}

# ══════════════════════════════════════════════════════════════════
# AMD RX 580 TUNING
# ══════════════════════════════════════════════════════════════════

tune_rx580_on() {
    # Set AMD GPU power profile to high performance (if supported)
    local pp_file="/sys/class/drm/${GPU_CARD}/device/power_dpm_force_performance_level"
    if [[ -f "$pp_file" ]]; then
        echo "high" | sudo tee "$pp_file" > /dev/null 2>&1 && \
            log "RX 580 power profile → high" || true
    fi

    # Mesa/RADV env hints written to a file sourced by Steam
    local env_file="$STATE_DIR/gaming-env.sh"
    cat > "$env_file" << 'ENV'
# WehttamSnaps RX 580 Gaming Env — source before launching games
export RADV_PERFTEST=aco
export AMD_VULKAN_ICD=RADV
export MESA_VK_WSI_PRESENT_MODE=mailbox
export DXVK_ASYNC=1
export WINE_FULLSCREEN_FSR=1
export WINE_FULLSCREEN_FSR_STRENGTH=2
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$HOME/.cache/mesa_shader_cache"
export mesa_glthread=true
ENV
    log "RX 580 env hints written → $env_file"
}

tune_rx580_off() {
    local pp_file="/sys/class/drm/${GPU_CARD}/device/power_dpm_force_performance_level"
    if [[ -f "$pp_file" ]]; then
        echo "auto" | sudo tee "$pp_file" > /dev/null 2>&1 && \
            log "RX 580 power profile → auto" || true
    fi
}

# ══════════════════════════════════════════════════════════════════
# STATUS DISPLAY
# ══════════════════════════════════════════════════════════════════

show_status() {
    local mode gov freq gpu_temp ram_free gm_pid

    if is_on; then
        mode="${PINK}${BOLD}iDROID ONLINE — GAMING MODE ACTIVE${NC}"
    else
        mode="${CYAN}J.A.R.V.I.S. ONLINE — NORMAL MODE${NC}"
    fi

    gov=$(get_cpu_governor)
    freq=$(get_cpu_freq_mhz)
    gpu_temp=$(get_gpu_temp)
    ram_free=$(get_ram_free_gb)
    gm_pid=$(pgrep gamemoded 2>/dev/null | head -1 || echo "—")

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   WehttamSnaps Gaming Mode Status            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Mode       : $mode"
    echo -e "  CPU Gov    : ${YELLOW}${gov}${NC}  @ ${freq} MHz"
    echo -e "  GPU Temp   : ${YELLOW}${gpu_temp}°C${NC}  (RX 580)"
    echo -e "  RAM Free   : ${YELLOW}${ram_free} GB${NC}"
    echo -e "  GameMode   : ${YELLOW}PID ${gm_pid}${NC}"
    echo -e "  Flag file  : $(is_on && echo "${GREEN}EXISTS${NC}" || echo "${RED}NOT SET${NC}")"
    echo ""
    echo -e "  Keybind    : ${CYAN}Super+G${NC}  →  toggle"
    echo -e "  Alias      : ${CYAN}gaming${NC}   →  toggle-gamemode.sh"
    echo -e "  Log        : ${CYAN}${LOG_FILE}${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════
# ACTIVATE
# ══════════════════════════════════════════════════════════════════

activate() {
    log "═══ GAMING MODE ACTIVATING ═══"

    # Write flag
    touch "$FLAG"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$FLAG"

    # CPU → performance
    set_cpu_governor "performance"

    # Niri → no animations
    disable_niri_animations

    # GameMode daemon
    start_gamemode

    # RX 580 tuning
    tune_rx580_on

    # iDroid sound system
    [[ -x "$SOUND" ]] && "$SOUND" gaming-toggle 2>/dev/null || true

    # Notification
    local freq gov gpu_temp
    gov=$(get_cpu_governor)
    freq=$(get_cpu_freq_mhz)
    gpu_temp=$(get_gpu_temp)

    notify \
        "iDROID ONLINE" \
        "Combat systems active.\nCPU: ${gov} @ ${freq}MHz\nGPU: ${gpu_temp}°C\nAnimations: disabled" \
        "normal" \
        "input-gaming"

    log "═══ GAMING MODE ACTIVE ═══"

    echo ""
    echo -e "${PINK}${BOLD}  ◆ iDROID ONLINE — COMBAT SYSTEMS ACTIVE${NC}"
    echo -e "${YELLOW}  CPU: ${gov} @ ${freq} MHz  ·  GPU: ${gpu_temp}°C${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════
# DEACTIVATE
# ══════════════════════════════════════════════════════════════════

deactivate() {
    log "═══ GAMING MODE DEACTIVATING ═══"

    # Remove flag
    rm -f "$FLAG"

    # CPU → schedutil (balanced)
    set_cpu_governor "schedutil"

    # Niri → restore animations
    enable_niri_animations

    # Stop GameMode
    stop_gamemode

    # RX 580 → auto
    tune_rx580_off

    # JARVIS sound system
    [[ -x "$SOUND" ]] && "$SOUND" gaming-toggle 2>/dev/null || true

    # Kill gamescope if running from this session
    if [[ -f "$STATE_DIR/gamescope.pid" ]]; then
        local gs_pid
        gs_pid=$(cat "$STATE_DIR/gamescope.pid")
        kill "$gs_pid" 2>/dev/null || true
        rm -f "$STATE_DIR/gamescope.pid"
        log "Gamescope PID $gs_pid → terminated"
    fi

    local gov freq
    gov=$(get_cpu_governor)
    freq=$(get_cpu_freq_mhz)

    notify \
        "J.A.R.V.I.S. ONLINE" \
        "Normal operations resumed.\nCPU: ${gov} @ ${freq}MHz\nAnimations: restored" \
        "normal" \
        "utilities-system-monitor"

    log "═══ NORMAL MODE ACTIVE ═══"

    echo ""
    echo -e "${CYAN}  ◇ J.A.R.V.I.S. ONLINE — NORMAL OPERATIONS${NC}"
    echo -e "${YELLOW}  CPU: ${gov} @ ${freq} MHz${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════════

show_help() {
    cat << EOF

${CYAN}WehttamSnaps Gaming Mode Toggle${NC}

${YELLOW}Usage:${NC}
  toggle-gamemode.sh              Toggle on/off
  toggle-gamemode.sh on           Force activate
  toggle-gamemode.sh off          Force deactivate
  toggle-gamemode.sh status       Show current state
  toggle-gamemode.sh gamescope    Toggle + launch gamescope
  toggle-gamemode.sh steam        Toggle + launch Steam
  toggle-gamemode.sh --help       This help

${YELLOW}What happens ON:${NC}
  • CPU governor    → performance  (all ${CPU_COUNT} cores, i7-4790)
  • Niri animations → disabled     (hot-reload via niri msg)
  • GameMode daemon → started      (CPU/IO priority boost)
  • RX 580 profile  → high         (power_dpm_force_performance_level)
  • Mesa/RADV env   → tuned        (ACO, mailbox, DXVK_ASYNC)
  • Sound system    → iDroid       (combat sounds active)
  • Notify          → iDroid alert

${YELLOW}What happens OFF:${NC}
  • CPU governor    → schedutil    (balanced)
  • Niri animations → restored     (hot-reload)
  • GameMode daemon → stopped
  • RX 580 profile  → auto
  • Gamescope       → killed       (if launched by this script)
  • Sound system    → J.A.R.V.I.S.
  • Notify          → JARVIS confirmation

${YELLOW}Sudoers rule (one-time setup):${NC}
  Run install.sh sudoers  — or manually:
  echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" | sudo tee /etc/sudoers.d/wehttamsnaps-gamemode
  sudo chmod 440 /etc/sudoers.d/wehttamsnaps-gamemode

${YELLOW}Niri keybind:${NC}
  Super+G → spawn "/usr/local/bin/sound-system" "gaming-toggle"
  (sound-system calls this script internally)

${YELLOW}Log:${NC} ${LOG_FILE}

EOF
}

# ══════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════

case "${1:-toggle}" in

    toggle)
        if is_on; then
            deactivate
        else
            activate
        fi
        ;;

    on|activate|enable)
        if is_on; then
            echo -e "${YELLOW}Gaming mode already active.${NC}"
            show_status
        else
            activate
        fi
        ;;

    off|deactivate|disable)
        if is_on; then
            deactivate
        else
            echo -e "${CYAN}Gaming mode already off.${NC}"
            show_status
        fi
        ;;

    status|stat|s)
        show_status
        ;;

    gamescope|gs)
        # Toggle gaming mode then launch gamescope wrapping steam
        if ! is_on; then activate; fi
        launch_gamescope "steam"
        ;;

    steam)
        # Toggle gaming mode then launch Steam normally
        if ! is_on; then activate; fi
        log "Launching Steam..."
        [[ -x "$SOUND" ]] && "$SOUND" steam-launch 2>/dev/null || true
        steam &
        ;;

    --help|-h|help)
        show_help
        ;;

    *)
        echo -e "${RED}Unknown argument: $1${NC}"
        show_help
        exit 1
        ;;

esac
