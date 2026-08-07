import QtQuick
import QtQuick.Controls
import qs.Common

// Drop this inside your dock settings panel wherever the other
// dock appearance sliders live (dockScale, dockTransparency, etc.).
//
// It writes to SettingsData.dockCavaIntensity (0.0 – 1.0).
// DockCavaBackground reads that property live, so dragging the slider
// updates the visualizer immediately with no restart needed.
//
// Register dockCavaIntensity in your SettingsData singleton with:
//   property real dockCavaIntensity: 1.0

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Safe read — keeps the slider in sync if the setting is changed elsewhere
    readonly property real currentIntensity: (typeof SettingsData !== "undefined" && SettingsData.dockCavaIntensity !== undefined)
                                              ? SettingsData.dockCavaIntensity
                                              : 1.0

    Row {
        id: row
        spacing: 12
        anchors.verticalCenter: parent.verticalCenter

        // Label
        Text {
            text: "Cava Intensity"
            color: Theme.onSurface
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        // Slider  0.0 → 1.0  displayed as  0% → 100%
        Slider {
            id: intensitySlider
            from: 0.0
            to: 1.0
            stepSize: 0.01
            value: root.currentIntensity
            width: 200

            // Write back to SettingsData on every change (live preview)
            onValueChanged: {
                if (typeof SettingsData !== "undefined") {
                    SettingsData.dockCavaIntensity = value
                }
            }

            background: Rectangle {
                x: intensitySlider.leftPadding
                y: intensitySlider.topPadding + intensitySlider.availableHeight / 2 - height / 2
                width: intensitySlider.availableWidth
                height: 4
                radius: 2
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.2)

                Rectangle {
                    width: intensitySlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.primary
                }
            }

            handle: Rectangle {
                x: intensitySlider.leftPadding + intensitySlider.visualPosition * (intensitySlider.availableWidth - width)
                y: intensitySlider.topPadding + intensitySlider.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: Theme.primary
                border.color: Theme.surface
                border.width: 2

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                scale: intensitySlider.pressed ? 1.2 : 1.0
            }
        }

        // Percentage readout
        Text {
            text: Math.round(intensitySlider.value * 100) + "%"
            color: Theme.onSurfaceVariant
            font.pixelSize: 12
            width: 44
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }

        // Reset button — snaps back to default 100%
        Rectangle {
            width: 28
            height: 28
            radius: 6
            color: resetHover.containsMouse
                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                   : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: "↺"
                font.pixelSize: 16
                color: Theme.onSurfaceVariant
            }

            MouseArea {
                id: resetHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    intensitySlider.value = 1.0
                }
            }
        }
    }
}
