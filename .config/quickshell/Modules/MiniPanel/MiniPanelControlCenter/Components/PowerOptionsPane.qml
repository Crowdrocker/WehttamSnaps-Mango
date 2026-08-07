import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool expanded: false
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }

    signal powerActionRequested(string action, string title, string message)

    implicitHeight: root.expanded ? root.spx(56) : 0
    height: implicitHeight
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Compact dock-style background
    Rectangle {
        width: parent.width
        height: root.spx(56)
        radius: Theme.cornerRadius
        color: {
            const alpha = Theme.getContentBackgroundAlpha() * 0.3
            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
        }
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        opacity: root.expanded ? 1 : 0
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        // Compact dock-style row layout
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM
            visible: root.expanded

            PowerButton {
                width: 44
                height: 40
                iconName: "logout"
                onPressed: root.powerActionRequested("logout", "Logout", "Are you sure you want to logout?")
            }

            PowerButton {
                width: 44
                height: 40
                iconName: "restart_alt"
                onPressed: root.powerActionRequested("reboot", "Restart", "Are you sure you want to restart?")
            }

            PowerButton {
                width: 44
                height: 40
                iconName: "bedtime"
                onPressed: root.powerActionRequested("suspend", "Suspend", "Are you sure you want to suspend?")
            }

            PowerButton {
                width: 44
                height: 40
                iconName: "ac_unit"
                visible: SessionService.hibernateSupported
                onPressed: root.powerActionRequested("hibernate", "Hibernate", "Are you sure you want to hibernate?")
            }

            PowerButton {
                width: 44
                height: 40
                iconName: "power_settings_new"
                onPressed: root.powerActionRequested("poweroff", "Shutdown", "Are you sure you want to shutdown?")
            }
        }
    }
}
