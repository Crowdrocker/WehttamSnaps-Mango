#!/usr/bin/env bash
# photo-export.sh — Photography export helper with J.A.R.V.I.S. feedback
# Copies selected image(s) to ~/Pictures/Exports/ with timestamp folder

SOUND_SYSTEM="/usr/local/bin/sound-system"
EXPORT_DIR="$HOME/Pictures/Exports/$(date +%Y-%m-%d)"

mkdir -p "$EXPORT_DIR"

notify-send "J.A.R.V.I.S." "Preparing export, sir..." -t 2000

# If darktable is running, trigger export via its CLI
if pgrep darktable > /dev/null; then
    notify-send "J.A.R.V.I.S." "Use Darktable's export panel for selected images." -t 4000
    $SOUND_SYSTEM photo-export
else
    # Fallback: file picker to select images to copy to export dir
    FILES=$(zenity --file-selection --multiple --separator='|' \
        --title="WehttamSnaps — Select Photos to Export" \
        --file-filter="Images | *.jpg *.jpeg *.png *.tif *.tiff *.raw *.cr2 *.nef *.arw" \
        2>/dev/null)

    if [[ -n "$FILES" ]]; then
        IFS='|' read -ra SELECTED <<< "$FILES"
        for f in "${SELECTED[@]}"; do
            cp "$f" "$EXPORT_DIR/"
        done
        COUNT=${#SELECTED[@]}
        $SOUND_SYSTEM photo-export
        notify-send "J.A.R.V.I.S." "Export complete. $COUNT file(s) → $EXPORT_DIR" \
            -i emblem-photos -t 4000
    fi
fi
