import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string section: "center"
    property var parentScreen: null
    property real scaleFactor: 1
    property real iconSpacing: 8
    property real iconSize: 24
    property real barHeight: 48
    property real widgetHeight: 30
    property real padding: 1
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

    function getDarkDashLoader() {
        let current = root
        while (current) {
            if (current.darkDashLoader) {
                return current.darkDashLoader
            }
            current = current.parent
        }
        return null
    }

    function calculateTriggerPosition(currentScreen) {
        // Get widget position in screen coordinates (like dock does)
        const rect = parent.mapToItem(null, 0, 0, width, height)
        
        // Calculate taskbar thickness (similar to dock)
        var taskBarThickness = SettingsData?.taskBarHeight || 48
        
        // Position popup above taskbar, centered on button
        const triggerX = rect.x + rect.width / 2
        const triggerY = (currentScreen.y || 0) + (currentScreen.height || Screen.height || 0) - taskBarThickness
        
        return { x: triggerX, y: triggerY, width: rect.width }
    }

    function openDarkDash() {
        const loader = getDarkDashLoader()
        const currentScreen = parentScreen || Screen
        const pos = calculateTriggerPosition(currentScreen)
        if (loader) {
            loader.active = true
            if (loader.item) {
                loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                loader.item.show()
            }
        } else if (typeof darkDashLoader !== 'undefined') {
            darkDashLoader.active = true
            if (darkDashLoader.item) {
                darkDashLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                darkDashLoader.item.show()
            }
        }
    }

    function toggleDarkDash() {
        const loader = getDarkDashLoader()
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
        } else if (typeof darkDashLoader !== 'undefined') {
            darkDashLoader.active = true
            if (darkDashLoader.item) {
                if (darkDashLoader.item.shouldBeVisible) {
                    darkDashLoader.item.close()
                } else {
                    darkDashLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "taskbar", currentScreen)
                    darkDashLoader.item.show()
                }
            }
        }
    }

    width: dashIcon.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = dashMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    EHIcon {
        id: dashIcon

        anchors.centerIn: parent
        name: "dashboard"
        size: Theme.iconSize - 6
        color: {
            const loader = root.getDarkDashLoader()
            const isVisible = loader && loader.item && loader.item.shouldBeVisible
            return isVisible ? Theme.primary : Theme.surfaceText
        }
        
    }

    MouseArea {
        id: dashMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onEntered: {
            hoverTimer.start()
        }
        onExited: {
            hoverTimer.stop()
        }
        onClicked: {
            hoverTimer.stop()
            root.toggleDarkDash()
        }
    }

    Timer {
        id: hoverTimer
        interval: 2000
        onTriggered: {
            root.openDarkDash()
        }
    }
}

