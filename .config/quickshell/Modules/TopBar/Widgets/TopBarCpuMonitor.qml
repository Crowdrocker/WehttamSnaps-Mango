import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    width: isBarVertical ? widgetHeight : (cpuContent.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (cpuContent.implicitHeight + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = cpuArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    MouseArea {
        id: cpuArea

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
            DgopService.setSortBy("cpu");
            if (root.toggleProcessList) {
                root.toggleProcessList();
            }

        }
    }

    Row {
        id: cpuContent

        anchors.centerIn: parent
        spacing: 3

        EHIcon {
            name: "memory"
            size: Theme.iconSize - 8
            color: {
                if (DgopService.cpuUsage > 80) {
                    return Theme.tempDanger;
                }

                if (DgopService.cpuUsage > 60) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
            
        }

        StyledText {
            text: {
                if (DgopService.cpuUsage === undefined || DgopService.cpuUsage === null || DgopService.cpuUsage === 0) {
                    return "--%";
                }

                return DgopService.cpuUsage.toFixed(0) + "%";
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone
            

            StyledTextMetrics {
                id: cpuBaseline
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                text: "100%"
            }

            width: Math.max(cpuBaseline.width, paintedWidth)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

    }

}
