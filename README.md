# WehttamSnaps-Mango

Arch Linux MangoWM configuration for photography, gaming, and content
creation. Ported from [WehttamSnaps-Niri](https://github.com/Crowdrocker/WehttamSnaps-Niri) —
same J.A.R.V.I.S. sound-system integration, per-monitor tag routing for
modding tools/gaming/streaming, and animation tuning, rebuilt for
[MangoWM](https://github.com/mangowm/mango) after switching compositors.

If you're looking for the niri version this was migrated from, see
[WehttamSnaps-Niri](https://github.com/Crowdrocker/WehttamSnaps-Niri).

## Structure

```
config.conf                  # entry point — sources everything below
10-keybinds.conf             # bind= lines
20-window-rules.conf         # windowrule= — floating/geometry/behavior
30-tags.conf                 # tagrule= layouts + app→tag/monitor routing
40-startup.conf              # exec-once= / exec=
50-animations.conf
60-layer-rules.conf
70-environment.conf          # env=
80-layout-and-monitors.conf  # input, monitorrule=, theming, effects
90-user-extra.conf           # personal one-offs
scripts/                     # screenshot.sh, screenshot-window.sh
NOTES.md                     # gotchas, gaps vs. niri, confirmed fixes
```

Read `NOTES.md` before touching anything — it documents everything that
doesn't map 1:1 from niri, plus a confirmed fix for keybinds that use
`&&` chains (use `spawn,sh -c "cmd1 && cmd2"`, not `spawn_shell`, on this
build).

## Requirements

Assumes these are already installed and on `$PATH`:
`ghostty`, `kitty`, `brave`, `firefox`, `dolphin`, `rofi`, `kate`, `obs`,
`spotify-launcher`, `steam`, `qs` (Noctalia shell), `swww`, `dunst`,
`wl-clipboard`/`cliphist`, `grim`, `slurp`, `satty`, `wayfreeze`, `jq`,
`swayidle`, `swaylock`, `udiskie`, `blueman`, `network-manager-applet`,
`xwayland-satellite`, plus my own scripts under
`~/.config/wehttamsnaps/scripts/` and `/usr/local/bin/`
(`sound-system`, `jarvis`, `jarvis-menu`) — **those aren't in this repo**,
they live in a separate dotfiles/scripts repo.

## Install

```bash
git clone git@github.com:Crowdrocker/WehttamSnaps-Mango.git ~/.config/mango
chmod +x ~/.config/mango/scripts/*.sh
mango -c ~/.config/mango/config.conf -p   # validate before launching
```

If `~/.config/mango` already has something in it, back it up first:
```bash
mv ~/.config/mango ~/.config/mango.bak
```

## Updating the backup

```bash
cd ~/.config/mango
git add -A
git commit -m "describe what changed"
git push
```

See `install.sh` for a quick way to pull the live config back into a repo
checkout if you edited it in place.
