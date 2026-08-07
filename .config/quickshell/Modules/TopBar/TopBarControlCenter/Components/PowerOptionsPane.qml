import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool expanded: false

    signal powerActionRequested(string action, string title, string message)

    implicitHeight: root.expanded ? (contentRect.height) : 0
    height: implicitHeight
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: contentRect
        width: parent.width
        height: buttonsRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        border.width: 1
        opacity: root.expanded ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            id: buttonsRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.spacingM
                rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS

            PowerButton {
                iconName: "logout"
                text: "Log Out"
                accentColor: Theme.primary
                Layout.fillWidth: true
                onPressed: root.powerActionRequested("logout", "Log Out", "Are you sure you want to log out?")
            }

            PowerButton {
                iconName: "bedtime"
                text: "Suspend"
                accentColor: Theme.primary
                Layout.fillWidth: true
                onPressed: root.powerActionRequested("suspend", "Suspend", "Are you sure you want to suspend?")
            }

            PowerButton {
                iconName: "ac_unit"
                text: "Hibernate"
                accentColor: Theme.primary
                Layout.fillWidth: true
                visible: SessionService.hibernateSupported
                onPressed: root.powerActionRequested("hibernate", "Hibernate", "Are you sure you want to hibernate?")
            }

            PowerButton {
                iconName: "restart_alt"
                text: "Restart"
                accentColor: Theme.warning
                Layout.fillWidth: true
                onPressed: root.powerActionRequested("reboot", "Restart", "Are you sure you want to restart?")
            }

            PowerButton {
                iconName: "power_settings_new"
                text: "Shut Down"
                accentColor: Theme.error
                Layout.fillWidth: true
                onPressed: root.powerActionRequested("poweroff", "Shut Down", "Are you sure you want to shut down?")
            }
        }
    }
}
