import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: visualEffectsTab

    property var parentModal: null

    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: visualEffectsSection.childrenRect.height + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: visualEffectsSection

                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    y: Theme.spacingM
                    spacing: Theme.spacingM

                    // Header
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        topPadding: Theme.spacingXS
                        bottomPadding: Theme.spacingXS

                        StyledText {
                            text: "Visual Effects"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Adjust color intensity, corner rounding, and blur effects"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    Column {
                        id: visualEffectsContent
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Color Vibrance"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: SettingsData.colorVibrance * 100
                                minimum: 0
                                maximum: 100
                                unit: "%"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => {
                                                          SettingsData.setColorVibrance(
                                                              newValue / 100)
                                                      }
                            }

                            StyledText {
                                text: "Corner Radius (0 = square corners)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: SettingsData.cornerRadius
                                minimum: 0
                                maximum: 32
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => {
                                                          SettingsData.setCornerRadius(
                                                              newValue)
                                                      }
                            }
                        }
                    }
                }
            }
        }
    }
}
