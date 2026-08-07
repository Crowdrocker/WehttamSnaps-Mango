import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandRenderTab

    property var parentModal: null

    readonly property bool isHyprland: typeof CompositorService !== "undefined" && CompositorService.isHyprland

    Component.onCompleted: {
        console.log("[RenderTab] Component loaded, isHyprland:", isHyprland)
        console.log("[RenderTab] TEST - trying to call setter")
        if (typeof SettingsData !== 'undefined') {
            console.log("[RenderTab] SettingsData is available")
            SettingsData.setHyprlandRenderNewScheduling(false)
            console.log("[RenderTab] Called setter")
        } else {
            console.log("[RenderTab] SettingsData is NOT available")
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // CATEGORY 1: Rendering
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: renderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: renderSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "settings"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Rendering"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { 
                        width: parent.width
                        text: "New Render Scheduling"
                        description: "Use improved render scheduling algorithm"
                        checked: SettingsData.hyprlandRenderNewScheduling
                        onToggled: checked => { 
                            console.log("[RenderTab] New Render Scheduling toggled:", checked)
                            SettingsData.setHyprlandRenderNewScheduling(checked)
                        }
                    }
                    EHToggle { 
                        width: parent.width
                        text: "Expand Undersized Textures"
                        description: "Expand textures smaller than the output size"
                        checked: SettingsData.hyprlandRenderExpandUndersizedTextures
                        onToggled: checked => { 
                            console.log("[RenderTab] Expand Undersized Textures toggled:", checked)
                            SettingsData.setHyprlandRenderExpandUndersizedTextures(checked)
                        }
                    }

                    // Direct Scanout
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Direct Scanout"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "0 = disabled, 1 = enabled, 2 = auto"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandRenderDirectScanout
                            minimum: 0; maximum: 2; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => { 
                                console.log("[RenderTab] Direct Scanout changed:", v)
                                SettingsData.setHyprlandRenderDirectScanout(v)
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Color Management
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: colorMgmtSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: colorMgmtSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Color Management"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Color Management"
                        description: "Enable color management features"
                        checked: SettingsData.hyprlandRenderCmEnabled
                        onToggled: checked => SettingsData.setHyprlandRenderCmEnabled(checked)
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.hyprlandRenderCmEnabled
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                        EHToggle { width: parent.width; text: "Auto HDR"; description: "Automatically enable HDR when available"; checked: SettingsData.hyprlandRenderCmAutoHdr; onToggled: checked => SettingsData.setHyprlandRenderCmAutoHdr(checked) }
                        EHToggle { width: parent.width; text: "Send Content Type"; description: "Send content type information to the display"; checked: SettingsData.hyprlandRenderSendContentType; onToggled: checked => SettingsData.setHyprlandRenderSendContentType(checked) }

                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "FS Passthrough"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Fullscreen color management passthrough mode"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.hyprlandRenderCmFsPassthrough
                                minimum: 0; maximum: 1; unit: ""; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => SettingsData.setHyprlandRenderCmFsPassthrough(v)
                            }
                        }
                    }
                }
            }
        }
    }
}
