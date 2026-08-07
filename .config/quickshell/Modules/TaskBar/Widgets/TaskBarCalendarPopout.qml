import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// TaskBar variant of DockCalendarPopout:
// identical UI, but uses taskbarScale for placement scaling.
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:bar:blur"

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

    screen: Quickshell.screens[0]
    visible: showPopup
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    // Dismiss on backdrop click (and keep clicks inside popup).
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            mouse.accepted = true
            root.close()
        }
    }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onVisibleChanged: if (visible) updatePosition()

    function updatePosition() {
        if (!parentScreen) {
            anchorPos = Qt.point(screen.width / 2, screen.height / 2)
            return
        }
        const sx    = screen.x || 0
        const sy    = screen.y || 0
        const barUi = (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
        const thick = barThickness * barUi
        const dist  = 10 * barUi
        const off   = 15 * barUi
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

        readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
        function spx(px) { return Math.round(px * uiScale) }
        readonly property real popupW: spx(340)

        width:          popupW
        implicitHeight: calendarInner.implicitHeight + Theme.spacingM * 2 + spx(16)

        onHeightChanged: root.updatePosition()
        onWidthChanged:  root.updatePosition()

        x: Math.max(spx(10), Math.min(root.screen.width  - width  - spx(10), root.anchorPos.x - width  / 2))
        y: {
            const margin = spx(10)
            if (root.barPosition === "top") {
                return Math.max(margin, root.anchorPos.y)
            } else if (root.barPosition === "bottom") {
                return Math.min(root.screen.height - height - margin, root.anchorPos.y - height - spx(2))
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

        Rectangle {
            id: calendarInner

            implicitHeight: innerCol.implicitHeight + Theme.spacingL * 2
            anchors { fill: parent; margins: Theme.spacingS }
            radius: spx(16)
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
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                spacing: 0

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
                            color:          Theme.surfaceVariantText
                        }
                    }

                    EHActionButton {
                        circular: false
                        iconName: "chevron_left"
                        iconSize: Theme.iconSize
                        iconColor: Theme.surfaceText
                        onClicked: showPreviousMonth()
                    }
                    EHActionButton {
                        circular: false
                        iconName: "chevron_right"
                        iconSize: Theme.iconSize
                        iconColor: Theme.surfaceText
                        onClicked: showNextMonth()
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10) }
                Item { width: 1; height: Theme.spacingM }

                Row {
                    id: dayHeaderRow
                    width: parent.width
                    height: spx(24)
                    spacing: 0
                    Repeater {
                        model: ["M","T","W","T","F","S","S"]
                        delegate: Item {
                            width: dayHeaderRow.width / 7
                            height: parent.height
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingS }

                GridLayout {
                    id: dayGrid
                    width: parent.width
                    columns: 7
                    rows: 6
                    columnSpacing: popupContainer.spx(3)
                    rowSpacing: popupContainer.spx(3)

                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            readonly property date d0: startOfWeek(new Date(displayDate.getFullYear(), displayDate.getMonth(), 1))
                            readonly property date d:  new Date(d0.getFullYear(), d0.getMonth(), d0.getDate() + index)
                            readonly property bool isCurrentMonth: d.getMonth() === displayDate.getMonth()
                            readonly property bool isToday: {
                                const now = new Date()
                                return d.getFullYear() === now.getFullYear()
                                       && d.getMonth() === now.getMonth()
                                       && d.getDate() === now.getDate()
                            }
                            readonly property bool isSelected: {
                                return selectedDate
                                       && d.getFullYear() === selectedDate.getFullYear()
                                       && d.getMonth() === selectedDate.getMonth()
                                       && d.getDate() === selectedDate.getDate()
                            }

                            Layout.fillWidth: true
                            Layout.preferredHeight: popupContainer.spx(30)
                            radius: popupContainer.spx(15)
                            color: isSelected
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                   : "transparent"
                            border.width: (isToday || isSelected) ? 1 : 0
                            border.color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.65)
                                                  : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                            StyledText {
                                anchors.centerIn: parent
                                text: "" + d.getDate()
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isToday ? Font.Bold : Font.Normal
                                color: isCurrentMonth ? Theme.surfaceText : Theme.surfaceVariantText
                                opacity: isCurrentMonth ? 1.0 : 0.55
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectedDate = d
                                    selectedDateEvents = CalendarService.getEventsForDate(d)
                                    root.dateSelected(d)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Eat pointer events inside the popup so backdrop doesn't close.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: (mouse) => { mouse.accepted = true }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        }
    }
}

