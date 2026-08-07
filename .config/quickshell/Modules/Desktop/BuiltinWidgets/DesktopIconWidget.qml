import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    readonly property string desktopFilePath:  cfg?.desktopFilePath  ?? ""
    readonly property string desktopFileName:  cfg?.desktopFileName  ?? ""
    readonly property string desktopName:      cfg?.desktopName      ?? desktopFileName.replace(/\.desktop$/, "").replace(/\.ink$/, "")
    readonly property string desktopIcon:      cfg?.desktopIcon      ?? "application-x-desktop"
    readonly property string desktopExec:      cfg?.desktopExec      ?? ""
    readonly property string desktopWorkingDir:cfg?.desktopWorkingDir ?? ""
    readonly property bool   desktopIsLink:    cfg?.desktopIsLink    ?? false
    readonly property string linkTarget:       cfg?.linkTarget       ?? ""

    property real widgetWidth:   isInstance ? (cfg?.width  ?? 100) : 100
    property real widgetHeight:  isInstance ? (cfg?.height ?? 100) : 100
    property real defaultWidth:  100
    property real defaultHeight: 100
    property real minWidth:  64
    property real minHeight: 64

    readonly property real iconDisplaySize: Math.min(widgetWidth, widgetHeight) * 0.62
    readonly property string iconPath: Quickshell.iconPath(desktopIcon, true) || ""

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight

    function launchDesktopItem() {
        if (desktopIsLink && linkTarget) {
            Quickshell.execDetached(["xdg-open", linkTarget])
        } else if (desktopExec) {
            const appId = desktopFileName.replace(/\.desktop$/, "")
            if (typeof SessionService !== "undefined") {
                const entry = DesktopEntries.lookup(desktopFilePath)
                if (entry) SessionService.launchDesktopEntry(entry)
                else Quickshell.execDetached(["gtk-launch", appId])
            } else {
                Quickshell.execDetached(["gtk-launch", appId])
            }
        } else {
            Quickshell.execDetached(["xdg-open", desktopFilePath])
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 5

        // Icon bubble
        Rectangle {
            id: iconBubble
            width: iconDisplaySize + 16
            height: iconDisplaySize + 16
            radius: (iconDisplaySize + 16) * 0.22
            anchors.horizontalCenter: parent.horizontalCenter
            color: iconArea.containsMouse
                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                   : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
            border.color: iconArea.containsMouse
                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                          : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1

            Behavior on color  { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

            // Press scale
            scale: iconArea.pressed ? 0.91 : (iconArea.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }

            Image {
                id: iconImage
                anchors.centerIn: parent
                width: iconDisplaySize
                height: iconDisplaySize
                source: root.iconPath
                smooth: true
                asynchronous: true
                fillMode: Image.PreserveAspectFit

                EHIcon {
                    anchors.centerIn: parent
                    name: "application-x-desktop"
                    size: iconDisplaySize * 0.75
                    color: Theme.surfaceTextMedium
                    visible: iconImage.status !== Image.Ready || !root.iconPath
                }
            }
        }

        // Label
        StyledText {
            width: iconDisplaySize + 20
            text: root.desktopName
            font.pixelSize: 10
            font.weight: Font.Medium
            color: Theme.surfaceText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 2
            wrapMode: Text.Wrap
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: iconArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:       (e) => { if (e.button === Qt.LeftButton) root.launchDesktopItem() }
        onDoubleClicked: (e) => { if (e.button === Qt.LeftButton) root.launchDesktopItem() }
    }
}
