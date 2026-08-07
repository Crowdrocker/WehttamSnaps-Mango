import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool hasUnread: false
    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real padding: 1
    property real iconSize: 64
    property real iconSpacing: 4
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real barHeight: spx(48)
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: isBarVertical ? widgetHeight : (notificationIcon.width + horizontalPadding * 2)
    height: isBarVertical ? (notificationIcon.width + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = notificationArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    EHIcon {
        id: notificationIcon

        anchors.centerIn: parent
        name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
        size: (Theme.iconSize - 6) * (widgetHeight / 30)
        color: SessionData.doNotDisturb ? Theme.error : (notificationArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText)
        
    }

    Rectangle {
        width: spx(8)
        height: spx(8)
        radius: spx(4)
        color: Theme.error
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: SettingsData.topBarNoBackground ? 0 : spx(6)
        anchors.topMargin: SettingsData.topBarNoBackground ? 0 : spx(6)
        visible: root.hasUnread
    }

    MouseArea {
        id: notificationArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                // Get widget position in screen coordinates (like dock does)
                const rect = parent.mapToItem(null, 0, 0, width, height);
                const currentScreen = parentScreen || Screen;
                
                // Calculate taskbar thickness (similar to dock)
                var taskBarThickness = SettingsData?.taskBarHeight || spx(48);
                
                // Position popup above taskbar, centered on button
                const triggerX = rect.x + rect.width / 2;
                const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness;
                
                popupTarget.setTriggerPosition(triggerX, triggerY, rect.width, "taskbar", currentScreen);
            }
            root.clicked();
        }
    }


}
