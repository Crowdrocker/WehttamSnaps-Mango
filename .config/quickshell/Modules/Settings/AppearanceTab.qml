import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: appearanceTab

    property var parentModal: null

    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingM

            StyledRect {
                width: parent.width
                height: contentColumn.childrenRect.height + Theme.spacingL * 2 + 4
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: contentColumn
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    y: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledRect {
                        width: parent.width
                        height: settingsBrightnessColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        Column {
                            id: settingsBrightnessColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Settings Brightness"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Adjust the settings window brightness (useful for HDR)."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: Math.round(SettingsData.settingsBrightness * 100)
                                minimum: 60
                                maximum: 140
                                unit: "%"
                                showValue: true
                                wheelEnabled: false
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setSettingsBrightness(finalValue / 100)
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: settingsContrastColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        Column {
                            id: settingsContrastColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Settings Contrast"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Adjust the settings window contrast (helps with HDR bloom)."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: Math.round(SettingsData.settingsContrast * 100)
                                minimum: 60
                                maximum: 140
                                unit: "%"
                                showValue: true
                                wheelEnabled: false
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setSettingsContrast(finalValue / 100)
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: settingsWhiteBalanceColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        Column {
                            id: settingsWhiteBalanceColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Settings White Balance"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Shift temperature toward warm (higher) or cool (lower)."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: Math.round(SettingsData.settingsWhiteBalance * 100)
                                minimum: 80
                                maximum: 120
                                unit: "%"
                                showValue: true
                                wheelEnabled: false
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setSettingsWhiteBalance(finalValue / 100)
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: settingsHighlightsColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        Column {
                            id: settingsHighlightsColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Settings Highlights"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Reduce or boost bright areas of the settings UI."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: Math.round(SettingsData.settingsHighlights * 100)
                                minimum: 80
                                maximum: 120
                                unit: "%"
                                showValue: true
                                wheelEnabled: false
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setSettingsHighlights(finalValue / 100)
                                }
                            }
                        }
                    }

                    // Transparency Section
                    OpacityTab {
                        id: transparencyTabItem
                        width: parent.width
                        parentModal: appearanceTab.parentModal
                        
                        Component.onCompleted: {
                            for (var i = 0; i < children.length; i++) {
                                var child = children[i]
                                if (child.contentHeight !== undefined) {
                                    child.interactive = false
                                    height = child.contentHeight + Theme.spacingL
                                    child.contentHeightChanged.connect(function() {
                                        transparencyTabItem.height = child.contentHeight + Theme.spacingL
                                    })
                                    break
                                }
                            }
                        }
                    }

                    // Borders & Shadows Section
                    BordersShadowsTab {
                        id: bordersShadowsTabItem
                        width: parent.width
                        parentModal: appearanceTab.parentModal
                        
                        Component.onCompleted: {
                            for (var i = 0; i < children.length; i++) {
                                var child = children[i]
                                if (child.contentHeight !== undefined) {
                                    child.interactive = false
                                    height = child.contentHeight + Theme.spacingL
                                    child.contentHeightChanged.connect(function() {
                                        bordersShadowsTabItem.height = child.contentHeight + Theme.spacingL
                                    })
                                    break
                                }
                            }
                        }
                    }

                    // Icon Tinting Section
                    IconTintingTab {
                        id: iconTintingTabItem
                        width: parent.width
                        parentModal: appearanceTab.parentModal
                        
                        Component.onCompleted: {
                            for (var i = 0; i < children.length; i++) {
                                var child = children[i]
                                if (child.contentHeight !== undefined) {
                                    child.interactive = false
                                    height = child.contentHeight
                                    child.contentHeightChanged.connect(function() {
                                        iconTintingTabItem.height = child.contentHeight
                                    })
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
