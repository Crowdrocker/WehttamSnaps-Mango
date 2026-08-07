import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services

Item {
    id: colorPickerModal

    signal colorSelected(color selectedColor)

    property color currentColor: Theme.primary
    property real hueValue: 0 // 0-360
    property real opacityValue: 1 // 0-1

    function show() {
        colorPopup.open()
    }

    function hide() {
        colorPopup.close()
    }

    function copyColorToClipboard(colorValue) {
        Quickshell.execDetached(["sh", "-c", `echo "${colorValue}" | wl-copy`])
        ToastService.showInfo(`Color ${colorValue} copied to clipboard`)
    }

    // Get color from HSV values
    function getColor() {
        return Qt.hsla(hueSlider.value / 360, 1, 0.5, opacitySlider.value)
    }

    function updateColor() {
        currentColor = getColor()
    }

    Popup {
        id: colorPopup
        x: (parent.width - 320) / 2
        y: (parent.height - 400) / 2
        width: 320
        height: 340
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 20

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: 12
            border.width: 1
            border.color: Theme.outlineVariant
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            // Title
            Text {
                text: "Color Picker"
                font.pixelSize: 18
                font.bold: true
                color: Theme.surfaceText
            }

            // Color Preview
            Rectangle {
                id: colorPreview
                width: parent.width
                height: 60
                radius: 8
                color: currentColor
                border.width: 1
                border.color: Theme.outlineVariant
            }

            // Hex Value Display
            Text {
                id: hexValue
                text: "#" + 
                      Math.round(currentColor.r * 255).toString(16).padStart(2, '0') +
                      Math.round(currentColor.g * 255).toString(16).padStart(2, '0') +
                      Math.round(currentColor.b * 255).toString(16).padStart(2, '0').toUpperCase()
                font.pixelSize: 14
                font.family: "monospace"
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
            }

            // Hue Slider Label
            Text {
                text: "Hue"
                font.pixelSize: 13
                color: Theme.surfaceText
            }

            // Hue Slider (0-360)
            Slider {
                id: hueSlider
                from: 0
                to: 360
                value: 0
                stepSize: 1
                Layout.fillWidth: true

                // Custom hue gradient background
                background: Rectangle {
                    width: hueSlider.availableWidth
                    height: 8
                    radius: 4
                    gradient: Gradient {
                        GradientStop { position: 0/360; color: "#ff0000" }
                        GradientStop { position: 60/360; color: "#ffff00" }
                        GradientStop { position: 120/360; color: "#00ff00" }
                        GradientStop { position: 180/360; color: "#00ffff" }
                        GradientStop { position: 240/360; color: "#0000ff" }
                        GradientStop { position: 300/360; color: "#ff00ff" }
                        GradientStop { position: 360/360; color: "#ff0000" }
                    }
                }

                onValueChanged: {
                    hueValue = value
                    updateColor()
                }
            }

            // Opacity Slider Label
            Text {
                text: "Opacity"
                font.pixelSize: 13
                color: Theme.surfaceText
            }

            // Opacity Slider (replaces alpha)
            Slider {
                id: opacitySlider
                from: 0
                to: 1
                value: 1
                stepSize: 0.01
                Layout.fillWidth: true

                background: Rectangle {
                    width: opacitySlider.availableWidth
                    height: 8
                    radius: 4
                    // Checkerboard pattern to show transparency
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.hsva(hueSlider.value / 360, 1, 1, 1) }
                    }
                }

                onValueChanged: {
                    opacityValue = value
                    updateColor()
                }
            }

            // Buttons
            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: {
                        colorPopup.close()
                    }
                }

                Button {
                    text: "Copy"
                    Layout.fillWidth: true
                    onClicked: {
                        const colorString = "#" + 
                            Math.round(currentColor.r * 255).toString(16).padStart(2, '0') +
                            Math.round(currentColor.g * 255).toString(16).padStart(2, '0') +
                            Math.round(currentColor.b * 255).toString(16).padStart(2, '0').toUpperCase()
                        copyColorToClipboard(colorString)
                    }
                }

                Button {
                    text: "Select"
                    Layout.fillWidth: true
                    onClicked: {
                        colorSelected(currentColor)
                        colorPopup.close()
                    }
                }
            }
        }

        // Initialize with Theme.primary color converted to HSV
        Component.onCompleted: {
            // Convert Theme.primary to HSV and set slider values
            var r = Theme.primary.r
            var g = Theme.primary.g
            var b = Theme.primary.b
            
            var max = Math.max(r, g, b)
            var min = Math.min(r, g, b)
            var delta = max - min
            
            // Calculate hue
            if (delta === 0) {
                hueSlider.value = 0
            } else if (max === r) {
                hueSlider.value = 60 * (((g - b) / delta) % 6)
            } else if (max === g) {
                hueSlider.value = 60 * (((b - r) / delta) + 2)
            } else {
                hueSlider.value = 60 * (((r - g) / delta) + 4)
            }
            if (hueSlider.value < 0) hueSlider.value += 360
            
            // Set opacity
            opacitySlider.value = Theme.primary.a
            
            // Update initial color
            updateColor()
        }
    }
}
