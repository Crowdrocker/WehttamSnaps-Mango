import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property real widgetHeight: 40
    property var parentScreen: null

    readonly property real horizontalPadding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

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
        // Get the button rectangle in screen coordinates (same as DockVolumeMixer)
        const rect = appsMouseArea.mapToItem(null, 0, 0, appsMouseArea.width, appsMouseArea.height)

        // Calculate dock thickness (same logic as DockVolumeMixer)
        var dockThickness = (SettingsData?.dockExclusiveZone || 0) * (SettingsData?.dockScale || 1) + (SettingsData?.dockBottomGap || 0) + ((SettingsData?.dockTopPadding || 0) * 2 * Math.sqrt(SettingsData?.dockScale || 1))
        if (dockThickness === 0) {
            dockThickness = ((SettingsData?.dockHeight || 48) + (SettingsData?.dockBottomGap || 0) + ((SettingsData?.dockTopPadding || 0) * 2 * Math.sqrt(SettingsData?.dockScale || 1))) * (SettingsData?.dockScale || 1)
        }

        // Position popup above the dock (not at button position)
        const popupWidth = 400
        const popupHeight = 600
        const screenHeight = Screen.height

        // Center horizontally on the button, position above dock
        const triggerX = Math.max(20, Math.min(rect.x + rect.width/2 - popupWidth/2, Screen.width - popupWidth - 20))
        const triggerY = screenHeight - dockThickness - popupHeight - 20

        return {
            x: triggerX,
            y: triggerY,
            width: root.width
        }
    }

    function openApplications() {
        const loader = getApplicationsLoader()
        if (loader) {
            loader.active = true
            if (loader.item) {
                const pos = calculateTriggerPosition()
                const screen = parentScreen || Screen
                loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", screen)
                loader.item.show()
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                if (calculateWidgetPosition) {
                    const position = calculateWidgetPosition("center", 400, 600)
                    const screen = parentScreen || Screen
                    applicationsLoader.item.setTriggerPosition(position.x, position.y, root.width, position.section, screen)
                } else {
                    // Fallback to old logic if calculateWidgetPosition not available
                    const dockWindow = root.Window.window
                    if (!dockWindow) {
                        return
                    }

                    const currentScreen = parentScreen || Screen
                    const screenWidth = currentScreen.width || 1920
                    const screenHeight = currentScreen.height || 1080

                    const buttonPosInDock = root.mapToItem(dockWindow.contentItem, 0, 0)

                    // Use dock exclusive zone for thickness (matches dock volumemixer pattern)
                    // Exclusive zone includes: dockExclusiveZone + dockBottomGap + (dockTopPadding * 2)
                    var dockThickness = (SettingsData?.dockExclusiveZone || 0) * (SettingsData?.dockScale || 1) + (SettingsData?.dockBottomGap || 0) + ((SettingsData?.dockTopPadding || 0) * 2 * Math.sqrt(SettingsData?.dockScale || 1))
                    // Fallback to dockHeight if exclusive zone not set
                    if (dockThickness === 0) {
                        dockThickness = ((SettingsData?.dockHeight || 80) + (SettingsData?.dockBottomGap || 0) + ((SettingsData?.dockTopPadding || 0) * 2)) * (SettingsData?.dockScale || 1)
                    }

                    const dockBottomMargin = 16
                    const buttonScreenY = screenHeight - dockThickness - dockBottomMargin - 20

                    const dockContentWidth = dockWindow.width
                    const dockLeftMargin = Math.round((screenWidth - dockContentWidth) / 2)
                    const buttonScreenX = dockLeftMargin + buttonPosInDock.x + root.width / 2

                    applicationsLoader.item.setTriggerPosition(buttonScreenX, buttonScreenY, root.width, "center", currentScreen)
                }
                applicationsLoader.item.show()
            }
        }
    }

    function toggleApplications() {
        const loader = getApplicationsLoader()
        if (loader) {
            loader.active = true
            if (loader.item) {
                if (loader.item.shouldBeVisible) {
                    loader.item.close()
                } else {
                    const pos = calculateTriggerPosition()
                    const screen = parentScreen || Screen
                    loader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", screen)
                    loader.item.show()
                }
            }
        } else if (typeof applicationsLoader !== 'undefined') {
            applicationsLoader.active = true
            if (applicationsLoader.item) {
                if (applicationsLoader.item.shouldBeVisible) {
                    applicationsLoader.item.close()
                } else {
                    const pos = calculateTriggerPosition()
                    const screen = parentScreen || Screen
                    applicationsLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, "center", screen)
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

    Item {
        id: appsIconContainer
        anchors.centerIn: parent
        width: Math.max(1, (SettingsData.launcherLogoSize - 6) * (root.widgetHeight / 40))
        height: Math.max(1, (SettingsData.launcherLogoSize - 6) * (root.widgetHeight / 40))

        Image {
            id: customImage
            anchors.fill: parent
            source: SettingsData.customLauncherImagePath ? "file://" + SettingsData.customLauncherImagePath : ""
            visible: source !== ""
            fillMode: Image.PreserveAspectFit
        }

        EHIcon {
            id: appsIcon
            anchors.fill: parent
            name: "apps"
            visible: !customImage.visible
            color: {
                const loader = root.getApplicationsLoader()
                const isVisible = loader && loader.item && loader.item.shouldBeVisible
                return isVisible ? Theme.primary : Theme.surfaceText
            }
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







