#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  generate_cheatsheet.sh — WehttamSnaps Keybind Cheatsheet       ║
# ║  Reads live sway config.d → outputs HTML + plain text           ║
# ║  Usage:  generate_cheatsheet.sh [--html|--txt|--open]           ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

SWAY_CFG="${HOME}/.config/sway/config.d"
OUT_DIR="${HOME}/.config/wehttamsnaps"
OUT_TXT="${OUT_DIR}/cheat-sheet.txt"
OUT_HTML="${OUT_DIR}/cheat-sheet.html"
mkdir -p "${OUT_DIR}"

CFG_FILES=(
    "${SWAY_CFG}/01-variables.conf"
    "${SWAY_CFG}/05-keybinds.conf"
    "${SWAY_CFG}/09-gaming.conf"
    "${SWAY_CFG}/10-bars.conf"
)

parse_binds() {
    grep -hE "^bindsym[[:space:]]" "${CFG_FILES[@]}" 2>/dev/null | \
    awk '
    function normalise_key(k,  r) {
        r = k
        gsub(/\$mod1\+/, "Alt+",   r)
        gsub(/\$mod\+/,  "Super+", r)
        gsub(/\$mod1/,   "Alt",    r)
        gsub(/\$mod/,    "Super",  r)
        gsub(/shift/,    "Shift",  r)
        gsub(/ctrl/,     "Ctrl",   r)
        return r
    }
    function category(a,  c) {
        c = "Other"
        if      (a ~ /toggle-gamemode|gamescope|lutris|[Ss]team|protonup|gamemode/) c = "Gaming"
        else if (a ~ /jarvis|sound_system|voice-engine/)   c = "JARVIS"
        else if (a ~ /screenshot|grim|swappy/)             c = "Screenshots"
        else if (a ~ /volume|playerctl|brightnessctl|AudioMute|AudioPlay|AudioNext|AudioPrev|AudioStop|MicMute/) c = "Media"
        else if (a ~ /darktable|digikam|gimp|krita|photo/) c = "Photography"
        else if (a ~ /obs|OBS|stream|Stream/)              c = "Streaming"
        else if (a ~ /brave|browser|firefox|youtube|twitch/) c = "Browser"
        else if (a ~ /ghostty|kitty|terminal|Terminal|kate|editor/) c = "Apps"
        else if (a ~ /thunar|dolphin/)                     c = "Apps"
        else if (a ~ /floating|fullscreen|kill|focus|layout|resize|move|scratchpad|tabbed|dpms/) c = "Windows"
        else if (a ~ /workspace/)                          c = "Workspaces"
        else if (a ~ /noctalia|controlCenter|powermenu|power-down|swaylock|gtklock|lock|reload|swaymsg|swaynag/) c = "System"
        else if (a ~ /rofi|clipboard|wallpaper|welcome|keyhints|nwg-drawer/) c = "Launcher"
        else if (a ~ /webapps|discord|spotify/)            c = "Webapps"
        return c
    }
    function clean_action(a,  r) {
        r = a
        sub(/^exec[[:space:]]+/, "", r)
        gsub(/~\/\.config\/[^ ]*/, "", r)
        gsub(/\$[a-zA-Z_]+\/[^ ]*/, "", r)
        gsub(/\$sound_system/, "", r)
        gsub(/\$jarvis_menu/, "", r)
        gsub(/\$jarvis/, "", r)
        gsub(/\$term/, "", r)
        gsub(/\$menu/, "nwg-drawer", r)
        gsub(/\$browser/, "brave", r)
        gsub(/\$editor/, "kate", r)
        gsub(/\$file_manager2/, "dolphin", r)
        gsub(/\$file_manager/, "thunar", r)
        gsub(/\$launcher/, "rofi", r)
        gsub(/\$ipc/, "noctalia", r)
        gsub(/\$scripts\/[^ ]*/, "", r)
        gsub(/voice-engine\.sh[[:space:]]*[a-z_-]*/, "", r)
        gsub(/[[:space:]]*&&[[:space:]]*$/, "", r)
        gsub(/[[:space:]]+/, " ", r)
        sub(/^[[:space:]]+/, "", r)
        sub(/[[:space:]]+$/, "", r)
        if (length(r) > 58) r = substr(r, 1, 55) "..."
        return r
    }
    {
        line = $0
        sub(/--to-code[[:space:]]+/, "", line)
        n = split(line, f, /[[:space:]]+/)
        if (n < 3) next
        key = normalise_key(f[2])
        action = ""
        for (i = 3; i <= n; i++) action = action (i>3?" ":"") f[i]
        cat = category(action)
        disp = clean_action(action)
        if (disp == "") next
        if (action ~ /resize (shrink|grow)/ && key !~ /Super/) next
        print cat "|" key "|" disp
    }
    ' | sort -t'|' -k1,1 -k2,2 | uniq
}

CATS=(Launcher Apps Windows Screenshots Media Gaming Photography Streaming Browser Webapps JARVIS System Other)

key_to_html() {
    local key="$1" result="" first=1 part
    local oldIFS="$IFS"
    IFS='+'
    read -ra parts <<< "$key"
    IFS="$oldIFS"
    for part in "${parts[@]}"; do
        [[ $first -eq 0 ]] && result+='<span class="plus">+</span>'
        result+="<kbd>${part}</kbd>"
        first=0
    done
    printf '%s' "$result"
}

generate_txt() {
    local binds="$1"
    {
        printf "╔══════════════════════════════════════════════════════════════╗\n"
        printf "║  WehttamSnaps Keybind Cheatsheet                            ║\n"
        printf "║  github.com/Crowdrocker  |  twitch.tv/WehttamSnaps          ║\n"
        printf "╚══════════════════════════════════════════════════════════════╝\n\n"
        for cat in "${CATS[@]}"; do
            local section
            section=$(printf '%s\n' "$binds" | grep "^${cat}|" || true)
            [[ -z "$section" ]] && continue
            printf "── %s ──────────────────────────────────────────────\n" "$cat"
            printf '%s\n' "$section" | while IFS='|' read -r _ key action; do
                printf "  %-28s %s\n" "$key" "$action"
            done
            printf '\n'
        done
        printf "── Resize Mode (Super+Ctrl+R) ──────────────────────────────\n"
        printf "  Left/H    shrink width    Right/;   grow width\n"
        printf "  Up/K      shrink height   Down/J    grow height\n"
    } > "$OUT_TXT"
    echo "  ✓ Text:  $OUT_TXT"
}

generate_html() {
    local binds="$1" sections_html="" cat css rows key_html
    for cat in "${CATS[@]}"; do
        local section
        section=$(printf '%s\n' "$binds" | grep "^${cat}|" || true)
        [[ -z "$section" ]] && continue
        css="default"
        case "$cat" in
            Gaming)      css="gaming" ;;
            JARVIS)      css="jarvis" ;;
            Photography) css="photo"  ;;
            System)      css="system" ;;
        esac
        rows=""
        while IFS='|' read -r _ key action; do
            key_html=$(key_to_html "$key")
            rows+="<tr><td class=\"key\">${key_html}</td><td class=\"action\">${action}</td></tr>"$'\n'
        done <<< "$section"
        # Use JARVIS display name with dots
        local display_cat="$cat"
        [[ "$cat" == "JARVIS" ]] && display_cat="J.A.R.V.I.S."
        sections_html+="<div class=\"section ${css}\"><h2>${display_cat}</h2><table>${rows}</table></div>"$'\n'
    done

    # Write HTML in three parts to avoid any interpolation issues
    printf '%s' '<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>WehttamSnaps // Keybinds</title>
<style>
@import url("https://fonts.googleapis.com/css2?family=Orbitron:wght@600;800&family=Share+Tech+Mono&family=Rajdhani:wght@400;600&display=swap");
:root{--cyan:#00ffd1;--blue:#3b82ff;--pink:#ff5af1;--dark:#0a0014;--mid:#110022;--surf:#1a0035;--text:#cce8e4;--dim:#4a6860}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--dark);color:var(--text);font-family:"Rajdhani",sans-serif;font-size:15px;padding:28px 24px}
body::before{content:"";position:fixed;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,.07) 2px,rgba(0,0,0,.07) 4px);pointer-events:none;z-index:999}
header{text-align:center;margin-bottom:28px;padding-bottom:20px;border-bottom:1px solid rgba(0,255,209,.25)}
header h1{font-family:"Orbitron",monospace;font-size:2rem;font-weight:800;background:linear-gradient(90deg,var(--cyan),var(--blue),var(--pink));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;letter-spacing:.12em}
header p{color:var(--dim);font-family:"Share Tech Mono",monospace;font-size:.82rem;margin-top:6px}
.sw{max-width:480px;margin:0 auto 28px}
#search{width:100%;padding:10px 16px;background:var(--mid);border:1px solid var(--cyan);border-radius:4px;color:var(--cyan);font-family:"Share Tech Mono",monospace;font-size:.9rem;outline:none}
#search::placeholder{color:var(--dim)}
#search:focus{border-color:var(--blue);box-shadow:0 0 10px rgba(59,130,255,.25)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(400px,1fr));gap:18px}
.section{background:var(--mid);border:1px solid #200040;border-radius:6px;overflow:hidden;border-left:3px solid var(--cyan)}
.section.gaming{border-left-color:var(--pink)}.section.jarvis{border-left-color:var(--blue)}
.section.photo{border-left-color:#b8ff80}.section.system{border-left-color:#ff8c42}
.section h2{font-family:"Orbitron",monospace;font-size:.68rem;font-weight:600;letter-spacing:.18em;color:var(--cyan);background:rgba(0,255,209,.05);padding:8px 14px;border-bottom:1px solid #200040;text-transform:uppercase}
.section.gaming h2{color:var(--pink);background:rgba(255,90,241,.05)}
.section.jarvis h2{color:var(--blue);background:rgba(59,130,255,.05)}
.section.photo h2{color:#b8ff80;background:rgba(184,255,128,.04)}
.section.system h2{color:#ff8c42;background:rgba(255,140,66,.05)}
table{width:100%;border-collapse:collapse}
tr{transition:background .1s}tr:hover{background:rgba(0,255,209,.04)}tr.hidden{display:none}
td{padding:5px 14px;border-bottom:1px solid rgba(255,255,255,.03);vertical-align:middle}
tr:last-child td{border-bottom:none}
td.key{width:46%;font-family:"Share Tech Mono",monospace;font-size:.8rem;white-space:nowrap}
kbd{display:inline-block;background:var(--surf);border:1px solid var(--blue);border-radius:3px;padding:1px 6px;color:var(--blue);font-family:"Share Tech Mono",monospace;font-size:.78rem;margin:1px}
.plus{color:var(--dim);font-size:.7rem;margin:0 1px}
td.action{color:var(--text);font-size:.9rem;font-weight:600}
.rn{background:var(--mid);border:1px solid #200040;border-left:3px solid var(--pink);border-radius:6px;padding:14px 18px;margin-top:18px;font-family:"Share Tech Mono",monospace;font-size:.82rem;color:var(--dim);line-height:1.9}
.rn strong{color:var(--pink)}
footer{text-align:center;margin-top:28px;color:var(--dim);font-family:"Share Tech Mono",monospace;font-size:.78rem;border-top:1px solid #1e0040;padding-top:16px}
footer a{color:var(--cyan);text-decoration:none}
</style></head><body>
<header><h1>WehttamSnaps // Keybinds</h1>
<p>SwayFX &middot; Noctalia &middot; J.A.R.V.I.S. &nbsp;&middot;&nbsp; github.com/Crowdrocker &nbsp;&middot;&nbsp; twitch.tv/WehttamSnaps</p></header>
<div class="sw"><input type="text" id="search" placeholder="// Search keybinds..." autocomplete="off" spellcheck="false"></div>
<div class="grid" id="grid">
' > "$OUT_HTML"

    printf '%s\n' "$sections_html" >> "$OUT_HTML"

    printf '%s' '
</div>
<div class="rn"><strong>Resize Mode</strong> &mdash; Enter with <kbd style="background:#1a0035;border:1px solid #ff5af1;border-radius:3px;padding:1px 6px;color:#ff5af1;font-family:monospace;font-size:.78rem">Super+Ctrl+R</kbd>, exit with <strong>Enter</strong> or <strong>Escape</strong><br>
<strong>H/&#8592;</strong> shrink width &nbsp;&middot;&nbsp; <strong>;/&#8594;</strong> grow width &nbsp;&middot;&nbsp; <strong>K/&#8593;</strong> shrink height &nbsp;&middot;&nbsp; <strong>J/&#8595;</strong> grow height</div>
<footer><a href="https://github.com/Crowdrocker/wehttamsnaps-dots">wehttamsnaps-dots</a>
&nbsp;&middot;&nbsp; Regenerate: <code style="color:var(--cyan)">generate_cheatsheet.sh</code>
&nbsp;&middot;&nbsp; <a href="https://twitch.tv/WehttamSnaps">twitch.tv/WehttamSnaps</a></footer>
<script>
const s=document.getElementById("search");
s.addEventListener("input",()=>{
  const q=s.value.toLowerCase().trim();
  document.querySelectorAll(".section").forEach(sec=>{
    let any=false;
    sec.querySelectorAll("tr").forEach(r=>{
      const m=!q||r.textContent.toLowerCase().includes(q);
      r.classList.toggle("hidden",!m);
      if(m)any=true;
    });
    sec.style.display=any?"":"none";
  });
});
</script></body></html>
' >> "$OUT_HTML"

    echo "  ✓ HTML: $OUT_HTML"
}

# ════════════════════════════════════════════════════════════════════
MODE="${1:---all}"
echo ""
echo "  WehttamSnaps Cheatsheet Generator"
echo "  Reading configs from ${SWAY_CFG}"
echo ""
missing=0
for f in "${CFG_FILES[@]}"; do [[ ! -f "$f" ]] && echo "  ⚠  Missing: $f" && missing=1; done
[[ $missing -eq 1 ]] && echo "" && exit 1
BINDS=$(parse_binds)
COUNT=$(printf '%s\n' "$BINDS" | grep -c '|' || true)
echo "  Found ${COUNT} keybinds across ${#CFG_FILES[@]} config files"
echo ""
case "$MODE" in
    --html) generate_html "$BINDS" ;;
    --txt)  generate_txt  "$BINDS" ;;
    --open) generate_html "$BINDS"; generate_txt "$BINDS"; brave "$OUT_HTML" &>/dev/null & disown ;;
    *)      generate_html "$BINDS"; generate_txt "$BINDS" ;;
esac
echo ""
echo "  Done.  brave ${OUT_HTML}"
echo ""
