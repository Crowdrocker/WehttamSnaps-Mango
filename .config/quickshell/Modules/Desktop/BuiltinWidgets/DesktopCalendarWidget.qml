import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: defaultWidth
    property real widgetHeight: defaultHeight
    property real defaultWidth: 360
    property real defaultHeight: 360
    property real minWidth: 280
    property real minHeight: 300

    // Stable surface: keep the internal calendar layout at a fixed design size
    // and scale that surface within the resizable desktop-widget window.
    readonly property int designWidth: 340
    readonly property int designHeight: 420
    readonly property real contentScale: Math.max(0.01, Math.min(widgetWidth / designWidth, widgetHeight / designHeight))
    function spx(px) { return px }

    // Use the same sliders/toggles as the dock/taskbar calendar popup.
    readonly property real popupOpacity: (SettingsData.calendarPopupTransparency ?? 0.88)

    // Matugen wallpaper colors (same approach as Fastfetch)
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : (SettingsData.desktopWidgetWallpaperColors ?? false)
    readonly property var matugenColorNames: [
        "primary_container",
        "secondary_container",
        "tertiary_container"
    ]
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

    // Calendar state (match dock calendar design)
    property date selectedDate: new Date()
    property date displayDate: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property var selectedDateEvents: []
    readonly property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    // Locale helpers
    function weekStartJs() { return Qt.locale().firstDayOfWeek % 7 }
    function startOfWeek(d) {
        const dt = new Date(d)
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

    onSelectedDateChanged: {
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
    }

    Component.onCompleted: {
        CalendarService.checkKhalAvailability()
        // Ensure the service actually populates `eventsByDate` for lookups.
        CalendarService.loadCurrentMonth()
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
    }

    // When the service finishes loading/updating events, refresh our list.
    Connections {
        target: CalendarService
        function onEventsByDateChanged() {
            root.selectedDateEvents = CalendarService.getEventsForDate(root.selectedDate)
        }
    }

    width: widgetWidth
    height: widgetHeight

    Rectangle {
        id: popupContainer
        width: root.designWidth
        height: root.designHeight
        anchors.centerIn: parent
        scale: root.contentScale
        transformOrigin: Item.Center
        color: {
            const a = Math.max(0.55, root.popupOpacity)
            const mc = root.getMatugenColor(0)
            if (mc) {
                const c = Qt.color(mc)
                return Qt.rgba(c.r, c.g, c.b, a)
            }
            return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, a)
        }
        radius: spx(22)
        border.color: (SettingsData.calendarPopupDynamicBorderColors ? Theme.primary
                     : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                               SettingsData.calendarPopupBorderOpacity !== undefined
                                   ? SettingsData.calendarPopupBorderOpacity
                                   : 0.30))
        border.width: (SettingsData.calendarPopupBorderEnabled
                      ? Math.max(1,
                                 SettingsData.calendarPopupBorderThickness !== undefined
                                     ? SettingsData.calendarPopupBorderThickness
                                     : 2)
                      : 0)
        antialiasing: true
        clip: true

        // Drop shadow (same as dock popout)
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: spx(4)
            anchors.leftMargin: spx(2)
            anchors.rightMargin: -spx(2)
            anchors.bottomMargin: -spx(4)
            radius: popupContainer.radius
            color: Qt.rgba(0, 0, 0, 0.20)
            z: -1
        }

        // ── Inner frosted card ────────────────────────────────────────────────
        Rectangle {
            id: calendarInner
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            radius: spx(16)
            color: {
                const alpha = (typeof Theme.getContentBackgroundAlpha === "function")
                              ? Theme.getContentBackgroundAlpha()
                              : 0.85
                const op = SettingsData.calendarPopupWidgetBackgroundOpacity !== undefined
                           ? SettingsData.calendarPopupWidgetBackgroundOpacity
                           : 0.60
                return Qt.rgba(
                    Theme.surfaceVariant.r,
                    Theme.surfaceVariant.g,
                    Theme.surfaceVariant.b,
                    alpha * op
                )
            }
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.07)
            border.width: 1
            antialiasing: true

            Column {
                id: innerCol
                // Match `Widgets/CalendarPopup.qml` anchoring (top aligned, not stretched).
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Theme.spacingL
                }
                spacing: 0

                // ── Events (dock screenshot: on top) ────────────────────────────
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.hasEvents

                    StyledText {
                        text: "Events · " + root.selectedDate.toLocaleDateString(Qt.locale(), "MMM d")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        color: Theme.primary
                        opacity: 0.80
                    }

                    Repeater {
                        model: root.selectedDateEvents
                        delegate: RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS
                            Rectangle {
                                width: 6; height: 6; radius: 3
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

                    Item { width: 1; height: Theme.spacingS }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
                    Item { width: 1; height: Theme.spacingS }
                }

                // ── Selected date + close (dock screenshot: above grid) ─────────
                RowLayout {
                    width: parent.width

                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 15
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                        StyledText {
                            anchors.centerIn: parent
                            text: root.selectedDate && !isNaN(root.selectedDate.getTime())
                                  ? root.selectedDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy")
                                  : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                            elide: Text.ElideRight
                            width: parent.width - Theme.spacingM * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: closeMA.containsMouse
                               ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                               : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }

                        EHIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 14
                            color: closeMA.containsMouse ? Theme.error : Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: closeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Desktop widget can't "close", so reset to today (acts like a quick-jump).
                                const d = new Date()
                                root.displayDate = new Date(d.getFullYear(), d.getMonth(), 1)
                                root.selectedDate = d
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingS }

                // ── Calendar grid ───────────────────────────────────────────────
                Grid {
                    id: calGrid
                    width: parent.width
                    columns: 7
                    rows: 6
                    spacing: 3

                    readonly property int cellSize: Math.floor((width - spacing * 6) / 7)
                    readonly property date firstCell: {
                        const d = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth(), 1)
                        if (isNaN(d.getTime())) return new Date()
                        return root.startOfWeek(d)
                    }

                    Repeater {
                        model: 42
                        Item {
                            width: calGrid.cellSize
                            height: calGrid.cellSize

                            readonly property date dayDate: {
                                const d = new Date(calGrid.firstCell)
                                if (isNaN(d.getTime())) return new Date()
                                d.setDate(d.getDate() + index)
                                return d
                            }
                            readonly property bool isCurrentMonth: dayDate.getMonth() === root.displayDate.getMonth()
                            readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                            readonly property bool isSelected: dayDate.toDateString() === root.selectedDate.toDateString()
                            readonly property bool isWeekend: { const d = dayDate.getDay(); return d === 0 || d === 6 }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: width
                                radius: width / 2
                                color: {
                                    if (isSelected) return Theme.primary
                                    if (isToday) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                    if (isCurrentMonth && dayMA.containsMouse)
                                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: 130 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Theme.primary
                                    border.width: isToday && !isSelected ? 1.5 : 0
                                    opacity: 0.75
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: dayDate && !isNaN(dayDate.getTime()) ? dayDate.getDate() : ""
                                    font.pixelSize: 13
                                    font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                                    color: {
                                        if (!isCurrentMonth) return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.22)
                                        if (isSelected) return "white"
                                        if (isToday) return Theme.primary
                                        if (isWeekend) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.80)
                                        return Theme.surfaceText
                                    }
                                }
                            }

                            MouseArea {
                                id: dayMA
                                anchors.fill: parent
                                hoverEnabled: isCurrentMonth
                                cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: isCurrentMonth
                                onClicked: root.selectedDate = dayDate
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingM }

                // ── Day headers (dock screenshot: below grid) ───────────────────
                Row {
                    id: dayHeaderRow
                    width: parent.width
                    height: 24
                    spacing: 0
                    Repeater {
                        model: {
                            const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            const start = root.weekStartJs()
                            let out = []
                            for (let i = 0; i < 7; i++) out.push(days[(start + i) % 7])
                            return out
                        }
                        Item {
                            width: dayHeaderRow.width / 7
                            height: 24
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.primary
                                opacity: 0.70
                                font.letterSpacing: 0.5
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingM }

                // ── Month footer + controls (dock screenshot: bottom) ───────────
                RowLayout {
                    width: parent.width
                    height: spx(48)
                    spacing: Theme.spacingS

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        StyledText {
                            text: root.displayDate && !isNaN(root.displayDate.getTime())
                                  ? root.displayDate.toLocaleDateString(Qt.locale(), "MMMM")
                                  : ""
                            font.pixelSize: Theme.fontSizeLarge + 2
                            font.weight: Font.Bold
                            font.letterSpacing: 0.2
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: root.displayDate && !isNaN(root.displayDate.getTime())
                                  ? Qt.formatDate(root.displayDate, "yyyy")
                                  : ""
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                            opacity: 0.85
                        }
                    }

                    Rectangle {
                        width: 56
                        height: 26
                        radius: 13
                        color: todayMA.containsMouse
                               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                               : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
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

                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: [{ icon: "chevron_left", action: "prev" }, { icon: "chevron_right", action: "next" }]
                            Rectangle {
                                required property var modelData
                                width: 32; height: 32; radius: 16
                                color: navMA.containsMouse
                                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                EHIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    size: 17
                                    color: navMA.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                }
                                MouseArea {
                                    id: navMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.action === "prev" ? root.showPreviousMonth() : root.showNextMonth()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
