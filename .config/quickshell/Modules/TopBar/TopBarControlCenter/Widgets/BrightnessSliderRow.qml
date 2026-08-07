import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root
    width: parent.width

    Repeater {
        model: DisplayService.devices.filter(d => !d.name.includes("kbd"))

        delegate: Column {
            spacing: Theme.spacingXS
            width: parent.width

            Row {
                spacing: 8
                width: parent.width

                EHIcon {
                    name: {
                        if (!DisplayService.brightnessAvailable) return "brightness_low"

                        let brightness = DisplayService.getDeviceBrightness(model.name)
                        if (brightness <= 33) return "brightness_low"
                        if (brightness <= 66) return "brightness_medium"
                        return "brightness_high"
                    }
                    size: Theme.iconSize
                    color: DisplayService.brightnessAvailable && DisplayService.getDeviceBrightness(model.name) > 0 ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (model.name || "Display") + " (" + model.class + ")"
                    font.pixelSize: 15
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.width - Theme.iconSize - 8
                }
            }

            Item {
                width: parent.width
                height: 14
                Layout.topMargin: Theme.spacingS
                Layout.bottomMargin: Theme.spacingS

                EHSlider {
                    anchors.fill: parent
                    enabled: DisplayService.brightnessAvailable
                    minimum: 1
                    maximum: 100
                    value: DisplayService.getDeviceBrightness(model.name)

                    onSliderValueChanged: function(newValue) {
                        if (DisplayService.brightnessAvailable) {
                            DisplayService.setBrightness(newValue, model.name)
                        }
                    }
                    thumbOutlineColor: Theme.surfaceContainer
                    trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
                }
            }
        }
    }
}
