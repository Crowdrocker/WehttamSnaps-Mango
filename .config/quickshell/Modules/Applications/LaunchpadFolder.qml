import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// Folder tile — shown in the launchpad grid in place of individual apps
Item {
    id: root

    property string folderId:    ""
    property string folderName:  ""
    property var    appIds:      []
    property real   tileSize:    80
    property real   uiScale:     1.0
    property bool   isDropTarget: false  // set by the grid when something is dragged over

    signal clicked(string folderId)

    width:  tileSize
    height: tileSize

    // ── Background pill ───────────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Math.max(10, tileSize * 0.18)
        color: root.isDropTarget
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
            : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
        border.width: root.isDropTarget ? 2 : 1
        border.color: root.isDropTarget
            ? Theme.primary
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
        Behavior on color        { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        scale: folderArea.containsMouse ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    }

    // ── Mini icon grid (up to 4 icons in 2×2) ────────────────────────────────
    Grid {
        id: miniGrid
        anchors.centerIn: parent
        columns: 2
        rows:    2
        spacing: Math.max(2, tileSize * 0.05)

        readonly property real iconSize: tileSize * 0.30

        Repeater {
            model: Math.min(4, root.appIds.length)

            Item {
                width:  miniGrid.iconSize
                height: miniGrid.iconSize

                Image {
                    anchors.fill: parent
                    source: Quickshell.iconPath(
                        DesktopEntries.heuristicLookup(root.appIds[index])?.icon || "application-x-executable",
                        true
                    )
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }
            }
        }
    }

    // ── Click ─────────────────────────────────────────────────────────────────
    MouseArea {
        id: folderArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.folderId)
    }
}
