import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var parentScreen: null
    property var systemUpdateLoader: null
    property real widgetHeight: 30
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property bool hasUpdates: SystemUpdateService.updateCount > 0
    readonly property bool isChecking: SystemUpdateService.isChecking

    signal clicked()

    width: isBarVertical ? widgetHeight : (updaterIcon.width + horizontalPadding * 2)
    height: isBarVertical ? (updaterIcon.width + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = updaterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Row {
        id: updaterIcon

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            id: statusIcon

            anchors.verticalCenter: parent.verticalCenter
            name: {
                if (isChecking) return "refresh";
                if (SystemUpdateService.hasError) return "error";
                if (hasUpdates) return "system_update_alt";
                return "check_circle";
            }
            size: (Theme.iconSize - 6) * (widgetHeight / 30)
            color: {
                if (SystemUpdateService.hasError) return Theme.error;
                if (hasUpdates) return Theme.primary;
                return (updaterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText);
            }

            RotationAnimation {
                id: rotationAnimation
                target: statusIcon
                property: "rotation"
                from: 0
                to: 360
                duration: 1000
                running: isChecking
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running) {
                        statusIcon.rotation = 0
                    }
                }
            }
        }

        StyledText {
            id: countText

            anchors.verticalCenter: parent.verticalCenter
            text: SystemUpdateService.updateCount.toString()
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            visible: hasUpdates && !isChecking
        }
    }

    MouseArea {
        id: updaterArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            // Toggle the system update popup directly
            if (root.systemUpdateLoader) {
                root.systemUpdateLoader.active = true
                if (root.systemUpdateLoader.item) {
                    // Get button rect in screen coordinates
                    const rect = updaterArea.mapToItem(null, 0, 0, width, height);
                    const currentScreen = parentScreen || Screen;

                    // Set bar position for proper positioning (top for MiniPanel)
                    root.systemUpdateLoader.item.barPosition = SettingsData.minipanelPosition || "top"
                    root.systemUpdateLoader.item.barThickness = (SettingsData.miniPanelHeight || 48) * (SettingsData.miniPanelScale || 1)

                    // Set trigger position for the popup using setTriggerPosition method
                    root.systemUpdateLoader.item.setTriggerPosition(rect.x, rect.y, rect.width, section, currentScreen)

                    // Toggle the popup
                    root.systemUpdateLoader.item.toggle()
                }
            }
            root.clicked();
        }
    }

}
