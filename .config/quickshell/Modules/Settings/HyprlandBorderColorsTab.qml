import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandBorderColorsTab

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
            // CATEGORY 1: Border Settings
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: borderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: borderSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "window"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Border Colors"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Dynamic Border Colors"
                        description: "Apply dynamic colors to window borders"
                        checked: SettingsData.hyprlandThemingEnabled
                        onToggled: checked => SettingsData.setHyprlandThemingEnabled(checked)
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        visible: SettingsData.hyprlandThemingEnabled
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                        StyledText { text: "Border Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Thickness of window borders"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.hyprlandBorderSize
                            minimum: 1; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setHyprlandBorderSize(v)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Border Color Adjustment
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: colorAdjSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland && SettingsData.hyprlandThemingEnabled
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                Column {
                    id: colorAdjSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Border Color Adjustment"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Preview + sliders side by side
                    Row {
                        width: parent.width
                        spacing: Theme.spacingL

                        // Color preview
                        Column {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Preview"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; horizontalAlignment: Text.AlignHCenter; width: parent.width }

                            Rectangle {
                                id: previewColorBox
                                width: 80; height: 80
                                radius: Theme.cornerRadius
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 2

                                property color baseColor: typeof Theme !== "undefined" ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0)
                                property real hueShift: hueSlider.value
                                property real alpha: alphaSlider.value / 100.0

                                function calculatePreviewColor() {
                                    var r = baseColor.r, g = baseColor.g, b = baseColor.b
                                    var max = Math.max(r, Math.max(g, b))
                                    var min = Math.min(r, Math.min(g, b))
                                    var h, s, l = (max + min) / 2
                                    var d = max - min
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
                                        if (t < 1/6) return p + (q - p) * 6 * t
                                        if (t < 1/2) return q
                                        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
                                        return p
                                    }
                                    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
                                    var p = 2 * l - q
                                    r = hue2rgb(p, q, h + 1/3); g = hue2rgb(p, q, h); b = hue2rgb(p, q, h - 1/3)
                                    r = r * alpha; g = g * alpha; b = b * alpha
                                    return Qt.rgba(r, g, b, 1.0)
                                }

                                color: calculatePreviewColor()

                                Connections { target: hueSlider;   function onSliderValueChanged() { previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Connections { target: alphaSlider;  function onSliderValueChanged() { previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Connections { target: Theme; function onPrimaryChanged() { previewColorBox.baseColor = Theme.primary; previewColorBox.color = previewColorBox.calculatePreviewColor() } }
                                Component.onCompleted: { baseColor = typeof Theme !== "undefined" ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0); color = calculatePreviewColor() }
                            }
                        }

                        // Hue + Alpha sliders
                        Column {
                            width: parent.width - 80 - Theme.spacingL
                            spacing: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter

                            Column {
                                width: parent.width; spacing: Theme.spacingS
                                StyledText { text: "Hue Shift"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                Rectangle {
                                    width: parent.width; height: 10; radius: 5
                                    opacity: 0.5
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
                                }
                                EHSlider {
                                    id: hueSlider
                                    width: parent.width; height: 24
                                    value: Math.round(SettingsData.hyprlandBorderHue)
                                    minimum: -180; maximum: 180; unit: "°"; showValue: true; wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    onSliderDragFinished: v => SettingsData.setHyprlandBorderHue(v)
                                }
                            }

                            Column {
                                width: parent.width; spacing: Theme.spacingS
                                StyledText { text: "Alpha"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                EHSlider {
                                    id: alphaSlider
                                    width: parent.width; height: 24
                                    value: Math.round(SettingsData.hyprlandBorderAlpha * 100)
                                    minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    onSliderDragFinished: v => SettingsData.setHyprlandBorderAlpha(v / 100)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
