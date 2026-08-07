import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    // Unified icon-OSD size — matches IdleInhibitorOSD
    osdWidth:  Theme.iconSize + Theme.spacingL * 2
    osdHeight: Theme.iconSize + Theme.fontSizeSmall + Theme.spacingXS + Theme.spacingM * 2
    autoHideInterval:     2000
    enableMouseInteraction: false

    Connections {
        target: AudioService
        function onInputMutedChanged() { root.show() }
    }

    content: Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name:  AudioService.inputMuted ? "mic_off" : "mic"
            size:  Theme.iconSize
            color: AudioService.inputMuted ? Theme.error : Theme.primary
            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  AudioService.inputMuted ? "Muted" : "Live"
            font.pixelSize: Theme.fontSizeSmall - 1
            color: AudioService.inputMuted ? Theme.error : Theme.primary
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }
    }
}
