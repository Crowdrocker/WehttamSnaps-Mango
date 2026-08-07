import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

/**
 * DockSystemUpdatePopout - A system update popup for the dock
 * Uses the same PanelWindow positioning pattern as DockVolumeMixerPopout
 */
Item {
    id: root

    /**
     * Open the system update popup for an anchor item
     * @param {Item} anchorItem - The visual element to anchor to
     * @param {Screen} screen - The screen to display on
     * @param {string} barPosition - Position of the bar ("top", "bottom", "left", "right")
     * @param {bool} isVertical - Whether the bar is vertical
     * @param {real} barThickness - Thickness of the bar
     */
    function openForItem(anchorItem, screen, barPosition, isVertical, barThickness) {
        // Close any existing popup
        if (currentPopup) {
            currentPopup.showPopup = false
            currentPopup.destroy()
            currentPopup = null
        }

        // Create new popup instance
        currentPopup = popupComponent.createObject(null)
        if (currentPopup) {
            currentPopup.showForAnchor(anchorItem, screen, barPosition, isVertical, barThickness)
        }
    }

    function open() {
        // Legacy compatibility - opens with default parameters
        openForItem(null, null, "bottom", false, 48)
    }

    function close() {
        if (currentPopup) {
            currentPopup.showPopup = false
            currentPopup.destroy()
            currentPopup = null
        }
    }

    function setTriggerPosition(x, y, width, section, screen) {
        // Legacy compatibility - stores values for next open
        storedTriggerX = x
        storedTriggerY = y
        storedTriggerWidth = width
        storedTriggerSection = section
        storedTriggerScreen = screen
    }

    // Stored trigger position for legacy compatibility
    property real storedTriggerX: 0
    property real storedTriggerY: 0
    property real storedTriggerWidth: 70
    property string storedTriggerSection: "right"
    property var storedTriggerScreen: null

    // Current popup instance
    property var currentPopup: null

    // Expose visibility for external checks
    property bool shouldBeVisible: currentPopup !== null && currentPopup.showPopup

    Component {
        id: popupComponent

        Item {
            id: popupRoot
            property var anchorItem: null
            property var parentScreen: null
            property string barPosition: "bottom"
            property bool isVertical: false
            readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
            function spx(px) { return Math.round(px * uiScale) }
            property real barThickness: spx(48)
            property real popupDistance: Theme.popupDistance !== undefined ? Theme.popupDistance : 1
            property bool showPopup: false

            function showForAnchor(anchor, screen, barPos, vertical, barThick) {
                anchorItem = anchor
                parentScreen = screen
                barPosition = barPos || "bottom"
                isVertical = vertical || false
                barThickness = barThick || spx(48)

                if (parentScreen) {
                    for (var i = 0; i < Quickshell.screens.length; i++) {
                        const s = Quickshell.screens[i]
                        if (s === parentScreen) {
                            popupWindow.screen = s
                            break
                        }
                    }
                }
                showPopup = true
            }

            function close() {
                showPopup = false
            }

            width: 0
            height: 0

            PanelWindow {
                id: popupWindow
                visible: popupRoot.showPopup
                screen: popupRoot.parentScreen
                WlrLayershell.namespace: "quickshell:bar:blur"
                WlrLayershell.layer: WlrLayershell.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnClick
                color: "transparent"

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

                onVisibleChanged: {
                    if (visible) {
                        updatePosition()
                    }
                }

                function updatePosition() {
                    if (!popupRoot.anchorItem) {
                        // Use stored position if no anchor item
                        anchorPos = Qt.point(root.storedTriggerX, root.storedTriggerY)
                        return
                    }

                    const scaledBarThickness = popupRoot.barThickness

                    let targetX, targetY

                    if (popupRoot.barPosition === "top") {
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - (screen.x || 0) + popupRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = scaledBarThickness + popupRoot.popupDistance + Math.round(15 * (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1))
                    } else if (popupRoot.barPosition === "bottom") {
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - (screen.x || 0) + popupRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = screen.height - scaledBarThickness - popupRoot.popupDistance - Math.round(15 * (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1))
                    } else if (popupRoot.barPosition === "left") {
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - (screen.y || 0) + popupRoot.anchorItem.height / 2
                        targetX = scaledBarThickness + popupRoot.popupDistance + Math.round(15 * (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1))
                        targetY = iconCenterY
                    } else if (popupRoot.barPosition === "right") {
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - (screen.y || 0) + popupRoot.anchorItem.height / 2
                        targetX = screen.width - scaledBarThickness - popupRoot.popupDistance - Math.round(15 * (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1))
                        targetY = iconCenterY
                    } else {
                        targetX = screen.width / 2
                        targetY = screen.height / 2
                    }

                    anchorPos = Qt.point(targetX, targetY)
                }

                Rectangle {
                    id: updateContainer
                    width: 380
                    height: Math.max(300, contentColumn.implicitHeight + Theme.spacingL * 2)

                    onWidthChanged: popupWindow.updatePosition()
                    onHeightChanged: popupWindow.updatePosition()

                    x: {
                        if (popupRoot.barPosition === "right") {
                            return Math.max(10, popupWindow.anchorPos.x - width)
                        }
                        if (popupRoot.barPosition === "left") {
                            return Math.min(popupWindow.screen.width - width - 10, popupWindow.anchorPos.x)
                        }

                        const left = 10
                        const right = popupWindow.screen.width - width - 10
                        const want = popupWindow.anchorPos.x - width / 2
                        return Math.max(left, Math.min(right, want))
                    }

                    y: {
                        if (popupRoot.barPosition === "top") {
                            return Math.max(10, popupWindow.anchorPos.y)
                        }
                        if (popupRoot.barPosition === "bottom") {
                            return Math.min(popupWindow.screen.height - height - 10, popupWindow.anchorPos.y - height)
                        }

                        const top = 10
                        const bottom = popupWindow.screen.height - height - 10
                        const want = popupWindow.anchorPos.y - height / 2
                        return Math.max(top, Math.min(bottom, want))
                    }

                    color: Theme.popupBackground()
                    radius: Theme.widgetRadius
                    border.color: Theme.outlineMedium
                    border.width: 1
                    antialiasing: true
                    smooth: true
                    opacity: popupRoot.showPopup ? 1 : 0
                    scale: popupRoot.showPopup ? 1 : 0.85

                    focus: true
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            popupRoot.close()
                            event.accepted = true
                        }
                    }

                    // Shadow layers
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        color: "transparent"
                        radius: parent.radius + 3
                        border.color: Theme.outlineLight
                        border.width: 1
                        z: -3
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        radius: parent.radius + 2
                        border.color: Theme.shadowMedium
                        border.width: 1
                        z: -2
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Theme.outlineStrong
                        border.width: 1
                        radius: parent.radius
                        z: -1
                    }

                    // Close on outside click
                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(event) {
                            // Don't close if clicking inside
                            event.accepted = false
                        }
                    }

                    ColumnLayout {
                        id: contentColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            EHIcon {
                                name: SystemUpdateService.hasError ? "error" : (SystemUpdateService.updateCount > 0 ? "system_update_alt" : "check_circle")
                                size: Theme.iconSize
                                color: SystemUpdateService.hasError ? Theme.error : (SystemUpdateService.updateCount > 0 ? Theme.primary : Theme.success)
                            }

                            StyledText {
                                text: SystemUpdateService.hasError ? "Update Error" : (SystemUpdateService.updateCount > 0 ? `${SystemUpdateService.updateCount} Updates Available` : "System Up to Date")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: "white"
                                Layout.fillWidth: true
                            }

                            // Refresh button
                            Rectangle {
                                width: Theme.iconSize + Theme.spacingS
                                height: Theme.iconSize + Theme.spacingS
                                radius: (Theme.iconSize + Theme.spacingS) / 2
                                color: refreshArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                EHIcon {
                                    anchors.centerIn: parent
                                    name: "refresh"
                                    size: Theme.iconSize - 4
                                    color: refreshArea.containsMouse ? Theme.primary : Theme.surfaceText
                                    rotation: SystemUpdateService.isChecking ? 360 : 0

                                    Behavior on rotation {
                                        NumberAnimation { duration: SystemUpdateService.isChecking ? 1000 : 0; loops: Animation.Infinite }
                                    }
                                }

                                MouseArea {
                                    id: refreshArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SystemUpdateService.checkForUpdates()
                                }
                            }
                        }

                        // Distribution info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Distribution:"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: SystemUpdateService.distribution || "Unknown"
                                font.pixelSize: Theme.fontSizeSmall
                                color: "white"
                                font.weight: Font.Medium
                            }

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: SystemUpdateService.distributionSupported ? Theme.success : Theme.warning
                            }

                            StyledText {
                                text: SystemUpdateService.distributionSupported ? "Supported" : "Not Supported"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }

                        // Error message
                        Rectangle {
                            Layout.fillWidth: true
                            height: errorText.implicitHeight + Theme.spacingM * 2
                            radius: Theme.widgetRadius
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
                            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                            border.width: 1
                            visible: SystemUpdateService.hasError

                            StyledText {
                                id: errorText
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                text: SystemUpdateService.errorMessage || "An error occurred while checking for updates"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Helper info
                        Rectangle {
                            Layout.fillWidth: true
                            height: helperInfo.implicitHeight + Theme.spacingM * 2
                            radius: Theme.widgetRadius
                            color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.1)
                            border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3)
                            border.width: 1
                            visible: !SystemUpdateService.helperAvailable && SystemUpdateService.distributionSupported

                            RowLayout {
                                id: helperInfo
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "warning"
                                    size: Theme.iconSizeSmall
                                    color: Theme.warning
                                }

                                StyledText {
                                    text: "No AUR helper found. Install 'paru' or 'yay' to enable updates."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.warning
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            visible: SystemUpdateService.updateCount > 0
                        }

                        // Updates list
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 100
                            Layout.maximumHeight: 300
                            clip: true
                            visible: SystemUpdateService.updateCount > 0

                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: updateContainer.width - Theme.spacingL * 2 - Theme.spacingM
                                spacing: Theme.spacingS

                                Repeater {
                                    model: SystemUpdateService.availableUpdates

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: updateItemLayout.implicitHeight + Theme.spacingS * 2
                                        radius: Theme.widgetRadius
                                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)

                                        required property var modelData

                                        RowLayout {
                                            id: updateItemLayout
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS

                                            EHIcon {
                                                name: "package"
                                                size: Theme.iconSizeSmall
                                                color: Theme.primary
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                StyledText {
                                                    text: modelData.name
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: "white"
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    text: `${modelData.currentVersion} -> ${modelData.newVersion}`
                                                    font.pixelSize: Theme.fontSizeXSmall
                                                    color: Theme.surfaceText
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // No updates message
                        Rectangle {
                            Layout.fillWidth: true
                            height: noUpdatesLayout.implicitHeight + Theme.spacingL * 2
                            radius: Theme.widgetRadius
                            color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.1)
                            visible: SystemUpdateService.updateCount === 0 && !SystemUpdateService.hasError && SystemUpdateService.helperAvailable

                            RowLayout {
                                id: noUpdatesLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spacingL
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "check_circle"
                                    size: Theme.iconSize
                                    color: Theme.success
                                }

                                StyledText {
                                    text: "Your system is up to date!"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.success
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Update button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: Theme.widgetRadius
                            color: updateBtnArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9) : Theme.primary
                            visible: SystemUpdateService.updateCount > 0 && SystemUpdateService.helperAvailable

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "download"
                                    size: Theme.iconSizeSmall
                                    color: "white"
                                }

                                StyledText {
                                    text: "Install Updates"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: "white"
                                }
                            }

                            MouseArea {
                                id: updateBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SystemUpdateService.runUpdates()
                                    popupRoot.close()
                                }
                            }
                        }
                    }
                }

                // Close on click outside
                MouseArea {
                    anchors.fill: parent
                    z: -100
                    onPressed: function(event) {
                        const mapped = mapToItem(updateContainer, event.x, event.y)
                        if (!updateContainer.contains(Qt.point(mapped.x, mapped.y))) {
                            popupRoot.close()
                        }
                        event.accepted = false
                    }
                }
            }
        }
    }
}