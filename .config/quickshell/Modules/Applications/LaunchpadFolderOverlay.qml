import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// macOS-style centered folder overlay shown on top of the launchpad
Item {
    id: root

    property string folderId:   ""
    property string folderName: ""
    property var    appIds:     []
    property real   uiScale:    1.0
    property var    appLauncher: null  // reference to AppLauncher for launching

    signal closed()
    signal appRemoved(string appId)   // app dragged out of folder
    signal appLaunched()

    readonly property real iconSize:  Math.max(52, Math.min(120, Math.round(72 * uiScale)))
    readonly property real overlayW:  Math.max(320, Math.min(800, Math.round(520 * uiScale)))
    readonly property real overlayH:  Math.max(240, nameField.height + gridItem.implicitHeight + 80)

    visible: folderId !== ""

    // ── Dim backdrop (click to close) ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    // ── Folder card ───────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  root.overlayW
        height: cardCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius + 4
        color:  Qt.rgba(
            Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
            0.92
        )
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        clip: false

        scale:   root.visible ? 1.0 : 0.88
        opacity: root.visible ? 1.0 : 0.0
        Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        // Drop shadow
        Rectangle {
            anchors { fill: parent; topMargin: 6; leftMargin: 3; rightMargin: -3; bottomMargin: -6 }
            radius: card.radius
            color:  Qt.rgba(0, 0, 0, 0.22)
            z: -1
        }

        ColumnLayout {
            id: cardCol
            anchors {
                left: parent.left; right: parent.right
                top:  parent.top
                margins: Theme.spacingL
            }
            spacing: Theme.spacingM

            // ── Editable folder name ──────────────────────────────────────────
            Item {
                id: nameField
                Layout.fillWidth: true
                Layout.preferredHeight: nameInput.implicitHeight + Theme.spacingS * 2

                // Underline — only visible when editing
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 2
                    radius: 1
                    color: nameInput.activeFocus
                        ? Theme.primary
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextInput {
                    id: nameInput
                    anchors.centerIn: parent
                    width: parent.width
                    text: root.folderName
                    font.pixelSize: Math.max(14, Math.round((Theme.fontSizeLarge ?? 18) * root.uiScale))
                    font.weight: Font.SemiBold
                    color: Theme.surfaceText
                    horizontalAlignment: TextInput.AlignHCenter
                    selectByMouse: true
                    clip: true

                    onTextEdited: {
                        if (text.trim().length > 0 && root.folderId !== "") {
                            LaunchpadFolderService.renameFolder(root.folderId, text.trim())
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            }

            // ── App grid inside folder ────────────────────────────────────────
            Item {
                id: gridItem
                Layout.fillWidth: true
                Layout.preferredHeight: folderGrid.implicitHeight

                Grid {
                    id: folderGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: Math.max(2, Math.min(6, Math.ceil(Math.sqrt(root.appIds.length))))
                    spacing: Math.max(8, Math.round(Theme.spacingM * root.uiScale))

                    Repeater {
                        model: root.appIds

                        Item {
                            id: appTile
                            property string appId: modelData
                            property var    entry: DesktopEntries.heuristicLookup(appId)
                            readonly property real iSize: root.iconSize

                            width:  iSize + Theme.spacingS * 2
                            height: iSize + Theme.spacingS * 2

                            // Drag out of folder
                            Drag.active:    dragArea.drag.active
                            Drag.hotSpot.x: iSize / 2
                            Drag.hotSpot.y: iSize / 2
                            Drag.keys:      ["appId"]
                            Drag.mimeData:  { "appId": appId }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width:  appTile.iSize
                                    height: appTile.iSize
                                    radius: Math.max(8, appTile.iSize * 0.18)
                                    color:  dragArea.containsMouse
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                        : "transparent"
                                    scale: dragArea.containsMouse ? 1.07 : 1.0
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                    Image {
                                        anchors { fill: parent; margins: 4 }
                                        source: Quickshell.iconPath(appTile.entry?.icon || "application-x-executable", true)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                drag.target:  appTile
                                drag.threshold: 8

                                onClicked: {
                                    if (!drag.active && appTile.entry) {
                                        appLauncher?.launchApp({
                                            name: appTile.entry.name,
                                            exec: appTile.entry.execString || appTile.entry.exec,
                                            icon: appTile.entry.icon,
                                            desktopEntry: appTile.entry
                                        })
                                        root.appLaunched()
                                    }
                                }
                            }

                            // Drop zone for dragging back out — the overlay's DropArea handles it
                            states: State {
                                when: appTile.Drag.active
                                PropertyChanges { target: appTile; opacity: 0.4 }
                            }
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }
                }
            }

            // ── Hint text ─────────────────────────────────────────────────────
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Drag app out to remove from folder"
                font.pixelSize: Math.max(9, Math.round((Theme.fontSizeSmall - 1) * root.uiScale))
                color: Theme.surfaceVariantText
                opacity: 0.5
            }
        }
    }

    // Drop area covering the whole overlay — catches apps dragged out of the folder
    DropArea {
        anchors.fill: parent
        keys: ["appId"]
        onDropped: drag => {
            const appId = drag.getDataAsString("appId")
            if (appId && root.folderId) {
                LaunchpadFolderService.removeAppFromFolder(root.folderId, appId)
                root.appRemoved(appId)
                // If folder dissolved (< 2 apps), close
                Qt.callLater(() => {
                    if (!LaunchpadFolderService.getFolderById(root.folderId)) {
                        root.closed()
                    }
                })
            }
        }
    }

    // Sync name input when folder changes externally
    onFolderNameChanged: {
        if (nameInput.text !== folderName) nameInput.text = folderName
    }
}
