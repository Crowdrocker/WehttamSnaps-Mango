import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showPopup: false
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0
    property var  parentScreen: null
    property string barPosition: "bottom"
    property real barThickness: 48

    // Calendar state
    property date selectedDate: new Date()
    property date displayDate:  new Date()
    property var  selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    signal dateSelected(date selected)

    function open() {
        if (parentScreen) {
            root.screen = parentScreen
        } else {
            root.screen = Quickshell.screens[0]
        }
        showPopup = true
    }

    function close() {
        showPopup = false
    }

    function openForItem(anchor, screen, barPos, barThick) {
        parentScreen  = screen
        barPosition   = barPos  || "bottom"
        barThickness  = barThick || 48

        const gp = anchor.mapToGlobal(0, 0)
        triggerX     = gp.x - (screen ? (screen.x || 0) : 0)
        triggerY     = gp.y - (screen ? (screen.y || 0) : 0)
        triggerWidth = anchor.width

        if (parentScreen) {
            root.screen = parentScreen
        } else {
            root.screen = Quickshell.screens[0]
        }
        showPopup = true
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

    screen: Quickshell.screens[1] ?? Quickshell.screens[0]
    visible: showPopup
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onVisibleChanged: {
        if (visible) {
            updatePosition()
        }
    }

    function updatePosition() {
        if (!parentScreen) {
            anchorPos = Qt.point(screen.width / 2, screen.height / 2)
            return
        }
        const sx    = screen.x || 0
        const sy    = screen.y || 0
        // Bar thickness is already passed in screen px (includes Dock scale).
        // Only apply compositor/global scale to offsets.
        const ui    = (Appearance.combinedScale || 1)
        const thick = barThickness
        const dist  = 10 * ui
        const off   = 15 * ui
        let tx, ty

        switch (barPosition) {
            case "top":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (sx + screen.width  / 2)
                ty = sy + thick + dist + off
                break
            case "bottom":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (sx + screen.width  / 2)
                ty = sy + screen.height - thick - dist - off
                break
            case "left":
                tx = sx + thick + dist + off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (sy + screen.height / 2)
                break
            case "right":
                tx = sx + screen.width - thick - dist - off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (sy + screen.height / 2)
                break
            default:
                tx = sx + screen.width  / 2
                ty = sy + screen.height / 2
        }
        anchorPos = Qt.point(tx, ty)
    }

    Rectangle {
        id: popupContainer

        readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
        function spx(px) { return Math.round(px * uiScale) }
        readonly property real popupW: spx(340)

        width:          popupW
        implicitHeight: calendarInner.implicitHeight + Theme.spacingM * 2 + 16

        onHeightChanged: root.updatePosition()
        onWidthChanged:  root.updatePosition()

        x: Math.max(10, Math.min(root.screen.width  - width  - 10, root.anchorPos.x - width  / 2))
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

        color: Qt.rgba(
            Theme.surfaceContainer.r,
            Theme.surfaceContainer.g,
            Theme.surfaceContainer.b,
            Math.max(0.55, SettingsData.calendarPopupTransparency !== undefined
                           ? SettingsData.calendarPopupTransparency : 0.88))
        radius: spx(22)
        border.color: SettingsData.calendarPopupDynamicBorderColors
                      ? Theme.primary
                      : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                                SettingsData.calendarPopupBorderOpacity !== undefined
                                ? SettingsData.calendarPopupBorderOpacity : 0.30)
        border.width: SettingsData.calendarPopupBorderEnabled
                      ? Math.max(1, SettingsData.calendarPopupBorderThickness !== undefined
                                    ? SettingsData.calendarPopupBorderThickness : 2)
                      : 0

        opacity: showPopup ? 1 : 0
        scale:   showPopup ? 1 : 0.88
        transformOrigin: root.barPosition === "top" ? Item.Top : Item.Bottom

        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }

        // Drop shadow
        Rectangle {
            anchors.fill:         parent
            anchors.topMargin:    spx(4)
            anchors.leftMargin:   spx(2)
            anchors.rightMargin:  -spx(2)
            anchors.bottomMargin: -spx(4)
            radius: parent.radius
            color:  Theme.shadowMedium
            z: parent.z - 1
        }

        // ── Inner frosted card ────────────────────────────────────────────────
        Rectangle {
            id: calendarInner

            implicitHeight: innerCol.implicitHeight + Theme.spacingL * 2
            anchors {
                fill:    parent
                margins: Theme.spacingS
            }
            radius:       spx(16)
            color: {
                const alpha = (typeof Theme.getContentBackgroundAlpha === "function")
                              ? Theme.getContentBackgroundAlpha() : 0.85
                const op = SettingsData.calendarPopupWidgetBackgroundOpacity !== undefined
                           ? SettingsData.calendarPopupWidgetBackgroundOpacity : 0.60
                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, alpha * op)
            }
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.07)
            border.width: 1
            antialiasing: true

            Column {
                id: innerCol
                anchors {
                    left:    parent.left
                    right:   parent.right
                    top:     parent.top
                    margins: Theme.spacingL
                }
                spacing: 0

                // ── Header ────────────────────────────────────────────────────
                RowLayout {
                    width:   parent.width
                    height:  spx(48)
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
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
                Item { width: 1; height: Theme.spacingM }

                // ── Day headers ───────────────────────────────────────────────
                Row {
                    id: dayHeaderRow
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

                Item { width: 1; height: Theme.spacingS }

                // ── Calendar grid ─────────────────────────────────────────────
                Grid {
                    id: calGrid
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
                                onClicked: { root.selectedDate = dayDate; root.dateSelected(dayDate) }
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingM }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
                Item { width: 1; height: Theme.spacingS }

                // ── Selected date + close ─────────────────────────────────────
                RowLayout {
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
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
