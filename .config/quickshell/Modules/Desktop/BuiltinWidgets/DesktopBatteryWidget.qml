// DesktopBatteryWidget.qml
// macOS Tahoe-style battery widget for Quickshell on Linux
// Displays system battery + all connected Bluetooth device batteries
// Uses: `qs.Services.BatteryService` (+ `qs.Services.BluetoothService` via the service)

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    // ── Widget contract ──────────────────────────────────────────────────────
    property string instanceId: ""
    property var    instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    // Match other desktop widgets: optional matugen wallpaper colors + opacity.
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : (SettingsData.desktopWidgetWallpaperColors ?? false)
    // Use global battery opacity slider (like other widgets use popup-style controls).
    property real widgetOpacity: (SettingsData.batteryPopupTransparency ?? 0.92)
    readonly property var matugenColorNames: [ "primary_container", "secondary_container", "tertiary_container" ]
    function getMatugenColor(index) {
        Theme.colorUpdateTrigger
        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const name = matugenColorNames[index % matugenColorNames.length]
            const mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const v = Theme.matugenColors.colors[name]?.[mode]
            if (v) return v
        }
        return null
    }

    property real widgetWidth:  defaultWidth
    property real widgetHeight: defaultHeight
    property real defaultWidth:  380
    // defaultHeight tracks content (grows as devices appear)
    property real defaultHeight: designHeight
    property real minWidth:  260
    property real minHeight: Math.round(designHeight * 0.75)

    width:  widgetWidth
    height: widgetHeight

    readonly property int  designWidth:  380
    readonly property int  headerHeight: 46
    readonly property int  dividerHeight: 1
    readonly property int  contentMargin: 20
    readonly property int  contentSpacing: 14
    // Stable-surface height grows with actual content height.
    // This avoids “extra” Flickable scrolling when only a few devices exist.
    readonly property int  designHeight: Math.max(
        320,
        contentMargin * 2 +
        headerHeight +
        dividerHeight +
        contentSpacing * 2 +
        Math.round(tilesFlow.implicitHeight)
    )
    readonly property real s: Math.max(0.01, Math.min(widgetWidth / designWidth, widgetHeight / designHeight))

    // Data source: always use `BatteryService`

    // ── Battery icon helper ──────────────────────────────────────────────────
    function batteryIconFor(pct, charging, pluggedIn) {
        if (pct < 0) return "battery_unknown"
        if (charging || pluggedIn) {
            if (pct >= 90) return "battery_charging_full"
            if (pct >= 70) return "battery_charging_80"
            if (pct >= 50) return "battery_charging_60"
            if (pct >= 30) return "battery_charging_50"
            if (pct >= 15) return "battery_charging_30"
            return "battery_charging_20"
        }
        if (pct >= 95) return "battery_full"
        if (pct >= 80) return "battery_6_bar"
        if (pct >= 65) return "battery_5_bar"
        if (pct >= 50) return "battery_4_bar"
        if (pct >= 35) return "battery_3_bar"
        if (pct >= 20) return "battery_2_bar"
        return "battery_1_bar"
    }

    function btIconFor(type) {
        const t = String(type).toLowerCase()
        if (t.includes("headphone") || t.includes("headset")) return "headphones"
        if (t.includes("phone"))    return "smartphone"
        if (t.includes("keyboard")) return "keyboard"
        if (t.includes("mouse"))    return "mouse"
        if (t.includes("game") || t.includes("gamepad") || t.includes("controller")) return "sports_esports"
        if (t.includes("speaker"))  return "speaker"
        if (t.includes("watch"))    return "watch"
        if (t.includes("system"))   return "battery_full"
        return "bluetooth"
    }

    function formatTime(secs) {
        if (!secs || secs <= 0 || secs > 86400) return ""
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    // ── Device tile model (BatteryService) ───────────────────────────────────
    readonly property var tiles: {
        const out = []

        if (BatteryService.batteryAvailable) {
            const pct = BatteryService.batteryLevel
            out.push({
                kind:       "system",
                name:       "System",
                subtitle:   BatteryService.batteryStatus + (BatteryService.formatTimeRemaining() ? (" · " + BatteryService.formatTimeRemaining()) : ""),
                percentage: pct,
                icon:       BatteryService.getBatteryIcon(),
                charging:   BatteryService.isCharging,
                pluggedIn:  BatteryService.isPluggedIn,
                lowAlert:   BatteryService.isLowBattery
            })
        }

        const devs = BatteryService.devices || BatteryService.bluetoothDevices || []
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            const pct2 = (d.percentage !== undefined && d.percentage !== null) ? Math.round(d.percentage) : -1
            out.push({
                kind:       "device",
                name:       d.name || "Device",
                subtitle:   (d.type ? String(d.type) : "Device"),
                percentage: pct2,
                icon:       btIconFor(d.type),
                charging:   false,
                pluggedIn:  false,
                lowAlert:   (pct2 >= 0 && pct2 <= 20)
            })
        }

        return out
    }

    // ── Palette aligned with other widgets (Theme + Matugen) ─────────────────
    readonly property color cardBase: {
        const a = Math.max(0.55, root.widgetOpacity)
        const mc = root.getMatugenColor(0)
        if (mc) {
            const c = Qt.color(mc)
            return Qt.rgba(c.r, c.g, c.b, a)
        }
        return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, a)
    }
    readonly property color cardBorder: SettingsData.batteryPopupDynamicBorderColors
        ? Theme.primary
        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.batteryPopupBorderOpacity ?? 0.30)
    readonly property color glassTop:   Qt.rgba(1, 1, 1, 0.05)
    readonly property color labelPrimary: Theme.surfaceText
    readonly property color labelSecond:  Theme.surfaceVariantText
    readonly property color accent:       Theme.primary
    readonly property color accentLow:    Theme.error
    readonly property color accentCharge: Theme.tertiary ?? Theme.primary
    readonly property color trackBg:      Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
    readonly property color iconBg:       Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.22)

    // ── Root surface ─────────────────────────────────────────────────────────
    Item {
        id: surface
        width:  root.designWidth
        height: root.designHeight
        anchors.centerIn: parent
        scale: root.s
        transformOrigin: Item.Center

        // Outer glass card
        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.cornerRadius
            color:  root.cardBase
            border.color: root.cardBorder
            border.width: SettingsData.batteryPopupBorderEnabled
                ? Math.max(2, SettingsData.batteryPopupBorderThickness ?? 2)
                : 0
            antialiasing: true
            clip: true

            // Specular top-glass highlight (Tahoe signature)
            Rectangle {
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   parent.top
                height: parent.height * 0.38
                radius: parent.radius
                color:  root.glassTop
            }

            // Bottom depth bleed
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                height: parent.height * 0.20
                radius: parent.radius
                color: Qt.rgba(0,0,0,0.10)
            }

            // ── Content ──────────────────────────────────────────────────────
            Column {
                anchors.fill:    parent
                anchors.margins: Theme.spacingM
                spacing: 14

                // ── Widget header ─────────────────────────────────────────────
                Item {
                    width:  parent.width
                    height: 46

                    // Icon pill
                    Rectangle {
                        id: headerIcon
                        width: 36; height: 36
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

                        EHIcon {
                            anchors.centerIn: parent
                            name: "battery_full"
                            size: 18
                            color: root.accent
                        }
                    }

                    Column {
                        anchors.left:           headerIcon.right
                        anchors.leftMargin:     10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Battery"
                            color: root.labelPrimary
                            font { pixelSize: 17; weight: Font.DemiBold; family: "SF Pro Display, -apple-system, Helvetica Neue, sans-serif" }
                        }
                        Text {
                            text: {
                                const n = root.tiles.length
                                if (n === 0) return "No devices"
                                if (n === 1) return "1 device"
                                return n + " devices"
                            }
                            color: root.labelSecond
                            font { pixelSize: 12; family: "SF Pro Text, -apple-system, Helvetica Neue, sans-serif" }
                        }
                    }

                    // No embedded scrape indicator; BatteryService updates are automatic.
                }

                // ── Divider ───────────────────────────────────────────────────
                Rectangle {
                    width: parent.width; height: 1
                    color: root.cardBorder
                }

                // ── Tiles grid ────────────────────────────────────────────────
                Flickable {
                    width:  parent.width
                    readonly property real availableH: parent.height - headerHeight - dividerHeight - contentSpacing * 2
                    height: Math.min(tilesFlow.implicitHeight, Math.max(0, availableH))
                    clip:   true
                    contentWidth:  width
                    contentHeight: tilesFlow.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Flow {
                        id: tilesFlow
                        width: parent.width
                        spacing: 10

                        Repeater {
                            model: root.tiles
                            delegate: BatteryCard {
                                required property var modelData
                                // If the device name is long, let the tile span full width.
                                readonly property real halfW: (tilesFlow.width - tilesFlow.spacing) * 0.5 - tilesFlow.spacing * 0.5
                                TextMetrics {
                                    id: _nameMetrics
                                    text: (modelData?.name ?? "")
                                    font.pixelSize: 13
                                    font.family: "SF Pro Text, -apple-system, sans-serif"
                                    font.weight: Font.DemiBold
                                }
                                readonly property bool wantsWide: _nameMetrics.width > (halfW - 86)
                                width: wantsWide ? tilesFlow.width : halfW
                                tileData: modelData
                            }
                        }

                        // Empty state
                        Item {
                            visible: root.tiles.length === 0
                            width: tilesFlow.width
                            height: 160

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                EHIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "battery_unknown"
                                    size: 36
                                    color: root.labelSecond
                                    opacity: 0.55
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No battery data"
                                    color: root.labelSecond
                                    font { pixelSize: 13; family: "SF Pro Text, -apple-system, sans-serif" }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── BatteryCard component ────────────────────────────────────────────────
    component BatteryCard: Item {
        id: tileRoot
        property var tileData: null
        height: 128

        readonly property int   pct:      tileData?.percentage ?? -1
        readonly property bool  charging: tileData?.charging   ?? false
        readonly property bool  plugged:  tileData?.pluggedIn  ?? false
        readonly property bool  lowAlert: tileData?.lowAlert   ?? false
        readonly property real  fill:     Math.max(0, Math.min(1, pct < 0 ? 0 : pct / 100.0))

        readonly property color barColor: {
            if (lowAlert)  return root.accentLow
            if (charging)  return root.accentCharge
            if (pct >= 50) return root.accent
            return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.75)
        }

        // Card background
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
            border.width: 1
            antialiasing: true
            clip: true

            // Subtle glass sheen
            Rectangle {
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   parent.top
                height: parent.height * 0.45
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // Hover effect
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(1,1,1, hoverArea.containsMouse ? 0.05 : 0)
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Column {
            anchors.fill:    parent
            anchors.margins: 14
            spacing: 10

            // ── Top row: icon + name + percentage ────────────────────────────
            Row {
                width:   parent.width
                height:  36
                spacing: 10

                // Device icon pill
                Rectangle {
                    width: 36; height: 36
                    radius: 11
                    color: root.iconBg
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                    border.width: 1
                    antialiasing: true
                    anchors.verticalCenter: parent.verticalCenter

                    EHIcon {
                        anchors.centerIn: parent
                        name: tileRoot.tileData?.icon ?? "battery_unknown"
                        size: 18
                        color: root.labelPrimary
                        opacity: 0.9
                    }
                }

                // Name + subtitle
                Column {
                    width:  parent.width - 36 - 10 - 42
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text:  tileRoot.tileData?.name ?? ""
                        color: root.labelPrimary
                        font { pixelSize: 13; weight: Font.Medium; family: "SF Pro Text, -apple-system, sans-serif" }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        width: parent.width
                        text:  tileRoot.tileData?.subtitle ?? ""
                        color: root.labelSecond
                        font { pixelSize: 11; family: "SF Pro Text, -apple-system, sans-serif" }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }

                // Percentage badge
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  pct < 0 ? "–%" : (pct + "%")
                    color: tileRoot.barColor
                    font { pixelSize: 15; weight: Font.DemiBold; family: "SF Pro Display, -apple-system, sans-serif" }
                }
            }

            // ── Battery bar ───────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 22

                // Track
                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: height / 2
                    color: root.trackBg
                    antialiasing: true
                    clip: true

                    // Fill — animated
                    Rectangle {
                        id: fillRect
                        width: track.width * tileRoot.fill
                        height: track.height
                        anchors.left: parent.left
                        radius: track.radius
                        antialiasing: true
                        color: tileRoot.barColor

                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                        // Inner gloss
                        Rectangle {
                            anchors.left:  parent.left
                            anchors.right: parent.right
                            anchors.top:   parent.top
                            height: parent.height * 0.5
                            radius: parent.radius
                            color: Qt.rgba(1,1,1,0.20)
                        }
                    }

                    // Charging bolt overlay
                    EHIcon {
                        anchors.centerIn: parent
                        visible: (tileRoot.charging || tileRoot.plugged) && tileRoot.pct >= 0
                        name: "bolt"
                        size: 14
                        color: root.labelPrimary
                        opacity: 0.85
                    }
                }

                // Low battery pulse glow
                Rectangle {
                    anchors.fill: track
                    radius: track.radius
                    color: "transparent"
                    border.color: root.accentLow
                    border.width: 1.5
                    antialiasing: true
                    visible: tileRoot.lowAlert

                    SequentialAnimation on opacity {
                        running: tileRoot.lowAlert
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // No embedded scrape
}
