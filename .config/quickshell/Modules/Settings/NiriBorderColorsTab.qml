import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: niriBorderColorsTab

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
            // BORDER COLORS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: borderColorsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: borderColorsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "window"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Niri Border Colors"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Dynamic Border Colors"
                        description: "Apply dynamic colors to window borders using matugen"
                        checked: SettingsData.niriThemingEnabled
                        onToggled: checked => { SettingsData.setNiriThemingEnabled(checked) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        visible: SettingsData.niriThemingEnabled

                        StyledText { text: "Border Width: " + SettingsData.niriBorderWidth + "px"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Thickness of window borders"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.niriBorderWidth
                            minimum: 1; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriBorderWidth(finalValue) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // BORDER COLOR ADJUSTMENT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: niriBorderColorsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri && SettingsData.niriThemingEnabled

                Column {
                    id: niriBorderColorsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Border Color Adjustment"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Adjust the hue and opacity of window border colors"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM

                        Column {
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Preview"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            Rectangle {
                                id: previewColorBox
                                width: 80; height: 80; radius: Theme.cornerRadius
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2); border.width: 2

                                property color baseColor: typeof Theme !== 'undefined' ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0)
                                property real hueShift: hueSlider.value
                                property real alpha: alphaSlider.value / 100.0

                                function calculatePreviewColor() {
                                    var r = baseColor.r, g = baseColor.g, b = baseColor.b
                                    var max = Math.max(r, Math.max(g, b)), min = Math.min(r, Math.min(g, b))
                                    var h, s, l = (max + min) / 2, d = max - min
                                    if (d !== 0) {
                                        s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                                        if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
                                        else if (max === g) h = ((b - r) / d + 2) / 6
                                        else h = ((r - g) / d + 4) / 6
                                    } else { h = s = 0 }
                                    h = (h + hueShift / 360.0) % 1.0
                                    if (h < 0) h += 1.0
                                    var hue2rgb = function(p, q, t) {
                                        if (t < 0) t += 1; if (t > 1) t -= 1
                                        if (t < 1/6) return p + (q-p)*6*t
                                        if (t < 1/2) return q
                                        if (t < 2/3) return p + (q-p)*(2/3-t)*6
                                        return p
                                    }
                                    var q = l < 0.5 ? l*(1+s) : l+s-l*s, p = 2*l - q
                                    r = hue2rgb(p,q,h+1/3); g = hue2rgb(p,q,h); b = hue2rgb(p,q,h-1/3)
                                    r = r*alpha; g = g*alpha; b = b*alpha
                                    return Qt.rgba(r, g, b, 1.0)
                                }

                                color: calculatePreviewColor()

                                Connections { target: hueSlider;  function onSliderValueChanged() { previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Connections { target: alphaSlider; function onSliderValueChanged() { previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Connections { target: Theme; function onPrimaryChanged() { previewColorBox.baseColor = Theme.primary; previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Component.onCompleted: { previewColorBox.baseColor = typeof Theme !== 'undefined' ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0); previewColorBox.color = previewColorBox.calculatePreviewColor() }
                            }
                        }

                        Column {
                            width: parent.width - 80 - Theme.spacingM; spacing: Theme.spacingM; anchors.verticalCenter: parent.verticalCenter

                            Column {
                                width: parent.width; spacing: Theme.spacingXS
                                StyledText { text: "Hue: " + Math.round(hueSlider.value) + "°"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                EHSlider {
                                    id: hueSlider; width: parent.width; height: 32
                                    value: Math.round(SettingsData.niriBorderHue)
                                    minimum: -180; maximum: 180; unit: "°"; showValue: true; wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    onSliderDragFinished: finalValue => { SettingsData.setNiriBorderHue(finalValue) }
                                }
                            }

                            Column {
                                width: parent.width; spacing: Theme.spacingXS
                                StyledText { text: "Alpha: " + Math.round(alphaSlider.value) + "%"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                EHSlider {
                                    id: alphaSlider; width: parent.width; height: 32
                                    value: Math.round(SettingsData.niriBorderAlpha * 100)
                                    minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    onSliderDragFinished: finalValue => { SettingsData.setNiriBorderAlpha(finalValue / 100) }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // MATUGEN INFO
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: matugenInfoSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.niriThemingEnabled && typeof Theme !== 'undefined' && Theme.matugenAvailable

                Column {
                    id: matugenInfoSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "info"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Using matugen for color extraction"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Colors are extracted from your wallpaper using matugen and applied to Niri borders."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // NOT AVAILABLE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: notAvailableSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && !CompositorService.isNiri

                Column {
                    id: notAvailableSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "info"; size: Theme.iconSize; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Niri Not Active"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Niri theming settings are only available when running Niri as your window manager."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
