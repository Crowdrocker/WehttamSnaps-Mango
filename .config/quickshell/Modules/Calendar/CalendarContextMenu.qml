import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Dock

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showContextMenu: false
    property var  eventObj: null
    property point anchorPos: Qt.point(200, 200) // screen coordinates

    signal editRequested(var eventObj)
    signal removeRequested(var eventObj)

    function showAt(screenX, screenY, ev) {
        eventObj = ev || null
        // pick the screen the point falls within
        for (var i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i]
            if (screenX >= s.x && screenX < s.x + s.width &&
                screenY >= s.y && screenY < s.y + s.height) {
                root.screen = s
                break
            }
        }
        // store as coords relative to our screen's origin
        anchorPos = Qt.point(screenX - root.screen.x, screenY - root.screen.y)
        showContextMenu = true
    }

    function close() { showContextMenu = false }

    screen: Quickshell.screens[0]
    visible: showContextMenu
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    readonly property int rateAwareDuration: Math.round(Theme.mediumDuration * 60 / Math.max(60, screen ? screen.refreshRate : 60))

    Item {
        id: menuContainer

        readonly property int r: Theme.cornerRadius + 2

        width:  Math.min(260, Math.max(200, menuColumn.implicitWidth + Theme.spacingM * 2))
        height: menuColumn.implicitHeight + Theme.spacingS * 2

        x: Math.max(10, Math.min(root.width - width - 10, root.anchorPos.x - width / 2))
        y: Math.max(10, Math.min(root.height - height - 10, root.anchorPos.y - height / 2))

        opacity: showContextMenu ? 1 : 0
        scale:   showContextMenu ? 1 : 0.92

        Behavior on opacity { NumberAnimation { duration: root.rateAwareDuration; easing.type: Theme.emphasizedEasing } }
        Behavior on scale   { NumberAnimation { duration: root.rateAwareDuration; easing.type: Theme.emphasizedEasing } }

        Rectangle {
            anchors { fill: parent; topMargin: 4; leftMargin: 2; rightMargin: -2; bottomMargin: -4 }
            radius: menuContainer.r
            color:  Qt.rgba(0, 0, 0, 0.18)
            z:      -1
        }

        Rectangle {
            anchors.fill: parent
            radius: menuContainer.r
            color: Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingM * 2
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.spacingS }
            spacing: 0

            DockMenuRow {
                label: "Edit"
                iconName: "edit"
                onActivated: {
                    root.editRequested(root.eventObj)
                    root.close()
                }
            }

            DockMenuSeparator { visible: true }

            DockMenuRow {
                label: "Remove Event"
                iconName: "delete"
                isDanger: true
                onActivated: {
                    root.removeRequested(root.eventObj)
                    root.close()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
    }
}

