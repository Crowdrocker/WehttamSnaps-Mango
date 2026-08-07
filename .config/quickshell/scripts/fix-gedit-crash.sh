#!/bin/bash

echo "Configuring gedit to prevent quickshell crashes..."
gsettings set org.gnome.gedit.preferences.editor create-backup-copy false
gsettings set org.gnome.gedit.preferences.editor auto-save false
gsettings set org.gnome.gedit.preferences.encodings candidate-encodings "['UTF-8', 'CURRENT', 'ISO-8859-15', 'UTF-16']"

echo "Gedit configuration updated!"
echo ""
echo "Changes made:"
echo "  - Backup files disabled (no more filename~ files)"
echo "  - Auto-save disabled (prevents frequent writes)"
echo "  - UTF-8 encoding set as default"
echo ""
echo "Note: You may need to restart gedit for changes to take effect."
echo "If you still experience crashes, try using a different editor like vim, nano, or VS Code."
