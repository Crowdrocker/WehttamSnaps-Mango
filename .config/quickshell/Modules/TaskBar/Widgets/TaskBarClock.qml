import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool compactMode: false
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property bool useStackedFormat: SettingsData.clockStackedFormat
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

    signal clockClicked
    signal openCalendarPopup()

    readonly property var verticalTextParts: {
        root.formatUpdateTrigger
        if (!systemClock?.date) return []
        
        var parts = []
        

        if (!SettingsData.clockCompactMode) {
            var dayName = systemClock.date.toLocaleDateString(Qt.locale(), "ddd")
            var dayNum = systemClock.date.toLocaleDateString(Qt.locale(), "d")
            parts.push(dayName + " " + dayNum)
        }
        

        var timeStr = Qt.formatTime(systemClock.date, SettingsData.getEffectiveTimeFormat()).replace(/\./g, "").trim()
        parts.push(timeStr)
        
        return parts
    }

    width: isBarVertical && !useStackedFormat ? widgetHeight : (isBarVertical && useStackedFormat ? (clockColumn.implicitHeight + horizontalPadding * 2) : (useStackedFormat ? Math.max(widgetHeight, clockColumn.implicitWidth + horizontalPadding * 2 + 2) : (clockRow.implicitWidth + horizontalPadding * 2 + 2)))
    height: isBarVertical && !useStackedFormat ? (clockRow.implicitWidth + horizontalPadding * 2 + 2) : (isBarVertical && useStackedFormat ? (clockColumn.implicitWidth + horizontalPadding * 2 + 2) : (useStackedFormat ? (clockColumn.implicitHeight + horizontalPadding * 2) : widgetHeight))
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = clockMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        // Match exact opacity of other widgets
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }


    Row {
        id: clockRow
        visible: !useStackedFormat
        anchors.centerIn: parent
        spacing: Theme.spacingS
        rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? 90 : -90) : 0

        StyledText {
            id: clockTimeText
            text: {

                root.formatUpdateTrigger
                const use24Hour = SettingsData.use24HourClock
                if (!systemClock?.date) return ""
                
                return Qt.formatTime(systemClock.date, SettingsData.getEffectiveTimeFormat()).replace(/\./g, "").trim()
            }
            font.pixelSize: (Theme.fontSizeMedium - 1) * (widgetHeight / 30)
            font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
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
            font.pixelSize: (Theme.fontSizeMedium - 1) * (widgetHeight / 30)
            font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.clockCompactMode
            
        }
    }
    
    Column {
        id: clockColumn
        visible: useStackedFormat
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        width: implicitWidth

        Repeater {
            model: root.verticalTextParts
            delegate: StyledText {
                text: modelData
                font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
                font.weight: SettingsData.clockBoldFont ? Font.Bold : Font.Normal
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                
            }
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
            root.clockClicked()
            root.openCalendarPopup()
        }
    }

}
