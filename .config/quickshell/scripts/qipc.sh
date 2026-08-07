#!/usr/bin/env sh
# Quickshell IPC helper for compositor keybinds (Hyprland splits on commas — use this
# so the keybind line stays:  exec, /path/to/qipc.sh <target> <method> [args...]
set -e
QS_BIN="${QS_BIN:-/usr/bin/qs}"
if [ ! -x "$QS_BIN" ] && command -v qs >/dev/null 2>&1; then
  QS_BIN="$(command -v qs)"
fi
exec "$QS_BIN" ipc call "$@"
