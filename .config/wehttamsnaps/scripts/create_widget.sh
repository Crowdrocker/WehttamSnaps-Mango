#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   WehttamSnaps — Quickshell Widget Scaffolder                   ║
# ║   Author : Matthew (GitHub: Crowdrocker)                        ║
# ║                                                                  ║
# ║   Creates a complete widget folder under:                        ║
# ║   ~/.config/wehttamsnaps/widgets/<name>/                        ║
# ║                                                                  ║
# ║   Each widget gets:                                              ║
# ║     manifest.json   — metadata, keybind, toggle info            ║
# ║     widget.qml      — Quickshell QML component                  ║
# ║     widget.sh       — bash launcher / toggle script             ║
# ║     style.css       — WehttamSnaps cyberpunk stylesheet         ║
# ║     README.md       — usage docs for this widget                ║
# ║                                                                  ║
# ║   Usage:                                                         ║
# ║     create_widget.sh                    interactive mode        ║
# ║     create_widget.sh --name my-widget   skip name prompt        ║
# ║     create_widget.sh --list             list existing widgets   ║
# ║     create_widget.sh --help             show this help          ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ══════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════

WIDGETS_DIR="$HOME/.config/wehttamsnaps/widgets"
NOCTALIA_WIDGETS="$HOME/.config/Noctalia-Shell/widgets"
VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════

banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   WehttamSnaps Widget Scaffolder             ║"
    echo "  ║   github.com/Crowdrocker                     ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  ❯${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✗${NC}  $*"; }
ask()  { echo -e "${YELLOW}  ?${NC}  $*"; }

# Slugify a name — lowercase, spaces to hyphens, strip special chars
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Title case a slug — hyphens to spaces, capitalise each word
titlecase() {
    echo "$1" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g'
}

list_widgets() {
    echo ""
    info "Existing widgets in $WIDGETS_DIR:"
    echo ""
    if [[ ! -d "$WIDGETS_DIR" ]] || [[ -z "$(ls "$WIDGETS_DIR" 2>/dev/null)" ]]; then
        warn "No widgets found. Run create_widget.sh to create your first one."
    else
        for dir in "$WIDGETS_DIR"/*/; do
            local name
            name=$(basename "$dir")
            local manifest="$dir/manifest.json"
            if [[ -f "$manifest" ]]; then
                local title desc keybind category
                title=$(python3 -c "import json,sys; d=json.load(open('$manifest')); print(d.get('title','$name'))" 2>/dev/null || echo "$name")
                desc=$(python3  -c "import json,sys; d=json.load(open('$manifest')); print(d.get('description',''))"  2>/dev/null || echo "")
                keybind=$(python3 -c "import json,sys; d=json.load(open('$manifest')); print(d.get('keybind','—'))"   2>/dev/null || echo "—")
                category=$(python3 -c "import json,sys; d=json.load(open('$manifest')); print(d.get('category','misc'))" 2>/dev/null || echo "misc")
                echo -e "  ${CYAN}${title}${NC}  ${YELLOW}[${category}]${NC}  ${keybind}"
                [[ -n "$desc" ]] && echo -e "    ${desc}"
            else
                echo -e "  ${name}  ${RED}(no manifest)${NC}"
            fi
        done
    fi
    echo ""
}

# ══════════════════════════════════════════════════════════════════
# INTERACTIVE PROMPTS
# ══════════════════════════════════════════════════════════════════

prompt_name() {
    echo ""
    ask "Widget name (e.g. cpu-monitor, game-launcher, photo-export):"
    read -r raw_name
    WIDGET_NAME=$(slugify "$raw_name")
    WIDGET_TITLE=$(titlecase "$WIDGET_NAME")

    if [[ -z "$WIDGET_NAME" ]]; then
        err "Name cannot be empty."
        exit 1
    fi

    if [[ -d "$WIDGETS_DIR/$WIDGET_NAME" ]]; then
        warn "Widget '$WIDGET_NAME' already exists at $WIDGETS_DIR/$WIDGET_NAME"
        ask "Overwrite? [y/N]"
        read -r confirm
        [[ "${confirm,,}" != "y" ]] && exit 0
    fi
}

prompt_category() {
    echo ""
    info "Widget category:"
    echo "    1) work      — productivity, photography, editing"
    echo "    2) gaming    — gaming mode, Steam, performance"
    echo "    3) system    — CPU/GPU/RAM monitors, audio, network"
    echo "    4) media     — music, Spotify, media controls"
    echo "    5) misc      — custom / other"
    echo ""
    ask "Choose [1-5] (default: 5):"
    read -r cat_choice

    case "${cat_choice:-5}" in
        1) WIDGET_CATEGORY="work" ;;
        2) WIDGET_CATEGORY="gaming" ;;
        3) WIDGET_CATEGORY="system" ;;
        4) WIDGET_CATEGORY="media" ;;
        *) WIDGET_CATEGORY="misc" ;;
    esac
}

prompt_description() {
    echo ""
    ask "Short description (one line):"
    read -r WIDGET_DESC
    WIDGET_DESC="${WIDGET_DESC:-A WehttamSnaps Quickshell widget}"
}

prompt_keybind() {
    echo ""
    ask "Keybind to toggle this widget (e.g. Super+Shift+C, or leave blank):"
    read -r WIDGET_KEYBIND
    WIDGET_KEYBIND="${WIDGET_KEYBIND:-}"
}

prompt_position() {
    echo ""
    info "Default anchor position:"
    echo "    1) top-right"
    echo "    2) top-left"
    echo "    3) bottom-right"
    echo "    4) bottom-left"
    echo "    5) center"
    echo ""
    ask "Choose [1-5] (default: 1):"
    read -r pos_choice

    case "${pos_choice:-1}" in
        1) WIDGET_ANCHOR="top right" ;;
        2) WIDGET_ANCHOR="top left" ;;
        3) WIDGET_ANCHOR="bottom right" ;;
        4) WIDGET_ANCHOR="bottom left" ;;
        5) WIDGET_ANCHOR="center" ;;
        *) WIDGET_ANCHOR="top right" ;;
    esac
}

prompt_size() {
    echo ""
    ask "Widget width in px (default: 320):"
    read -r WIDGET_WIDTH
    WIDGET_WIDTH="${WIDGET_WIDTH:-320}"

    ask "Widget height in px (default: 200):"
    read -r WIDGET_HEIGHT
    WIDGET_HEIGHT="${WIDGET_HEIGHT:-200}"
}

prompt_sound() {
    echo ""
    ask "Play a JARVIS sound when toggled? [Y/n]:"
    read -r sound_choice
    if [[ "${sound_choice,,}" == "n" ]]; then
        WIDGET_SOUND=""
    else
        ask "Sound name (e.g. notification, status-report, jarvis-confirm — default: notification):"
        read -r WIDGET_SOUND
        WIDGET_SOUND="${WIDGET_SOUND:-notification}"
    fi
}

# ══════════════════════════════════════════════════════════════════
# FILE GENERATORS
# ══════════════════════════════════════════════════════════════════

generate_manifest() {
    local dst="$WIDGET_DIR/manifest.json"
    local keybind_json
    keybind_json="${WIDGET_KEYBIND:-}"
    local sound_json
    sound_json="${WIDGET_SOUND:-}"
    local ts
    ts=$(date '+%Y-%m-%d')

    cat > "$dst" << JSON
{
  "name": "${WIDGET_NAME}",
  "title": "${WIDGET_TITLE}",
  "description": "${WIDGET_DESC}",
  "version": "1.0.0",
  "author": "Matthew (WehttamSnaps)",
  "created": "${ts}",
  "category": "${WIDGET_CATEGORY}",

  "keybind": "${keybind_json}",
  "toggle_script": "~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh",
  "qml_component": "~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.qml",
  "stylesheet": "~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/style.css",

  "position": {
    "anchor": "${WIDGET_ANCHOR}",
    "margin_top": 50,
    "margin_right": 16,
    "margin_bottom": 16,
    "margin_left": 16
  },

  "size": {
    "width": ${WIDGET_WIDTH},
    "height": ${WIDGET_HEIGHT}
  },

  "sound": "${sound_json}",

  "niri_keybind": "${keybind_json}",
  "noctalia_shell": {
    "load": true,
    "autostart": false,
    "workspace_filter": []
  },

  "tags": ["${WIDGET_CATEGORY}", "wehttamsnaps"]
}
JSON
    ok "Created manifest.json"
}

generate_qml() {
    local dst="$WIDGET_DIR/widget.qml"

    # Pick accent colour by category
    local accent
    case "$WIDGET_CATEGORY" in
        gaming)  accent="#ff5af1" ;;
        work)    accent="#3b82ff" ;;
        system)  accent="#00ffd1" ;;
        media)   accent="#ffd700" ;;
        *)       accent="#00ffd1" ;;
    esac

    cat > "$dst" << QML
// ══════════════════════════════════════════════════════════════════
// WehttamSnaps — ${WIDGET_TITLE} Widget
// Category : ${WIDGET_CATEGORY}
// Keybind  : ${WIDGET_KEYBIND:-none}
// Author   : Matthew (github.com/Crowdrocker)
// ══════════════════════════════════════════════════════════════════

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Root shell window — anchored overlay
ShellWindow {
    id: root

    // ── Position & size ──────────────────────────────────────────
    anchors {
        top: ${WIDGET_ANCHOR == "bottom left" || WIDGET_ANCHOR == "bottom right" ? "false" : "true"}
        bottom: ${WIDGET_ANCHOR == "bottom left" || WIDGET_ANCHOR == "bottom right" ? "true" : "false"}
        left: ${WIDGET_ANCHOR == "top left" || WIDGET_ANCHOR == "bottom left" ? "true" : "false"}
        right: ${WIDGET_ANCHOR == "top right" || WIDGET_ANCHOR == "bottom right" ? "true" : "false"}
    }
    margins {
        top: 50
        right: 16
        bottom: 16
        left: 16
    }

    width: ${WIDGET_WIDTH}
    height: ${WIDGET_HEIGHT}

    // Keep above other windows, no taskbar entry
    WlrLayerShell.layer: WlrLayer.Overlay
    WlrLayerShell.keyboardFocus: WlrKeyboardFocus.None

    // Transparent background — widget draws its own bg
    color: "transparent"

    // ── Visibility toggle ────────────────────────────────────────
    visible: false

    function toggle() {
        visible = !visible
        if (visible) {
            refreshTimer.restart()
        }
    }

    // ── Auto-refresh every 2 seconds when visible ────────────────
    Timer {
        id: refreshTimer
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: dataProcess.running = true
    }

    // ── Backend data process ─────────────────────────────────────
    // Replace this with whatever command feeds your widget data.
    // Output is read line-by-line in onReadLine below.
    Process {
        id: dataProcess
        command: ["bash", "-c", "echo 'replace_with_your_command'"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                widgetContent.text = line
            }
        }
    }

    // ── Widget body ──────────────────────────────────────────────
    Rectangle {
        id: widgetBody
        anchors.fill: parent
        color: "#0d0a1a"
        border.color: "${accent}"
        border.width: 1
        radius: 6

        // Scanline effect
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            // Scanlines via repeating gradient
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0, 255, 209, 0.01) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Header bar ───────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                // Accent dot
                Rectangle {
                    width: 8; height: 8
                    radius: 4
                    color: "${accent}"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1000 }
                        NumberAnimation { to: 1.0; duration: 1000 }
                    }
                }

                Text {
                    text: "${WIDGET_TITLE^^}"
                    color: "${accent}"
                    font.family: "Share Tech Mono"
                    font.pixelSize: 10
                    letterSpacing: 2
                    Layout.fillWidth: true
                }

                // Close button
                Text {
                    text: "✕"
                    color: Qt.rgba(200, 240, 232, 0.3)
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.visible = false
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            // ── Divider ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(0, 255, 209, 0.18)
            }

            // ── Content area ─────────────────────────────────────
            // Replace this Text with your actual widget content.
            // See the work/ and gaming/ example widgets for patterns.
            Text {
                id: widgetContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "← Edit widget.qml to add your content here.\n\nTip: use a Process block above to\nread live system data."
                color: Qt.rgba(200, 240, 232, 0.6)
                font.family: "Share Tech Mono"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }

            // ── Footer ───────────────────────────────────────────
            Text {
                text: "WehttamSnaps  ·  ${WIDGET_CATEGORY}"
                color: Qt.rgba(200, 240, 232, 0.2)
                font.family: "Share Tech Mono"
                font.pixelSize: 8
                letterSpacing: 1
            }
        }
    }

    // ── Entry animation ──────────────────────────────────────────
    NumberAnimation on opacity {
        id: fadeIn
        from: 0; to: 1
        duration: 150
        running: root.visible
    }
}
QML
    ok "Created widget.qml"
}

generate_shell() {
    local dst="$WIDGET_DIR/widget.sh"
    local sound_line=""
    if [[ -n "$WIDGET_SOUND" ]]; then
        sound_line="    /usr/local/bin/sound-system ${WIDGET_SOUND} 2>/dev/null || true"
    fi

    cat > "$dst" << SHELL
#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# WehttamSnaps — ${WIDGET_TITLE} Widget Launcher
# Category : ${WIDGET_CATEGORY}
# Keybind  : ${WIDGET_KEYBIND:-none set — add to config.kdl}
# ══════════════════════════════════════════════════════════════════
#
# Usage:
#   widget.sh              toggle widget
#   widget.sh show         show widget
#   widget.sh hide         hide widget
#   widget.sh reload       reload widget (re-start Quickshell component)
#   widget.sh status       print running status

WIDGET_NAME="${WIDGET_NAME}"
QML_FILE="\$HOME/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.qml"
PID_FILE="\$HOME/.cache/wehttamsnaps/widget-${WIDGET_NAME}.pid"

is_running() {
    [[ -f "\$PID_FILE" ]] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null
}

start_widget() {
${sound_line}
    if command -v quickshell &>/dev/null; then
        quickshell -p "\$QML_FILE" &
        echo \$! > "\$PID_FILE"
        echo "Widget started: PID \$(cat "\$PID_FILE")"
    else
        notify-send "WehttamSnaps" "quickshell not found — install: paru -S quickshell-git" -t 4000
        echo "quickshell not installed"
        exit 1
    fi
}

stop_widget() {
    if is_running; then
        kill "\$(cat "\$PID_FILE")" 2>/dev/null || true
        rm -f "\$PID_FILE"
        echo "Widget stopped"
    fi
}

toggle_widget() {
    if is_running; then
        stop_widget
    else
        start_widget
    fi
}

case "\${1:-toggle}" in
    toggle)  toggle_widget ;;
    show)    is_running || start_widget ;;
    hide)    stop_widget ;;
    reload)  stop_widget; sleep 0.2; start_widget ;;
    status)
        if is_running; then
            echo "Running — PID \$(cat "\$PID_FILE")"
        else
            echo "Stopped"
        fi
        ;;
    *)
        echo "Usage: widget.sh [toggle|show|hide|reload|status]"
        exit 1
        ;;
esac
SHELL
    chmod +x "$dst"
    ok "Created widget.sh"
}

generate_css() {
    local dst="$WIDGET_DIR/style.css"

    # Pick accent by category
    local accent accent_dim border_col
    case "$WIDGET_CATEGORY" in
        gaming) accent="#ff5af1"; accent_dim="rgba(255,90,241,0.12)";  border_col="rgba(255,90,241,0.25)" ;;
        work)   accent="#3b82ff"; accent_dim="rgba(59,130,255,0.12)";  border_col="rgba(59,130,255,0.25)"  ;;
        media)  accent="#ffd700"; accent_dim="rgba(255,215,0,0.12)";   border_col="rgba(255,215,0,0.25)"   ;;
        *)      accent="#00ffd1"; accent_dim="rgba(0,255,209,0.12)";   border_col="rgba(0,255,209,0.22)"   ;;
    esac

    cat > "$dst" << CSS
/*
 * WehttamSnaps — ${WIDGET_TITLE} Widget Stylesheet
 * Category : ${WIDGET_CATEGORY}
 * Palette  : ${accent} accent on #07050f void black
 *
 * This CSS is loaded by the QML component via Quickshell.
 * Variables here mirror the main WehttamSnaps theme.
 */

/* ── Root variables ─────────────────────────────────────────── */
:root {
    --bg0:        #07050f;
    --bg1:        #0d0a1a;
    --bg2:        #130f22;
    --bg3:        #1a1430;

    --accent:     ${accent};
    --accent-dim: ${accent_dim};
    --border:     ${border_col};

    --text:       #c8f0e8;
    --text2:      rgba(200,240,232,0.55);
    --text3:      rgba(200,240,232,0.28);

    --mono:       'Share Tech Mono', monospace;
    --ui:         'Rajdhani', sans-serif;
}

/* ── Widget shell ───────────────────────────────────────────── */
.widget-root {
    background-color: var(--bg1);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text);
    font-family: var(--ui);
    font-size: 13px;
}

/* ── Header ─────────────────────────────────────────────────── */
.widget-header {
    background-color: var(--bg0);
    border-bottom: 1px solid var(--border);
    padding: 6px 12px;
    display: flex;
    align-items: center;
    gap: 8px;
}

.widget-title {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 2px;
    color: var(--accent);
    text-transform: uppercase;
    flex: 1;
}

.widget-close {
    color: var(--text3);
    font-size: 10px;
    cursor: pointer;
}

.widget-close:hover {
    color: var(--text);
}

/* ── Content area ───────────────────────────────────────────── */
.widget-body {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
}

/* ── Stat rows ──────────────────────────────────────────────── */
.stat-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
    border-bottom: 1px solid rgba(0,255,209,0.05);
}

.stat-label {
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--text3);
    text-transform: uppercase;
    width: 80px;
    flex-shrink: 0;
}

.stat-value {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--accent);
    flex: 1;
}

/* ── Progress bar ───────────────────────────────────────────── */
.bar-track {
    height: 3px;
    background: rgba(0,255,209,0.08);
    border-radius: 2px;
    overflow: hidden;
    flex: 1;
}

.bar-fill {
    height: 100%;
    background: var(--accent);
    border-radius: 2px;
    transition: width 0.4s ease;
}

/* ── Buttons ────────────────────────────────────────────────── */
.widget-btn {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 3px;
    padding: 4px 10px;
    font-family: var(--mono);
    font-size: 9px;
    letter-spacing: 1px;
    color: var(--accent);
    cursor: pointer;
    transition: background 0.12s, border-color 0.12s;
}

.widget-btn:hover {
    background: var(--accent-dim);
    border-color: var(--accent);
}

/* ── Accent dot (pulsing) ───────────────────────────────────── */
.accent-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--accent);
    flex-shrink: 0;
}

/* ── Footer ─────────────────────────────────────────────────── */
.widget-footer {
    font-family: var(--mono);
    font-size: 8px;
    color: var(--text3);
    letter-spacing: 1px;
    padding: 6px 12px 8px;
    border-top: 1px solid var(--border);
}
CSS
    ok "Created style.css"
}

generate_readme() {
    local dst="$WIDGET_DIR/README.md"
    local keybind_section=""
    if [[ -n "$WIDGET_KEYBIND" ]]; then
        keybind_section="## Keybind

Add this to your \`~/.config/niri/config.kdl\` inside the \`binds\` block:

\`\`\`kdl
${WIDGET_KEYBIND} {
    spawn \"sh\" \"-c\" \"~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh toggle\";
}
\`\`\`
"
    fi

    local sound_section=""
    if [[ -n "$WIDGET_SOUND" ]]; then
        sound_section="## Sound

Plays \`${WIDGET_SOUND}\` from the J.A.R.V.I.S. sound system when toggled.
Requires \`/usr/share/wehttamsnaps/sounds/jarvis/${WIDGET_SOUND}.mp3\` to exist.
"
    fi

    cat > "$dst" << README
# ${WIDGET_TITLE} Widget

**Category:** ${WIDGET_CATEGORY}  
**Author:** Matthew — [github.com/Crowdrocker](https://github.com/Crowdrocker)  
**Created:** $(date '+%Y-%m-%d')

${WIDGET_DESC}

---

## Files

| File | Purpose |
|------|---------|
| \`manifest.json\` | Widget metadata, keybind, position, size |
| \`widget.qml\` | Quickshell QML component — edit this to customise the UI |
| \`widget.sh\` | Bash launcher — toggle, show, hide, reload, status |
| \`style.css\` | WehttamSnaps cyberpunk stylesheet |
| \`README.md\` | This file |

---

## Usage

\`\`\`bash
# Toggle widget on/off
~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh

# Or using the alias (after adding to .bashrc)
widget-${WIDGET_NAME}

# Other modes
widget.sh show     # show
widget.sh hide     # hide
widget.sh reload   # restart
widget.sh status   # check running state
\`\`\`

${keybind_section}
${sound_section}
## Customising the Widget

1. **Edit \`widget.qml\`** — the QML component is the main UI. The \`Process\` block at the top is where you feed in live data.
2. **Edit \`style.css\`** — colours and layout. CSS variables at the top control the whole palette.
3. **Edit \`manifest.json\`** — update position, size, keybind, or autostart settings.

### Example: show CPU usage

In \`widget.qml\`, replace the \`Process\` command with:
\`\`\`qml
command: ["bash", "-c", "grep 'cpu ' /proc/stat | awk '{usage=(\$2+\$4)*100/(\$2+\$4+\$5)} END {printf \"%.0f%%\", usage}'"]
\`\`\`

### Example: show current Spotify track

\`\`\`qml
command: ["bash", "-c", "playerctl metadata --format '{{ artist }} — {{ title }}' 2>/dev/null || echo 'Nothing playing'"]
\`\`\`

---

## Loading in Noctalia-Shell

Add to your Noctalia-Shell config:

\`\`\`js
// In your Noctalia-Shell widgets manifest
import "~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.qml" as ${WIDGET_NAME^}Widget
\`\`\`

Or load manually via Quickshell:
\`\`\`bash
quickshell -p ~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.qml
\`\`\`

---

*WehttamSnaps — [github.com/Crowdrocker](https://github.com/Crowdrocker)*
README
    ok "Created README.md"
}

# ══════════════════════════════════════════════════════════════════
# EXAMPLE WIDGETS (work + gaming templates)
# ══════════════════════════════════════════════════════════════════

create_example_widgets() {
    info "Creating example widgets..."

    # ── Work widget example ──────────────────────────────────────
    local work_dir="$WIDGETS_DIR/work-status"
    mkdir -p "$work_dir"

    cat > "$work_dir/manifest.json" << 'JSON'
{
  "name": "work-status",
  "title": "Work Status",
  "description": "Photography workflow tracker — shows current workspace, active app, and photo export progress",
  "version": "1.0.0",
  "author": "Matthew (WehttamSnaps)",
  "category": "work",
  "keybind": "Super+Shift+W",
  "toggle_script": "~/.config/wehttamsnaps/widgets/work-status/widget.sh",
  "qml_component": "~/.config/wehttamsnaps/widgets/work-status/widget.qml",
  "position": { "anchor": "top right", "margin_top": 50, "margin_right": 16 },
  "size": { "width": 300, "height": 180 },
  "sound": "status-report",
  "tags": ["work", "photography", "wehttamsnaps"]
}
JSON

    cat > "$work_dir/widget.sh" << 'SHELL'
#!/bin/bash
# WehttamSnaps — Work Status Widget
PID_FILE="$HOME/.cache/wehttamsnaps/widget-work-status.pid"
QML_FILE="$HOME/.config/wehttamsnaps/widgets/work-status/widget.qml"
is_running() { [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }
case "${1:-toggle}" in
    toggle)
        if is_running; then kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"
        else
            /usr/local/bin/sound-system status-report 2>/dev/null || true
            quickshell -p "$QML_FILE" & echo $! > "$PID_FILE"
        fi ;;
    status) is_running && echo "Running — PID $(cat "$PID_FILE")" || echo "Stopped" ;;
esac
SHELL
    chmod +x "$work_dir/widget.sh"
    ok "Example work-status widget created"

    # ── Gaming widget example ────────────────────────────────────
    local gaming_dir="$WIDGETS_DIR/gaming-status"
    mkdir -p "$gaming_dir"

    cat > "$gaming_dir/manifest.json" << 'JSON'
{
  "name": "gaming-status",
  "title": "Gaming Status",
  "description": "iDroid HUD — shows gaming mode state, CPU governor, GPU temp, and active game",
  "version": "1.0.0",
  "author": "Matthew (WehttamSnaps)",
  "category": "gaming",
  "keybind": "Super+Shift+G",
  "toggle_script": "~/.config/wehttamsnaps/widgets/gaming-status/widget.sh",
  "qml_component": "~/.config/wehttamsnaps/widgets/gaming-status/widget.qml",
  "position": { "anchor": "top right", "margin_top": 50, "margin_right": 16 },
  "size": { "width": 300, "height": 200 },
  "sound": "jarvis-gaming",
  "tags": ["gaming", "idroid", "performance", "wehttamsnaps"]
}
JSON

    cat > "$gaming_dir/widget.sh" << 'SHELL'
#!/bin/bash
# WehttamSnaps — Gaming Status Widget
PID_FILE="$HOME/.cache/wehttamsnaps/widget-gaming-status.pid"
QML_FILE="$HOME/.config/wehttamsnaps/widgets/gaming-status/widget.qml"
is_running() { [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }
case "${1:-toggle}" in
    toggle)
        if is_running; then kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"
        else
            /usr/local/bin/sound-system jarvis-gaming 2>/dev/null || true
            quickshell -p "$QML_FILE" & echo $! > "$PID_FILE"
        fi ;;
    status) is_running && echo "Running — PID $(cat "$PID_FILE")" || echo "Stopped" ;;
esac
SHELL
    chmod +x "$gaming_dir/widget.sh"
    ok "Example gaming-status widget created"
}

# ══════════════════════════════════════════════════════════════════
# MAIN SCAFFOLD
# ══════════════════════════════════════════════════════════════════

scaffold_widget() {
    WIDGET_DIR="$WIDGETS_DIR/$WIDGET_NAME"
    mkdir -p "$WIDGET_DIR"

    info "Scaffolding widget: ${BOLD}${WIDGET_TITLE}${NC}"
    echo "  Location : $WIDGET_DIR"
    echo "  Category : $WIDGET_CATEGORY"
    echo "  Anchor   : $WIDGET_ANCHOR"
    echo "  Size     : ${WIDGET_WIDTH}×${WIDGET_HEIGHT}"
    [[ -n "$WIDGET_KEYBIND" ]] && echo "  Keybind  : $WIDGET_KEYBIND"
    [[ -n "$WIDGET_SOUND"   ]] && echo "  Sound    : $WIDGET_SOUND"
    echo ""

    generate_manifest
    generate_qml
    generate_shell
    generate_css
    generate_readme

    # Optionally symlink into Noctalia-Shell widgets dir
    if [[ -d "$NOCTALIA_WIDGETS" ]]; then
        ln -sf "$WIDGET_DIR" "$NOCTALIA_WIDGETS/$WIDGET_NAME" 2>/dev/null || true
        ok "Symlinked into Noctalia-Shell widgets/"
    fi

    # Add bash alias for this widget
    local alias_line="alias widget-${WIDGET_NAME}='~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh'"
    if ! grep -q "widget-${WIDGET_NAME}" "$HOME/.bashrc" 2>/dev/null; then
        echo "$alias_line" >> "$HOME/.bashrc"
        ok "Added alias: widget-${WIDGET_NAME}"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}  ✓ Widget '${WIDGET_TITLE}' created!${NC}"
    echo ""
    echo -e "  ${CYAN}Next steps:${NC}"
    echo -e "  1. Edit   ${YELLOW}$WIDGET_DIR/widget.qml${NC}  — customise the UI"
    echo -e "  2. Edit   ${YELLOW}$WIDGET_DIR/style.css${NC}   — tweak colours/layout"
    echo -e "  3. Test   ${CYAN}~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh${NC}"

    if [[ -n "$WIDGET_KEYBIND" ]]; then
        echo ""
        echo -e "  ${CYAN}Add to ~/.config/niri/config.kdl inside binds {}:${NC}"
        echo -e "  ${YELLOW}${WIDGET_KEYBIND} { spawn \"sh\" \"-c\" \"~/.config/wehttamsnaps/widgets/${WIDGET_NAME}/widget.sh\"; }${NC}"
    fi
    echo ""
}

# ══════════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════════

show_help() {
    cat << EOF

${CYAN}WehttamSnaps Widget Scaffolder${NC}

${YELLOW}Usage:${NC}
  create_widget.sh                  Interactive (recommended)
  create_widget.sh --name NAME      Skip name prompt
  create_widget.sh --list           List existing widgets
  create_widget.sh --examples       Create example work + gaming widgets
  create_widget.sh --help           This help

${YELLOW}Each widget gets:${NC}
  manifest.json   Widget metadata, position, keybind, sound
  widget.qml      Quickshell QML component — the actual UI
  widget.sh       Bash launcher (toggle/show/hide/reload/status)
  style.css       WehttamSnaps cyberpunk stylesheet
  README.md       Per-widget usage docs

${YELLOW}Widget categories:${NC}
  work    — productivity, photography, photo export
  gaming  — gaming mode HUD, Steam, performance stats
  system  — CPU/GPU/RAM monitors, audio
  media   — music, Spotify, media controls
  misc    — anything else

${YELLOW}Widgets live at:${NC}
  ~/.config/wehttamsnaps/widgets/<name>/

${YELLOW}Load in Quickshell:${NC}
  quickshell -p ~/.config/wehttamsnaps/widgets/<name>/widget.qml

EOF
}

# ══════════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════════

# Parse flags
FORCE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name|-n)
            FORCE_NAME="${2:-}"
            shift 2
            ;;
        --list|-l)
            list_widgets
            exit 0
            ;;
        --examples|-e)
            mkdir -p "$WIDGETS_DIR"
            create_example_widgets
            exit 0
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# ── Interactive mode ─────────────────────────────────────────────
banner
mkdir -p "$WIDGETS_DIR"

if [[ -n "$FORCE_NAME" ]]; then
    WIDGET_NAME=$(slugify "$FORCE_NAME")
    WIDGET_TITLE=$(titlecase "$WIDGET_NAME")
    if [[ -d "$WIDGETS_DIR/$WIDGET_NAME" ]]; then
        warn "Widget '$WIDGET_NAME' already exists."
    fi
else
    prompt_name
fi

prompt_category
prompt_description
prompt_keybind
prompt_position
prompt_size
prompt_sound

echo ""
info "Ready to scaffold. Press Enter to continue or Ctrl+C to cancel."
read -r

scaffold_widget
