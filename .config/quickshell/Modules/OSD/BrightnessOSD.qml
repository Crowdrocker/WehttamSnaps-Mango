import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    // Matches VolumeOSD / InputOSD sizing exactly
    osdWidth:  Math.min(300, Screen.width - Theme.spacingL * 2)
    osdHeight: Theme.spacingM * 2 + Theme.iconSize
    autoHideInterval:     3000
    enableMouseInteraction: true

    // ── Debounce for DDC displays ─────────────────────────────────────────────

    property var brightnessDebounceTimer: Timer {
        property int pendingValue: 0
        interval: {
            const d = DisplayService.getCurrentDeviceInfo()
            return (d && d.class === "ddc") ? 200 : 50
        }
        repeat: false
        onTriggered: DisplayService.setBrightnessInternal(pendingValue, DisplayService.lastIpcDevice)
    }

    property var _brightnessSlider: null

    Connections {
        target: DisplayService
        function onBrightnessChanged() { root.show() }
    }

    // ── Content ───────────────────────────────────────────────────────────────

    content: Item {
        anchors.fill: parent

        Row {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS
            height:  Theme.iconSize

            // Brightness icon — reflects device type, no mouse interaction needed
            EHIcon {
                anchors.verticalCenter: parent.verticalCenter
                size:  Theme.iconSize - 2
                color: Theme.primary
                name: {
                    const d = DisplayService.getCurrentDeviceInfo()
                    if (!d || d.class === "backlight" || d.class === "ddc") return "brightness_medium"
                    if (d.name?.includes("kbd"))  return "keyboard"
                    return "lightbulb"
                }
            }

            EHSlider {
                id:     brightnessSlider
                width:  parent.width - Theme.iconSize - Theme.spacingS
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter

                minimum: 1
                maximum: 100
                enabled: DisplayService.brightnessAvailable
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer

                Component.onCompleted: {
                    root._brightnessSlider = brightnessSlider
                    if (DisplayService.brightnessAvailable)
                        value = DisplayService.brightnessLevel
                }

                Connections {
                    target: DisplayService
                    function onBrightnessChanged() {
                        if (!brightnessSlider.pressed)
                            brightnessSlider.value = DisplayService.brightnessLevel
                    }
                    function onDeviceSwitched() {
                        if (!brightnessSlider.pressed)
                            brightnessSlider.value = DisplayService.brightnessLevel
                    }
                }

                onSliderValueChanged: newValue => {
                    if (DisplayService.brightnessAvailable) {
                        root.brightnessDebounceTimer.pendingValue = newValue
                        root.brightnessDebounceTimer.restart()
                        root.hideTimer.restart()
                    }
                }

                onSliderDragFinished: finalValue => {
                    if (DisplayService.brightnessAvailable) {
                        root.brightnessDebounceTimer.stop()
                        DisplayService.setBrightnessInternal(finalValue, DisplayService.lastIpcDevice)
                    }
                }

                onContainsMouseChanged: setChildHovered(containsMouse)

            }
        }
    }

    onOsdShown: {
        if (DisplayService.brightnessAvailable)
            root._brightnessSlider && (root._brightnessSlider.value = DisplayService.brightnessLevel)
    }
}
