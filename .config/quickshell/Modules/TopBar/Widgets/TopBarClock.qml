import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services

Rectangle {
    id: root

    property bool compactMode: false
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property bool useStackedFormat: SettingsData.clockStackedFormat || isBarVertical
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

    readonly property real scaledFontSize: root.widgetHeight * 0.4
    readonly property real scaledSmallFontSize: root.widgetHeight * 0.33
    readonly property real verticalPadding: root.widgetHeight * 0.1

    property bool showCalendar: false

    signal clockClicked

    readonly property var verticalTextParts: {
        root.formatUpdateTrigger
        if (!systemClock?.date) return []
        

        var parts = []

        if (root.isBarVertical) {
            var hours = Qt.formatTime(systemClock.date, SettingsData.use24HourClock ? "HH" : "hh")
            var minutes = Qt.formatTime(systemClock.date, "mm")
            var ampm = SettingsData.use24HourClock ? "" : Qt.formatTime(systemClock.date, "ap").toLowerCase()

            parts.push(hours)
            parts.push(minutes)
            if (ampm) {
                parts.push(ampm)
            }
        } else {
            if (!SettingsData.clockCompactMode) {
                var dayName = systemClock.date.toLocaleDateString(Qt.locale(), "ddd")
                var dayNum = systemClock.date.toLocaleDateString(Qt.locale(), "d")
                parts.push(dayName + " " + dayNum)
            }
            var timeStr = Qt.formatTime(systemClock.date, SettingsData.getEffectiveTimeFormat()).replace(/\./g, "").trim()
            parts.push(timeStr)
        }return parts
    }

    width: isBarVertical && !useStackedFormat ? widgetHeight : (isBarVertical && useStackedFormat ? (clockColumn.implicitWidth + horizontalPadding * 2) : (useStackedFormat ? Math.max(widgetHeight, clockColumn.implicitWidth + horizontalPadding * 2 + 2) : (clockRow.implicitWidth + horizontalPadding * 2 + 2)))
    height: isBarVertical && !useStackedFormat ? (clockRow.implicitWidth + horizontalPadding * 2 + 2) : (isBarVertical && useStackedFormat ? (clockColumn.implicitHeight + verticalPadding * 2) : (useStackedFormat ? (clockColumn.implicitHeight + horizontalPadding * 2) : widgetHeight))
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = clockMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    // Ensure no border
    border.width: 0
    border.color: "transparent"

    Row {
        id: clockRow
        visible: !useStackedFormat
        anchors.centerIn: parent
        spacing: (root.widgetHeight || 30) * 0.15
        rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? 90 : -90) : 0

        StyledText {
            id: clockTimeText
            text: {

                root.formatUpdateTrigger
                const use24Hour = SettingsData.use24HourClock
                if (!systemClock?.date) return ""
                
                return Qt.formatTime(systemClock.date, SettingsData.getEffectiveTimeFormat()).replace(/\./g, "").trim()
            }
            font.pixelSize: root.scaledFontSize
            font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
            
        }

        StyledText {
            text: {
                if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0) {
                    return systemClock?.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat)
                }

                return systemClock?.date?.toLocaleDateString(Qt.locale(), "ddd d")
            }
            font.pixelSize: root.scaledFontSize
            font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
            
        }
    }
    


    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
    

    property int formatUpdateTrigger: 0
    

    Connections {
        target: SettingsData
        function onUse24HourClockChanged() {
            formatUpdateTrigger++
        }
        function onShowAmPmIn24HourChanged() {
            formatUpdateTrigger++
        }
        function onWidgetDataChanged() {
            formatUpdateTrigger++
        }
    }

    MouseArea {
        id: clockMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            showCalendar = !showCalendar

            const rect = root.mapToItem(null, 0, 0, root.width, root.height)
            const currentScreen = parentScreen || Screen
            calendarPopup.parentScreen = currentScreen
            // Keep calendar popout size independent of topbarScale.
            // (TopBar scale affects placement via barThickness, not popup content size.)
            calendarPopup.panelScale = 1.0
            calendarPopup.barPosition = SettingsData.topBarPosition || "top"
            calendarPopup.barThickness = (SettingsData.topBarHeight || 40) * (SettingsData.topbarScale || 1.0)
            calendarPopup.triggerX = rect.x
            calendarPopup.triggerY = rect.y
            calendarPopup.triggerWidth = rect.width

            if (showCalendar) calendarPopup.open()
            else calendarPopup.close()

            root.clockClicked()
        }
    }

    Column {
        id: clockColumn
        visible: useStackedFormat
        anchors.centerIn: parent
        spacing: (root.widgetHeight || 30) * 0.15
        width: implicitWidth

        Repeater {
            model: root.verticalTextParts
            delegate: StyledText {
                text: modelData
                font.pixelSize: root.isBarVertical ? root.scaledSmallFontSize : root.scaledFontSize
                font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
            }
        }
    }

    CalendarPopup {
        id: calendarPopup
    }

}
