import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Calendar

FloatingWindow {
    id: calendarModal

    function show()   { visible = true  }
    function hide()   { visible = false }
    function toggle() { visible = !visible }

    objectName: "calendarModal"
    title: "Calendar"
    minimumSize: Qt.size(800, 560)
    implicitWidth:  1100
    implicitHeight: 720
    backgroundColor: Theme.surfaceContainer
    visible: false

    readonly property real sW: width  / 1100
    readonly property real sH: (height - titleBar.height) / (720 - 44)
    readonly property real s:  Math.max(0.45, Math.min(sW, sH))

    property date selectedDate: new Date()
    property date displayDate:  new Date()

    signal dateSelected(date selected)

    // ── Helpers ──────────────────────────────────────────────────────────────
    function weekStartJs() { return Qt.locale().firstDayOfWeek % 7 }
    function startOfWeek(d) {
        const dt   = new Date(d)
        const diff = (dt.getDay() - weekStartJs() + 7) % 7
        dt.setDate(dt.getDate() - diff)
        return dt
    }
    function showPreviousMonth() {
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() - 1, 1)
    }
    function showNextMonth() {
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 1)
    }

    // ── Category color helpers ────────────────────────────────────────────────
    // We derive two extra roles from Theme.primary for Personal/Urgent.
    // tertiary / error are common Material roles — fall back gracefully if absent.
    readonly property color colorWork:     Theme.primary
    readonly property color colorPersonal: Theme.tertiary     || Qt.tint(Theme.primary, Qt.rgba(0.4, 0, 0.6, 0.35))
    readonly property color colorUrgent:   Theme.error        || Qt.tint(Theme.primary, Qt.rgba(0.8, 0, 0, 0.50))

    function colorForCategory(category) {
        const c = (category || "Work").toString().toLowerCase()
        if (c === "urgent") return colorUrgent
        if (c === "personal") return colorPersonal
        return colorWork
    }

    onVisibleChanged: { if (visible) CalendarService.loadCurrentMonth() }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: calendarModal.hide()

        // ── Title bar ────────────────────────────────────────────────────────
        Item {
            id: titleBar
            anchors.left:  parent.left
            anchors.right: parent.right
            height: Math.round(13 * sW) + 4
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       windowControls.tryStartMove()
                onDoubleClicked: windowControls.tryToggleMaximize()
            }
            Rectangle { anchors.fill: parent; color: Theme.surfaceContainer; opacity: 0.92 }

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     Math.round(20 * s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(10 * s)
                EHIcon {
                    name: "calendar_today"
                    size: Math.round(22 * s)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Calendar"
                    font.pixelSize: Math.round(18 * s)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right:          parent.right
                anchors.rightMargin:    Math.round(10 * s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * s)
                EHActionButton {
                    circular: false
                    iconName: "refresh"
                    iconSize: Math.round(18 * s)
                    iconColor: Theme.surfaceText
                    onClicked: CalendarService.loadCurrentMonth()
                }
                EHActionButton {
                    circular: false
                    iconName: "notifications"
                    iconSize: Math.round(18 * s)
                    iconColor: Theme.surfaceText
                    onClicked: NotificationService.pushLocal("Calendar", "Test notification", {
                        appName: "Calendar",
                        appIcon: "calendar_today",
                        force: true
                    })
                }
                EHActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Math.round(18 * s)
                    iconColor: Theme.surfaceText
                    onClicked: calendarModal.hide()
                }
            }
        }

        // ── Body row ─────────────────────────────────────────────────────────
        Row {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    titleBar.bottom
            anchors.bottom: parent.bottom

            // ── SIDEBAR ──────────────────────────────────────────────────────
            Item {
                id: sidebar
                width: Math.round(260 * s)
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                }

                Flickable {
                    id: sidebarFlick
                    anchors.fill: parent
                    anchors.margins: Math.round(16 * s)
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    contentWidth: width
                    contentHeight: sidebarColumn.implicitHeight

                    Column {
                        id: sidebarColumn
                        width: sidebarFlick.width
                        spacing: Math.round(18 * s)

                    // Mini calendar header
                    StyledText {
                        text: displayDate && !isNaN(displayDate.getTime())
                              ? Qt.formatDate(displayDate, "MMMM yyyy") : Qt.formatDate(new Date(), "MMMM yyyy")
                        font.pixelSize: Math.round(13 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    // Mini calendar day headers
                    Grid {
                        id: miniCalHeaders
                        width: parent.width
                        columns: 7
                        spacing: Math.round(2 * s)
                        Repeater {
                            model: ["S","M","T","W","T","F","S"]
                            StyledText {
                                width: Math.round(32 * s)
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.pixelSize: Math.round(10 * s)
                                font.weight: Font.Bold
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // Mini calendar date grid
                    Grid {
                        id: miniCal
                        width: parent.width
                        columns: 7
                        spacing: Math.round(2 * s)
                        readonly property int cellSize: Math.round(32 * s)
                        readonly property date firstCell: {
                            const d = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
                            return calendarModal.startOfWeek(d)
                        }
                        Repeater {
                            model: 35
                            Item {
                                width: miniCal.cellSize
                                height: miniCal.cellSize
                                readonly property date dayDate: {
                                    const d = new Date(miniCal.firstCell)
                                    d.setDate(d.getDate() + index)
                                    return d
                                }
                                readonly property bool isCurrentMonth: dayDate.getMonth() === displayDate.getMonth()
                                readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                                readonly property bool isSelected: dayDate.toDateString() === calendarModal.selectedDate.toDateString()

                                Rectangle {
                                    width: Math.round(26 * s)
                                    height: Math.round(20 * s)
                                    radius: Math.round(6 * s)
                                    color: isToday    ? Theme.primary
                                         : isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                         : "transparent"
                                    anchors.centerIn: parent

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: dayDate.getDate()
                                        font.pixelSize: Math.round(11 * s)
                                        font.weight: isToday ? Font.Bold : Font.Normal
                                        color: isToday       ? Theme.onPrimary || "white"
                                             : isCurrentMonth ? Theme.surfaceText
                                             : Theme.surfaceVariantText
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        calendarModal.selectedDate = dayDate
                                        calendarModal.displayDate  = new Date(dayDate.getFullYear(), dayDate.getMonth(), 1)
                                        calendarModal.dateSelected(dayDate)
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    }

                    // Category legend
                    StyledText {
                        text: "Legend"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    Column {
                        spacing: Math.round(8 * s)
                        Repeater {
                            model: [
                                { label: "Work",     color: calendarModal.colorWork     },
                                { label: "Personal", color: calendarModal.colorPersonal },
                                { label: "Urgent",   color: calendarModal.colorUrgent   }
                            ]
                            Row {
                                spacing: Math.round(8 * s)
                                Rectangle {
                                    width: Math.round(10 * s); height: width; radius: width / 2
                                    color: modelData.color
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Math.round(12 * s)
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    }

                    // Today's Events
                    StyledText {
                        text: "Today's Events"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    Column {
                        id: todayEventsList
                        width: parent.width
                        spacing: Math.round(6 * s)

                        readonly property var events: CalendarService.getEventsForDate(new Date())

                        Repeater {
                            model: todayEventsList.events.length > 0 ? todayEventsList.events : null
                            delegate: Item {
                                id: todayItem
                                width: todayEventsList.width
                                height: todayRow.implicitHeight

                                Row {
                                    id: todayRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: Math.round(8 * s)
                                    Rectangle {
                                        width: Math.round(8 * s); height: width; radius: width / 2
                                        color: calendarModal.colorForCategory(modelData.category)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        width: todayItem.width - Math.round(8 * s) - Math.round(8 * s)
                                        StyledText {
                                            text: modelData.title
                                            font.pixelSize: Math.round(12 * s)
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            text: modelData.allDay ? "All day"
                                                  : Qt.formatTime(modelData.start, "h:mm AP")
                                            font.pixelSize: Math.round(10 * s)
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => {
                                        mouse.accepted = true
                                        if (mouse.button === Qt.RightButton) {
                                            const p = todayItem.mapToItem(null, mouse.x, mouse.y)
                                            calendarContextMenu.showAt(calendarModal.x + p.x, calendarModal.y + titleBar.height + p.y, modelData)
                                        } else if (mouse.button === Qt.LeftButton) {
                                            eventModal.openEdit(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // Placeholder if no events / khal unavailable
                        StyledText {
                            visible: todayEventsList.events.length === 0
                            text: "No events today"
                            font.pixelSize: Math.round(11 * s)
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            visible: todayEventsList.events.length === 0 && !CalendarService.khalAvailable
                            text: "Local calendar"
                            font.pixelSize: Math.round(10 * s)
                            color: Theme.surfaceVariantText
                        }
                    }

                    // Yesterday's Events
                    StyledText {
                        text: "Yesterday"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    Column {
                        id: yestEventsList
                        width: parent.width
                        spacing: Math.round(6 * s)

                        readonly property date yesterday: {
                            const d = new Date(); d.setDate(d.getDate() - 1); return d
                        }
                        readonly property var events: CalendarService.getEventsForDate(yesterday)

                        Repeater {
                            model: yestEventsList.events.length > 0 ? yestEventsList.events : null
                            delegate: Item {
                                id: yestItem
                                width: yestEventsList.width
                                height: yestRow.implicitHeight

                                Row {
                                    id: yestRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: Math.round(8 * s)
                                    Rectangle {
                                        width: Math.round(8 * s); height: width; radius: width / 2
                                        color: Qt.rgba(calendarModal.colorForCategory(modelData.category).r,
                                                       calendarModal.colorForCategory(modelData.category).g,
                                                       calendarModal.colorForCategory(modelData.category).b, 0.55)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText { // keep yesterday list compact (single line)
                                        width: yestItem.width - Math.round(8 * s) - Math.round(8 * s)
                                        text: modelData.title
                                        font.pixelSize: Math.round(12 * s)
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => {
                                        mouse.accepted = true
                                        if (mouse.button === Qt.RightButton) {
                                            const p = yestItem.mapToItem(null, mouse.x, mouse.y)
                                            calendarContextMenu.showAt(calendarModal.x + p.x, calendarModal.y + titleBar.height + p.y, modelData)
                                        } else if (mouse.button === Qt.LeftButton) {
                                            eventModal.openEdit(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: yestEventsList.events.length === 0
                            text: "No events"
                            font.pixelSize: Math.round(11 * s)
                            color: Theme.surfaceVariantText
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    }

                    // World Clocks
                    StyledText {
                        text: "World Clocks"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    WorldClocksCard {
                        width: parent.width
                        maxClocks: 4
                    }
                    } // sidebarColumn
                } // sidebarFlick
            }

            // Sidebar divider
            Rectangle {
                width: 1
                height: parent.height
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            }

            // ── MAIN AREA ─────────────────────────────────────────────────────
            Item {
                id: mainArea
                width: parent.width - sidebar.width - 1
                height: parent.height

                // Use anchors throughout so the grid always fills exactly
                // what's left — no manual height arithmetic that breaks on scale.

                // ── Header bar ────────────────────────────────────────────────
                Item {
                    id: mainHeader
                    anchors.left:        parent.left
                    anchors.right:       parent.right
                    anchors.top:         parent.top
                    anchors.leftMargin:  Math.round(20 * s)
                    anchors.rightMargin: Math.round(20 * s)
                    anchors.topMargin:   Math.round(16 * s)
                    height: Math.round(48 * s)

                    // Month / year (left)
                    Column {
                        id: monthLabel
                        spacing: 1
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            text: displayDate && !isNaN(displayDate.getTime())
                                  ? displayDate.toLocaleDateString(Qt.locale(), "MMMM") : "April"
                            font.pixelSize: Math.round(26 * s)
                            font.weight: Font.Light
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: displayDate && !isNaN(displayDate.getTime())
                                  ? Qt.formatDate(displayDate, "yyyy") : "2026"
                            font.pixelSize: Math.round(13 * s)
                            color: Theme.surfaceVariantText
                        }
                    }

                    // Controls (right)
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(8 * s)

                        // Today button
                        Rectangle {
                            width: Math.round(62 * s); height: Math.round(28 * s)
                            radius: Math.round(14 * s)
                            color: "transparent"
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText {
                                anchors.centerIn: parent
                                text: "Today"
                                font.pixelSize: Math.round(11 * s)
                                font.weight: Font.Medium
                                color: Theme.primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    calendarModal.displayDate  = new Date()
                                    calendarModal.selectedDate = new Date()
                                }
                            }
                        }

                        // Prev / Next month
                        Repeater {
                            model: ["chevron_left", "chevron_right"]
                            Rectangle {
                                width: Math.round(30 * s); height: Math.round(30 * s); radius: width / 2
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                EHIcon {
                                    anchors.centerIn: parent
                                    name: modelData
                                    size: Math.round(17 * s)
                                    color: Theme.surfaceText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData === "chevron_left"
                                               ? calendarModal.showPreviousMonth()
                                               : calendarModal.showNextMonth()
                                }
                            }
                        }

                        // New Event button
                        Rectangle {
                            width: Math.round(106 * s); height: Math.round(30 * s)
                            radius: Math.round(15 * s)
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            Row {
                                anchors.centerIn: parent
                                spacing: Math.round(5 * s)
                                EHIcon {
                                    name: "add"
                                    size: Math.round(13 * s)
                                    color: Theme.onPrimary || "white"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "New Event"
                                    font.pixelSize: Math.round(11 * s)
                                    font.weight: Font.Medium
                                    color: Theme.onPrimary || "white"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: eventModal.openNew(calendarModal.selectedDate)
                            }
                        }

                        // Avatar
                        Rectangle {
                            width: Math.round(32 * s); height: width; radius: width / 2
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.80)
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            EHIcon {
                                anchors.centerIn: parent
                                name: "person"
                                size: Math.round(16 * s)
                                color: Theme.surfaceVariantText
                                visible: !avatarEffect.visible
                            }

                            Image {
                                id: avatarImage
                                anchors.fill: parent
                                source: {
                                    if (PortalService.profileImage === "") return ""
                                    if (PortalService.profileImage.startsWith("/")) return "file://" + PortalService.profileImage
                                    return PortalService.profileImage
                                }
                                visible: false
                                fillMode: Image.PreserveAspectCrop
                            }

                            MultiEffect {
                                id: avatarEffect
                                anchors.fill: parent
                                source: avatarImage
                                visible: PortalService.profileImage !== "" && avatarImage.status === Image.Ready
                                maskEnabled: true
                                maskSource: avatarMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Item {
                                id: avatarMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                            }
                        }
                    }
                }

                // ── Day-of-week headers ───────────────────────────────────────
                Item {
                    id: dayHeaderRow
                    anchors.left:        mainHeader.left
                    anchors.right:       mainHeader.right
                    anchors.top:         mainHeader.bottom
                    anchors.topMargin:   Math.round(10 * s)
                    height: Math.round(24 * s)

                    Repeater {
                        model: ["SUN","MON","TUE","WED","THU","FRI","SAT"]
                        Item {
                            x: index * (dayHeaderRow.width / 7)
                            width: dayHeaderRow.width / 7
                            height: parent.height
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

                // Thin rule between headers and grid
                Rectangle {
                    id: headerRule
                    anchors.left:      dayHeaderRow.left
                    anchors.right:     dayHeaderRow.right
                    anchors.top:       dayHeaderRow.bottom
                    anchors.topMargin: Math.round(6 * s)
                    height: 1
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                }

                // ── Month grid — fills all remaining space ────────────────────
                Item {
                    id: calGridArea
                    anchors.left:        dayHeaderRow.left
                    anchors.right:       dayHeaderRow.right
                    anchors.top:         headerRule.bottom
                    anchors.bottom:      parent.bottom
                    anchors.topMargin:   Math.round(6 * s)
                    anchors.bottomMargin: Math.round(12 * s)

                    // Divide area evenly into 7 cols × 6 rows
                    readonly property real cellW: (width  - Math.round(4 * s) * 6) / 7
                    readonly property real cellH: (height - Math.round(4 * s) * 5) / 6

                    readonly property date firstCell: {
                        const d = new Date(calendarModal.displayDate.getFullYear(),
                                           calendarModal.displayDate.getMonth(), 1)
                        if (isNaN(d.getTime())) return new Date()
                        return calendarModal.startOfWeek(d)
                    }

                    Repeater {
                        model: 42
                        Item {
                            readonly property int col: index % 7
                            readonly property int row: Math.floor(index / 7)
                            x: col * (calGridArea.cellW + Math.round(4 * s))
                            y: row * (calGridArea.cellH + Math.round(4 * s))
                            width:  calGridArea.cellW
                            height: calGridArea.cellH

                            readonly property date dayDate: {
                                const d = new Date(calGridArea.firstCell)
                                if (isNaN(d.getTime())) return new Date()
                                d.setDate(d.getDate() + index)
                                return d
                            }
                            readonly property bool isCurrentMonth: dayDate.getMonth() === calendarModal.displayDate.getMonth()
                            readonly property bool isToday:    dayDate.toDateString() === new Date().toDateString()
                            readonly property bool isSelected: dayDate.toDateString() === calendarModal.selectedDate.toDateString()
                            readonly property bool isWeekend:  dayDate.getDay() === 0 || dayDate.getDay() === 6
                            readonly property var  dayEvents:  CalendarService.eventsByDate[Qt.formatDate(dayDate, "yyyy-MM-dd")] || []

                            // Cell background
                            Rectangle {
                                anchors.fill: parent
                                radius: 6   // semi-rounded — not pill, not sharp
                                color: isWeekend
                                       ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.10)
                                       : "transparent"

                                border.color: isToday
                                              ? Theme.primary
                                              : isSelected
                                              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                              : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.18)
                                border.width: (isToday || isSelected) ? 2 : 1

                                // Date number — equal gap from top and left border
                                readonly property int bw: (isToday || isSelected) ? 2 : 1
                                readonly property int dateOffset: bw + 4
                                Rectangle {
                                    visible: isToday
                                    x: parent.dateOffset; y: parent.dateOffset
                                    width: Math.round(20 * s); height: Math.round(18 * s)
                                    radius: Math.round(6 * s)
                                    color: Theme.primary
                                }
                                StyledText {
                                    x: parent.dateOffset; y: parent.dateOffset
                                    text: dayDate.getDate()
                                    font.pixelSize: Math.round(11 * s)
                                    font.weight: isToday ? Font.Bold : Font.Normal
                                    color: isToday       ? (Theme.onPrimary || "white")
                                         : isCurrentMonth ? Theme.surfaceText
                                         : Theme.surfaceVariantText
                                    // keep text centred within the today circle
                                    width:               isToday ? Math.round(20 * s) : implicitWidth
                                    height:              isToday ? Math.round(18 * s) : implicitHeight
                                    verticalAlignment:   isToday ? Text.AlignVCenter : Text.AlignTop
                                    horizontalAlignment: isToday ? Text.AlignHCenter : Text.AlignLeft
                                }

                                // Event chips — anchored below the date, with a small top pad
                                Column {
                                    anchors.left:        parent.left
                                    anchors.right:       parent.right
                                    anchors.top:         parent.top
                                    anchors.topMargin:   Math.round(20 * s) + parent.dateOffset
                                    anchors.leftMargin:  parent.dateOffset
                                    anchors.rightMargin: parent.dateOffset
                                    spacing: Math.round(2 * s)

                                    Repeater {
                                        model: Math.min(3, dayEvents.length)
                                        delegate: Rectangle {
                                            id: chip
                                            width: parent.width
                                            height: Math.round(16 * s)
                                            radius: 3
                                            readonly property color catColor: calendarModal.colorForCategory(dayEvents[index] ? dayEvents[index].category : "Work")
                                            color: Qt.rgba(catColor.r, catColor.g, catColor.b, 0.22)
                                            StyledText {
                                                anchors.left: parent.left
                                                anchors.leftMargin: Math.round(4 * s)
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - Math.round(8 * s)
                                                text: dayEvents[index] ? dayEvents[index].title : ""
                                                font.pixelSize: Math.round(9 * s)
                                                font.weight: Font.Medium
                                                color: parent.catColor
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onPressed: (mouse) => {
                                                    mouse.accepted = true
                                                    const ev = dayEvents[index]
                                                    if (!ev) return
                                                    if (mouse.button === Qt.RightButton) {
                                                        const p = chip.mapToItem(null, mouse.x, mouse.y)
                                                        calendarContextMenu.showAt(calendarModal.x + p.x, calendarModal.y + titleBar.height + p.y, ev)
                                                    } else if (mouse.button === Qt.LeftButton) {
                                                        eventModal.openEdit(ev)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    StyledText {
                                        visible: dayEvents.length > 3
                                        text: "+" + (dayEvents.length - 3) + " more"
                                        font.pixelSize: Math.round(9 * s)
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: isCurrentMonth
                                cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    calendarModal.selectedDate = dayDate
                                    calendarModal.dateSelected(dayDate)
                                }
                                onDoubleClicked: {
                                    if (isCurrentMonth)
                                        eventModal.openNew(dayDate)
                                }
                            }
                        }
                    }
                } // calGridArea
            } // mainArea
        } // body Row
    } // FocusScope

    FloatingWindowControls { id: windowControls; targetWindow: calendarModal }

    EventModal { id: eventModal }

    CalendarContextMenu {
        id: calendarContextMenu
        onEditRequested: (ev) => {
            if (ev) eventModal.openEdit(ev)
        }
        onRemoveRequested: (ev) => {
            if (ev) CalendarService.deleteEvent(ev)
        }
    }
}
