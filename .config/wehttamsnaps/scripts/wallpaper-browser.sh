#!/bin/bash
# WehttamSnaps — Wallpaper Browser via Rofi

WALLPAPER_DIR="$HOME/.config/wehttamsnaps/wallpapers"

if [[ ! -d "$WALLPAPER_DIR" ]] || [[ -z "$(ls "$WALLPAPER_DIR" 2>/dev/null)" ]]; then
    notify-send "WehttamSnaps" "No wallpapers found in $WALLPAPER_DIR" -t 3000
    exit 0
fi

CHOICE=$(ls "$WALLPAPER_DIR" | \
    rofi -dmenu \
         -p "Wallpaper ❯" \
         -theme ~/.config/rofi/themes/wehttamsnaps.rasi)

if [[ -n "$CHOICE" ]]; then
    swww img "$WALLPAPER_DIR/$CHOICE" \
        --transition-type fade \
        --transition-duration 1
    ln -sf "$WALLPAPER_DIR/$CHOICE" "$WALLPAPER_DIR/current.jpg"
    notify-send "WehttamSnaps" "Wallpaper set: $CHOICE" -t 2000
fi
