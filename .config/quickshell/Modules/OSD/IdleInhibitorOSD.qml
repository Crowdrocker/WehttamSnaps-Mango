import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    // Unified icon-OSD size — matches MicMuteOSD
    osdWidth:  Theme.iconSize + Theme.spacingL * 2
    osdHeight: Theme.iconSize + Theme.fontSizeSmall + Theme.spacingXS + Theme.spacingM * 2
    autoHideInterval:     2000
    enableMouseInteraction: false

    Connections {
        target: SessionService
        function onInhibitorChanged() { root.show() }
    }

    content: Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name:  SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
            size:  Theme.iconSize
            color: SessionService.idleInhibited ? Theme.primary : Theme.surfaceVariantText
            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  SessionService.idleInhibited ? "Inhibited" : "Idle"
            font.pixelSize: Theme.fontSizeSmall - 1
            color: SessionService.idleInhibited ? Theme.primary : Theme.surfaceVariantText
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }
    }
}
