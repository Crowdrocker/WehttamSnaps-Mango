#!/usr/bin/env bash
# Symlinks this repo into ~/.config/mango. Use this if you keep the repo
# somewhere else (e.g. ~/dotfiles/mango) instead of cloning it directly to
# ~/.config/mango. Safe to re-run.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.config/mango"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "Backing up existing $TARGET -> $TARGET.bak"
  mv "$TARGET" "$TARGET.bak"
fi

ln -sfn "$REPO_DIR" "$TARGET"
chmod +x "$REPO_DIR"/scripts/*.sh
echo "Linked $TARGET -> $REPO_DIR"
echo "Validating config..."
mango -c "$TARGET/config.conf" -p
