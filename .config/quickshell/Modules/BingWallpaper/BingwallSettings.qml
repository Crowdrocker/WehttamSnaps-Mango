import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "wallpaperBing"

    // ── Description ─────────────────────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Fetches and applies the daily Bing wallpaper automatically every 3 hours."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Notifications ────────────────────────────────────────────────────────
    ToggleSetting {
        settingKey: "notifications"
        label: "Download notifications"
        description: "Show a desktop notification when a new wallpaper is downloaded and applied."
        defaultValue: true
    }

    // ── Storage ──────────────────────────────────────────────────────────────
    ToggleSetting {
        settingKey: "deleteOld"
        label: "Keep only the latest wallpaper"
        description: "Delete the previous wallpaper when a new one downloads. Disable to keep all wallpapers (uses more disk space)."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "GnomeExtensionBingWallpaperCompatibility"
        label: "GNOME Bing Wallpaper compatibility"
        description: "Save images to ~/Pictures/BingWallpaper/ to share with the GNOME Extension Bing Wallpaper."
        defaultValue: false
    }

    // ── Daily refresh ────────────────────────────────────────────────────────
    ToggleSetting {
        settingKey: "enableDailyRefresh"
        label: "Daily refresh at a set time"
        description: "Trigger an additional wallpaper refresh at a fixed time each day, on top of the 3-hour interval."
        defaultValue: false
    }

    StringSetting {
        settingKey: "dailyRefreshTime"
        label: "Refresh time (24 h)"
        description: "Time to run the daily refresh, in HH:MM format (e.g. 09:00). Only active when daily refresh is enabled."
        defaultValue: "09:00"
    }
}
