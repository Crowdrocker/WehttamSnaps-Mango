import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string section: "center"
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

    function getApplicationsLoader() {
        let current = root
        while (current) {
            if (current.applicationsLoader) {
                return current.applicationsLoader
            }
            current = current.parent
        }
        return null
    }

    function calculateTriggerPosition(currentScreen) {
        // Get widget position in screen coordinates (like dock does)
        const rect = parent.mapToItem(null, 0, 0, width, height)
        
        // Calculate taskbar thickness (similar to dock)
        var taskBarThickness = SettingsData?.taskBarHeight || spx(48)
        
        // Position popup above taskbar, centered on button
        const triggerX = rect.x + rect.width / 2
        const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness
        
        return { x: triggerX, y: triggerY, width: rect.width }
    }

    function openApplications() {
        const loader = getApplicationsLoader()
        const currentScreen = parentScreen || Screen
        const pos = calculateTriggerPosition(currentScreen)
        if (loader) {
            loader.active = true
            if (loader.item) {
                loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                loader.item.show()
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                applicationsLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                applicationsLoader.item.show()
            }
        }
    }

    function toggleApplications() {
        const loader = getApplicationsLoader()
        const currentScreen = parentScreen || Screen
        const pos = calculateTriggerPosition(currentScreen)
        if (loader) {
            loader.active = true
            if (loader.item) {
                if (loader.item.shouldBeVisible) {
                    loader.item.close()
                } else {
                    loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                    loader.item.show()
                }
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                if (applicationsLoader.item.shouldBeVisible) {
                    applicationsLoader.item.close()
                } else {
                    applicationsLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                    applicationsLoader.item.show()
                }
            }
        }
    }

    width: appsIcon.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = appsMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    EHIcon {
        id: appsIcon

        anchors.centerIn: parent
        name: "apps"
        size: (Theme.iconSize - 6) * (widgetHeight / 30)
        color: {
            const loader = root.getApplicationsLoader()
            const isVisible = loader && loader.item && loader.item.shouldBeVisible
            return isVisible ? Theme.primary : Theme.surfaceText
        }
        
    }

    MouseArea {
        id: appsMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            root.toggleApplications()
        }
    }
}







