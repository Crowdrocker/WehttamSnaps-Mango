Here is a reference cheat sheet covering CLI flags, `mmsg` IPC commands, keybinding dispatchers, and window rules for **MangoWM**.

---

### 🛠️ 1. Mango Executable Flags (`mango`)

| Command | Action |
| --- | --- |
| `mango -p` | **Check config for errors** (Dry run test without reloading) |
| `mango -c <file>` | Launch MangoWM using a custom configuration file path |
| `mango -v` | Print installed MangoWM version |
| `mango -d` | Launch with verbose debug logging enabled |
| `wlrctl window list` | **active/focused window** (App ID, geometry, floating state) |
---

### 📡 2. `mmsg` CLI & IPC Commands

Use `mmsg` to query window states or send live IPC commands to MangoWM.

#### Useful Query Options (`mmsg get ...` or `mmsg -g`)

| Command | Output |
| --- | --- |
| `mmsg get focusing-client` | Return JSON info for the **active/focused window** (App ID, geometry, floating state) |
| `mmsg get all-clients` | Return JSON list of **all running clients** |
| `mmsg -O` | List all connected displays/outputs |

#### Useful Control Options (`mmsg dispatch ...` or `mmsg -s -d`)

| Command | Action |
| --- | --- |
| `mmsg dispatch reload_config` | Hot-reload your configuration files |
| `mmsg dispatch killclient` | Close current focused window |
| `mmsg dispatch view,N` | Switch active screen to Tag $N$ |
| `mmsg dispatch tag,N` | Move focused window to Tag $N$ |

---

### 🎹 3. Mango Keybinding Dispatchers (`config.conf`)

Syntax in config: `bind=MODIFIERS,KEY,DISPATCHER,PARAMS`

#### Window Management & Movement

| Dispatcher | Params | Description |
| --- | --- | --- |
| `killclient` | — | Close active window |
| `togglefloating` | — | Toggle focused window floating state |
| `togglefullscreen` | — | Toggle true fullscreen |
| `togglemaximizescreen` | — | Maximize window (keeps bar visible) |
| `centerwin` | — | Center floating window on screen |
| `focusdir` | `left/right/up/down` | Move focus in a direction |
| `exchange_client` | `left/right/up/down` | Swap window position in tiled layout |

#### Tags & Monitors

| Dispatcher | Params | Description |
| --- | --- | --- |
| `view` | `1-9` or `0` | Switch to tag ($1$–$9$ or $0$ for overview) |
| `tag` | `1-9` | Move window to tag |
| `tagsilent` | `1-9` | Move window to tag silently without focusing it |
| `viewtoright` / `viewtoleft` | — | Move tag focus to next/previous tag |
| `focusmon` | `left/right` | Switch focus between physical monitors |
| `tagmon` | `left/right,1` | Move window to monitor (keeps same tag number) |

#### Command Launchers

| Dispatcher | Params | Description |
| --- | --- | --- |
| `spawn` | `command` | Run a single binary directly |
| `spawn` | `sh -c "cmd1 && cmd2"` | Run chained shell commands or scripts |

---

### 📐 4. Window Rules & Application Targeting

Syntax in config: `windowrule=CRITERIA,ACTION`

#### Common Window Rule Properties

| Rule Parameter | Example | Description |
| --- | --- | --- |
| `appid:<id>` | `appid:io.github.Faugus.faugus-launcher` | Target window by App ID |
| `tags:<N>` | `tags:3` | Send matching window to Tag $N$ |
| `istagsilent:1` | `istagsilent:1` | Open window on tag without jumping focus |
| `isfloating:1` | `isfloating:1` | Force matching window to open floating |

#### Quick Example

```ini
# Force Faugus Launcher to open floating on Tag 3 in the background
windowrule=appid:io.github.Faugus.faugus-launcher,tags:3,istagsilent:1,isfloating:1

```
# Move active window to left or right monitor, keeping its tag number (1)
bind=SUPER+SHIFT+CTRL,Right,tagmon,right,1
bind=SUPER+SHIFT+CTRL,Left,tagmon,left,1

# Vim key alternatives
bind=SUPER+SHIFT+CTRL,l,tagmon,right,1
bind=SUPER+SHIFT+CTRL,h,tagmon,left,1
