import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var instanceData: null
    property var screen: null

    readonly property var    cfg:         instanceData?.config ?? {}
    readonly property string desktopPath: StandardPaths.writableLocation(StandardPaths.DesktopLocation)

    readonly property int iconSize:    cfg.iconSize    ?? 64
    readonly property int iconSpacing: cfg.iconSpacing ?? 20
    readonly property int labelHeight: 22

    anchors.fill: parent

    FolderListModel {
        id: folderModel
        folder:          "file://" + desktopPath
        showDirsFirst:   true
        showDotAndDotDot:false
        showHidden:      cfg.showHidden ?? false
        nameFilters:     ["*.desktop", "*"]
        showFiles:       true
        showDirs:        true
        sortField:       FolderListModel.Name
        sortReversed:    false
    }

    GridView {
        id: iconsGrid
        anchors.fill: parent
        anchors.margins: iconSpacing
        cellWidth:  iconSize + iconSpacing
        cellHeight: iconSize + iconSpacing + labelHeight
        model: folderModel
        clip:  true

        delegate: Item {
            id: iconItem
            width:  iconsGrid.cellWidth
            height: iconsGrid.cellHeight

            readonly property bool   isDesktopFile: fileName.endsWith(".desktop")
            readonly property string fileName:      folderModel.get(index, "fileName")
            readonly property string filePath:      folderModel.get(index, "filePath")
            readonly property bool   isDir:         folderModel.get(index, "fileIsDir")
            readonly property string fileUrl:       folderModel.get(index, "fileURL")
            readonly property string displayName:   isDesktopFile ? fileName.replace(/\.desktop$/, "") : fileName

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                // Icon bubble
                Rectangle {
                    width:  iconSize
                    height: iconSize
                    radius: iconSize * 0.18
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: itemArea.containsMouse
                           ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                           : "transparent"
                    border.color: itemArea.containsMouse
                                  ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                  : "transparent"
                    border.width: 1

                    Behavior on color       { ColorAnimation { duration: Theme.shortDuration } }
                    Behavior on border.color{ ColorAnimation { duration: Theme.shortDuration } }

                    scale: itemArea.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }

                    EHIcon {
                        anchors.centerIn: parent
                        name: {
                            if (isDir)         return "folder"
                            if (isDesktopFile) return "description"
                            return "insert_drive_file"
                        }
                        size: iconSize - 18
                        color: itemArea.containsMouse ? Theme.primary : Theme.surfaceText
                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                    }
                }

                StyledText {
                    width: iconSize + 16
                    text: displayName
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: itemArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button !== Qt.LeftButton) return
                    if (isDir)              Quickshell.execDetached(["xdg-open", fileUrl])
                    else if (isDesktopFile) Quickshell.execDetached(["gtk-launch", fileName.replace(/\.desktop$/, "")])
                    else                   Quickshell.execDetached(["xdg-open", fileUrl])
                }
                onDoubleClicked: {
                    if (isDir)              Quickshell.execDetached(["xdg-open", fileUrl])
                    else if (isDesktopFile) Quickshell.execDetached(["gtk-launch", fileName.replace(/\.desktop$/, "")])
                    else                   Quickshell.execDetached(["xdg-open", fileUrl])
                }
            }
        }
    }
}
