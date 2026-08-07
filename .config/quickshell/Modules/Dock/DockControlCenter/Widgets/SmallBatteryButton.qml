import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: BatteryService.batteryAvailable && (BatteryService.isCharging || BatteryService.isPluggedIn)
    property bool enabled: BatteryService.batteryAvailable

    signal clicked()

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: 12
    antialiasing: true

    function hoverTint(base) {
        const factor = 1.15
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _tileBgActive: Theme.primary
    readonly property color _tileBgInactive: {
        const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    readonly property color _tileRingActive:
        Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)
    readonly property color _tileIconActive: Theme.primaryContainer
    readonly property color _tileIconInactive: Theme.primary

    color: isActive ? _tileBgActive : _tileBgInactive
    border.color: isActive ? _tileRingActive : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hoverTint(root.color)
        opacity: mouseArea.pressed ? 0.25 : (mouseArea.containsMouse ? 0.15 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 3

        EHIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: BatteryService.getBatteryIcon()
            size: 18
            color: {
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                return isActive ? _tileIconActive : _tileIconInactive
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: BatteryService.batteryAvailable ? `${BatteryService.batteryLevel}%` : ""
            font.pixelSize: 10
            font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: {
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                return isActive ? _tileIconActive : _tileIconInactive
            }
            visible: BatteryService.batteryAvailable
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
}
