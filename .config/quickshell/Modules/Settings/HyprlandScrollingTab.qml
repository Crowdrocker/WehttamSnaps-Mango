import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandScrollingTab

    property var parentModal: null

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
            // CATEGORY 1: Column Behavior
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: columnSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: columnSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "view_column"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Column Behavior"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Column Width
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Column Width"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Default width of a column"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandScrollingColumnWidth
                            minimum: 0.1
                            maximum: 1.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandScrollingColumnWidth(v)
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Fullscreen on One Column"
                        description: "A single column on a workspace will always span the entire screen"
                        checked: SettingsData.hyprlandScrollingFullscreenOnOneColumn
                        onToggled: checked => SettingsData.setHyprlandScrollingFullscreenOnOneColumn(checked)
                    }

                    // Focus Fit Method
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - focusFitDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Focus Fit Method"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "When a column is focused, how to bring it into view"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: focusFitDropdown
                            width: 180
                            text: "Focus Fit"
                            options: ["Center", "Fit"]
                            currentValue: ["center", "fit"][SettingsData.hyprlandScrollingFocusFitMethod] || "Fit"
                            onValueChanged: value => {
                                var idx = ["center", "fit"].indexOf(value)
                                if (idx >= 0) SettingsData.setHyprlandScrollingFocusFitMethod(idx)
                            }
                        }
                    }

                    // Direction
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - directionDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Direction"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Direction in which new windows appear and the layout scrolls"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: directionDropdown
                            width: 180
                            text: "Direction"
                            options: ["left", "right", "up", "down"]
                            currentValue: SettingsData.hyprlandScrollingDirection || "right"
                            onValueChanged: value => SettingsData.setHyprlandScrollingDirection(value)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Focus Behavior
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: focusSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: focusSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "center_focus_strong"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Focus Behavior"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Follow Focus"
                        description: "When a window is focused, the layout moves to bring it into view automatically"
                        checked: SettingsData.hyprlandScrollingFollowFocus
                        onToggled: checked => SettingsData.setHyprlandScrollingFollowFocus(checked)
                    }

                    // Follow Min Visible
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Follow Min Visible"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Minimum fraction of window that must be visible for focus to follow"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandScrollingFollowMinVisible
                            minimum: 0.0
                            maximum: 1.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandScrollingFollowMinVisible(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Wrapping
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: wrapSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: wrapSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "swap_horiz"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Wrapping"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Wrap Focus"
                        description: "Focus navigation wraps around at the beginning and end"
                        checked: SettingsData.hyprlandScrollingWrapFocus
                        onToggled: checked => SettingsData.setHyprlandScrollingWrapFocus(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Wrap Swap Column"
                        description: "Column swapping wraps around at the beginning and end"
                        checked: SettingsData.hyprlandScrollingWrapSwapcol
                        onToggled: checked => SettingsData.setHyprlandScrollingWrapSwapcol(checked)
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 4: Column Widths Configuration
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: configSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: configSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Column Width Presets"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Explicit Column Widths - using dropdown with presets
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - explicitWidthsDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Explicit Column Widths"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Preconfigured widths for colresize"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: explicitWidthsDropdown
                            width: 200
                            text: "Widths"
                            options: ["0.333, 0.5, 0.667, 1.0", "0.25, 0.5, 0.75, 1.0", "0.2, 0.4, 0.6, 0.8, 1.0", "0.5, 1.0", "0.333, 0.666, 1.0"]
                            currentValue: SettingsData.hyprlandScrollingExplicitColumnWidths || "0.333, 0.5, 0.667, 1.0"
                            onValueChanged: value => SettingsData.setHyprlandScrollingExplicitColumnWidths(value)
                        }
                    }
                }
            }
        }
    }
}
