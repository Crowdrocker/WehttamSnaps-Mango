// Dash calendar — layout + styling aligned with Modules/Calendar/CalendarModal (calGridArea month grid).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    anchors.fill: parent
    clip: true

    /// Event Horizon home column: hide chrome below grid, tighter scale so month fits a small square.
    property bool squareHomeEmbed: false
    /// Event Horizon dash: panel fill alpha multiplier (read from settings; avoids parent property on this type).
    readonly property real _ehChromeBg: SettingsData.desktopEventHorizonChromeBackgroundOpacity
    function bgA(a) {
        return Math.min(1, Math.max(0, a * _ehChromeBg))
    }

    property date selectedDate: new Date()
    property date displayDate: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property var selectedDateEvents: []

    /// Same idea as CalendarModal `s` — scale chrome + grid to panel width (stronger when squareHomeEmbed).
    readonly property real s: root.squareHomeEmbed
            ? Math.max(0.34, Math.min(0.88, root.width / 230))
            : Math.max(0.48, Math.min(1.08, root.width / 400))

    function weekStartJs() { return Qt.locale().firstDayOfWeek % 7 }
    function startOfWeek(d) {
        const dt = new Date(d)
        const diff = (dt.getDay() - weekStartJs() + 7) % 7
        dt.setDate(dt.getDate() - diff)
        return dt
    }
    function endOfWeek(dateObj) {
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const add = (weekStartJs() + 6 - jsDow + 7) % 7
        d.setDate(d.getDate() + add)
        return d
    }
    function showPreviousMonth() {
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() - 1, 1)
    }
    function showNextMonth() {
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 1)
    }

    function loadEventsForVisibleMonth() {
        CalendarService.rebuildEventsByDateFromLocal()
        const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
        const lastOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 0)
        const startDate = startOfWeek(firstOfMonth)
        startDate.setDate(startDate.getDate() - 7)
        const endDate = endOfWeek(lastOfMonth)
        endDate.setDate(endDate.getDate() + 7)
        if (CalendarService.khalAvailable)
            CalendarService.loadEvents(startDate, endDate)
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
    }

    onSelectedDateChanged: {
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
    }
    onDisplayDateChanged: loadEventsForVisibleMonth()

    Component.onCompleted: {
        CalendarService.checkKhalAvailability()
        loadEventsForVisibleMonth()
    }

    Connections {
        target: CalendarService
        function onEventsByDateChanged() {
            root.selectedDateEvents = CalendarService.getEventsForDate(root.selectedDate)
        }
        function onKhalAvailableChanged() {
            if (CalendarService.khalAvailable)
                root.loadEventsForVisibleMonth()
        }
    }

    readonly property real gap: root.squareHomeEmbed
            ? Math.max(1, Math.round(3 * s))
            : Math.max(2, Math.round(4 * s))

    // Integer cell width + horizontal offset so weekday row and day grid share the same centerline (home embed).
    readonly property real gridCellWFloat: (width - gap * 6) / 7
    readonly property real gridCellWResolved: root.squareHomeEmbed
            ? Math.floor(gridCellWFloat)
            : gridCellWFloat
    readonly property real gridBodyX0: root.squareHomeEmbed
            ? (width - (7 * gridCellWResolved + 6 * gap)) * 0.5
            : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: root.squareHomeEmbed ? Theme.spacingXS : Theme.spacingM

        RowLayout {
            Layout.fillWidth: true
            spacing: root.squareHomeEmbed ? Theme.spacingXS : Theme.spacingS

            // Equal nav slots so "MMMM yyyy" centers over the weekday grid (chevrons no longer skew text).
            Item {
                Layout.preferredWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.minimumWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.maximumWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.preferredHeight: Math.round(36 * s)

                EHActionButton {
                    anchors.centerIn: parent
                    iconName: "chevron_left"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceVariantText
                    onClicked: root.showPreviousMonth()
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: displayDate && !isNaN(displayDate.getTime())
                      ? Qt.formatDate(displayDate, "MMMM yyyy")
                      : ""
                font.pixelSize: Math.round(Theme.fontSizeMedium * s)
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            Item {
                Layout.preferredWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.minimumWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.maximumWidth: root.squareHomeEmbed ? Math.round(34 * s) : Math.round(40 * s)
                Layout.preferredHeight: Math.round(36 * s)

                EHActionButton {
                    anchors.centerIn: parent
                    iconName: "chevron_right"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceVariantText
                    onClicked: root.showNextMonth()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.squareHomeEmbed && selectedDateEvents && selectedDateEvents.length > 0
            spacing: Theme.spacingXS

            StyledText {
                Layout.fillWidth: true
                text: "Events · " + Qt.formatDate(selectedDate, "MMM d")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
            }

            Column {
                Layout.fillWidth: true
                Layout.maximumHeight: Math.round(100 * s)
                spacing: Theme.spacingXS
                clip: true

                Repeater {
                    model: selectedDateEvents
                    delegate: RowLayout {
                        required property var modelData
                        width: parent.width
                        spacing: Theme.spacingS
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Weekday headers — same cell width / x-origin as month grid (home embed alignment).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round((root.squareHomeEmbed ? 16 : 22) * s)

            Row {
                id: dayHeaderRow
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.squareHomeEmbed
                    ? (7 * root.gridCellWResolved + 6 * root.gap)
                    : parent.width
                spacing: root.gap

                Repeater {
                    model: {
                        const days = ["S", "M", "T", "W", "T", "F", "S"]
                        const start = root.weekStartJs()
                        let out = []
                        for (let i = 0; i < 7; i++) out.push(days[(start + i) % 7])
                        return out
                    }
                    delegate: Item {
                        required property var modelData
                        width: (dayHeaderRow.width - root.gap * 6) / 7
                        height: dayHeaderRow.height
                        StyledText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Math.round(10 * s)
                            font.weight: Font.Bold
                            font.letterSpacing: 1.0
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.18))
        }

        // Month grid — fills remaining space (CalendarModal calGridArea pattern)
        Item {
            id: calGridArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Math.round((root.squareHomeEmbed ? 56 : 120) * s)

            readonly property real cellW: root.gridCellWResolved
            readonly property real cellH: (height - root.gap * 5) / 6

            readonly property date firstCell: {
                const d = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth(), 1)
                if (isNaN(d.getTime())) return new Date()
                return root.startOfWeek(d)
            }

            Repeater {
                model: 42
                delegate: Item {
                    required property int index

                    readonly property int col: index % 7
                    readonly property int row: Math.floor(index / 7)

                    x: root.gridBodyX0 + col * (calGridArea.cellW + root.gap)
                    y: row * (calGridArea.cellH + root.gap)
                    width: calGridArea.cellW
                    height: calGridArea.cellH

                    readonly property date dayDate: {
                        const d = new Date(calGridArea.firstCell)
                        if (isNaN(d.getTime())) return new Date()
                        d.setDate(d.getDate() + index)
                        return d
                    }
                    readonly property bool isCurrentMonth: dayDate.getMonth() === root.displayDate.getMonth()
                    readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                    readonly property bool isSelected: dayDate.toDateString() === root.selectedDate.toDateString()
                    readonly property bool isWeekend: dayDate.getDay() === 0 || dayDate.getDay() === 6

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: isWeekend
                               ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, root.bgA(0.10))
                               : "transparent"

                        border.color: isToday
                                      ? Theme.primary
                                      : isSelected
                                      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.40))
                                      : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.bgA(0.18))
                        border.width: (isToday || isSelected) ? 2 : 1

                        readonly property int bw: (isToday || isSelected) ? 2 : 1
                        readonly property int dateOffset: bw + Math.round(4 * s)

                        StyledText {
                            x: parent.dateOffset
                            y: parent.dateOffset
                            text: dayDate.getDate()
                            font.pixelSize: Math.round(11 * s)
                            font.weight: isToday ? Font.Bold : Font.Normal
                            color: isToday ? Theme.primary
                                 : isCurrentMonth ? Theme.surfaceText
                                 : Theme.surfaceVariantText
                            verticalAlignment: Text.AlignTop
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: isCurrentMonth
                        cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.selectedDate = dayDate
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.squareHomeEmbed
            spacing: Theme.spacingM

            StyledText {
                Layout.fillWidth: true
                text: selectedDate && !isNaN(selectedDate.getTime())
                      ? selectedDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy")
                      : ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }

            Rectangle {
                width: 56
                height: 26
                radius: 13
                color: todayMA.containsMouse
                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.18))
                       : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.10))
                StyledText {
                    anchors.centerIn: parent
                    text: "Today"
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Medium
                    color: Theme.primary
                }
                MouseArea {
                    id: todayMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = new Date()
                        root.displayDate = new Date(d.getFullYear(), d.getMonth(), 1)
                        root.selectedDate = d
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.squareHomeEmbed
            text: "Open full calendar"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.primary
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarModal.show()
            }
        }
    }
}
