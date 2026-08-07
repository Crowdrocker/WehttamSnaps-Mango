import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandRoundingTab

    property var parentModal: null

    readonly property bool isHyprland: typeof CompositorService !== "undefined" && CompositorService.isHyprland

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
            // CATEGORY 1: Window Rounding
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: roundingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: roundingSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "rounded_corner"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Window Rounding"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Corner Rounding"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Pixel radius of window corner rounding"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandDecorationRounding
                            minimum: 0; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandDecorationRounding(v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Rounding Power"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Controls the curve shape of rounded corners"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandDecorationRoundingPower
                            minimum: 1; maximum: 20; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandDecorationRoundingPower(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Global Blur
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: globalBlurSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: globalBlurSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "blur_on"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Global Blur"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Blur Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandBlurSize; minimum: 0; maximum: 20; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandBlurSize(v) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Blur Passes"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandBlurPasses; minimum: 1; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandBlurPasses(v) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Decoration Blur
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: decorBlurSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: decorBlurSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "blur_on"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Decoration Blur"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Blur"
                        description: "Apply blur effects to window decorations"
                        checked: SettingsData.hyprlandDecorationBlurEnabled
                        onToggled: checked => SettingsData.setHyprlandDecorationBlurEnabled(checked)
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.hyprlandDecorationBlurEnabled
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                        EHToggle { width: parent.width; text: "X-Ray Mode"; description: "Allow blur to show through transparent areas"; checked: SettingsData.hyprlandDecorationBlurXray; onToggled: checked => SettingsData.setHyprlandDecorationBlurXray(checked) }
                        EHToggle { width: parent.width; text: "Special Blur"; description: "Apply blur to special workspaces"; checked: SettingsData.hyprlandDecorationBlurSpecial; onToggled: checked => SettingsData.setHyprlandDecorationBlurSpecial(checked) }
                        EHToggle { width: parent.width; text: "New Optimizations"; description: "Use improved blur algorithms"; checked: SettingsData.hyprlandDecorationBlurNewOptimizations; onToggled: checked => SettingsData.setHyprlandDecorationBlurNewOptimizations(checked) }
                        EHToggle { width: parent.width; text: "Ignore Opacity"; description: "Blur even when window is transparent"; checked: SettingsData.hyprlandDecorationBlurIgnoreOpacity; onToggled: checked => SettingsData.setHyprlandDecorationBlurIgnoreOpacity(checked) }
                        EHToggle { width: parent.width; text: "Blur Input Methods"; description: "Apply blur to input method popups"; checked: SettingsData.hyprlandDecorationBlurInputMethods; onToggled: checked => SettingsData.setHyprlandDecorationBlurInputMethods(checked) }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Vibrancy"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurVibrancy * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurVibrancy(v / 100) }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Vibrancy Darkness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurVibrancyDarkness * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurVibrancyDarkness(v / 100) }
                        }

                        // Brightness
                        EHToggle { width: parent.width; text: "Enable Brightness"; checked: SettingsData.hyprlandDecorationBlurBrightnessEnabled; onToggled: checked => SettingsData.setHyprlandDecorationBlurBrightnessEnabled(checked) }
                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: SettingsData.hyprlandDecorationBlurBrightnessEnabled
                            StyledText { text: "Brightness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurBrightness * 100); minimum: 0; maximum: 200; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurBrightness(v / 100) }
                        }

                        // Noise
                        EHToggle { width: parent.width; text: "Enable Noise"; checked: SettingsData.hyprlandDecorationBlurNoiseEnabled; onToggled: checked => SettingsData.setHyprlandDecorationBlurNoiseEnabled(checked) }
                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: SettingsData.hyprlandDecorationBlurNoiseEnabled
                            StyledText { text: "Noise"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurNoise * 1000); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurNoise(v / 1000) }
                        }

                        // Contrast
                        EHToggle { width: parent.width; text: "Enable Contrast"; checked: SettingsData.hyprlandDecorationBlurContrastEnabled; onToggled: checked => SettingsData.setHyprlandDecorationBlurContrastEnabled(checked) }
                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: SettingsData.hyprlandDecorationBlurContrastEnabled
                            StyledText { text: "Contrast"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurContrast * 100); minimum: 0; maximum: 200; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurContrast(v / 100) }
                        }

                        // Input methods ignore alpha
                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: SettingsData.hyprlandDecorationBlurInputMethods
                            StyledText { text: "Input Methods Ignore Alpha"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurInputMethodsIgnorealpha * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurInputMethodsIgnorealpha(v / 100) }
                        }

                        // Popups ignore alpha
                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: SettingsData.hyprlandDecorationBlurPopups
                            StyledText { text: "Popups Ignore Alpha"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationBlurPopupsIgnorealpha * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationBlurPopupsIgnorealpha(v / 100) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 4: Window Shadows
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: shadowSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: shadowSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "shadow"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Window Shadows"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Enable Shadows"; description: "Show shadows behind windows"; checked: SettingsData.hyprlandDecorationShadowEnabled; onToggled: checked => SettingsData.setHyprlandDecorationShadowEnabled(checked) }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.hyprlandDecorationShadowEnabled
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                        EHToggle { width: parent.width; text: "Ignore Window"; description: "Do not draw shadows behind the window content area"; checked: SettingsData.hyprlandDecorationShadowIgnoreWindow; onToggled: checked => SettingsData.setHyprlandDecorationShadowIgnoreWindow(checked) }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Shadow Range"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandDecorationShadowRange; minimum: 1; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationShadowRange(v) }
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Render Power"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandDecorationShadowRenderPower; minimum: 1; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationShadowRenderPower(v) }
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Shadow Offset"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "e.g. 0 2"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandDecorationShadowOffset; placeholderText: "e.g. 0 2"; onEditingFinished: SettingsData.setHyprlandDecorationShadowOffset(text) }
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Shadow Color"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "e.g. rgba(0000002A)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandDecorationShadowColor; placeholderText: "rgba(0000002A)"; onEditingFinished: SettingsData.setHyprlandDecorationShadowColor(text) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 5: Window Dimming
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: dimmingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: dimmingSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "brightness_low"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Window Dimming"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Dim Inactive Windows"; description: "Reduce brightness of unfocused windows"; checked: SettingsData.hyprlandDecorationDimInactive; onToggled: checked => SettingsData.setHyprlandDecorationDimInactive(checked) }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        visible: SettingsData.hyprlandDecorationDimInactive
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                        StyledText { text: "Dim Strength"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandDecorationDimStrength * 100; minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationDimStrength(v / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Dim Special Workspace"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandDecorationDimSpecial * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandDecorationDimSpecial(v / 100) }
                    }
                }
            }
        }
    }
}
