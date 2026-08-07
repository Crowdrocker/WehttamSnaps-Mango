import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Widgets

Item {
    id: root

    property date currentDate: new Date()
    property var eventsForToday: []
    property bool showCalendar: false

    width: 120
    height: 60

    // Clock display
    Column {
        anchors.centerIn: parent
        spacing: 2

        StyledText {
            id: timeText
            text: currentDate.toLocaleTimeString(Qt.locale(), "hh:mm")
            font.pixelSize: 24
            font.weight: Font.Bold
            color: Theme.primary
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            id: dateText
            text: currentDate.toLocaleDateString(Qt.locale(), "ddd, MMM d")
            font.pixelSize: 12
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignHCenter
        }

        // Events indicator
        Row {
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
            visible: eventsForToday.length > 0

            Repeater {
                model: Math.min(eventsForToday.length, 3)
                delegate: Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: index === 0 ? Theme.primary : Theme.secondary
                }
            }

            StyledText {
                text: "+" + (eventsForToday.length - 3 > 0 ? (eventsForToday.length - 3) : 0)
                font.pixelSize: 10
                color: Theme.surfaceVariantText
                visible: eventsForToday.length > 3
            }
        }
    }

    // Click area to open calendar
    MouseArea {
        anchors.fill: parent
        onClicked: {
            showCalendar = true
            CalendarPopup.open()
        }
    }

    // Update time every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            currentDate = new Date()
            eventsForToday = CalendarService.getEventsForDate(currentDate)
        }
    }

    // Calendar popup reference
    CalendarPopup {
        id: CalendarPopup
        visible: showCalendar
        onVisibleChanged: {
            if (!visible) {
                showCalendar = false
            }
        }
    }

    // Update calendar when date changes
    Connections {
        target: CalendarService
        function onEventsByDateChanged() {
            eventsForToday = CalendarService.getEventsForDate(currentDate)
        }
    }

    Component.onCompleted: {
        eventsForToday = CalendarService.getEventsForDate(currentDate)
    }
}