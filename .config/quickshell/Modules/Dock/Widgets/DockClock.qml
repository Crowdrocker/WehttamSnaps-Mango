import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool   compactMode: false
    property string section:     "center"
    property var    popupTarget: null
    property var    parentScreen: null
    property real   barHeight:   48
    property real   widgetHeight: 30
    property bool   isBarVertical: false

    readonly property bool useStackedFormat:   SettingsData.clockStackedFormat
    readonly property real horizontalPadding:  SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    readonly property real dockFontScale:      SettingsData.dockClockFontSize
    readonly property bool useDock12Hour:      SettingsData.dockClockUse12Hour
    readonly property bool dockShowAmPm:       SettingsData.dockClockShowAmPm
    readonly property bool dockShowSeconds:    SettingsData.dockClockShowSeconds
    readonly property bool dockShowFullDate:   SettingsData.dockClockShowFullDate

    signal clockClicked
    signal openCalendarPopup()

    function dockTimeFormat() {
        return useDock12Hour
            ? (dockShowSeconds ? "h:mm:ss AP" : "h:mm AP")
            : (dockShowSeconds ? "HH:mm:ss" : "HH:mm")
    }

    function dockTimeString() {
        var t = Qt.formatTime(systemClock.date, dockTimeFormat()).replace(/\./g, "").trim()
        if (useDock12Hour && !dockShowAmPm)
            t = t.replace(/\s*(AM|PM|am|pm)\s*$/i, "").trim()
        return t
    }

    function dockDateString() {
        if (!systemClock?.date) return ""
        if (dockShowFullDate)
            return systemClock.date.toLocaleDateString(Qt.locale(), "ddd d MMM")
        if (SettingsData.clockDateFormat?.length > 0)
            return systemClock.date.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat)
        return systemClock.date.toLocaleDateString(Qt.locale(), "ddd d")
    }

    // ── Vertical text helpers ─────────────────────────────────────────────────
    readonly property var verticalTextParts: {
        root.formatUpdateTrigger
        if (!systemClock?.date) return []

        var parts = []
        if (dockShowFullDate) {
            parts.push(systemClock.date.toLocaleDateString(Qt.locale(), "ddd d MMM"))
        } else if (!SettingsData.clockCompactMode) {
            var dayName = systemClock.date.toLocaleDateString(Qt.locale(), "ddd")
            var dayNum  = systemClock.date.toLocaleDateString(Qt.locale(), "d")
            parts.push(dayName + " " + dayNum)
        }
        parts.push(dockTimeString())
        return parts
    }

    // ── Geometry & appearance ─────────────────────────────────────────────────
    width:  useStackedFormat
            ? (clockColumn.implicitWidth  + horizontalPadding * 2 + 2)
            : (clockRow.implicitWidth     + horizontalPadding * 2 + 2)
    height: useStackedFormat
            ? (clockColumn.implicitHeight + horizontalPadding * 2)
            : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const base = clockMouseArea.containsMouse
                     ? Theme.widgetBaseHoverColor
                     : Theme.widgetBaseBackgroundColor
        return Qt.rgba(base.r, base.g, base.b, base.a * Theme.widgetTransparency)
    }

    // ── Inline (horizontal) display ───────────────────────────────────────────
    Row {
        id:      clockRow
        visible: !useStackedFormat
        anchors.centerIn: parent
        spacing: Theme.spacingS

        StyledText {
            id: clockTimeText
            text: {
                root.formatUpdateTrigger
                if (!systemClock?.date) return ""
                return dockTimeString()
            }
            font.pixelSize: (Theme.fontSizeMedium - 1) * (widgetHeight / 30) * dockFontScale
            font.weight:    SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color:          Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text:    "•"
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30) * dockFontScale
            color:   Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
        }

        StyledText {
            text: {
                root.formatUpdateTrigger
                return dockDateString()
            }
            font.pixelSize: (Theme.fontSizeMedium - 1) * (widgetHeight / 30) * dockFontScale
            font.weight:    SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color:          Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
        }
    }

    // ── Stacked (vertical) display ────────────────────────────────────────────
    Column {
        id:      clockColumn
        visible: useStackedFormat
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        width:   implicitWidth

        Repeater {
            model: root.verticalTextParts
            delegate: StyledText {
                text:           modelData
                font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30) * dockFontScale
                font.weight:    SettingsData.clockBoldFont ? Font.Bold : Font.Normal
                color:          Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
            }
        }
    }

    // ── System clock ──────────────────────────────────────────────────────────
    SystemClock {
        id:        systemClock
        precision: dockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    property int formatUpdateTrigger: 0

    Connections {
        target: SettingsData
        function onUse24HourClockChanged()      { formatUpdateTrigger++ }
        function onShowAmPmIn24HourChanged()    { formatUpdateTrigger++ }
        function onWidgetDataChanged()          { formatUpdateTrigger++ }
        function onDockClockUse12HourChanged()  { formatUpdateTrigger++ }
        function onDockClockShowAmPmChanged()   { formatUpdateTrigger++ }
        function onDockClockShowSecondsChanged() { formatUpdateTrigger++ }
        function onDockClockShowFullDateChanged() { formatUpdateTrigger++ }
        function onDockClockFontSizeChanged()   { formatUpdateTrigger++ }
    }

    // ── Interaction ───────────────────────────────────────────────────────────
    MouseArea {
        id:           clockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            root.clockClicked()
            root.openCalendarPopup()
        }
    }
}
