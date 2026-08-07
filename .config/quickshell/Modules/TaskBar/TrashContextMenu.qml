import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:taskbar:trash"

    property bool showContextMenu: false
    property var anchorItem: null
    property real taskBarVisibleHeight: 40
    property int margin: 10
    property var appData: null
    property var desktopEntry: null

    signal trashEmptied()

    function showForButton(button, data, taskBarHeight, entry) {
        if (showContextMenu && anchorItem === button) {
            close()
            return
        }

        anchorItem = button
        appData = data
        taskBarVisibleHeight = taskBarHeight || 40
        desktopEntry = entry || null

        const taskBarWindow = button.Window.window
        if (taskBarWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (taskBarWindow.x >= s.x && taskBarWindow.x < s.x + s.width) {
                    root.screen = s
                    break
                }
            }
        }

        showContextMenu = true
    }

    function close() {
        showContextMenu = false
    }

    screen: Quickshell.screens[0]

    visible: showContextMenu
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

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: {
        if (visible) {
            updatePosition()
        }
    }

    function updatePosition() {
        if (!anchorItem) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100)
            return
        }

        const taskBarWindow = anchorItem.Window.window
        if (!taskBarWindow) {
            anchorPos = Qt.point(screen.width / 2, screen.height - 100)
            return
        }

        const buttonPosInTaskBar = anchorItem.mapToItem(taskBarWindow.contentItem, 0, 0)
        let actualTaskBarHeight = root.taskBarVisibleHeight

        function findTaskBarBackground(item) {
            if (item.objectName === "panelBackground") {
                return item
            }
            for (var i = 0; i < item.children.length; i++) {
                const found = findTaskBarBackground(item.children[i])
                if (found) {
                    return found
                }
            }
            return null
        }

        const taskBarBackground = findTaskBarBackground(taskBarWindow.contentItem)
        if (taskBarBackground) {
            actualTaskBarHeight = taskBarBackground.height
        }

        const taskBarTopMargin = 16
        const buttonScreenY = root.screen.height - actualTaskBarHeight - taskBarTopMargin

        // Calculate button X position on screen
        // buttonPosInTaskBar is relative to taskBarWindow.contentItem
        // We need to add the taskbar window's X position on screen
        const taskBarWindowX = taskBarWindow.x - root.screen.x
        const buttonScreenX = taskBarWindowX + buttonPosInTaskBar.x + anchorItem.width / 2

        anchorPos = Qt.point(buttonScreenX, buttonScreenY)
    }

    Rectangle {
        id: menuContainer

        width: Math.min(200, Math.max(150, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(50, menuColumn.implicitHeight + Theme.spacingS * 2)

        x: {
            const left = 10
            const right = root.width - width - 10
            const want = root.anchorPos.x - width / 2
            return Math.max(left, Math.min(right, want))
        }
        y: Math.max(10, root.anchorPos.y - height - 10)
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        opacity: showContextMenu ? 1 : 0
        scale: showContextMenu ? 1 : 0.85

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingS
            spacing: 1

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: emptyArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Empty Trash"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: emptyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Execute trash emptying command
                            emptyTrashProcess.running = true
                            root.close()
                        }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    // Process to empty trash
    Process {
        id: emptyTrashProcess
        running: false
        command: ["sh", "-c", "rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/* 2>/dev/null; true"]

        onExited: exitCode => {
            console.log("Trash emptied, exit code:", exitCode)
            // Signal that trash was emptied (will be picked up by parent widget)
            root.trashEmptied && root.trashEmptied()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.close()
        }
    }
}