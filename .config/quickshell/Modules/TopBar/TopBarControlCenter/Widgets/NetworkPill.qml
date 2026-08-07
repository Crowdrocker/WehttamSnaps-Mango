import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    // Do NOT override horizontalPadding / contentSpacing — use CompoundPill defaults
    // so the text actually fills the full widget width.

    isActive: {
        if (NetworkService.wifiToggling) return false
        return NetworkService.networkStatus === "ethernet"
            || NetworkService.networkStatus === "wifi"
            || NetworkService.wifiEnabled
    }

    iconName: {
        if (NetworkService.wifiToggling) return "sync"
        if (NetworkService.networkStatus === "ethernet") return "settings_ethernet"
        if (NetworkService.networkStatus === "wifi") return NetworkService.wifiSignalIcon
        return "wifi_off"
    }

    iconColor: Theme.primary

    primaryText: {
        if (NetworkService.wifiToggling)
            return NetworkService.wifiEnabled ? "Disabling Wi-Fi…" : "Enabling Wi-Fi…"
        if (NetworkService.networkStatus === "ethernet") return "Ethernet"
        if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID)
            return NetworkService.currentWifiSSID
        if (NetworkService.wifiEnabled) return "Not connected"
        return "Wi-Fi off"
    }

    secondaryText: {
        if (NetworkService.wifiToggling) return "Please wait…"
        if (NetworkService.networkStatus === "ethernet") return "Connected"
        if (NetworkService.networkStatus === "wifi")
            return NetworkService.wifiSignalStrength > 0
                ? NetworkService.wifiSignalStrength + "% signal"
                : "Connected"
        if (NetworkService.wifiEnabled) return "Select a network"
        return ""
    }

    onToggled: {
        if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling)
            NetworkService.toggleWifiRadio()
    }
}
