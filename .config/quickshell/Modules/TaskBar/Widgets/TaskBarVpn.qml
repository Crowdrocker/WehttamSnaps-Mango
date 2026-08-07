import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property int widgetHeight: 30
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property int barHeight: spx(48)
    property real padding: 0
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleVpnPopup()

    width: isBarVertical ? widgetHeight : (Theme.iconSize + horizontalPadding * 2)
    height: isBarVertical ? (Theme.iconSize + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = clickArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    EHIcon {
        id: icon

        name: VpnService.isBusy ? "sync" : (VpnService.connected ? "vpn_lock" : "vpn_key_off")
        size: (Theme.iconSize - 6) * (widgetHeight / 30)
        color: VpnService.connected ? Theme.primary : Theme.surfaceText
        anchors.centerIn: parent

        RotationAnimation on rotation {
            running: VpnService.isBusy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }

    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                // Get widget position in screen coordinates (like dock does)
                const rect = parent.mapToItem(null, 0, 0, width, height);
                const currentScreen = parentScreen || Screen;
                
                // Calculate taskbar thickness (similar to dock)
                var taskBarThickness = SettingsData?.taskBarHeight || 48;
                
                // Position popup above taskbar, centered on button
                const triggerX = rect.x + rect.width / 2;
                const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness;
                
                popupTarget.setTriggerPosition(triggerX, triggerY, rect.width, "taskbar", currentScreen);
            }
            root.toggleVpnPopup();
        }
    }

    Rectangle {
        id: tooltip

        width: isBarVertical ? (tooltipText.contentHeight + Theme.spacingS * 2) : Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: isBarVertical ? Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2) : (tooltipText.contentHeight + Theme.spacingS * 2)
        radius: Theme.widgetRadius
        color: Theme.widgetBaseBackgroundColor
        border.color: Theme.surfaceVariantAlpha
        border.width: 1
        visible: clickArea.containsMouse && SettingsData.dockTooltipsEnabled && !(popupTarget && popupTarget.shouldBeVisible)
        anchors.bottom: isBarVertical ? undefined : (SettingsData.topBarPosition === "top" ? parent.top : undefined)
        anchors.top: isBarVertical ? undefined : (SettingsData.topBarPosition === "bottom" ? parent.bottom : undefined)
        anchors.bottomMargin: isBarVertical ? undefined : (SettingsData.topBarPosition === "top" ? Theme.spacingS : undefined)
        anchors.topMargin: isBarVertical ? undefined : (SettingsData.topBarPosition === "bottom" ? Theme.spacingS : undefined)
        anchors.horizontalCenter: isBarVertical ? undefined : parent.horizontalCenter
        anchors.right: isBarVertical && SettingsData.topBarPosition === "left" ? parent.left : undefined
        anchors.left: isBarVertical && SettingsData.topBarPosition === "right" ? parent.right : undefined
        anchors.verticalCenter: isBarVertical ? parent.verticalCenter : undefined
        anchors.rightMargin: isBarVertical ? Theme.spacingS : undefined
        anchors.leftMargin: isBarVertical ? Theme.spacingS : undefined
        rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? 90 : -90) : 0
        opacity: clickArea.containsMouse ? 1 : 0

        Text {
            id: tooltipText

            anchors.centerIn: parent
            rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? -90 : 90) : 0
            text: {
                if (!VpnService.connected) {
                    return "VPN Disconnected";
                }

                const names = VpnService.activeNames || [];
                if (names.length <= 1) {
                    return "VPN Connected • " + (names[0] || "");
                }

                return "VPN Connected • " + names[0] + " +" + (names.length - 1);
            }
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
            color: Theme.surfaceText
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }

        }

    }

}
