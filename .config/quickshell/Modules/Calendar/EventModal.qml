import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Calendar

FloatingWindow {
    id: eventModal

    // ── Public API ────────────────────────────────────────────────────────────
    // Call openNew(date) to create, openEdit(eventObj) to edit existing.
    function openNew(forDate) {
        editMode       = false
        editEventId    = ""
        titleField.text       = ""
        notesField.text       = ""
        categoryIndex  = 0
        // pre-fill date from the cell that was clicked
        const d = (forDate instanceof Date && !isNaN(forDate)) ? forDate : new Date()
        _year  = d.getFullYear()
        _month = d.getMonth()
        _day   = d.getDate()
        _hour  = 9
        _minute = 0
        _endHour   = 10
        _endMinute = 0
        allDay     = false
        visible    = true
        titleField.forceActiveFocus()
    }

    function openEdit(ev) {
        editMode    = true
        editEventId = ev.id || ""
        editEventUid = ev.uid || ""
        originalTitle = ev.title || ""
        originalAllDay = ev.allDay || false
        originalStart = ev.start instanceof Date ? new Date(ev.start) : new Date()
        titleField.text  = ev.title       || ""
        notesField.text  = ev.description || ""
        allDay           = ev.allDay      || false
        categoryIndex    = 0   // TODO: map ev.calendar → category index when service exposes it
        const s = ev.start instanceof Date ? ev.start : new Date()
        const e = ev.end   instanceof Date ? ev.end   : new Date(s.getTime() + 3600000)
        _year  = s.getFullYear(); _month = s.getMonth(); _day = s.getDate()
        _hour  = s.getHours();    _minute = Math.round(s.getMinutes() / 5) * 5
        _endHour   = e.getHours(); _endMinute = Math.round(e.getMinutes() / 5) * 5
        if (_minute >= 60) { _minute = 0; _hour = (_hour + 1) % 24 }
        if (_endMinute >= 60) { _endMinute = 0; _endHour = (_endHour + 1) % 24 }
        visible = true
        titleField.forceActiveFocus()
    }

    function hide() { visible = false }

    // ── Internal state ────────────────────────────────────────────────────────
    property bool   editMode:      false
    property string editEventId:   ""
    property string editEventUid:  ""
    property string originalTitle: ""
    property bool   originalAllDay: false
    property date   originalStart: new Date()
    property int    categoryIndex: 0       // 0=Work 1=Personal 2=Urgent
    property bool   allDay:        false
    property int    _year:   new Date().getFullYear()
    property int    _month:  new Date().getMonth()
    property int    _day:    new Date().getDate()
    property int    _hour:   9
    property int    _minute: 0
    property int    _endHour:   10
    property int    _endMinute: 0

    readonly property var categoryNames:  ["Work", "Personal", "Urgent"]
    readonly property var categoryColors: [Theme.primary,
                                           Theme.tertiary  || Qt.tint(Theme.primary, Qt.rgba(0.4,0,0.6,0.35)),
                                           Theme.error     || Qt.tint(Theme.primary, Qt.rgba(0.8,0,0,0.50))]

    // Formatted helpers used in the UI
    readonly property string dateLabel: {
        const months = ["Jan","Feb","Mar","Apr","May","Jun",
                        "Jul","Aug","Sep","Oct","Nov","Dec"]
        return months[_month] + " " + _day + ", " + _year
    }
    readonly property string startLabel: _timeLabel(_hour, _minute)
    readonly property string endLabel:   _timeLabel(_endHour, _endMinute)
    function _pad(n) { return n < 10 ? "0" + n : "" + n }
    function _timeLabel(h24, m) {
        // 12-hour display with AM/PM selector in UI
        let h = h24 % 24
        const isPm = h >= 12
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        return h12 + ":" + _pad(m) + " " + (isPm ? "PM" : "AM")
    }
    function _setMeridiem(which, isPm) {
        // which: "start" | "end"
        if (which === "start") {
            const wasPm = _hour >= 12
            if (isPm && !wasPm) _hour = (_hour + 12) % 24
            else if (!isPm && wasPm) _hour = (_hour + 12) % 24
        } else {
            const wasPmE = _endHour >= 12
            if (isPm && !wasPmE) _endHour = (_endHour + 12) % 24
            else if (!isPm && wasPmE) _endHour = (_endHour + 12) % 24
        }
    }
    readonly property bool startIsPm: _hour >= 12
    readonly property bool endIsPm: _endHour >= 12

    readonly property var hours12Model: [1,2,3,4,5,6,7,8,9,10,11,12]
    readonly property var minutes5Model: ["00","05","10","15","20","25","30","35","40","45","50","55"]

    function _hour12From24(h24) {
        let h = h24 % 24
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        return h12
    }

    function _setHourFrom12(which, h12) {
        // keep current meridiem for that field
        let targetPm = (which === "start") ? startIsPm : endIsPm
        let v = Math.max(1, Math.min(12, parseInt(h12)))
        let h24 = v % 12
        if (targetPm) h24 += 12
        if (which === "start") _hour = h24
        else _endHour = h24
    }

    function _setMinute5(which, idx) {
        const m = Math.max(0, Math.min(11, idx)) * 5
        if (which === "start") _minute = m
        else _endMinute = m
    }

    // ── Window chrome ─────────────────────────────────────────────────────────
    objectName: "eventModal"
    title: editMode ? "Edit Event" : "New Event"
    minimumSize: Qt.size(640, 480)
    implicitWidth:  720
    implicitHeight: 560
    backgroundColor: Theme.surfaceContainer
    visible: false

    readonly property real sW: width  / 720
    readonly property real sH: (height - titleBar.height) / (560 - 44)
    readonly property real s:  Math.max(0.55, Math.min(sW, sH))

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: eventModal.hide()

        // ── Title bar ─────────────────────────────────────────────────────────
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
                    name: eventModal.editMode ? "edit_calendar" : "event"
                    size: Math.round(20 * s)
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: eventModal.editMode ? "Edit Event" : "New Event"
                    font.pixelSize: Math.round(16 * s)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right:          parent.right
                anchors.rightMargin:    Math.round(10 * s)
                anchors.verticalCenter: parent.verticalCenter
                EHActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Math.round(18 * s)
                    iconColor: Theme.surfaceText
                    onClicked: eventModal.hide()
                }
            }
        }

        // ── Body ──────────────────────────────────────────────────────────────
        Flickable {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    titleBar.bottom
            anchors.bottom: actionBar.top
            anchors.margins: Math.round(20 * s)
            contentHeight: formColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: formColumn
                width: parent.width
                spacing: Math.round(16 * s)

                // ── Title field ───────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: Math.round(6 * s)
                    StyledText {
                        text: "Title"
                        font.pixelSize: Math.round(11 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.round(38 * s)
                        radius: 6
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                        border.color: titleField.activeFocus
                                      ? Theme.primary
                                      : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                        border.width: titleField.activeFocus ? 2 : 1

                        TextInput {
                            id: titleField
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin:     Math.round(10 * s)
                            anchors.rightMargin:    Math.round(10 * s)
                            font.pixelSize: Math.round(13 * s)
                            color: Theme.surfaceText
                            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                            clip: true

                            // Placeholder
                            StyledText {
                                anchors.fill: parent
                                text: "Event title…"
                                font.pixelSize: Math.round(13 * s)
                                color: Theme.surfaceVariantText
                                visible: titleField.text.length === 0 && !titleField.activeFocus
                            }
                        }
                    }
                }

                // ── Category picker ───────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: Math.round(6 * s)
                    StyledText {
                        text: "Category"
                        font.pixelSize: Math.round(11 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    Row {
                        spacing: Math.round(8 * s)
                        Repeater {
                            model: eventModal.categoryNames
                            delegate: Rectangle {
                                width:  Math.round(88 * s)
                                height: Math.round(32 * s)
                                radius: 6
                                readonly property bool active: index === eventModal.categoryIndex
                                color: active
                                       ? Qt.rgba(eventModal.categoryColors[index].r,
                                                 eventModal.categoryColors[index].g,
                                                 eventModal.categoryColors[index].b, 0.22)
                                       : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
                                border.color: active
                                              ? eventModal.categoryColors[index]
                                              : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                                border.width: active ? 2 : 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Math.round(6 * s)
                                    Rectangle {
                                        width: Math.round(8 * s); height: width; radius: width / 2
                                        color: eventModal.categoryColors[index]
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: modelData
                                        font.pixelSize: Math.round(11 * s)
                                        font.weight: active ? Font.Medium : Font.Normal
                                        color: active ? eventModal.categoryColors[index] : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: eventModal.categoryIndex = index
                                }
                            }
                        }
                    }
                }

                // ── Date row ─────────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: Math.round(6 * s)
                    StyledText {
                        text: "Date"
                        font.pixelSize: Math.round(11 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.round(38 * s)
                        radius: 6
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                        border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                        border.width: 1

                        Row {
                            anchors.left:           parent.left
                            anchors.leftMargin:     Math.round(10 * s)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(8 * s)
                            EHIcon { name: "calendar_today"; size: Math.round(14 * s); color: Theme.primary }
                            StyledText {
                                text: eventModal.dateLabel
                                font.pixelSize: Math.round(13 * s)
                                color: Theme.surfaceText
                            }
                        }

                        // Inline date stepper (prev/next day)
                        Row {
                            anchors.right:          parent.right
                            anchors.rightMargin:    Math.round(6 * s)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(2 * s)
                            EHActionButton {
                                circular: false
                                iconName: "chevron_left"
                                iconSize: Math.round(16 * s)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    const d = new Date(eventModal._year, eventModal._month, eventModal._day - 1)
                                    eventModal._year  = d.getFullYear()
                                    eventModal._month = d.getMonth()
                                    eventModal._day   = d.getDate()
                                }
                            }
                            EHActionButton {
                                circular: false
                                iconName: "chevron_right"
                                iconSize: Math.round(16 * s)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    const d = new Date(eventModal._year, eventModal._month, eventModal._day + 1)
                                    eventModal._year  = d.getFullYear()
                                    eventModal._month = d.getMonth()
                                    eventModal._day   = d.getDate()
                                }
                            }
                        }
                    }
                }

                // ── All-day toggle + time row ─────────────────────────────────
                // Keep it one clean line like other modals; if it doesn't fit,
                // allow horizontal scroll instead of wrapping/cutting off.
                Flickable {
                    id: timeFlick
                    width: parent.width
                    height: Math.round(38 * s)
                    clip: true
                    interactive: contentWidth > width
                    flickableDirection: Flickable.HorizontalFlick
                    contentWidth: Math.max(timeRow.implicitWidth, width)
                    contentHeight: height

                    Row {
                        id: timeRow
                        height: timeFlick.height
                        spacing: Math.round(12 * s)
                        x: Math.max(0, Math.round((timeFlick.width - implicitWidth) / 2))

                        // All-day toggle
                        Row {
                            spacing: Math.round(8 * s)
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width:  Math.round(36 * s)
                                height: Math.round(20 * s)
                                radius: Math.round(10 * s)
                                color:  eventModal.allDay
                                        ? Theme.primary
                                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.50)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width:  Math.round(16 * s)
                                    height: width
                                    radius: width / 2
                                    color:  "white"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: eventModal.allDay
                                       ? parent.width  - width  - Math.round(2 * s)
                                       : Math.round(2 * s)
                                    Behavior on x { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: eventModal.allDay = !eventModal.allDay
                                }
                            }
                            StyledText {
                                text: "All day"
                                font.pixelSize: Math.round(12 * s)
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Start time
                        Rectangle {
                            visible: !eventModal.allDay
                            width:  Math.round(230 * s)
                            height: Math.round(38 * s)
                            radius: 6
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                            border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                            border.width: 1

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * s)
                                anchors.rightMargin: Math.round(8 * s)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Math.round(6 * s)

                                    EHIcon { name: "schedule"; size: Math.round(13 * s); color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    TimeDropdown { width: Math.round(54 * s); height: Math.round(26 * s); model: eventModal.hours12Model; currentIndex: eventModal._hour12From24(eventModal._hour) - 1; onActivated: (idx) => eventModal._setHourFrom12("start", model[idx]) }
                                    TimeDropdown { width: Math.round(58 * s); height: Math.round(26 * s); model: eventModal.minutes5Model; currentIndex: Math.round(eventModal._minute / 5); onActivated: (idx) => eventModal._setMinute5("start", idx) }
                                    TimeDropdown { width: Math.round(58 * s); height: Math.round(26 * s); model: ["AM", "PM"]; currentIndex: eventModal.startIsPm ? 1 : 0; onActivated: (idx) => eventModal._setMeridiem("start", idx === 1) }
                                }
                            }
                        }

                        StyledText {
                            visible: !eventModal.allDay
                            text: "→"
                            font.pixelSize: Math.round(13 * s)
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // End time
                        Rectangle {
                            visible: !eventModal.allDay
                            width:  Math.round(230 * s)
                            height: Math.round(38 * s)
                            radius: 6
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                            border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                            border.width: 1

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * s)
                                anchors.rightMargin: Math.round(8 * s)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Math.round(6 * s)

                                    EHIcon { name: "schedule"; size: Math.round(13 * s); color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    TimeDropdown { width: Math.round(54 * s); height: Math.round(26 * s); model: eventModal.hours12Model; currentIndex: eventModal._hour12From24(eventModal._endHour) - 1; onActivated: (idx) => eventModal._setHourFrom12("end", model[idx]) }
                                    TimeDropdown { width: Math.round(58 * s); height: Math.round(26 * s); model: eventModal.minutes5Model; currentIndex: Math.round(eventModal._endMinute / 5); onActivated: (idx) => eventModal._setMinute5("end", idx) }
                                    TimeDropdown { width: Math.round(58 * s); height: Math.round(26 * s); model: ["AM", "PM"]; currentIndex: eventModal.endIsPm ? 1 : 0; onActivated: (idx) => eventModal._setMeridiem("end", idx === 1) }
                                }
                            }
                        }
                    }
                }

                // ── Notes field ───────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: Math.round(6 * s)
                    StyledText {
                        text: "Notes"
                        font.pixelSize: Math.round(11 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.round(80 * s)
                        radius: 6
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                        border.color: notesField.activeFocus
                                      ? Theme.primary
                                      : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                        border.width: notesField.activeFocus ? 2 : 1

                        TextEdit {
                            id: notesField
                            anchors.fill: parent
                            anchors.margins: Math.round(10 * s)
                            font.pixelSize: Math.round(12 * s)
                            color: Theme.surfaceText
                            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                            wrapMode: TextEdit.Wrap
                            clip: true

                            StyledText {
                                anchors.fill: parent
                                text: "Optional notes…"
                                font.pixelSize: Math.round(12 * s)
                                color: Theme.surfaceVariantText
                                visible: notesField.text.length === 0 && !notesField.activeFocus
                            }
                        }
                    }
                }

            } // formColumn
        } // Flickable

        // ── Action bar ────────────────────────────────────────────────────────
        Item {
            id: actionBar
            anchors.left:         parent.left
            anchors.right:        parent.right
            anchors.bottom:       parent.bottom
            anchors.leftMargin:   Math.round(20 * s)
            anchors.rightMargin:  Math.round(20 * s)
            anchors.bottomMargin: Math.round(16 * s)
            height: Math.round(38 * s)

            // Delete button — only visible in edit mode
            Rectangle {
                visible: eventModal.editMode && CalendarService.canDelete
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width:  Math.round(90 * s)
                height: Math.round(36 * s)
                radius: 6
                color: "transparent"
                border.color: eventModal.colorUrgent || Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
                border.width: 1

                readonly property color colorUrgent: Theme.error || Qt.tint(Theme.primary, Qt.rgba(0.8,0,0,0.50))

                Row {
                    anchors.centerIn: parent
                    spacing: Math.round(5 * s)
                    EHIcon { name: "delete"; size: Math.round(14 * s); color: parent.parent.colorUrgent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Remove Event"; font.pixelSize: Math.round(12 * s); color: parent.parent.colorUrgent; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        CalendarService.deleteEvent({
                            id:    eventModal.editEventId,
                            uid:   eventModal.editEventUid,
                            title: eventModal.originalTitle,
                            allDay: eventModal.originalAllDay,
                            start: eventModal.originalStart
                        })
                        eventModal.hide()
                    }
                }
            }

            // Cancel + Save (right side)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(10 * s)

                // Cancel
                Rectangle {
                    width:  Math.round(80 * s)
                    height: Math.round(36 * s)
                    radius: 6
                    color: "transparent"
                    border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                    border.width: 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Math.round(12 * s)
                        color: Theme.surfaceText
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: eventModal.hide()
                    }
                }

                // Save
                Rectangle {
                    width:  Math.round(80 * s)
                    height: Math.round(36 * s)
                    radius: 6
                    color: titleField.text.trim().length > 0 ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                    StyledText {
                        anchors.centerIn: parent
                        text: eventModal.editMode ? "Update" : "Save"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.onPrimary || "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: titleField.text.trim().length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (titleField.text.trim().length === 0) return
                            const ev = {
                                title:       titleField.text.trim(),
                                category:    eventModal.categoryNames[eventModal.categoryIndex],
                                start:       new Date(eventModal._year, eventModal._month, eventModal._day,
                                                      eventModal._hour, eventModal._minute),
                                end:         new Date(eventModal._year, eventModal._month, eventModal._day,
                                                      eventModal._endHour, eventModal._endMinute),
                                description: notesField.text.trim(),
                                allDay:      eventModal.allDay
                            }
                            if (eventModal.editMode) {
                                ev.id = eventModal.editEventId
                                // khal has no direct "update" — delete the old entry then create the new one
                                ev.uid = eventModal.editEventUid
                                CalendarService.deleteEvent({ id: eventModal.editEventId, uid: eventModal.editEventUid, title: eventModal.originalTitle, allDay: eventModal.originalAllDay, start: eventModal.originalStart })
                            }
                            CalendarService.createEvent(ev)
                            eventModal.hide()
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls { id: windowControls; targetWindow: eventModal }
}
