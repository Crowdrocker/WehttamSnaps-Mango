#!/usr/bin/env bash
set -euo pipefail

# Uncomment to re-enable debug logging:
# DEBUG_LOG="$HOME/.config/quickshell/matugen-debug.log"
# exec >> "$DEBUG_LOG" 2>&1
# echo "=== $(date) ==="

if [ $# -lt 3 ]; then
    echo "Usage: $0 STATE_DIR SHELL_DIR --run" >&2
    exit 1
fi

STATE_DIR="$1"
SHELL_DIR="$2"

if [ ! -d "$STATE_DIR" ]; then
    echo "Error: STATE_DIR '$STATE_DIR' does not exist" >&2
    exit 1
fi

if [ ! -d "$SHELL_DIR" ]; then
    echo "Error: SHELL_DIR '$SHELL_DIR' does not exist" >&2
    exit 1
fi

shift 2

if [[ "${1:-}" != "--run" ]]; then
    echo "usage: $0 STATE_DIR SHELL_DIR --run" >&2
    exit 1
fi

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
BUILT_KEY="$STATE_DIR/matugen.key"
LAST_JSON="$STATE_DIR/last.json"
LOCK="$STATE_DIR/matugen-worker.lock"

exec 9>"$LOCK"
flock 9

# ── Helpers ───────────────────────────────────────────────────────────────────

read_desired() {
    [[ ! -f "$DESIRED_JSON" ]] && { echo "no desired state" >&2; exit 0; }
    cat "$DESIRED_JSON"
}

key_of() {
    local json="$1"
    local kind value mode icon matugen_type
    kind=$(echo "$json"         | jq -r '.kind          // ""')
    value=$(echo "$json"        | jq -r '.value         // ""')
    mode=$(echo "$json"         | jq -r '.mode          // ""')
    icon=$(echo "$json"         | jq -r '.iconTheme     // "System Default"')
    matugen_type=$(echo "$json" | jq -r '.matugenType   // "scheme-tonal-spot"')
    [[ -z "$icon" ]]         && icon="System Default"
    [[ -z "$matugen_type" ]] && matugen_type="scheme-tonal-spot"

    # Cache key must incorporate settings + templates, not only desired.json.
    # Otherwise toggling templates (or editing template/config files) won't
    # trigger a rebuild and outputs can look "stuck".
    local settings_sig
    settings_sig="$(stat -c '%Y:%s' "$SETTINGS_FILE" 2>/dev/null || echo 'missing')"

    local templates_sig
    templates_sig="$(
        python3 - "$SHELL_DIR" <<'PY' 2>/dev/null || echo "pyfail"
import hashlib, os, sys
from pathlib import Path

shell_dir = Path(sys.argv[1])
roots = [
    shell_dir / "matugen" / "templates",
    shell_dir / "matugen" / "configs",
    shell_dir / "scripts" / "matugen-worker.sh",
]

h = hashlib.sha256()
for root in roots:
    if root.is_file():
        st = root.stat()
        h.update(str(root).encode())
        h.update(f"{st.st_mtime_ns}:{st.st_size}".encode())
        continue
    if not root.exists():
        h.update(f"missing:{root}".encode())
        continue
    for dp, _dn, fn in os.walk(root):
        fn.sort()
        for f in fn:
            p = Path(dp) / f
            try:
                st = p.stat()
            except OSError:
                continue
            h.update(str(p).encode())
            h.update(f"{st.st_mtime_ns}:{st.st_size}".encode())

print(h.hexdigest())
PY
    )"

    echo "${kind}|${value}|${mode}|${icon}|${matugen_type}|settings:${settings_sig}|tmpl:${templates_sig}" \
        | sha256sum | cut -d' ' -f1
}

# ── Settings ──────────────────────────────────────────────────────────────────

SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/EventHorizon/settings.json"

get_setting() {
    local key="$1"
    local default="$2"
    echo "DEBUG get_setting key=$key default=$default" >> /tmp/matugen-debug.log
    if [ -f "$SETTINGS_FILE" ]; then
        # Use has() to properly handle boolean false values (jq's // treats false as falsy)
        local result=$(jq -r "if has(\"$key\") then .$key else \"$default\" end" "$SETTINGS_FILE" 2>/dev/null || echo "$default")
        echo "DEBUG get_setting result=$result" >> /tmp/matugen-debug.log
        echo "$result"
    else
        echo "DEBUG settings file not found" >> /tmp/matugen-debug.log
        echo "$default"
    fi
}

# ── GNOME named accent picker ─────────────────────────────────────────────────

hex_to_gnome_accent() {
    local hex="${1#\#}"
    local r g b
    r=$(( 16#${hex:0:2} ))
    g=$(( 16#${hex:2:2} ))
    b=$(( 16#${hex:4:2} ))

    local rf gf bf
    rf=$(awk "BEGIN { printf \"%.6f\", $r/255 }")
    gf=$(awk "BEGIN { printf \"%.6f\", $g/255 }")
    bf=$(awk "BEGIN { printf \"%.6f\", $b/255 }")

    local hue
    hue=$(awk "BEGIN {
        r=$rf; g=$gf; b=$bf
        mx = (r > g ? r : g); if (b > mx) mx = b
        mn = (r < g ? r : g); if (b < mn) mn = b
        d = mx - mn
        if (d == 0) { print 0; exit }
        if (mx == r) h = (g - b) / d % 6
        else if (mx == g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h = h * 60
        if (h < 0) h += 360
        printf \"%.1f\", h
    }")

    local sat
    sat=$(awk "BEGIN {
        r=$rf; g=$gf; b=$bf
        mx = (r > g ? r : g); if (b > mx) mx = b
        mn = (r < g ? r : g); if (b < mn) mn = b
        l = (mx + mn) / 2
        d = mx - mn
        if (d == 0) { print 0; exit }
        s = (l > 0.5) ? d/(2-mx-mn) : d/(mx+mn)
        printf \"%.3f\", s
    }")

    local is_slate
    is_slate=$(awk "BEGIN { print ($sat < 0.15) ? 1 : 0 }")
    if [[ "$is_slate" == "1" ]]; then echo "slate"; return; fi

    local h
    h=$(printf "%.0f" "$hue")
    if   (( h >= 210 && h < 260 )); then echo "blue"
    elif (( h >= 170 && h < 210 )); then echo "teal"
    elif (( h >=  90 && h < 170 )); then echo "green"
    elif (( h >=  50 && h <  90 )); then echo "yellow"
    elif (( h >=  20 && h <  50 )); then echo "orange"
    elif (( h >= 340 || h <  20 )); then echo "red"
    elif (( h >= 300 && h < 340 )); then echo "pink"
    elif (( h >= 260 && h < 300 )); then echo "purple"
    else echo "blue"
    fi
}

# ── Best-effort live reload nudges ────────────────────────────────────────────

refresh_gtk_color_scheme() {
    # GTK4 + many GTK/portal consumers re-read colors when this key changes.
    # Toggle trick forces reload even if mode didn't change.
    local want="$1"
    command -v gsettings >/dev/null 2>&1 || return 0

    local cur
    cur="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")"
    # gsettings returns quoted strings like: 'prefer-dark'
    if [[ "$cur" == "'$want'" ]]; then
        local other
        other=$([[ "$want" == "prefer-dark" ]] && echo "prefer-light" || echo "prefer-dark")
        gsettings set org.gnome.desktop.interface color-scheme "$other" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "$want"  2>/dev/null || true
    else
        gsettings set org.gnome.desktop.interface color-scheme "$want" 2>/dev/null || true
    fi
}

refresh_qt_ct() {
    # qt5ct/qt6ct watch their main config file; touching it prompts a reload
    # (with a small delay in some apps).
    local qt5="$CONFIG_DIR/qt5ct/qt5ct.conf"
    local qt6="$CONFIG_DIR/qt6ct/qt6ct.conf"

    if [ -f "$qt5" ]; then
        touch "$qt5" 2>/dev/null || true
    fi
    if [ -f "$qt6" ]; then
        touch "$qt6" 2>/dev/null || true
    fi
}

reload_terminals_best_effort() {
    # If terminal can reload colors live, ask it to.
    # Safe: all commands are best-effort and failures are ignored.

    # Kitty: apply generated theme file to running kitty instances.
    if command -v kitty >/dev/null 2>&1 && [ -f "$CONFIG_DIR/kitty/event-theme.conf" ]; then
        kitty @ set-colors -a "$CONFIG_DIR/kitty/event-theme.conf" >/dev/null 2>&1 || true
    fi

    # Ghostty: reload config/colors via SIGUSR2.
    if command -v ghostty >/dev/null 2>&1; then
        pkill -SIGUSR2 ghostty >/dev/null 2>&1 || true
    fi

    # Alacritty: generally auto-reloads config on file change; if IPC is enabled,
    # alacritty-msg exists. We don't assume IPC; touching config is safer.
    if command -v alacritty >/dev/null 2>&1; then
        [ -f "$CONFIG_DIR/alacritty/alacritty.toml" ] && touch "$CONFIG_DIR/alacritty/alacritty.toml" 2>/dev/null || true
        [ -f "$CONFIG_DIR/alacritty/alacritty.yml" ]  && touch "$CONFIG_DIR/alacritty/alacritty.yml"  2>/dev/null || true
    fi

    # WezTerm: by default it auto-reloads when its config file changes.
    # Touching wezterm.lua is the safest "poke" (colors files may not be watched).
    if command -v wezterm >/dev/null 2>&1; then
        [ -f "$CONFIG_DIR/wezterm/wezterm.lua" ] && touch "$CONFIG_DIR/wezterm/wezterm.lua" 2>/dev/null || true
    fi
}

# ── Path fixup ────────────────────────────────────────────────────────────────

fix_paths() {
    local cfg="$1"

    sed -i "s|SHELL_DIR|$SHELL_DIR|g"        "$cfg"
    sed -i "s|CONFIG_DIR|$CONFIG_DIR|g"      "$cfg"
    sed -i "s|HOME_DIR|$HOME|g"              "$cfg"
    sed -i "s|CACHE_DIR|$HOME/.cache|g"      "$cfg"
    sed -i "s|DATA_DIR|$HOME/.local/share|g" "$cfg"
    sed -i "s|EMACS_DIR|$HOME/.emacs.d|g"    "$cfg"

    sed -i "s|input_path = '~/|input_path = '$HOME/|g"    "$cfg"
    sed -i "s|input_path = '~\./|input_path = '$HOME/.|g" "$cfg"

    sed -i "s|input_path = '\./matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$cfg"
    sed -i "s|input_path = '$HOME/.config/quickshell/matugen/templates/|input_path = '$SHELL_DIR/matugen/templates/|g" "$cfg"

    local COLLOID_TEMPLATE="$SHELL_DIR/matugen/templates/gtk3-colors.css"
    sed -i "/\[templates\.gtk3\]/,/^$/ s|input_path = './matugen/templates/gtk-colors.css'|input_path = '$COLLOID_TEMPLATE'|" "$cfg"

    sed -i "s|output_path = '~/|output_path = '$HOME/|g"    "$cfg"
    sed -i "s|output_path = '~\./|output_path = '$HOME/.|g" "$cfg"
}

# ── matugen invocation helpers ────────────────────────────────────────────────

run_matugen_json() {
    local cfg="$1" kind="$2" value="$3"
    shift 3
    case "$kind" in
        image)
            matugen -c "$cfg" --json hex --quiet \
                image "$value" --source-color-index 0 "$@"
            ;;
        hex)
            matugen -c "$cfg" --json hex --quiet \
                color hex "$value" "$@"
            ;;
    esac
}

run_matugen_templates() {
    local cfg="$1" kind="$2" value="$3"
    shift 3
    case "$kind" in
        image)
            matugen -c "$cfg" \
                image "$value" --source-color-index 0 "$@" >/dev/null
            ;;
        hex)
            matugen -c "$cfg" \
                color hex "$value" "$@" >/dev/null
            ;;
    esac
}

# ── append_toml ───────────────────────────────────────────────────────────────

append_toml() {
    local toml_path="$1" cfg="$2"
    if [[ -f "$toml_path" ]]; then
        cat "$toml_path" >> "$cfg"
        echo "" >> "$cfg"
    else
        echo "Warning: toml not found, skipping: $toml_path" >&2
    fi
}

# ── Main build function ───────────────────────────────────────────────────────

build_once() {
    local json="$1"

    local kind value mode icon matugen_type
    kind=$(echo "$json"         | jq -r '.kind          // ""')
    value=$(echo "$json"        | jq -r '.value         // ""')
    mode=$(echo "$json"         | jq -r '.mode          // ""')
    icon=$(echo "$json"         | jq -r '.iconTheme     // "System Default"')
    matugen_type=$(echo "$json" | jq -r '.matugenType   // "scheme-tonal-spot"')
    [[ -z "$icon" ]]         && icon="System Default"
    [[ -z "$matugen_type" ]] && matugen_type="scheme-tonal-spot"

    case "$kind" in
        image)
            [[ -f "$value" ]] || { echo "wallpaper not found: $value" >&2; return 2; }
            ;;
        hex)
            [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "invalid hex: $value" >&2; return 2; }
            ;;
        *)
            echo "unknown kind: $kind" >&2; return 2;;
    esac

    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

    local RUN_EH_TEMPLATES TEMPLATE_NIRI TEMPLATE_HYPRLAND TEMPLATE_GTK
    local TEMPLATE_KCOLOR TEMPLATE_QT5 TEMPLATE_QT6 TEMPLATE_KITTY
    local TEMPLATE_GHOSTTY TEMPLATE_WEZTERM TEMPLATE_ALACRITTY TEMPLATE_FOOT TEMPLATE_OTTER
    local TEMPLATE_NEOVIM TEMPLATE_VSCODE TEMPLATE_FIREFOX TEMPLATE_ZEN
    local TEMPLATE_VESKTOP TEMPLATE_PYWALFOX TEMPLATE_DGOP TEMPLATE_EMACS
    local TEMPLATE_STEAM TEMPLATE_BTOP TEMPLATE_ZED TEMPLATE_EQUIBOP HYPRLAND_ENABLED

    RUN_EH_TEMPLATES=$(get_setting "runEHMatugenTemplates" "true")
    TEMPLATE_NIRI=$(get_setting      "matugenTemplateNiri"        "true")
    TEMPLATE_HYPRLAND=$(get_setting  "matugenTemplateHyprland"    "true")
    TEMPLATE_GTK=$(get_setting       "matugenTemplateGtk"         "true")
    TEMPLATE_KCOLOR=$(get_setting    "matugenTemplateKcolorscheme" "true")
    TEMPLATE_QT5=$(get_setting       "matugenTemplateQt5ct"        "true")
    TEMPLATE_QT6=$(get_setting       "matugenTemplateQt6ct"        "true")
    TEMPLATE_KITTY=$(get_setting     "matugenTemplateKitty"        "true")
    TEMPLATE_GHOSTTY=$(get_setting   "matugenTemplateGhostty"      "true")
    TEMPLATE_WEZTERM=$(get_setting   "matugenTemplateWezterm"      "true")
    TEMPLATE_ALACRITTY=$(get_setting "matugenTemplateAlacritty"    "true")
    TEMPLATE_FOOT=$(get_setting      "matugenTemplateFoot"         "true")
    TEMPLATE_OTTER=$(get_setting     "matugenTemplateOtterTerm"     "true")
    TEMPLATE_NEOVIM=$(get_setting    "matugenTemplateNeovim"       "true")
    TEMPLATE_VSCODE=$(get_setting    "matugenTemplateVscode"       "true")
    TEMPLATE_FIREFOX=$(get_setting   "matugenTemplateFirefox"      "true")
    TEMPLATE_ZEN=$(get_setting       "matugenTemplateZenbrowser"   "true")
    TEMPLATE_VESKTOP=$(get_setting   "matugenTemplateVesktop"      "true")
    TEMPLATE_ZED=$(get_setting        "matugenTemplateZed"          "true")
    TEMPLATE_EQUIBOP=$(get_setting    "matugenTemplateEquibop"      "true")
    TEMPLATE_PYWALFOX=$(get_setting  "matugenTemplatePywalfox"     "true")
    TEMPLATE_DGOP=$(get_setting      "matugenTemplateDgop"         "true")
    TEMPLATE_EMACS=$(get_setting     "matugenTemplateEmacs"        "true")
    TEMPLATE_STEAM=$(get_setting     "matugenTemplateSteam"        "true")
    TEMPLATE_BTOP=$(get_setting      "matugenTemplateBtop"         "true")
    HYPRLAND_ENABLED=$(get_setting   "hyprlandThemingEnabled"      "true")

    # FIX: declare both temp files upfront and set a single trap covering both
    local TMP_CFG TMP_CONTENT_CFG
    TMP_CFG="$(mktemp)"
    TMP_CONTENT_CFG="$(mktemp)"
    trap 'rm -f "$TMP_CFG" "$TMP_CONTENT_CFG"' RETURN

    # ── Assemble primary config ───────────────────────────────────────────────

    if [ "$RUN_EH_TEMPLATES" = "true" ]; then
        cat "$SHELL_DIR/matugen/configs/base.toml" > "$TMP_CFG"
    else
        printf '[config]\n\n[templates]\n' > "$TMP_CFG"
    fi
    echo "" >> "$TMP_CFG"

    if command -v niri >/dev/null 2>&1 && [ "$TEMPLATE_NIRI" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/niri.toml" "$TMP_CFG"
    fi

    if command -v qt5ct >/dev/null 2>&1 && [ "$TEMPLATE_QT5" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/qt5ct.toml" "$TMP_CFG"
    fi

    if command -v qt6ct >/dev/null 2>&1 && [ "$TEMPLATE_QT6" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/qt6ct.toml" "$TMP_CFG"
    fi

    if [ "$TEMPLATE_GTK" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/gtk.toml" "$TMP_CFG"
    fi

    # FIX: kcolorscheme was read from settings but never appended
    if [ "$TEMPLATE_KCOLOR" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/kcolorscheme.toml" "$TMP_CFG"
    fi

    if command -v firefox >/dev/null 2>&1 && [ "$TEMPLATE_FIREFOX" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/firefox.toml" "$TMP_CFG"
    fi

    if command -v pywalfox >/dev/null 2>&1 && [ "$TEMPLATE_PYWALFOX" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/pywalfox.toml" "$TMP_CFG"
    fi

    # Zen Browser — check for ~/.zen profile directory rather than binary name
    # since the binary may be named 'zen', 'zen-browser', or 'zen-bin'
    if [[ -d "$HOME/.zen" ]] && [ "$TEMPLATE_ZEN" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/zenbrowser.toml" "$TMP_CFG"
    fi

    if command -v vesktop >/dev/null 2>&1 && [[ -d "$CONFIG_DIR/vesktop" ]] && [ "$TEMPLATE_VESKTOP" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/vesktop.toml" "$TMP_CFG"
    fi

    # Zed — require config dir (CLI may be flatpak-only)
    if [[ -d "$CONFIG_DIR/zed" ]] && [ "$TEMPLATE_ZED" = "true" ]; then
        mkdir -p "$CONFIG_DIR/zed/themes" 2>/dev/null || true
        append_toml "$SHELL_DIR/matugen/configs/zed.toml" "$TMP_CFG"
    fi

    # Equibop (Discord + Equibop) — same CSS pipeline as Vesktop; output under ~/.config/equibop/themes/
    if [[ -d "$CONFIG_DIR/equibop" ]] && [ "$TEMPLATE_EQUIBOP" = "true" ]; then
        mkdir -p "$CONFIG_DIR/equibop/themes" 2>/dev/null || true
        append_toml "$SHELL_DIR/matugen/configs/equibop.toml" "$TMP_CFG"
    fi

    if command -v code >/dev/null 2>&1 && [ "$TEMPLATE_VSCODE" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/vscode.toml" "$TMP_CFG"
    fi

    # Steam — check for ~/.steam or ~/.local/share/Steam rather than binary
    if { [[ -d "$HOME/.steam" ]] || [[ -d "$HOME/.local/share/Steam" ]]; } && [ "$TEMPLATE_STEAM" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/steam.toml" "$TMP_CFG"
    fi

    if command -v hyprctl >/dev/null 2>&1 && [ "$HYPRLAND_ENABLED" = "true" ] && [ "$TEMPLATE_HYPRLAND" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/hyprland.toml" "$TMP_CFG"
    fi

    # MangoWM: generate a dedicated colors fragment (template-way) when enabled.
    # Requires BOTH:
    # - Dynamic Borders (mangoDynamicBorders)
    # - Mango template enabled (matugenTemplateMango)
    MANGO_DYNAMIC_BORDERS=$(get_setting "mangoDynamicBorders" "true")
    TEMPLATE_MANGO=$(get_setting "matugenTemplateMango" "true")
    if command -v mmsg >/dev/null 2>&1 && [ "$MANGO_DYNAMIC_BORDERS" = "true" ] && [ "$TEMPLATE_MANGO" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/mangowc.toml" "$TMP_CFG"
    fi

    # FIX: neovim was read from settings but never appended
    if command -v nvim >/dev/null 2>&1 && [ "$TEMPLATE_NEOVIM" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/neovim.toml" "$TMP_CFG"
    fi

    # FIX: emacs was read from settings but never appended
    if command -v emacs >/dev/null 2>&1 && [ "$TEMPLATE_EMACS" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/emacs.toml" "$TMP_CFG"
    fi

    if command -v btop >/dev/null 2>&1 && [ "$TEMPLATE_BTOP" = "true" ]; then
        mkdir -p "$CONFIG_DIR/btop/themes"
        append_toml "$SHELL_DIR/matugen/configs/btop.toml" "$TMP_CFG"
    fi

    fix_paths "$TMP_CFG"

    # ── Run matugen (use subshell to avoid pushd/popd leak on early return) ───

    local MAT_MODE=(-m "$mode")
    local MAT_TYPE=(-t "$matugen_type")
    local JSON

    # FIX: use a subshell instead of pushd/popd so cd is always unwound,
    # even if run_matugen_json fails under set -e
    JSON=$(
        cd "$SHELL_DIR"
        run_matugen_json "$TMP_CFG" "$kind" "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}"
    )
    (
        cd "$SHELL_DIR"
        run_matugen_templates "$TMP_CFG" "$kind" "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}"
    )

    # ── Content-only config (terminals, dgop, wezterm, alacritty, foot) ───────

    printf '[config]\n\n[templates]\n' > "$TMP_CONTENT_CFG"
    echo "" >> "$TMP_CONTENT_CFG"

    local content_has_templates=false

    if command -v ghostty >/dev/null 2>&1 && [ "$TEMPLATE_GHOSTTY" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/ghostty.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    if command -v kitty >/dev/null 2>&1 && [ "$TEMPLATE_KITTY" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/kitty.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    # FIX: wezterm was read from settings but never appended
    if command -v wezterm >/dev/null 2>&1 && [ "$TEMPLATE_WEZTERM" = "true" ]; then
        mkdir -p "$CONFIG_DIR/wezterm/colors" 2>/dev/null || true
        append_toml "$SHELL_DIR/matugen/configs/wezterm.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    # FIX: alacritty was read from settings but never appended
    if command -v alacritty >/dev/null 2>&1 && [ "$TEMPLATE_ALACRITTY" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/alacritty.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    # FIX: foot was read from settings but never appended
    if command -v foot >/dev/null 2>&1 && [ "$TEMPLATE_FOOT" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/foot.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    if [ "$TEMPLATE_OTTER" = "true" ]; then
        mkdir -p "$CONFIG_DIR/otter-shell/otter-term" 2>/dev/null || true
        append_toml "$SHELL_DIR/matugen/configs/otter-term.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    if command -v dgop >/dev/null 2>&1 && [ "$TEMPLATE_DGOP" = "true" ]; then
        append_toml "$SHELL_DIR/matugen/configs/dgop.toml" "$TMP_CONTENT_CFG"
        content_has_templates=true
    fi

    if [ "$content_has_templates" = true ]; then
        fix_paths "$TMP_CONTENT_CFG"
        (
            cd "$SHELL_DIR"
            run_matugen_templates "$TMP_CONTENT_CFG" "$kind" "$value" "${MAT_MODE[@]}" "${MAT_TYPE[@]}"
        )
    fi

    # ── Otter-term: sync generated RGB into otter-term.conf, keep alpha ───────
    # Users commonly keep opacity in otter-term.conf (8-digit hex) while wanting
    # wallpaper-driven RGB updates. We therefore merge only the RGB portion from
    # the generated matugen fragment into the real config, preserving AA.
    if [ "$TEMPLATE_OTTER" = "true" ]; then
        local OTTER_FRAGMENT="$CONFIG_DIR/otter-shell/otter-term/otter-term-matugen.conf"
        local OTTER_CONF="$CONFIG_DIR/otter-shell/otter-term.conf"
        # Back-compat: older configs imported ~/.config/otter-shell/otter-term-matugen.conf
        # Keep writing that file too, so reloads don't appear to "unapply".
        local OTTER_LEGACY_FRAGMENT="$CONFIG_DIR/otter-shell/otter-term-matugen.conf"
        if [ -f "$OTTER_FRAGMENT" ]; then
            cp -f "$OTTER_FRAGMENT" "$OTTER_LEGACY_FRAGMENT" 2>/dev/null || true
        fi
        if command -v python3 >/dev/null 2>&1 && [ -f "$OTTER_FRAGMENT" ] && [ -f "$OTTER_CONF" ]; then
            python3 - "$OTTER_FRAGMENT" "$OTTER_CONF" <<'PY'
import re, sys
from pathlib import Path

fragment = Path(sys.argv[1])
conf = Path(sys.argv[2])

kv_re = re.compile(r'^(colors_[a-z_]+)\s*=\s*"?(#[0-9a-fA-F]{6})([0-9a-fA-F]{2})?"?\s*$')

def read_kv(path: Path):
    out = {}
    lines = path.read_text(errors="ignore").splitlines(True)
    return lines

frag_lines = read_kv(fragment)
conf_lines = read_kv(conf)

new_rgb = {}
for ln in frag_lines:
    m = kv_re.match(ln.strip())
    if not m:
        continue
    key, rgb, _aa = m.group(1), m.group(2).upper(), m.group(3)
    new_rgb[key] = rgb

old_alpha = {}
for ln in conf_lines:
    m = kv_re.match(ln.strip())
    if not m:
        continue
    key, _rgb, aa = m.group(1), m.group(2), m.group(3)
    if aa:
        old_alpha[key] = aa.upper()

out_lines = []
for ln in conf_lines:
    s = ln.strip()
    m = kv_re.match(s)
    if not m:
        out_lines.append(ln)
        continue
    key = m.group(1)
    if key not in new_rgb:
        out_lines.append(ln)
        continue
    aa = old_alpha.get(key, "FF")
    out_lines.append(f'{key} = "{new_rgb[key]}{aa}"\n')

conf.write_text("".join(out_lines))
PY
        fi
    fi

    # ── VS Code: merge material-code.colors into settings.json ───────────────
    # matugen writes only the colors block to a sidecar file; we merge it here
    # so we don't clobber the user's full settings.json.

    if command -v code >/dev/null 2>&1 && [ "$TEMPLATE_VSCODE" = "true" ]; then
        local VSCODE_SIDECAR="$CONFIG_DIR/Code/User/material-code-colors.matugen.json"
        local VSCODE_SETTINGS="$CONFIG_DIR/Code/User/settings.json"
        if [ -f "$VSCODE_SIDECAR" ] && command -v jq >/dev/null 2>&1; then
            local COLORS_BLOCK
            COLORS_BLOCK=$(jq '."material-code.colors"' "$VSCODE_SIDECAR" 2>/dev/null || true)
            if [ -n "$COLORS_BLOCK" ] && [ "$COLORS_BLOCK" != "null" ]; then
                if [ -f "$VSCODE_SETTINGS" ]; then
                    local TMP_SETTINGS
                    TMP_SETTINGS="$(mktemp)"
                    jq --argjson colors "$COLORS_BLOCK" \
                        '."material-code.colors" = $colors' \
                        "$VSCODE_SETTINGS" > "$TMP_SETTINGS" \
                        && mv "$TMP_SETTINGS" "$VSCODE_SETTINGS" \
                        || rm -f "$TMP_SETTINGS"
                else
                    # No existing settings.json — write the whole sidecar as-is
                    mkdir -p "$CONFIG_DIR/Code/User"
                    cp "$VSCODE_SIDECAR" "$VSCODE_SETTINGS"
                fi
            fi
            rm -f "$VSCODE_SIDECAR"
        fi
    fi

    # ── Validate and store JSON output ────────────────────────────────────────

    echo "$JSON" | jq -e '.colors.primary' >/dev/null 2>&1 \
        || { echo "matugen JSON missing primary" >&2; return 2; }
    printf "%s" "$JSON" > "$LAST_JSON"

    # ── Extract colors for downstream use ────────────────────────────────────

    local PRIMARY HONOR SURFACE
    PRIMARY=$(echo "$JSON" | jq -r ".colors.primary_container.$mode.color // empty")
    HONOR=$(echo "$JSON"   | jq -r ".colors.primary.$mode.color           // empty")
    SURFACE=$(echo "$JSON" | jq -r ".colors.surface.$mode.color           // empty")

    # ── Hyprland border colors ────────────────────────────────────────────────

    if command -v hyprctl >/dev/null 2>&1 && [ "$HYPRLAND_ENABLED" = "true" ]; then
        local PRIMARY_HEX SURFACE_HEX BORDER_SIZE
        PRIMARY_HEX=$(echo "$JSON" | jq -r '.colors.primary.dark.color // empty')
        SURFACE_HEX=$(echo "$JSON" | jq -r '.colors.surface.dark.color // empty')
        BORDER_SIZE=$(get_setting "hyprlandBorderSize" "4")

        if [ -n "$PRIMARY_HEX" ] && [ -n "$SURFACE_HEX" ]; then
            local PRIMARY_RGB SURFACE_RGB
            PRIMARY_RGB="${PRIMARY_HEX#\#}"
            SURFACE_RGB="${SURFACE_HEX#\#}"
            local COLORS_CONF="$CONFIG_DIR/hypr/hyprland/colors.conf"
            if [ -f "$COLORS_CONF" ]; then
                sed -i "s/col\.active_border = rgb([0-9a-fA-F]\{6\})/col.active_border = rgb($PRIMARY_RGB)/" "$COLORS_CONF"
                sed -i "s/col\.inactive_border = rgb([0-9a-fA-F]\{6\})/col.inactive_border = rgb($SURFACE_RGB)/" "$COLORS_CONF"
                sed -i "s/border_size = [0-9]\+/border_size = $BORDER_SIZE/" "$COLORS_CONF"
                hyprctl reload >/dev/null 2>&1 || true
            fi
        fi
    fi

    # Mango reload is handled by the matugen template post_hook (template-way).

    # ── GTK accent color (GNOME 47+) ──────────────────────────────────────────

    if [ "$TEMPLATE_GTK" = "true" ]; then
        local PRIMARY_COLOR_HEX
        PRIMARY_COLOR_HEX=$(echo "$JSON" | jq -r ".colors.primary.$mode.color // empty")
        if [ -n "$PRIMARY_COLOR_HEX" ]; then
            local GNOME_ACCENT
            GNOME_ACCENT=$(hex_to_gnome_accent "$PRIMARY_COLOR_HEX")
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.desktop.interface accent-color "$GNOME_ACCENT" 2>/dev/null || true
            elif command -v dconf >/dev/null 2>&1; then
                dconf write /org/gnome/desktop/interface/accent-color "\"$GNOME_ACCENT\"" 2>/dev/null || true
            fi
        fi
    fi

    # ── Ghostty dark-16 palette ───────────────────────────────────────────────

    if command -v ghostty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/ghostty/config-darkcolors" ]]; then
        local OUT
        OUT=$("$SHELL_DIR/matugen/dark16.py" "$PRIMARY" \
            $([[ "$mode" == "light" ]] && echo --light) \
            ${HONOR:+--honor-primary "$HONOR"} \
            ${SURFACE:+--background "$SURFACE"} 2>/dev/null || true)
        if [[ -n "${OUT:-}" ]]; then
            local TMP
            TMP="$(mktemp)"
            printf "%s\n\n" "$OUT" > "$TMP"
            cat "$CONFIG_DIR/ghostty/config-darkcolors" >> "$TMP"
            mv "$TMP" "$CONFIG_DIR/ghostty/config-darkcolors"
        fi
    fi

    # ── Kitty dark-16 palette ─────────────────────────────────────────────────

    if command -v kitty >/dev/null 2>&1 && [[ -f "$CONFIG_DIR/kitty/dark-theme.conf" ]]; then
        local OUT
        OUT=$("$SHELL_DIR/matugen/dark16.py" "$PRIMARY" \
            $([[ "$mode" == "light" ]] && echo --light) \
            ${HONOR:+--honor-primary "$HONOR"} \
            ${SURFACE:+--background "$SURFACE"} \
            --kitty 2>/dev/null || true)
        if [[ -n "${OUT:-}" ]]; then
            local TMP
            TMP="$(mktemp)"
            printf "%s\n\n" "$OUT" > "$TMP"
            cat "$CONFIG_DIR/kitty/dark-theme.conf" >> "$TMP"
            mv "$TMP" "$CONFIG_DIR/kitty/dark-theme.conf"
        fi
    fi

    # ── Color scheme preference (GNOME/GTK) ───────────────────────────────────

    local COLOR_SCHEME
    COLOR_SCHEME=$([[ "$mode" == "light" ]] && echo prefer-light || echo prefer-dark)

    if command -v dconf >/dev/null 2>&1; then
        dconf write /org/gnome/desktop/interface/color-scheme "\"$COLOR_SCHEME\"" 2>/dev/null || true
        [[ "$icon" != "System Default" && -n "$icon" ]] \
            && dconf write /org/gnome/desktop/interface/icon-theme "\"$icon\"" 2>/dev/null || true
    elif command -v gsettings >/dev/null 2>&1; then
        refresh_gtk_color_scheme "$COLOR_SCHEME"
        [[ "$icon" != "System Default" && -n "$icon" ]] \
            && gsettings set org.gnome.desktop.interface icon-theme "$icon" 2>/dev/null || true
    fi

    # ── Qt (qt5ct/qt6ct) best-effort refresh ─────────────────────────────────
    # If the matugen templates wrote new qt{5,6}ct color files, touch the ct
    # config to encourage running apps to reload.
    if [ "$TEMPLATE_QT5" = "true" ] || [ "$TEMPLATE_QT6" = "true" ]; then
        refresh_qt_ct
    fi

    # ── Terminals: best-effort live apply ────────────────────────────────────
    reload_terminals_best_effort

    # FIX: PyWalFox update moved here from top-level, gated on TEMPLATE_PYWALFOX
    if command -v pywalfox >/dev/null 2>&1 \
        && [ "$TEMPLATE_PYWALFOX" = "true" ] \
        && [[ -f "$HOME/.cache/wal/colors.json" ]]; then
        pywalfox update >/dev/null 2>&1 || true
    fi
}

# ── Main loop ─────────────────────────────────────────────────────────────────

while :; do
    DESIRED="$(read_desired)"
    WANT_KEY="$(key_of "$DESIRED")"
    HAVE_KEY=""
    [[ -f "$BUILT_KEY" ]] && HAVE_KEY="$(cat "$BUILT_KEY" 2>/dev/null || true)"

    if [[ "$WANT_KEY" == "$HAVE_KEY" ]]; then
        exit 0
    fi

    if build_once "$DESIRED"; then
        echo "$WANT_KEY" > "$BUILT_KEY"
    else
        exit 2
    fi
done

exit 0