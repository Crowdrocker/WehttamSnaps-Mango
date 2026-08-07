import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandMasterTab

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
            // CATEGORY 1: Master Window Behavior
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: masterSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: masterSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "view_agenda"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Master Window"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // M-Fact
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "M-Fact"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Size as a percentage of the master window"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandMasterMfact
                            minimum: 0.0
                            maximum: 1.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandMasterMfact(v)
                        }
                    }

                    // Orientation
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - orientationDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Orientation"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Default placement of the master area"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: orientationDropdown
                            width: 180
                            text: "Orientation"
                            options: ["left", "right", "top", "bottom", "center"]
                            currentValue: SettingsData.hyprlandMasterOrientation || "left"
                            onValueChanged: value => SettingsData.setHyprlandMasterOrientation(value)
                        }
                    }

                    // New Status
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - newStatusDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "New Window Status"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Whether new windows become master or slave"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: newStatusDropdown
                            width: 180
                            text: "New Status"
                            options: ["master", "slave", "inherit"]
                            currentValue: SettingsData.hyprlandMasterNewStatus || "slave"
                            onValueChanged: value => SettingsData.setHyprlandMasterNewStatus(value)
                        }
                    }

                    // New on Top
                    EHToggle {
                        width: parent.width
                        text: "New on Top"
                        description: "Whether a newly open window should be on the top of the stack"
                        checked: SettingsData.hyprlandMasterNewOnTop
                        onToggled: checked => SettingsData.setHyprlandMasterNewOnTop(checked)
                    }

                    // New on Active
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - newOnActiveDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "New on Active"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Place new window relative to the focused window"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: newOnActiveDropdown
                            width: 180
                            text: "New on Active"
                            options: ["none", "before", "after"]
                            currentValue: SettingsData.hyprlandMasterNewOnActive || "none"
                            onValueChanged: value => SettingsData.setHyprlandMasterNewOnActive(value)
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Allow Small Split"
                        description: "Enable adding additional master windows in a horizontal split style"
                        checked: SettingsData.hyprlandMasterAllowSmallSplit
                        onToggled: checked => SettingsData.setHyprlandMasterAllowSmallSplit(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Always Keep Position"
                        description: "Keep master window in configured position when there are no slave windows"
                        checked: SettingsData.hyprlandMasterAlwaysKeepPosition
                        onToggled: checked => SettingsData.setHyprlandMasterAlwaysKeepPosition(checked)
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Center Master
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: centerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== "undefined" && CompositorService.isHyprland

                Column {
                    id: centerSection
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
                            text: "Center Master"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Slave Count for Center Master
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Slave Count for Center Master"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Minimum slave windows for center master placement (0 = always center)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandMasterSlaveCountForCenterMaster
                            minimum: 0
                            maximum: 10
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandMasterSlaveCountForCenterMaster(v)
                        }
                    }

                    // Center Master Fallback
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - centerFallbackDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Center Master Fallback"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Fallback placement when slaves are less than slave_count_for_center_master"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: centerFallbackDropdown
                            width: 180
                            text: "Fallback"
                            options: ["left", "right", "top", "bottom"]
                            currentValue: SettingsData.hyprlandMasterCenterMasterFallback || "left"
                            onValueChanged: value => SettingsData.setHyprlandMasterCenterMasterFallback(value)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Window Sizing
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
                        description: "Resize direction determined by mouse position on window"
                        checked: SettingsData.hyprlandMasterSmartResizing
                        onToggled: checked => SettingsData.setHyprlandMasterSmartResizing(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Drop at Cursor"
                        description: "Dragging and dropping windows puts them at the cursor position"
                        checked: SettingsData.hyprlandMasterDropAtCursor
                        onToggled: checked => SettingsData.setHyprlandMasterDropAtCursor(checked)
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
                            text: "Scale of the special workspace windows"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.hyprlandMasterSpecialScaleFactor
                            minimum: 0.0
                            maximum: 1.0
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandMasterSpecialScaleFactor(v)
                        }
                    }
                }
            }
        }
    }
}
