// macOS-style digital clock: flat squircle, 3-letter location, 60-tick second ring (no gloss)
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var instanceData: null
    property var screen: null
    property real widgetWidth: 220
    property real widgetHeight: 220
    property real defaultWidth: 220
    property real defaultHeight: 220
    property real minWidth: 180
    property real minHeight: 180
    property bool forceSquare: true
    /// Softer corners for small tiles (e.g. Event Horizon home); default keeps 0.22 squircle.
    property bool semiRoundedCard: false
    /// Event Horizon: multiply card fill alpha only (time/text unchanged).
    property real chromeBackgroundOpacityScale: 1.0

    readonly property var cfg: instanceData?.config ?? {}
    readonly property real base: 220
    readonly property real sf: Math.min(widgetWidth / base, widgetHeight / base)

    readonly property real cornerR: {
        const m = Math.min(widgetWidth, widgetHeight)
        if (semiRoundedCard)
            return Math.min(20, m * 0.11)
        return m * 0.22
    }
    readonly property real tickRadius: (Math.min(widgetWidth, widgetHeight) - 36 * sf) / 2 - 6 * sf

    readonly property real glassAlpha: {
        const t = cfg.transparency
        if (t !== undefined && t !== null)
            return Math.max(0.4, Math.min(1, t))
        return 0.88
    }

    readonly property color cardFill: Qt.rgba(
        Theme.surfaceContainer.r,
        Theme.surfaceContainer.g,
        Theme.surfaceContainer.b,
        Math.min(1, glassAlpha * chromeBackgroundOpacityScale)
    )
    readonly property color timeColor: {
        Theme.colorUpdateTrigger
        if (cfg.wallpaperColors && Theme.matugenColors?.colors) {
            const m = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const p = Theme.matugenColors.colors.primary?.[m]
            if (p)
                return Qt.color(p)
        }
        return Theme.surfaceText
    }

    // Time line only: high-contrast (reference is bright white on dark glass)
    readonly property color displayTimeColor: {
        Theme.colorUpdateTrigger
        if (cfg.wallpaperColors && Theme.matugenColors?.colors) {
            const m = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const p = Theme.matugenColors.colors.primary?.[m]
            if (p)
                return Qt.color(p)
        }
        if (typeof SessionData !== "undefined" && SessionData.isLightMode)
            return Theme.surfaceText
        return Qt.rgba(1, 1, 1, 1)
    }

    // Bumps when clock format settings change so 12h/24h bindings always refresh (see TopBarClock)
    property int _formatTick: 0

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    // Qt: "h:mm" without AP uses hours 0–23 — split parts so colon can optically center (not baseline-low)
    readonly property string clockHourStr: {
        void _formatTick
        void SettingsData.use24HourClock
        if (!systemClock.date)
            return ""
        const d = systemClock.date
        if (SettingsData.use24HourClock)
            return String(d.getHours()).padStart(2, "0")
        const h24 = d.getHours()
        return String(((h24 + 11) % 12) + 1)
    }
    readonly property string clockMinuteStr: {
        void _formatTick
        void SettingsData.use24HourClock
        if (!systemClock.date)
            return ""
        return String(systemClock.date.getMinutes()).padStart(2, "0")
    }

    readonly property string clockPeriod: {
        void _formatTick
        void SettingsData.use24HourClock
        void SettingsData.showAmPmIn24Hour
        if (!systemClock.date)
            return ""
        const d = systemClock.date
        if (SettingsData.use24HourClock && !SettingsData.showAmPmIn24Hour)
            return ""
        const h24 = d.getHours()
        return h24 >= 12 ? "PM" : "AM"
    }

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    readonly property real secondProgress: {
        const s = systemClock.seconds
        const d = systemClock.date
        const ms = d ? d.getMilliseconds() : 0
        return s + ms / 1000
    }

    function locationTag() {
        const custom = (cfg.locationCode || "").trim().toUpperCase().replace(/[^A-Z]/g, "")
        if (custom.length >= 3)
            return custom.slice(0, 3)

        if (typeof WeatherService !== "undefined" && WeatherService.location && WeatherService.location.city) {
            const c = String(WeatherService.location.city).replace(/[^a-zA-Z]/g, "").toUpperCase()
            if (c.length >= 3)
                return c.slice(0, 3)
            if (c.length > 0)
                return (c + "XXX").slice(0, 3)
        }
        if (typeof TimeService !== "undefined" && TimeService.currentTimezone) {
            const last = TimeService.currentTimezone.split("/").pop() || ""
            const letters = last.replace(/[^a-zA-Z]/g, "").toUpperCase()
            if (letters.length >= 3)
                return letters.slice(0, 3)
            if (letters.length > 0)
                return (letters + "XXX").slice(0, 3)
        }
        return "LOC"
    }

    function _onTimezoneChanged() {
        Date.timeZoneUpdated()
    }

    Connections {
        target: typeof TimeService !== "undefined" ? TimeService : null
        enabled: typeof TimeService !== "undefined"
        function onCurrentTimezoneChanged() { root._onTimezoneChanged() }
    }
    Connections {
        target: SettingsData
        function onSystemTimezoneChanged() { root._onTimezoneChanged() }
        function onUse24HourClockChanged() { _formatTick++ }
        function onShowAmPmIn24HourChanged() { _formatTick++ }
        function onWidgetDataChanged() { _formatTick++ }
    }
    Component.onCompleted: _onTimezoneChanged()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cornerR
        color: root.cardFill
        border.color: Qt.rgba(
            Theme.outline.r,
            Theme.outline.g,
            Theme.outline.b,
            SettingsData.desktopWidgetBorderOpacity ?? 0.22
        )
        border.width: Math.max(1, SettingsData.desktopWidgetBorderThickness ?? 1)
        antialiasing: true
        clip: true

        Item {
            id: ringHost
            anchors.fill: parent
            anchors.margins: 10 * root.sf

            Repeater {
                model: 60

                Item {
                    required property int index

                    width: 0
                    height: 0
                    x: ringHost.width / 2
                    y: ringHost.height / 2
                    rotation: index * 6

                    readonly property bool elapsed: index < root.secondProgress

                    Rectangle {
                        width: Math.max(2, 2.2 * root.sf)
                        height: 6.5 * root.sf
                        radius: width / 2
                        x: -width / 2
                        y: -root.tickRadius - height
                        color: elapsed
                            ? Qt.rgba(root.timeColor.r, root.timeColor.g, root.timeColor.b, 0.92)
                            : Qt.rgba(
                                Theme.surfaceVariantText.r,
                                Theme.surfaceVariantText.g,
                                Theme.surfaceVariantText.b,
                                0.28
                            )
                        antialiasing: true
                    }
                }
            }
        }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 2 * root.sf

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (typeof WeatherService !== "undefined")
                        void WeatherService.location
                    if (typeof TimeService !== "undefined")
                        void TimeService.currentTimezone
                    void cfg.locationCode
                    return root.locationTag()
                }
                font.pixelSize: Math.round(11 * root.sf)
                font.weight: Font.Medium
                font.letterSpacing: 2.2
                font.capitalization: Font.AllUppercase
                font.hintingPreference: SettingsData.fontHintingPreference
                renderType: SettingsData.fontRenderType
                color: Theme.surfaceVariantText
                opacity: 0.85
            }

            // Time + period stacked (12h: "9:29" / "PM"); avoids StyledText global font
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -4 * root.sf

                RowLayout {
                    id: timeDigitsRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(2 * root.sf)

                    Text {
                        id: hourDigits
                        Layout.alignment: Qt.AlignVCenter
                        text: root.clockHourStr
                        font.pixelSize: Math.round(43 * root.sf)
                        font.family: "SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
                        font.weight: Font.Bold
                        font.letterSpacing: -0.35
                        font.hintingPreference: Font.PreferDefaultHinting
                        renderType: Text.QtRendering
                        color: root.displayTimeColor
                        antialiasing: true
                    }
                    Text {
                        id: colonText
                        Layout.alignment: Qt.AlignVCenter
                        text: ":"
                        font: hourDigits.font
                        color: root.displayTimeColor
                        antialiasing: true
                    }
                    Text {
                        id: minuteDigits
                        Layout.alignment: Qt.AlignVCenter
                        text: root.clockMinuteStr
                        font: hourDigits.font
                        color: root.displayTimeColor
                        antialiasing: true
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.clockPeriod.length > 0
                    text: root.clockPeriod
                    font.pixelSize: Math.round(17 * root.sf)
                    font.family: "SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
                    font.weight: Font.Medium
                    font.letterSpacing: 2.4
                    font.hintingPreference: Font.PreferDefaultHinting
                    renderType: Text.QtRendering
                    color: root.displayTimeColor
                    opacity: 0.88
                    horizontalAlignment: Text.AlignHCenter
                    antialiasing: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
        }
    }
}
