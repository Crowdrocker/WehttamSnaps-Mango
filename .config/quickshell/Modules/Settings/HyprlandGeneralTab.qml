import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandGeneralTab

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
            // CATEGORY 1: Gaps
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: gapsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: gapsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "space_bar"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Gaps"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Inner Gaps"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Gap between windows"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandGeneralGapsIn
                            minimum: 0; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandGeneralGapsIn(v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Outer Gaps"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Gap between windows and monitor edges"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandGeneralGapsOut
                            minimum: 0; maximum: 100; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandGeneralGapsOut(v)
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Workspace Gaps"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Gap between workspaces"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandGeneralGapsWorkspaces
                            minimum: 0; maximum: 100; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandGeneralGapsWorkspaces(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Borders
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: bordersSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: bordersSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "border_all"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Borders"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Border Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Window border thickness"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandGeneralBorderSize
                            minimum: 0; maximum: 20; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandGeneralBorderSize(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Behavior
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: behaviorSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: behaviorSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Behavior"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Layout
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - layoutDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Window Layout"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Tiling algorithm used for window placement"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHDropdown {
                            id: layoutDropdown
                            width: 180
                            text: "Layout"
                            options: ["Dwindle", "Master", "Scrolling", "Monocle"]
                            currentValue: {
                                var l = (SettingsData.hyprlandGeneralLayout || "dwindle").toLowerCase()
                                if (l === "master") return "Master"
                                if (l === "scroller" || l === "scrolling") return "Scrolling"
                                if (l === "monocle") return "Monocle"
                                return "Dwindle"
                            }
                            onValueChanged: value => {
                                var map = { "Dwindle": "dwindle", "Master": "master", "Scrolling": "scrolling", "Monocle": "monocle" }
                                SettingsData.setHyprlandGeneralLayout(map[value] || "dwindle")
                            }
                        }
                    }

                    EHToggle { width: parent.width; text: "Resize on Border"; description: "Allow resizing by dragging borders and gaps"; checked: SettingsData.hyprlandGeneralResizeOnBorder; onToggled: checked => SettingsData.setHyprlandGeneralResizeOnBorder(checked) }
                    EHToggle { width: parent.width; text: "No Focus Fallback"; description: "Do not focus another window if the focused one closes and no other is found"; checked: SettingsData.hyprlandGeneralNoFocusFallback; onToggled: checked => SettingsData.setHyprlandGeneralNoFocusFallback(checked) }
                    EHToggle { width: parent.width; text: "Allow Tearing"; description: "Allow the immediate window rule to tear — useful for gaming"; checked: SettingsData.hyprlandGeneralAllowTearing; onToggled: checked => SettingsData.setHyprlandGeneralAllowTearing(checked) }
                }
            }
        }
    }
}