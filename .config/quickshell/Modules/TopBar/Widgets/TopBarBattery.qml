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
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal toggleBatteryPopup()

    width: isBarVertical ? widgetHeight : (batteryContentRow.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (batteryContentColumn.implicitHeight + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
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
        spacing: SettingsData.topBarNoBackground ? 1 : Math.max(2, root.widgetHeight * 0.1)

        EHIcon {
            name: BatteryService.getBatteryIcon()
            size: root.widgetHeight * 0.55
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
            font.pixelSize: root.widgetHeight * 0.4
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
        spacing: SettingsData.topBarNoBackground ? 1 : Math.max(2, root.widgetHeight * 0.1)

        EHIcon {
            name: BatteryService.getBatteryIcon()
            size: root.widgetHeight * 0.55
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
                    font.pixelSize: root.widgetHeight * 0.4
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
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                
                let triggerX, triggerY;
                if (isBarVertical) {
                    if (SettingsData.topBarPosition === "left") {
                        triggerX = globalPos.x + width + Theme.spacingXS;
                        triggerY = globalPos.y;
                    } else {
                        triggerX = globalPos.x - Theme.spacingXS;
                        triggerY = globalPos.y;
                    }
                } else {
                    triggerX = globalPos.x;
                    if (SettingsData.topBarPosition === "top") {
                        triggerY = globalPos.y + height + Theme.spacingXS;
                    } else {
                        triggerY = globalPos.y - Theme.spacingXS;
                    }
                }
                
                popupTarget.setTriggerPosition(triggerX, triggerY, isBarVertical ? height : width, section, currentScreen);
            }
            toggleBatteryPopup();
        }
    }



}
