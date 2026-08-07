import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.TaskBar

Item {
    id: root

    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property bool pillEnabled: SettingsData.dockTrashPillEnabled

    // Trash state tracking
    property bool isTrashEmpty: true
    property bool trashCheckRunning: false

    // Shell directory for asset paths
    readonly property string shellDir: Paths.strip(Qt.resolvedUrl("../../../").toString())

    implicitWidth: pillEnabled ? pillBackground.implicitWidth : trashIcon.width
    implicitHeight: pillEnabled ? pillBackground.implicitHeight : trashIcon.height
    width: implicitWidth
    height: implicitHeight

    property bool isHovered: mouseArea.containsMouse

    onIsHoveredChanged: {
        if (isHovered) {
            exitAnimation.stop()
            if (!bounceAnimation.running) bounceAnimation.restart()
        } else {
            bounceAnimation.stop()
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: bounceAnimation
        running: false
        NumberAnimation { target: translateY; property: "y"; to: -Math.round(10 * uiScale); duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: translateY; property: "y"; to: -Math.round(8 * uiScale);  duration: 120; easing.type: Easing.InCubic }
    }

    NumberAnimation {
        id: exitAnimation
        running: false
        target: translateY; property: "y"; to: 0
        duration: 150
        easing.type: Easing.OutCubic
    }

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)

    transform: Translate { id: translateY; y: 0 }

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        visible: root.pillEnabled
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.widgetTransparency)
        radius: Theme.widgetRadius
        border.width: 0
        border.color: "transparent"
        clip: true

        implicitWidth: trashIcon.width + 16
        implicitHeight: root.widgetHeight

        Image {
            id: trashIcon
            anchors.centerIn: parent
            width: (SettingsData.taskbarIconSize || 30) * SettingsData.taskbarScale
            height: (SettingsData.taskbarIconSize || 30) * SettingsData.taskbarScale
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            antialiasing: true

            // Use custom macOS-style trash icons based on trash state
            source: isTrashEmpty ? Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Empty.png")
                               : Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Full.png")

            // Update icon when trash state changes
            Connections {
                target: trashChecker
                function onTrashStateChanged() {
                    trashIcon.source = isTrashEmpty ? Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Empty.png")
                                                  : Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Full.png")
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    // Left-click: Open trash in default file browser
                    trashOpenProcess.running = true;
                } else if (mouse.button === Qt.RightButton) {
                    // Right-click: Show context menu
                    if (trashContextMenuLoader.item) {
                        trashContextMenuLoader.item.showForButton(root, null, root.parent ? root.parent.height : 40, null)
                    }
                }
            }
        }
    }

    // Non-pill version
    Image {
        id: trashIconNoPill
        visible: !root.pillEnabled
        anchors.centerIn: parent
        width: (SettingsData.taskbarIconSize || 30) * SettingsData.taskbarScale
        height: (SettingsData.taskbarIconSize || 30) * SettingsData.taskbarScale
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        antialiasing: true

        source: isTrashEmpty ? Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Empty.png")
                           : Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Full.png")

        Connections {
            target: trashChecker
            function onTrashStateChanged() {
                trashIconNoPill.source = isTrashEmpty ? Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Empty.png")
                                                    : Qt.resolvedUrl(shellDir + "/assets/MacOS-Trash-Full.png")
            }
        }
    }

    MouseArea {
        id: mouseAreaNoPill
        visible: !root.pillEnabled
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                trashOpenProcess.running = true;
            } else if (mouse.button === Qt.RightButton) {
                if (trashContextMenuLoader.item) {
                    trashContextMenuLoader.item.showForButton(root, null, root.parent ? root.parent.height : 40, null)
                }
            }
        }
    }

    // Context menu loader
    Loader {
        id: trashContextMenuLoader
        active: true
        asynchronous: false
        sourceComponent: TrashContextMenu {
            screen: root.parentScreen || Quickshell.screens[0]
            onTrashEmptied: {
                // Immediately recheck trash state after emptying
                trashCheckRunning = true;
                trashCheckProcess.running = true;
            }
        }
    }

    // Trash state checker
    Item {
        id: trashChecker

        signal trashStateChanged()

        Process {
            id: trashCheckProcess
            running: false
            command: ["sh", "-c", "ls ~/.local/share/Trash/files/ | grep -v '^\\.$' | grep -v '^\\.\\.$' | wc -l"]

            onExited: exitCode => {
                if (exitCode === 0 && stdout) {
                    const count = parseInt(stdout.trim());
                    const hasItems = count > 0;
                    if (root.isTrashEmpty !== !hasItems) {
                        root.isTrashEmpty = !hasItems;
                        trashChecker.trashStateChanged();
                    }
                }
                trashCheckRunning = false;
            }
        }

        // Process to open trash in file browser
        Process {
            id: trashOpenProcess
            running: false
            command: ["sh", "-c", "xdg-open ~/.local/share/Trash/files"]
        }

        Timer {
            id: trashCheckTimer
            interval: 5000  // Check every 5 seconds
            running: false  // Disabled automatic checking
            repeat: true
            onTriggered: {
                if (!trashCheckRunning) {
                    trashCheckRunning = true;
                    trashCheckProcess.running = true;
                }
            }
        }
    }

    Component.onCompleted: {
        // Initial check
        trashCheckRunning = true;
        trashCheckProcess.running = true;
    }
}
