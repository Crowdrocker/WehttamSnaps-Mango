import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: battery

    property bool batteryPopupVisible: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real barHeight: spx(48)
    property real padding: 0
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleBatteryPopup()

    width: isBarVertical ? widgetHeight : (batteryContentRow.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (batteryContentColumn.implicitHeight + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = batteryArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: true

    Row {
        id: batteryContentRow
        visible: !isBarVertical
        anchors.centerIn: parent
        spacing: (SettingsData.topBarNoBackground ? 1 : 2) * (widgetHeight / 30)

        EHIcon {
            name: BatteryService.getBatteryIcon()
            size: (Theme.iconSize - 6) * (widgetHeight / 30)
            color: {
                if (!BatteryService.batteryAvailable) {
                    return Theme.surfaceText;
                }

                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error;
                }

                if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                    return Theme.primary;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
            
        }

        StyledText {
            text: `${BatteryService.batteryLevel}%`
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.batteryAvailable
            
        }
    }
    
    Column {
        id: batteryContentColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: SettingsData.topBarNoBackground ? 1 : 2

        EHIcon {
            name: BatteryService.getBatteryIcon()
            size: (Theme.iconSize - 6) * (widgetHeight / 30)
            color: {
                if (!BatteryService.batteryAvailable) {
                    return Theme.surfaceText;
                }

                if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                    return Theme.error;
                }

                if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                    return Theme.primary;
                }

                return Theme.surfaceText;
            }
            anchors.horizontalCenter: parent.horizontalCenter
            
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            visible: BatteryService.batteryAvailable
            
            Repeater {
                model: {
                    const levelStr = BatteryService.batteryLevel.toString()
                    const chars = ['%']
                    for (let i = 0; i < levelStr.length; i++) {
                        chars.push(levelStr[i])
                    }
                    return chars
                }
                
                StyledText {
                    text: modelData
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                }
            }
        }
    }

    MouseArea {
        id: batteryArea

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
                // triggerY should be the top of the taskbar area - EHPopout will position above it
                const triggerX = rect.x + rect.width / 2;
                const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness;
                
                popupTarget.setTriggerPosition(triggerX, triggerY, rect.width, "taskbar", currentScreen);
            }
            toggleBatteryPopup();
        }
    }

    Rectangle {
        id: batteryTooltip

        width: isBarVertical ? (tooltipText.contentHeight + Theme.spacingS * 2) : Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: isBarVertical ? Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2) : (tooltipText.contentHeight + Theme.spacingS * 2)
        radius: Theme.widgetRadius
        color: Theme.widgetBaseBackgroundColor
        border.color: Theme.surfaceVariantAlpha
        border.width: 1
        visible: batteryArea.containsMouse && SettingsData.dockTooltipsEnabled && !batteryPopupVisible
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
        opacity: batteryArea.containsMouse ? 1 : 0
        

        Column {
            anchors.centerIn: parent
            spacing: 2
            rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? -90 : 90) : 0

            StyledText {
                id: tooltipText

                text: {
                    if (!BatteryService.batteryAvailable) {
                        if (typeof PowerProfiles === "undefined") {
                            return "Power Management";
                        }

                        switch (PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:
                            return "Power Profile: Power Saver";
                        case PowerProfile.Performance:
                            return "Power Profile: Performance";
                        default:
                            return "Power Profile: Balanced";
                        }
                    }
                    const status = BatteryService.batteryStatus;
                    const level = `${BatteryService.batteryLevel}%`;
                    const time = BatteryService.formatTimeRemaining();
                    if (time !== "Unknown") {
                        return `${status} • ${level} • ${time}`;
                    } else {
                        return `${status} • ${level}`;
                    }
                }
                font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }

        }

    }


}
