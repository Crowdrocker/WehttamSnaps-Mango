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
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real barHeight: spx(48)
    property real widgetHeight: 30
    property real padding: 0
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    width: isBarVertical ? widgetHeight : (cpuContent.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (cpuContent.implicitHeight + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
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
                const currentScreen = parentScreen || Screen;
                
                // Get widget position in screen coordinates (like dock does)
                const rect = parent.mapToItem(null, 0, 0, width, height);
                
                // Calculate taskbar thickness (similar to dock)
                var taskBarThickness = SettingsData?.taskBarHeight || 48;
                
                // Position popup above taskbar, centered on button
                const triggerX = rect.x + rect.width / 2;
                const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness;
                
                popupTarget.setTriggerPosition(triggerX, triggerY, rect.width, "taskbar", currentScreen);
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
        spacing: 3 * (widgetHeight / 30)

        EHIcon {
            name: "memory"
            size: (Theme.iconSize - 8) * (widgetHeight / 30)
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
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone
            

            StyledTextMetrics {
                id: cpuBaseline
                font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
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
