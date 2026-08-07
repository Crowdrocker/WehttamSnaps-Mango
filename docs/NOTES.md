# Niri → MangoWM conversion notes

## New features added after the initial conversion

Four things from the mango wiki's `windowrule` examples got added on top of
the original niri conversion (these have no niri equivalent — pure additions):

- **Tearing for games** — `allow_tearing=2` (fullscreen-only) globally in
  `80-layout-and-monitors.conf`, plus `force_tearing:1` on Cyberpunk 2077,
  Fallout 4, The Division 2 (`30-tags.conf`), and the broad
  `steam_app_.*` catch-all + a `vkcube` test rule (`20-window-rules.conf`).
  If a game visibly artifacts/glitches instead of just tearing cleanly, some
  GPUs need `WLR_DRM_NO_ATOMIC=1` in `/etc/environment` — see the monitors
  wiki page.
- **OBS global hotkeys** (`30-tags.conf`) — `Ctrl+Alt+R` / `Ctrl+Alt+S` will
  reach OBS even when it's not focused, **but only if you also set the same
  combos under OBS's own Settings → Hotkeys** (Start/Stop Recording,
  Start/Stop Streaming). The mango-side binding alone does nothing without
  that. Also added `isopensilent:1` so OBS doesn't steal focus when it
  launches.
- **Terminal swallow** (`20-window-rules.conf`) — `isterm:1` on ghostty/kitty.
  Launch a GUI app from either and it'll replace the terminal window,
  restoring it when the app closes. If any specific app becomes annoying to
  have swallow your terminal, add `windowrule=noswallow:1,appid:<that-app>`.
- **Translucent terminals** (`20-window-rules.conf`) — `focused_opacity:0.92`
  / `unfocused_opacity:0.85` on ghostty/kitty. This is flat see-through, not
  frosted glass, because global `blur=0`. Flip `blur=1` in
  `80-layout-and-monitors.conf` if you want the blur-behind-the-terminal
  look instead — it's off by default to match your old niri appearance.

## ⚠️ CONFIRMED FIX: sound-system keybinds not firing

If keybinds that chain commands with `&&` (like
`sound-system launch-brave && brave`) silently do nothing, it's this build's
`spawn_shell` dispatcher not reliably running shell chains. Two changes fixed
it, both already applied throughout `10-keybinds.conf` and `40-startup.conf`:

1. **`spawn_shell,cmd`** → **`spawn,sh -c "cmd"`**. Explicitly invoking
   `sh -c "..."` through `spawn` works; relying on `spawn_shell` to do that
   for you did not.
2. **Absolute paths** for your own scripts — `/usr/local/bin/sound-system`
   instead of bare `sound-system`, same for `jarvis-menu`. `spawn` (and
   `exec-once` at boot, before your shell PATH is fully set up) don't
   reliably resolve things on `$PATH` the way niri's `spawn` did.

If you add new keybinds later that chain multiple commands, use this
pattern:
```
bind=SUPER,x,spawn,sh -c "/usr/local/bin/sound-system some-command && some-app"
```
not:
```
bind=SUPER,x,spawn_shell,sound-system some-command && some-app   # unreliable
```


Copy this whole folder to `~/.config/mango/`, then validate before your first
real launch:

```bash
mkdir -p ~/.config/mango
cp -r ./* ~/.config/mango/
mango -c ~/.config/mango/config.conf -p
```

Also `chmod +x ~/.config/mango/scripts/screenshot-window.sh`.

## What changed structurally

- **Workspaces → Tags.** niri's 11 named workspaces became 9-per-monitor
  numbered tags (mango's limit). Since tags are independent per monitor, all
  11 still fit — see the table at the top of `30-tags.conf`. Mod+1..9 now
  switches tags on the *currently focused monitor*, so use Mod+Shift+Arrow to
  jump monitors first if you want DP-1's tags.
- **Mod+0** used to be "workspace 10"; there's no tag 10, so it's repurposed
  as mango's built-in "view all tags" (id `0`).
- **Mod+Shift+0** used to move a window to workspace 10; repurposed as
  "pin window to all tags" (`toggletag,0`) since there's no tag 10 to move to.
- **Columns → Layouts.** niri's scrolling-columns model doesn't exist in
  mango. I picked `scroller` (closest feel) for general-purpose tags and
  `monocle` for Gaming/Stream/Media tags (single fullscreen-ish window,
  matching what `open-maximized` was doing). You can change any tag's layout
  live with `setlayout` or by cycling with `switch_layout`.

## Confirm/adjust before relying on this

- **Monitor names.** I kept `DP-2` (primary/4K-left) and `DP-1` (secondary,
  right) from your niri config. Run `wlr-randr` under mango to confirm these
  didn't change, and fix `monitorrule=` in `80-layout-and-monitors.conf` plus
  every `monitor:DP-x` in `30-tags.conf` if they did.
- **RADV_PERFTEST env var.** Its value contains a comma (`aco,rt`), and
  mango's `env=KEY,VALUE` format is comma-delimited. It *should* parse fine
  (only the first comma is the delimiter), but double check with `mango -p`
  or by watching for RADV features actually applying.

## Things that don't have a mango equivalent (yet)

- **Hot corners / edge-drag workspace scrolling** (niri's `gestures { }`
  block) — no matching mango setting found in the docs.
- **Screencast privacy rules** — niri's `block-out-from "screencast"` (used
  on KeePassXC, Gnome Secrets, notifications, and your welcome app) has no
  mango equivalent. Those windows *will* show up in screen shares/recordings
  now. Worth keeping an eye on if you ever stream.
- **Red border on the window being screen-shared** (`is-window-cast-target`)
  — no matching condition in mango's window-rule system.
- **Per-app corner radius.** mango only has one global `border_radius`
  (set in `80-layout-and-monitors.conf`); individual apps can only opt out
  entirely (`isnoradius:1`), not get a custom radius.
- **Per-app border/focus-ring gradients** (MO2's pink→blue, the generic
  webapp blue, the cast-target red) — mango borders are solid colors, set
  globally only.
- **niri's `show-hotkey-overlay`** — no mango equivalent, but your own
  Mod+H `keyhints.sh` rofi cheat-sheet already fills this role.
- **Reordering workspaces** (`move-workspace-up/down`) — mango tags have
  fixed numeric identity, nothing to reorder, so these 4 keybinds were
  dropped.
- **Mouse wheel workspace/column switching.** mango handles the scroll
  wheel through a separate "mouse gestures" config block, not the `bind=`
  keyboard syntax used everywhere else in `10-keybinds.conf`. I didn't want
  to guess at syntax I hadn't verified — check
  https://github.com/mangowm/mango/wiki/mouse-gestures and add these back in
  a new `15-mouse-gestures.conf` if you want wheel-based tag switching back.
- **niriswitcher** is a niri-only Alt-Tab-style switcher (it talks to niri's
  own IPC) and will not run under mango. It's commented out in
  `40-startup.conf`. mango's built-ins (`focusstack`, `toggleoverview`,
  `togglejump`) are already bound and cover most of the same ground; if you
  want a floating HUD switcher specifically, look at `swayr` or a
  rofi-based alt-tab script instead.

## Things worth double-checking once you're running

- **Noctalia Shell** is built primarily for niri and may have a niri-specific
  workspace/overview widget that won't render correctly (or at all) under
  mango. The launcher/controlCenter/settings toggles are plain `qs` IPC calls
  and should keep working regardless. Check Noctalia's own docs for a
  generic/wlroots compatibility mode if the panel itself looks off.
- **swayidle / swaylock** and **xwayland-satellite** are wlroots-protocol
  based (not niri-specific) so they should just work — the only change made
  was swapping `niri msg action power-off-monitors` for two
  `mmsg dispatch disable_monitor,<name>` calls (mango powers monitors off
  individually, not with one "all monitors" command).
- **xkbset repeat rate** — mango has native `repeat_rate`/`repeat_delay`
  settings (added to `80-layout-and-monitors.conf`, commented as a
  suggestion); the old `xkbset` spawn line is commented out since it's an X11
  tool that mostly won't affect native Wayland clients.
