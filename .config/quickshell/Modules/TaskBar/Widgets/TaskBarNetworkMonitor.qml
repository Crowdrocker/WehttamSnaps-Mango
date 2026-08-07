import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Modules.ProcessList
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property real widgetHeight: 30
    property real padding: 0
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property int availableWidth: 400
    readonly property int baseWidth: contentRow.implicitWidth + Theme.spacingS * 2
    readonly property int maxNormalWidth: 456
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    function formatNetworkSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) {
            return bytesPerSec.toFixed(0) + " B/s";
        } else if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s";
        }
    }

    width: contentRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = networkArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["network"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["network"]);
    }

    MouseArea {
        id: networkArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        EHIcon {
            name: "network_check"
            size: (Theme.iconSize - 8) * (root.widgetHeight / 30)
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: "↓"
                font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                color: Theme.info
                
            }

            StyledText {
                text: DgopService.networkRxRate > 0 ? formatNetworkSpeed(DgopService.networkRxRate) : "0 B/s"
                font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.NoWrap
                

                StyledTextMetrics {
                    id: rxBaseline
                    font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                    font.weight: Font.Medium
                    text: "88.8 MB/s"
                }

                width: Math.max(rxBaseline.width, paintedWidth)

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StyledText {
                text: "↑"
                font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                color: Theme.error
                
            }

            StyledText {
                text: DgopService.networkTxRate > 0 ? formatNetworkSpeed(DgopService.networkTxRate) : "0 B/s"
                font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.NoWrap
                
                StyledTextMetrics {
                    id: txBaseline
                    font.pixelSize: Theme.fontSizeSmall * (root.widgetHeight / 30)
                    font.weight: Font.Medium
                    text: "88.8 MB/s"
                }

                width: Math.max(txBaseline.width, paintedWidth)

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

        }

    }


}
