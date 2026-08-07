import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

/**
 * TaskBarVolumeMixerPopout - A volume mixer popup for the taskbar
 * Uses the same PanelWindow positioning pattern as TrayContextMenu
 */
Item {
    id: root

    /**
     * Open the volume mixer popup for an anchor item
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
            readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
            function spx(px) { return Math.round(px * uiScale) }
            property real barThickness: spx(48)
            property real popupDistance: Theme.popupDistance !== undefined ? Theme.popupDistance : 8
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

                    // For vertical bars (left/right), position relative to bar edge, not icon position
                    // For horizontal bars (top/bottom), center on the icon
                    let targetX, targetY

                    if (popupRoot.barPosition === "top") {
                        // Get icon's horizontal center
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - (screen.x || 0) + popupRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = scaledBarThickness + popupRoot.popupDistance + popupRoot.spx(15)
                    } else if (popupRoot.barPosition === "bottom") {
                        // Get icon's horizontal center
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - (screen.x || 0) + popupRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = screen.height - scaledBarThickness - popupRoot.popupDistance - popupRoot.spx(15)
                    } else if (popupRoot.barPosition === "left") {
                        // Get icon's vertical center
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - (screen.y || 0) + popupRoot.anchorItem.height / 2
                        targetX = scaledBarThickness + popupRoot.popupDistance + popupRoot.spx(15)
                        targetY = iconCenterY
                    } else if (popupRoot.barPosition === "right") {
                        // Get icon's vertical center
                        const globalPos = popupRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - (screen.y || 0) + popupRoot.anchorItem.height / 2
                        targetX = screen.width - scaledBarThickness - popupRoot.popupDistance - popupRoot.spx(15)
                        targetY = iconCenterY
                    } else {
                        // Fallback
                        targetX = screen.width / 2
                        targetY = screen.height / 2
                    }

                    anchorPos = Qt.point(targetX, targetY)
                }

                Rectangle {
                    id: volumeContainer
                    width: 400
                    height: Math.max(300, contentColumn.implicitHeight + Theme.spacingL * 2)

                    onWidthChanged: popupWindow.updatePosition()
                    onHeightChanged: popupWindow.updatePosition()

                    x: {
                        if (popupRoot.barPosition === "right") {
                            // Right bar: popup appears to the left of the anchor
                            return Math.max(10, popupWindow.anchorPos.x - width)
                        }
                        if (popupRoot.barPosition === "left") {
                            // Left bar: popup appears to the right of the anchor
                            return Math.min(popupWindow.screen.width - width - 10, popupWindow.anchorPos.x)
                        }

                        // Top/bottom bars: center on the anchor
                        const left = 10
                        const right = popupWindow.screen.width - width - 10
                        const want = popupWindow.anchorPos.x - width / 2
                        return Math.max(left, Math.min(right, want))
                    }

                    y: {
                        if (popupRoot.barPosition === "top") {
                            // Top bar: popup appears below the anchor
                            return Math.max(10, popupWindow.anchorPos.y)
                        }
                        if (popupRoot.barPosition === "bottom") {
                            // Bottom bar: popup appears above the anchor
                            return Math.min(popupWindow.screen.height - height - 10, popupWindow.anchorPos.y - height)
                        }

                        // Left/right bars: center on the anchor
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

                    ScrollView {
                        id: scrollView
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            id: contentColumn
                            width: scrollView.width - Theme.spacingL * 2
                            spacing: Theme.spacingM

                            // System Volume Controls
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: systemVolumeRow.implicitHeight + Theme.spacingL * 2
                                radius: Theme.widgetRadius
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                border.width: 1

                                RowLayout {
                                    id: systemVolumeRow
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingL
                                    spacing: Theme.spacingM

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: Theme.spacingXS

                                        RowLayout {
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: "System Volume"
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: AudioService.muted ? Theme.error : "white"
                                                font.weight: Font.Medium
                                            }

                                            StyledText {
                                                text: AudioService.sink ? (" - " + AudioService.displayName(AudioService.sink)) : ""
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: "white"
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        EHSlider {
                                            Layout.fillWidth: true
                                            minimum: 0
                                            maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                            value: Math.round(AudioService.volume * 100)
                                            showValue: true
                                            unit: "%"
                                            onSliderValueChanged: function(newValue) {
                                                AudioService.suppressOutputOSD()
                                                AudioService.setVolume(newValue / 100.0)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: Theme.iconSize + Theme.spacingS * 2
                                        height: Theme.iconSize + Theme.spacingS * 2
                                        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                                        color: muteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                        MouseArea {
                                            id: muteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                AudioService.suppressOutputOSD()
                                                AudioService.setOutputMuted(!AudioService.muted)
                                            }
                                        }

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: AudioService.getOutputIcon()
                                            size: Theme.iconSize
                                            color: AudioService.muted ? Theme.error : Theme.primary
                                        }
                                    }
                                }
                            }

                            // Application Streams
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: "Applications"
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: "white"
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: `${ApplicationAudioService.applicationStreams.length} active`
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "white"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                }

                                // Application volume controls
                                Repeater {
                                    model: ApplicationAudioService.applicationStreams

                                    delegate: Rectangle {
                                        required property PwNode modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: appRow.implicitHeight + Theme.spacingM * 2
                                        radius: Theme.widgetRadius
                                        color: appArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: 1

                                        // Track individual node to ensure properties are bound
                                        PwObjectTracker {
                                            objects: modelData ? [modelData] : []
                                        }

                                        // Define audio properties
                                        property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                                        property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
                                        property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false

                                        MouseArea {
                                            id: appArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        RowLayout {
                                            id: appRow
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            // App Icon
                                            Image {
                                                Layout.preferredWidth: Theme.iconSize
                                                Layout.preferredHeight: Theme.iconSize
                                                Layout.alignment: Qt.AlignHCenter
                                                source: ApplicationAudioService.getApplicationIcon(modelData)
                                                sourceSize.width: Theme.iconSize * 2
                                                sourceSize.height: Theme.iconSize * 2
                                                smooth: true
                                                mipmap: true
                                                fillMode: Image.PreserveAspectFit
                                                cache: true
                                                asynchronous: true

                                                EHIcon {
                                                    anchors.fill: parent
                                                    name: "apps"
                                                    size: Theme.iconSize
                                                    color: Theme.primary
                                                    visible: parent.status === Image.Error || parent.status === Image.Null || parent.source === ""
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: Theme.spacingXS

                                                StyledText {
                                                    text: ApplicationAudioService.getApplicationName(modelData)
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: "white"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                EHSlider {
                                                    Layout.fillWidth: true
                                                    minimum: 0
                                                    maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                                    value: Math.round(appVolume * 100)
                                                    showValue: true
                                                    unit: "%"
                                                    enabled: nodeAudio && modelData.ready
                                                    onSliderValueChanged: function(newValue) {
                                                        if (nodeAudio && modelData.ready) {
                                                            nodeAudio.volume = newValue / 100.0
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                                                Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                                                Layout.alignment: Qt.AlignBottom
                                                radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                                                color: appMuteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                                MouseArea {
                                                    id: appMuteArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: nodeAudio && modelData.ready
                                                    onClicked: {
                                                        if (nodeAudio && modelData.ready) {
                                                            nodeAudio.muted = !appMuted
                                                        }
                                                    }
                                                }

                                                EHIcon {
                                                    anchors.centerIn: parent
                                                    name: appMuted ? "volume_off" : "volume_up"
                                                    size: Theme.iconSize
                                                    color: !appMuted ? Theme.primary : "white"
                                                    opacity: (nodeAudio && modelData.ready) ? 1 : 0.3
                                                }
                                            }
                                        }
                                    }
                                }

                                // Empty state
                                Rectangle {
                                    width: parent.width
                                    height: 60
                                    radius: Theme.widgetRadius
                                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                    border.width: 1
                                    visible: ApplicationAudioService.applicationStreams.length === 0

                                    StyledText {
                                        text: "No applications with audio output"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "white"
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: popupRoot.close()
                }
            }
        }
    }
}