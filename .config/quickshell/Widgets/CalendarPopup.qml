import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Services

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showCalendar: false

    // Calendar state (match DockCalendarPopout design)
    property date selectedDate: new Date()
    property date displayDate:  new Date()
    property var  selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    signal dateSelected(date selected)
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0
    property var parentScreen: null
    property string barPosition: "bottom"
    property real barThickness: 48
    // Scale used for popup sizing/radii (caller sets: dockScale / miniPanelScale).
    property real panelScale: 1.0

    // Keep this small like other popouts by default.
    property real calendarHeight: 280

    function open() {
        if (parentScreen) root.screen = parentScreen
        else root.screen = Quickshell.screens[0]
        showCalendar = true
    }
    function close() {
        showCalendar = false
    }

    onShowCalendarChanged: {
        if (showCalendar) {
            // Sync display month to selection when opened
            displayDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
            selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
        }
    }

    screen: Quickshell.screens[1] ?? Quickshell.screens[0]
    visible: showCalendar
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onVisibleChanged: if (visible) updatePosition()

    function updatePosition() {
        if (!parentScreen) {
            anchorPos = Qt.point(screen.width / 2, screen.height / 2)
            return
        }
        // NOTE: PanelWindow with anchors { top/left/right/bottom: true } and
        // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
        // Do NOT add screen.x / screen.y here — those are global compositor
        // offsets and would double-displace the popup on any monitor whose
        // virtual-desktop origin is not 0,0 (e.g. a bottom monitor in a
        // stacked layout).
        const scale = (Appearance.combinedScale || 1)
        const thick = barThickness
        const dist  = 10 * scale
        const off   = 15 * scale
        let tx, ty

        switch (barPosition) {
            case "top":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width  / 2)
                ty = thick + dist + off
                break
            case "bottom":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width  / 2)
                ty = screen.height - thick - dist - off
                break
            case "left":
                tx = thick + dist + off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (screen.height / 2)
                break
            case "right":
                tx = screen.width - thick - dist - off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (screen.height / 2)
                break
            default:
                tx = screen.width  / 2
                ty = screen.height / 2
        }
        anchorPos = Qt.point(tx, ty)
    }

    // Locale helpers
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

    onSelectedDateChanged: {
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
        dateSelected(selectedDate)
    }

    // Backdrop click dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        z: -1
    }

    PopupSurface {
        id: popupContainer

        readonly property real uiScale: (Appearance.combinedScale || 1) * (root.panelScale || 1.0)
        function spx(px) { return Math.round(px * uiScale) }
        readonly property real popupW: spx(340)

        width:          popupW
        implicitHeight: calendarInner.implicitHeight + Theme.spacingM * 2 + 16

        x: Math.max(10, Math.min(root.screen.width - width - 10, root.anchorPos.x - width / 2))
        y: {
            const margin = 10
            if (root.barPosition === "top") {
                return Math.max(margin, root.anchorPos.y)
            } else if (root.barPosition === "bottom") {
                return Math.min(root.screen.height - height - margin, root.anchorPos.y - height - 2)
            }
            const want = root.anchorPos.y - height / 2
            return Math.max(margin, Math.min(root.screen.height - height - margin, want))
        }

        surfaceColor: Theme.surfaceContainer
        surfaceAlpha: Math.max(
            0.55,
            SettingsData.calendarPopupTransparency !== undefined
                ? SettingsData.calendarPopupTransparency
                : 0.88
        )
        wallpaperTintEnabled: SettingsData.desktopWidgetWallpaperColors || false
        wallpaperTintRole: "primary_container"
        radius: spx(22)
        borderColor: SettingsData.calendarPopupDynamicBorderColors ? Theme.primary : Theme.outline
        borderAlpha: SettingsData.calendarPopupDynamicBorderColors
                    ? 1.0
                    : (SettingsData.calendarPopupBorderOpacity !== undefined ? SettingsData.calendarPopupBorderOpacity : 0.30)
        borderWidth: SettingsData.calendarPopupBorderEnabled
                    ? Math.max(1, SettingsData.calendarPopupBorderThickness !== undefined ? SettingsData.calendarPopupBorderThickness : 2)
                    : 0

        opacity: showCalendar ? 1 : 0
        scale:   showCalendar ? 1 : 0.88
        transformOrigin: root.barPosition === "top" ? Item.Top : Item.Bottom

        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }

        shadowEnabled: true
        shadowColor: Theme.shadowMedium
        shadowAlpha: 1.0
        shadowTopMargin: spx(4)
        shadowLeftMargin: spx(2)
        shadowRightMargin: -spx(2)
        shadowBottomMargin: -spx(4)

        // ── Inner frosted card ────────────────────────────────────────────────
        Rectangle {
            id: calendarInner

            implicitHeight: innerCol.implicitHeight + Theme.spacingL * 2
            anchors { fill: parent; margins: Theme.spacingS }
            radius:       spx(16)
            color: {
                const alpha = (typeof Theme.getContentBackgroundAlpha === "function")
                              ? Theme.getContentBackgroundAlpha() : 0.85
                const op = SettingsData.calendarPopupWidgetBackgroundOpacity !== undefined
                           ? SettingsData.calendarPopupWidgetBackgroundOpacity : 0.60
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
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                spacing: 0
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────
    RowLayout {
        parent: innerCol
        width:   parent.width
        height:  popupContainer.spx(48)
        spacing: Theme.spacingS

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                text: displayDate && !isNaN(displayDate.getTime())
                      ? displayDate.toLocaleDateString(Qt.locale(), "MMMM") : ""
                font.pixelSize:    Theme.fontSizeLarge + 2
                font.weight:       Font.Bold
                font.letterSpacing: 0.2
                color:             Theme.surfaceText
            }
            StyledText {
                text: displayDate && !isNaN(displayDate.getTime())
                      ? Qt.formatDate(displayDate, "yyyy") : ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight:    Font.Medium
                color:          Theme.primary
                opacity:        0.85
            }
        }

        // Today button
        Rectangle {
            width:  56; height: 26; radius: 13
            color: todayMA.containsMouse
                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                   : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120 } }
            StyledText {
                anchors.centerIn: parent
                text: "Today"; font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium; color: Theme.primary
            }
            MouseArea {
                id: todayMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.displayDate = new Date(); root.selectedDate = new Date() }
            }
        }

        // Prev / Next
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
                        anchors.centerIn: parent; name: modelData.icon; size: 17
                        color: navMA.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    }
                    MouseArea {
                        id: navMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.action === "prev" ? root.showPreviousMonth() : root.showNextMonth()
                    }
                }
            }
        }
    }

    // Divider
    Rectangle { parent: innerCol; width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
    Item { parent: innerCol; width: 1; height: Theme.spacingM }

    // ── Day headers ───────────────────────────────────────────────
    Row {
        id: dayHeaderRow
        parent: innerCol
        width: parent.width; height: 24; spacing: 0
        Repeater {
            model: {
                const days = ["Su","Mo","Tu","We","Th","Fr","Sa"]
                const start = root.weekStartJs()
                let out = []
                for (let i = 0; i < 7; i++) out.push(days[(start + i) % 7])
                return out
            }
            Item {
                width: dayHeaderRow.width / 7; height: 24
                StyledText {
                    anchors.centerIn: parent; text: modelData
                    font.pixelSize: 10; font.weight: Font.Bold
                    color: Theme.primary; opacity: 0.70; font.letterSpacing: 0.5
                }
            }
        }
    }

    Item { parent: innerCol; width: 1; height: Theme.spacingS }

    // ── Calendar grid ─────────────────────────────────────────────
    Grid {
        id: calGrid
        parent: innerCol
        width: parent.width; columns: 7; rows: 6; spacing: 3
        readonly property int cellSize: Math.floor((width - spacing * 6) / 7)
        readonly property date firstCell: {
            const d = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth(), 1)
            if (isNaN(d.getTime())) return new Date()
            return root.startOfWeek(d)
        }
        Repeater {
            model: 42
            Item {
                width: calGrid.cellSize; height: calGrid.cellSize
                readonly property date dayDate: {
                    const d = new Date(calGrid.firstCell)
                    if (isNaN(d.getTime())) return new Date()
                    d.setDate(d.getDate() + index)
                    return d
                }
                readonly property bool isCurrentMonth: dayDate.getMonth() === root.displayDate.getMonth()
                readonly property bool isToday:    dayDate.toDateString() === new Date().toDateString()
                readonly property bool isSelected: dayDate.toDateString() === root.selectedDate.toDateString()
                readonly property bool isWeekend:  { const d = dayDate.getDay(); return d === 0 || d === 6 }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 4; height: width; radius: width / 2
                    color: {
                        if (isSelected) return Theme.primary
                        if (isToday)    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        if (isCurrentMonth && dayMA.containsMouse)
                                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                        return "transparent"
                    }
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: "transparent"
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
                            if (isToday)    return Theme.primary
                            if (isWeekend)  return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.80)
                            return Theme.surfaceText
                        }
                    }
                }
                MouseArea {
                    id: dayMA; anchors.fill: parent
                    hoverEnabled: isCurrentMonth
                    cursorShape:  isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled:      isCurrentMonth
                    onClicked: { root.selectedDate = dayDate }
                }
            }
        }
    }

    Item { parent: innerCol; width: 1; height: Theme.spacingM }
    Rectangle { parent: innerCol; width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
    Item { parent: innerCol; width: 1; height: Theme.spacingS }

    // ── Selected date + close ─────────────────────────────────────
    RowLayout {
        parent: innerCol
        width: parent.width
        Rectangle {
            Layout.fillWidth: true; height: 30; radius: 15
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
            StyledText {
                anchors.centerIn: parent
                text: root.selectedDate && !isNaN(root.selectedDate.getTime())
                      ? root.selectedDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy") : ""
                font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.primary
                elide: Text.ElideRight
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        Rectangle {
            width: 30; height: 30; radius: 15
            color: closeMA.containsMouse
                   ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                   : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120 } }
            EHIcon { anchors.centerIn: parent; name: "close"; size: 14
                color: closeMA.containsMouse ? Theme.error : Theme.surfaceVariantText }
            MouseArea {
                id: closeMA; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor; onClicked: root.close()
            }
        }
    }

    // ── Events ───────────────────────────────────────────────────
    Column {
        parent: innerCol
        width: parent.width; spacing: Theme.spacingXS
        visible: root.hasEvents; topPadding: Theme.spacingS
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
        Item { width: 1; height: Theme.spacingXS }
        StyledText {
            text: "Events · " + root.selectedDate.toLocaleDateString(Qt.locale(), "MMM d")
            font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Medium
            color: Theme.primary; opacity: 0.80
        }
        Repeater {
            model: root.selectedDateEvents
            delegate: RowLayout {
                width: parent.width; spacing: Theme.spacingS
                Rectangle { width: 6; height: 6; radius: 3; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                StyledText { Layout.fillWidth: true; text: modelData.title || ""; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight }
            }
        }
    }

    // Service integration
    function rebuildCalendarModel() {
        // The popup relies on CalendarService's internal month cache.
        // Keep this function for backwards compatibility with older call sites.
        if (typeof CalendarService !== "undefined" && typeof CalendarService.loadCurrentMonth === "function") {
            CalendarService.loadCurrentMonth()
        }
    }

    Component.onCompleted: {
        CalendarService.checkKhalAvailability()
        selectedDateEvents = CalendarService.getEventsForDate(selectedDate)
        rebuildCalendarModel()
    }
}