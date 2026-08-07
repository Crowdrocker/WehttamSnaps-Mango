import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: colorAdjustmentsTab

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
            // HUE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: hueSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: hueSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Hue"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Hue wheel preview strip
                    Rectangle {
                        width: parent.width
                        height: 10
                        radius: 5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.000; color: "#ff0000" }
                            GradientStop { position: 0.167; color: "#ffff00" }
                            GradientStop { position: 0.333; color: "#00ff00" }
                            GradientStop { position: 0.500; color: "#00ffff" }
                            GradientStop { position: 0.667; color: "#0000ff" }
                            GradientStop { position: 0.833; color: "#ff00ff" }
                            GradientStop { position: 1.000; color: "#ff0000" }
                        }
                        opacity: 0.5
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Hue Shift"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(ColorPaletteService.hueShiftDegrees)
                            minimum: -180; maximum: 180; unit: "°"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { ColorPaletteService.hueShiftDegrees = newValue }
                            onSliderDragFinished: finalValue => {
                                ColorPaletteService.hueShiftDegrees = finalValue
                                ColorPaletteService.seedSelectionFromCurrentTheme()
                                ColorPaletteService.applySelectedColors()
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // SATURATION & LIGHTNESS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: satLightSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: satLightSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Saturation & Lightness"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Saturation"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(ColorPaletteService.saturationScale * 100)
                            minimum: 50; maximum: 150; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { ColorPaletteService.saturationScale = newValue / 100 }
                            onSliderDragFinished: finalValue => {
                                ColorPaletteService.saturationScale = finalValue / 100
                                ColorPaletteService.seedSelectionFromCurrentTheme()
                                ColorPaletteService.applySelectedColors()
                            }
                        }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Lightness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(ColorPaletteService.lightnessScale * 100)
                            minimum: 50; maximum: 150; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { ColorPaletteService.lightnessScale = newValue / 100 }
                            onSliderDragFinished: finalValue => {
                                ColorPaletteService.lightnessScale = finalValue / 100
                                ColorPaletteService.seedSelectionFromCurrentTheme()
                                ColorPaletteService.applySelectedColors()
                            }
                        }
                    }
                }
            }
        }
    }
}
