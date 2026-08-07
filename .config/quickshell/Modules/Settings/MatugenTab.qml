import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals
import qs.Widgets

Item {
    id: matugenTab

    property var parentModal: null

    // Theme fallbacks (some themes omit *XSmall / *Small variants)
    readonly property int _fontXSmall: Theme.fontSizeXSmall || Math.max(10, (Theme.fontSizeSmall || 12) - 2)
    readonly property real _cornerSmall: Theme.cornerRadiusSmall || Math.max(4, (Theme.cornerRadius || 12) * 0.5)

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
            // HEADER
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: headerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: headerSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Matugen Color Generation"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "Fine-tune how matugen extracts and generates colors from your wallpaper. These settings control the color extraction algorithm and can help preserve vibrant colors."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    Row {
                        spacing: Theme.spacingS
                        visible: !Theme.matugenAvailable
                        EHIcon { name: "warning"; size: Theme.fontSizeSmall; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "matugen not found — install matugen package for dynamic theming"; font.pixelSize: Theme.fontSizeSmall; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // PALETTE ALGORITHM
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: paletteSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: paletteSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "auto_awesome"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Palette Algorithm"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHDropdown {
                        width: parent.width; text: "Scheme Type"; description: "Select the palette algorithm used for wallpaper-based colors"
                        currentValue: Theme.getMatugenScheme(SettingsData.matugenScheme).label
                        options: Theme.availableMatugenSchemes.map(s => s.label)
                        enabled: Theme.matugenAvailable
                        onValueChanged: value => {
                            for (var i = 0; i < Theme.availableMatugenSchemes.length; i++) {
                                if (Theme.availableMatugenSchemes[i].label === value) {
                                    SettingsData.setMatugenScheme(Theme.availableMatugenSchemes[i].value)
                                    break
                                }
                            }
                        }
                    }

                    StyledText {
                        text: Theme.getMatugenScheme(SettingsData.matugenScheme).description
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Recommendations for vibrant colors:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "• Vibrant — Best for keeping colors bright and saturated"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Fidelity — Best for preserving exact source hues"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Content — Best for matching the underlying image closely"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CONTRAST
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: contrastSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: contrastSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "contrast"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Contrast"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "Adjust the contrast of generated colors. Higher values increase the difference between light and dark colors."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    Column {
                        width: parent.width; spacing: Theme.spacingS

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Contrast Level"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter; Layout.fillWidth: true }
                            Item { width: 1; height: 1 }
                            StyledText {
                                text: { var v = SettingsData.matugenContrast; return v < -0.3 ? "Low" : v < 0.3 ? "Standard" : "High" }
                                font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.matugenContrast * 100
                            minimum: -100; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.setMatugenContrast(newValue / 100) }
                        }

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "-1 (Min)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "0 (Standard)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "+1 (Max)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    EHActionButton {
                        iconName: "restart_alt"; iconSize: Theme.iconSizeSmall
                        buttonSize: 32
                        iconColor: Theme.primary
                        onClicked: SettingsData.setMatugenContrast(0)
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // RESIZE FILTER
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: filterSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: filterSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "filter"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Resize Filter"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "The filter used when resizing the image for color extraction. Different filters can produce different source colors."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    EHDropdown {
                        width: parent.width; text: "Filter Type"; description: "Select the resize filter for color extraction"
                        currentValue: {
                            const filters = ["nearest","triangle","catmull-rom","gaussian","lanczos3"]
                            const labels  = ["Nearest","Triangle","Catmull-Rom","Gaussian","Lanczos3"]
                            const i = filters.indexOf(SettingsData.matugenResizeFilter)
                            return i >= 0 ? labels[i] : "Lanczos3"
                        }
                        options: ["Nearest","Triangle","Catmull-Rom","Gaussian","Lanczos3"]
                        enabled: Theme.matugenAvailable
                        onValueChanged: value => {
                            const labels  = ["Nearest","Triangle","Catmull-Rom","Gaussian","Lanczos3"]
                            const filters = ["nearest","triangle","catmull-rom","gaussian","lanczos3"]
                            const i = labels.indexOf(value)
                            if (i >= 0) SettingsData.setMatugenResizeFilter(filters[i])
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Filter descriptions:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "• Nearest — Fast, pixelated, can preserve sharp color edges"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Triangle — Simple bilinear filtering, smooth results"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Catmull-Rom — Sharp interpolation, good for detailed images"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Gaussian — Smooth, blurrier, averages colors more"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        StyledText { text: "• Lanczos3 — High quality, default, good balance (recommended)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // FALLBACK COLOR
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: fallbackSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: fallbackSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "colorize"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Fallback Color"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "The color to use if matugen cannot find a good source color from the image. This ensures consistent results even with difficult images."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    EHToggle {
                        width: parent.width; text: "Use Fallback Color"; description: "Set a specific color as a fallback for color extraction"
                        checked: SettingsData.matugenFallbackColor !== ""
                        onToggled: toggled => { SettingsData.setMatugenFallbackColor(toggled ? "#ff0000" : "") }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.matugenFallbackColor !== ""

                        Rectangle {
                            width: 40; height: 40; radius: matugenTab._cornerSmall
                            color: SettingsData.matugenFallbackColor
                            border.color: Theme.outline; border.width: 1
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: colorPicker.show() }
                        }

                        StyledText { text: SettingsData.matugenFallbackColor || "No color set"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }

                        EHActionButton { iconName: "colorize"; iconSize: Theme.iconSizeSmall; buttonSize: 32; iconColor: Theme.primary; anchors.verticalCenter: parent.verticalCenter; onClicked: colorPicker.show() }
                        EHActionButton { iconName: "close"; iconSize: Theme.iconSizeSmall; buttonSize: 32; iconColor: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter; onClicked: SettingsData.setMatugenFallbackColor("") }
                    }

                    ColorPickerModal {
                        id: colorPicker
                        onColorSelected: color => { SettingsData.setMatugenFallbackColor(color) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // SATURATION BOOST
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: saturationSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: saturationSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "invert_colors"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Saturation Boost"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "Boost the saturation of generated colors. This can help make muted colors more vibrant. Applied after color extraction."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    Column {
                        width: parent.width; spacing: Theme.spacingS

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Saturation Multiplier"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: 1; height: 1 }
                            StyledText { text: (SettingsData.matugenSaturationBoost * 100).toFixed(0) + "%"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.matugenSaturationBoost * 100
                            minimum: 50; maximum: 200; unit: "%"; showValue: false; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.setMatugenSaturationBoost(newValue / 100); Theme.reapplyColorAdjustments() }
                        }

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "50% (Muted)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "100% (Normal)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "200% (Vibrant)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    Row {
                        spacing: Theme.spacingM
                        EHActionButton { iconName: "restart_alt"; iconSize: Theme.iconSizeSmall; buttonSize: 32; iconColor: Theme.surfaceVariantText; onClicked: { SettingsData.setMatugenSaturationBoost(1.0); Theme.reapplyColorAdjustments() } }
                        EHActionButton { iconName: "trending_up"; iconSize: Theme.iconSizeSmall; buttonSize: 32; iconColor: Theme.primary; onClicked: { SettingsData.setMatugenSaturationBoost(1.5); Theme.reapplyColorAdjustments() } }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // LIGHTNESS ADJUSTMENT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: lightnessSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: lightnessSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "light_mode"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Lightness Adjustment"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { text: "Adjust the lightness of generated colors. Positive values make colors lighter, negative values make them darker."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }

                    Column {
                        width: parent.width; spacing: Theme.spacingS

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Lightness Offset"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: 1; height: 1 }
                            StyledText { text: SettingsData.matugenLightnessOffset > 0 ? "+" + SettingsData.matugenLightnessOffset.toFixed(2) : SettingsData.matugenLightnessOffset.toFixed(2); font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.matugenLightnessOffset * 100
                            minimum: -50; maximum: 50; unit: ""; showValue: false; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.setMatugenLightnessOffset(newValue / 100); Theme.reapplyColorAdjustments() }
                        }

                        Row {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "-0.5 (Darker)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "0 (Normal)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                            Item { width: 1; height: 1; Layout.fillWidth: true }
                            StyledText { text: "+0.5 (Lighter)"; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    EHActionButton { iconName: "restart_alt"; iconSize: Theme.iconSizeSmall; buttonSize: 32; iconColor: Theme.surfaceVariantText; onClicked: { SettingsData.setMatugenLightnessOffset(0); Theme.reapplyColorAdjustments() } }
                }
            }

            // ════════════════════════════════════════════════════════════
            // ACTIONS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: actionsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: actionsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "play_circle"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Actions"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        spacing: Theme.spacingM

                        Rectangle {
                            width: regenText.implicitWidth + Theme.spacingL * 2; height: 40
                            radius: Theme.cornerRadius; color: Theme.primary
                            Row { anchors.centerIn: parent; spacing: Theme.spacingS
                                EHIcon { name: "refresh"; size: 16; color: Theme.onPrimary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { id: regenText; text: "Regenerate Colors"; font.pixelSize: Theme.fontSizeMedium; color: Theme.onPrimary; font.weight: Font.Medium }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (typeof Theme !== 'undefined') Theme.extractColors() } }
                        }

                        Rectangle {
                            width: gtkText.implicitWidth + Theme.spacingL * 2; height: 40
                            radius: Theme.cornerRadius; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            border.color: Theme.primary; border.width: 1
                            Row { anchors.centerIn: parent; spacing: Theme.spacingS
                                EHIcon { name: "folder"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { id: gtkText; text: "Apply GTK Theme"; font.pixelSize: Theme.fontSizeMedium; color: Theme.primary; font.weight: Font.Medium }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (typeof Theme !== 'undefined') Theme.applyGtkColors() } }
                        }

                        Rectangle {
                            width: qtText.implicitWidth + Theme.spacingL * 2; height: 40
                            radius: Theme.cornerRadius; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            border.color: Theme.primary; border.width: 1
                            Row { anchors.centerIn: parent; spacing: Theme.spacingS
                                EHIcon { name: "settings"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { id: qtText; text: "Apply Qt Theme"; font.pixelSize: Theme.fontSizeMedium; color: Theme.primary; font.weight: Font.Medium }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (typeof Theme !== 'undefined') Theme.applyQtColors() } }
                        }
                    }

                    StyledText { text: "Click 'Regenerate Colors' to apply your changes and extract new colors from the current wallpaper."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                }
            }

            // ════════════════════════════════════════════════════════════
            // COLOR PREVIEW
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: previewSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: Theme.matugenAvailable && Theme.matugenColors && Object.keys(Theme.matugenColors).length > 0

                Column {
                    id: previewSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Current Color Preview"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Flow {
                        width: parent.width; spacing: Theme.spacingS
                        Repeater {
                            model: ["primary","secondary","tertiary","error","surface","surfaceContainer"]
                            Column {
                                spacing: Theme.spacingXS
                                Rectangle {
                                    width: 60; height: 40; radius: matugenTab._cornerSmall
                                    color: {
                                        if (!Theme.matugenColors || !Theme.matugenColors.colors) return Theme.surfaceVariant
                                        const mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
                                        return (Theme.matugenColors.colors[modelData] && Theme.matugenColors.colors[modelData][mode]) ? Theme.matugenColors.colors[modelData][mode] : Theme.surfaceVariant
                                    }
                                    border.color: Theme.outline; border.width: 1
                                }
                                StyledText { text: modelData; font.pixelSize: matugenTab._fontXSmall; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
