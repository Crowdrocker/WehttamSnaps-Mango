import QtQuick
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property int textWidth: 0
    readonly property int currentContentWidth: {
        return volumeRow.implicitWidth + horizontalPadding * 2;
    }
    property string section: "center"
    property var volumeMixerLoader: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.minipanelPosition === "left" || SettingsData.minipanelPosition === "right"
    readonly property real horizontalPadding: SettingsData.minipanelNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: isBarVertical ? widgetHeight : currentContentWidth
    height: isBarVertical ? currentContentWidth : widgetHeight
    radius: SettingsData.minipanelNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.minipanelNoBackground) {
            return "transparent";
        }

        const baseColor = volumeArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    MouseArea {
        id: volumeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            // Toggle the volume mixer directly
            if (root.volumeMixerLoader) {
                root.volumeMixerLoader.active = true
                if (root.volumeMixerLoader.item) {
                    // Get button rect in screen coordinates
                    const rect = volumeArea.mapToItem(null, 0, 0, width, height);
                    const currentScreen = parentScreen || Screen;

                    // Set trigger position for the popup using setTriggerPosition method
                    root.volumeMixerLoader.item.setTriggerPosition(rect.x, rect.y, rect.width, section, currentScreen)
                    
                    // Toggle the popup
                    root.volumeMixerLoader.item.toggle()
                }
            }
            root.clicked();
        }
    }

    Row {
        id: volumeRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            name: AudioService.getOutputIcon()
            size: 16
            color: AudioService.muted ? Theme.error : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter

        }

        StyledText {
            text: Math.round(AudioService.volume * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: AudioService.muted ? Theme.error : Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            visible: SettingsData.mediaSize > 0

        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}