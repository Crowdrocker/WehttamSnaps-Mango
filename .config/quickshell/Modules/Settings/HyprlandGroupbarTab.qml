import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandGroupbarTab

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
            // CATEGORY 1: General
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: generalSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: generalSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "view_carousel"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Groupbar"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Enabled"; description: "Toggle groupbar rendering"; checked: SettingsData.hyprlandGroupbarEnabled; onToggled: checked => SettingsData.setHyprlandGroupbarEnabled(checked) }
                    EHToggle { width: parent.width; text: "Render Titles"; description: "Show window titles inside groupbar tabs"; checked: SettingsData.hyprlandGroupbarRenderTitles; onToggled: checked => SettingsData.setHyprlandGroupbarRenderTitles(checked) }
                    EHToggle { width: parent.width; text: "Gradients"; description: "Use gradient fills for groupbar tab colors"; checked: SettingsData.hyprlandGroupbarGradients; onToggled: checked => SettingsData.setHyprlandGroupbarGradients(checked) }

                    Row {
                        width: parent.width; spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Height"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandGroupbarHeight; minimum: 10; maximum: 100; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandGroupbarHeight(v) }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Priority"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandGroupbarPriority; minimum: 0; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandGroupbarPriority(v) }
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Rounding"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Corner radius of groupbar tabs"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandGroupbarRounding; minimum: 0; maximum: 30; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandGroupbarRounding(v) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Colors
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: colorsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: colorsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Colors"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Active Color"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Color of the focused window's tab"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandGroupbarColActive; placeholderText: "rgba(...) or gradient"; onEditingFinished: SettingsData.setHyprlandGroupbarColActive(text) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Inactive Color"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Color of unfocused window tabs"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandGroupbarColInactive; placeholderText: "rgba(...)"; onEditingFinished: SettingsData.setHyprlandGroupbarColInactive(text) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Text Color"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Color of tab title text"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandGroupbarTextColor; placeholderText: "rgba(...)"; onEditingFinished: SettingsData.setHyprlandGroupbarTextColor(text) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Typography
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: typographySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: typographySection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "text_fields"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Typography"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Font Family"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandGroupbarFontFamily; placeholderText: "Inter Variable, Inter, Roboto, ..."; onEditingFinished: SettingsData.setHyprlandGroupbarFontFamily(text) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Font Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandGroupbarFontSize; minimum: 6; maximum: 36; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandGroupbarFontSize(v) }
                    }
                }
            }
        }
    }
}
