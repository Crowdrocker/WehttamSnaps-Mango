import QtQuick
import Quickshell.Services
import qs.Common
import qs.Services
import qs.Widgets
import Quickshell.Services.UPower

Rectangle {
    id: root

    property string iconName: PerformanceService.getCurrentModeInfo().icon
    property color iconColor: PerformanceService.getCurrentModeInfo().color
    property string primaryText: PerformanceService.isChanging ? "Changing..." : PerformanceService.getCurrentModeInfo().name
    property string secondaryText: ""
    property bool isActive: false

    signal toggled()
    signal wheelEvent(var wheelEvent)

    width: parent ? parent.width : 220
    height: 56
    radius: 12
    antialiasing: true

    function hoverTint(base) {
        const factor = 1.15
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _containerBg:
        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)

    color: _containerBg
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1

    // Subtle tinted overlay for current mode
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        antialiasing: true
        color: PerformanceService.getCurrentModeInfo().color
        opacity: 0.10
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: hoverOverlay
        anchors.fill: parent
        radius: parent.radius
        z: 2
        visible: false
        color: hoverTint(_containerBg)
        opacity: 0.0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 10
        z: 1

        // Icon (no tile box — just the icon itself, cleaner for performance)
        Item {
            width: 36; height: 36
            anchors.verticalCenter: parent.verticalCenter

            EHIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: 20
                color: root.iconColor
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: root.primaryText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                renderType: Text.NativeRendering
            }
        }
    }

    MouseArea {
        id: bodyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered:  { hoverOverlay.visible = true;  hoverOverlay.opacity = 0.07 }
        onExited:   { hoverOverlay.opacity = 0.0;   hoverOverlay.visible = false }
        onPressed:  hoverOverlay.opacity = 0.14
        onReleased: hoverOverlay.opacity = containsMouse ? 0.07 : 0.0
        onClicked: {
            if (PerformanceService.isChanging) return
            const modes = ["power-saver", "balanced", "performance"]
            const currentIndex = modes.indexOf(PerformanceService.currentMode)
            const nextIndex = (currentIndex + 1) % modes.length
            PerformanceService.setMode(modes[nextIndex])
        }
        onWheel: function (ev) { root.wheelEvent(ev) }
    }

    focus: true
    Keys.onPressed: function (ev) {
        if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Return) {
            if (PerformanceService.isChanging) return
            const modes = ["power-saver", "balanced", "performance"]
            const currentIndex = modes.indexOf(PerformanceService.currentMode)
            const nextIndex = (currentIndex + 1) % modes.length
            PerformanceService.setMode(modes[nextIndex])
            ev.accepted = true
        }
    }
}
