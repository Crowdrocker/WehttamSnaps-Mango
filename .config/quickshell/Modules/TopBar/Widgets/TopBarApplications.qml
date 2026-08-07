import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string section: "follow-trigger"
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
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

    function calculateTriggerPosition() {
        const globalPos = appsMouseArea.mapToGlobal(0, 0)
        const currentScreen = parentScreen || Screen
        
        let triggerX, triggerY
        if (isBarVertical) {
            if (SettingsData.topBarPosition === "left") {
                triggerX = globalPos.x + width + Theme.spacingXS
                triggerY = globalPos.y
            } else {
                triggerX = globalPos.x - Theme.spacingXS
                triggerY = globalPos.y
            }
        } else {
            triggerX = globalPos.x
            if (SettingsData.topBarPosition === "top") {
                triggerY = globalPos.y + height + Theme.spacingXS
            } else {
                triggerY = globalPos.y - Theme.spacingXS
            }
        }
        
        return { x: triggerX, y: triggerY, width: isBarVertical ? height : width }
    }

    function openApplications() {
        const loader = getApplicationsLoader()
        const pos = calculateTriggerPosition()
        const currentScreen = parentScreen || Screen
        if (loader) {
            loader.active = true
            if (loader.item) {
                loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", currentScreen)
                loader.item.show()
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                applicationsLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", currentScreen)
                applicationsLoader.item.show()
            }
        }
    }

    function toggleApplications() {
        const loader = getApplicationsLoader()
        const pos = calculateTriggerPosition()
        const currentScreen = parentScreen || Screen
        if (loader) {
            loader.active = true
            if (loader.item) {
                if (loader.item.shouldBeVisible) {
                    loader.item.close()
                } else {
                    loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", currentScreen)
                    loader.item.show()
                }
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                if (applicationsLoader.item.shouldBeVisible) {
                    applicationsLoader.item.close()
                } else {
                    applicationsLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", currentScreen)
                    applicationsLoader.item.show()
                }
            }
        }
    }

    width: appsIcon.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
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
        size: Theme.iconSize - 6
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







