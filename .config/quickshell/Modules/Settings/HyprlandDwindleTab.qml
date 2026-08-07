import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandDwindleTab

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
            // CATEGORY 1: Splitting Behavior
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: splitSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: splitSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "splitscreen"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Splitting Behavior"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Preserve Split"
                        description: "Keep split direction when new windows open"
                        checked: SettingsData.hyprlandDwindlePreserveSplit
                        onToggled: checked => SettingsData.setHyprlandDwindlePreserveSplit(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Smart Split"
                        description: "Prefer splitting in the larger dimension"
                        checked: SettingsData.hyprlandDwindleSmartSplit
                        onToggled: checked => SettingsData.setHyprlandDwindleSmartSplit(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Pseudotile"
                        description: "Pseudotiled windows retain their floating size when tiled"
                        checked: SettingsData.hyprlandDwindlePseudotile
                        onToggled: checked => SettingsData.setHyprlandDwindlePseudotile(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Permanent Direction Override"
                        description: "Makes the preselect direction persist until turned off or changed"
                        checked: SettingsData.hyprlandDwindlePermanentDirectionOverride
                        onToggled: checked => SettingsData.setHyprlandDwindlePermanentDirectionOverride(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Use Active For Splits"
                        description: "Prefer the active window for split direction over mouse position"
                        checked: SettingsData.hyprlandDwindleUseActiveForSplits
                        onToggled: checked => SettingsData.setHyprlandDwindleUseActiveForSplits(checked)
                    }

                    // Force Split
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - forceSplitDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Force Split"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Control the direction new windows split into"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: forceSplitDropdown
                            width: 180
                            text: "Force Split"
                            options: ["Auto", "Left/Top", "Right/Bottom"]
                            currentValue: ["Auto", "Left/Top", "Right/Bottom"][SettingsData.hyprlandDwindleForceSplit] || "Auto"
                            onValueChanged: value => {
                                var idx = ["Auto", "Left/Top", "Right/Bottom"].indexOf(value)
                                if (idx >= 0) SettingsData.setHyprlandDwindleForceSplit(idx)
                            }
                        }
                    }

                    // Split Bias
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - splitBiasDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Split Bias"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Which window receives the split ratio"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: splitBiasDropdown
                            width: 180
                            text: "Split Bias"
                            options: ["Directional", "Current Window"]
                            currentValue: ["Directional", "Current Window"][SettingsData.hyprlandDwindleSplitBias] || "Directional"
                            onValueChanged: value => {
                                var idx = ["Directional", "Current Window"].indexOf(value)
                                if (idx >= 0) SettingsData.setHyprlandDwindleSplitBias(idx)
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Window Sizing
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: sizingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: sizingSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "aspect_ratio"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Window Sizing"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Smart Resizing"
                        description: "Resize windows while preserving split ratios"
                        checked: SettingsData.hyprlandDwindleSmartResizing
                        onToggled: checked => SettingsData.setHyprlandDwindleSmartResizing(checked)
                    }

                    // Default Split Ratio
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Default Split Ratio"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Default split ratio on window open. 1.0 = even 50/50 split"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandDwindleDefaultSplitRatio
                            minimum: 0.5
                            maximum: 1.5
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandDwindleDefaultSplitRatio(v)
                        }
                    }

                    // Split Width Multiplier
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Split Width Multiplier"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Auto-split width multiplier. Useful on ultrawide monitors"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandDwindleSplitWidthMultiplier
                            minimum: 0.5
                            maximum: 2.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandDwindleSplitWidthMultiplier(v)
                        }
                    }

                    // Special Scale Factor
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Special Workspace Scale Factor"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Scale factor of windows on the special workspace"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandDwindleSpecialScaleFactor
                            minimum: 0.1
                            maximum: 1.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandDwindleSpecialScaleFactor(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Mouse & Interaction
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: mouseSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: mouseSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "mouse"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Mouse & Interaction"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Precise Mouse Move"
                        description: "Drop windows more precisely depending on mouse position when using bindm movewindow"
                        checked: SettingsData.hyprlandDwindlePreciseMouseMove
                        onToggled: checked => SettingsData.setHyprlandDwindlePreciseMouseMove(checked)
                    }
                }
            }
        }
    }
}