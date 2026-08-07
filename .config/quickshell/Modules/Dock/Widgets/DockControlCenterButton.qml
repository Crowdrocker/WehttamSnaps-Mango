import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool   isActive:           false
    property string section:            "right"
    property var    popupTarget:        null
    property var    parentScreen:       null
    property var    widgetData:         null
    property bool   showNetworkIcon:    SettingsData.controlCenterShowNetworkIcon
    property bool   showBluetoothIcon:  SettingsData.controlCenterShowBluetoothIcon
    property bool   showAudioIcon:      SettingsData.controlCenterShowAudioIcon
    property bool   showMicIcon:        SettingsData.controlCenterShowMicIcon
    property real   widgetHeight:       30
    property real   barHeight:          48
    property string barPosition:        "top"
    property bool   isBarVertical:      barPosition === "left" || barPosition === "right"

    signal clicked()

    // ── Scale & sizing ────────────────────────────────────────────────────────
    readonly property real s:      widgetHeight / 30
    readonly property real iconSz: Math.round((Theme.fontSizeMedium + 2) * s)
    readonly property real hPad:   SettingsData.topBarNoBackground ? 0 : Math.round(Theme.spacingM * s)

    // ── Audio helpers (shared between horizontal and vertical) ────────────────
    readonly property string audioIconName: {
        const audio = AudioService.sink?.audio
        if (!audio) return "volume_up"
        if (audio.muted || audio.volume === 0) return "volume_off"
        if (audio.volume * 100 < 33) return "volume_down"
        return "volume_up"
    }
    readonly property string micIconName: {
        return (AudioService.source?.audio?.muted ?? false) ? "mic_off" : "mic"
    }
    readonly property color micIconColor: {
        return (AudioService.source?.audio?.muted ?? true)
            ? Theme.outlineButton
            : Theme.primary
    }
    readonly property string networkIconName: {
        if (NetworkService.wifiToggling) return "sync"
        if (NetworkService.networkStatus === "ethernet") return "lan"
        return NetworkService.wifiSignalIcon
    }
    readonly property color networkIconColor: {
        if (NetworkService.wifiToggling) return Theme.primary
        return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton
    }

    // Whether to show the fallback settings cog (no other icons visible)
    readonly property bool showFallbackIcon:
        !root.showNetworkIcon &&
        !root.showBluetoothIcon &&
        !root.showAudioIcon &&
        !root.showMicIcon

    // ── Geometry ──────────────────────────────────────────────────────────────
    width:  isBarVertical ? widgetHeight : (iconStrip.implicitWidth + hPad * 2)
    height: isBarVertical ? (iconStrip.implicitHeight + hPad * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * s
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const base = (controlCenterArea.containsMouse || root.isActive)
            ? Theme.widgetBaseHoverColor
            : Theme.widgetBaseBackgroundColor
        return Qt.rgba(base.r, base.g, base.b, base.a * Theme.widgetTransparency)
    }

    Behavior on color { ColorAnimation { duration: 120 } }

    // ── Icon strip — one layout, orientation toggled via anchors ──────────────
    // Using a Flow instead of Row/Column so we can drive direction with a flag.
    Flow {
        id: iconStrip
        anchors.centerIn: parent
        flow:    isBarVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: Math.round(Theme.spacingS * s)

        // Network
        EHIcon {
            name:    root.networkIconName
            size:    root.iconSz
            color:   root.networkIconColor
            visible: root.showNetworkIcon
        }

        // Bluetooth
        EHIcon {
            name:    "bluetooth"
            size:    root.iconSz
            color:   BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
        }

        // Audio — scroll to adjust volume
        EHIcon {
            name:    root.audioIconName
            size:    root.iconSz
            color:   Theme.surfaceText
            visible: root.showAudioIcon

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const audio = AudioService.sink?.audio
                    if (!audio) return
                    const cur  = audio.volume * 100
                    const next = wheel.angleDelta.y > 0
                        ? Math.min(100, cur + 5)
                        : Math.max(0,   cur - 5)
                    audio.muted  = false
                    audio.volume = next / 100
                    AudioService.volumeChanged()
                    wheel.accepted = true
                }
            }
        }

        // Mic — click to toggle mute
        EHIcon {
            name:    root.micIconName
            size:    root.iconSz
            color:   root.micIconColor
            visible: root.showMicIcon

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked: AudioService.toggleMicMute()
            }
        }

        // Fallback settings cog
        EHIcon {
            name:    "settings"
            size:    root.iconSz
            color:   (controlCenterArea.containsMouse || root.isActive)
                     ? Theme.primary : Theme.surfaceText
            visible: root.showFallbackIcon
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // ── Click — open control center ───────────────────────────────────────────
    MouseArea {
        id: controlCenterArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            if (popupTarget) popupTarget.toggle()
            root.clicked()
        }
        onPressAndHold: {
            if (popupTarget?.showContextMenu) {
                const r = parent.mapToItem(null, 0, 0, width, height)
                popupTarget.showContextMenu(r.x + r.width / 2, r.y + r.height / 2, parentScreen)
            }
        }
    }
}
