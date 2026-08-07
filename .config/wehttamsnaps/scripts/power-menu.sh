#!/bin/bash
# WehttamSnaps — Power Menu via Rofi

CHOICE=$(printf "⏻  Shutdown\n  Reboot\n  Suspend\n🔒  Lock\n⬚  Log Out" | \
    rofi -dmenu \
         -p "Power ❯" \
         -theme ~/.config/rofi/themes/wehttamsnaps.rasi \
         -lines 5 \
         -width 300)

case "$CHOICE" in
    *Shutdown*)
        /usr/local/bin/sound-system shutdown
        sleep 2
        systemctl poweroff
        ;;
    *Reboot*)
        /usr/local/bin/sound-system shutdown
        sleep 2
        systemctl reboot
        ;;
    *Suspend*)
        /usr/local/bin/sound-system lock
        systemctl suspend
        ;;
    *Lock*)
        /usr/local/bin/sound-system notification
        swaylock -f -c 07050f
        ;;
    *Log\ Out*)
        /usr/local/bin/sound-system shutdown
        sleep 1
        niri msg action quit
        ;;
esac
