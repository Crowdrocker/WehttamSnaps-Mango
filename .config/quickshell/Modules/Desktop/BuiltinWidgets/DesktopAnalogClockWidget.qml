// Analog desktop clock — semi-rounded card
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? {}

    property real widgetWidth: 220
    property real widgetHeight: 220
    property real defaultWidth: 220
    property real defaultHeight: 220
    property real minWidth: 160
    property real minHeight: 160
    property bool forceSquare: true

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    readonly property real base: 220
    readonly property real sf: Math.min(widgetWidth / base, widgetHeight / base)
    readonly property bool showSeconds: cfg.showSeconds !== false
    readonly property real glassAlpha: {
        const t = cfg.transparency
        if (t !== undefined && t !== null)
            return Math.max(0.35, Math.min(1, t))
        return 0.72
    }

    readonly property color cardBase: Qt.rgba(
        Theme.surfaceContainer.r,
        Theme.surfaceContainer.g,
        Theme.surfaceContainer.b,
        glassAlpha
    )
    readonly property color cardBorder: Qt.rgba(
        Theme.outline.r,
        Theme.outline.g,
        Theme.outline.b,
        SettingsData.desktopWidgetBorderOpacity ?? 0.28
    )
    readonly property real cornerR: Math.min(widgetWidth, widgetHeight) * 0.19

    SystemClock {
        id: systemClock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // Local wall time from SystemClock (same source as bar/dock clocks). Integer
    // parts from Qt avoid JS Date TZ drift; ms only from date for smooth hands.
    property int _tzEpoch: 0
    readonly property real h12: {
        void _tzEpoch
        const h = systemClock.hours
        const m = systemClock.minutes
        const s = systemClock.seconds
        const d = systemClock.date
        const ms = d ? d.getMilliseconds() : 0
        let hour = h % 12
        return hour + m / 60 + (root.showSeconds ? (s + ms / 1000) / 3600 : 0)
    }
    readonly property real minuteFloat: {
        void _tzEpoch
        const m = systemClock.minutes
        const s = systemClock.seconds
        const d = systemClock.date
        const ms = d ? d.getMilliseconds() : 0
        return m + (root.showSeconds ? (s + ms / 1000) / 60 : 0)
    }
    readonly property real secondFloat: {
        void _tzEpoch
        const s = systemClock.seconds
        const d = systemClock.date
        const ms = d ? d.getMilliseconds() : 0
        return s + ms / 1000
    }

    function _onTimezoneChanged() {
        Date.timeZoneUpdated()
        _tzEpoch += 1
    }

    Connections {
        target: typeof TimeService !== "undefined" ? TimeService : null
        enabled: typeof TimeService !== "undefined"
        function onCurrentTimezoneChanged() { root._onTimezoneChanged() }
    }
    Connections {
        target: SettingsData
        function onSystemTimezoneChanged() { root._onTimezoneChanged() }
    }
    Component.onCompleted: _onTimezoneChanged()

    readonly property real hourDeg: h12 * 30
    readonly property real minuteDeg: minuteFloat * 6
    readonly property real secondDeg: secondFloat * 6

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cornerR
        color: root.cardBase
        border.color: root.cardBorder
        border.width: Math.max(1, SettingsData.desktopWidgetBorderThickness ?? 1)
        antialiasing: true
        clip: true

        Item {
            id: face
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) - 28 * root.sf
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.35)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
            }

            Repeater {
                model: 12
                Item {
                    required property int index
                    width: face.width
                    height: face.height
                    rotation: index * 30

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 4 * root.sf
                        width: (index % 3 === 0 ? 2.2 : 1.2) * root.sf
                        height: (index % 3 === 0 ? 10 : 6) * root.sf
                        radius: width / 2
                        color: Theme.surfaceVariantText
                        opacity: 0.85
                    }
                }
            }

            Item {
                id: pivot
                anchors.centerIn: parent
                width: 0
                height: 0

                Rectangle {
                    id: hourHand
                    width: 5 * root.sf
                    height: face.width * 0.26
                    radius: width / 2
                    x: -width / 2
                    y: -height
                    color: Theme.surfaceText
                    opacity: 0.92
                    transformOrigin: Item.Bottom
                    rotation: root.hourDeg
                    antialiasing: true
                }
                Rectangle {
                    id: minuteHand
                    width: 3.2 * root.sf
                    height: face.width * 0.38
                    radius: width / 2
                    x: -width / 2
                    y: -height
                    color: Theme.primary
                    transformOrigin: Item.Bottom
                    rotation: root.minuteDeg
                    antialiasing: true
                }
                Rectangle {
                    visible: root.showSeconds
                    width: 1.8 * root.sf
                    height: face.width * 0.42
                    radius: width / 2
                    x: -width / 2
                    y: -height
                    color: Theme.tertiary ?? Theme.error
                    opacity: 0.9
                    transformOrigin: Item.Bottom
                    rotation: root.secondDeg
                    antialiasing: true
                }
                Rectangle {
                    width: 8 * root.sf
                    height: 8 * root.sf
                    radius: width / 2
                    x: -width / 2
                    y: -height / 2
                    color: Theme.surfaceText
                    border.color: Theme.primary
                    border.width: 1
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
