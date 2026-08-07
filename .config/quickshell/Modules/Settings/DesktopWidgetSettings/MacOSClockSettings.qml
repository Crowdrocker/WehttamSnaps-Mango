import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null

    readonly property var cfg: instanceData?.config ?? {}

    function updateConfig(key, value) {
        if (!instanceId)
            return
        var updates = {}
        updates[key] = value
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates)
    }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    Column {
        width: parent.width
        spacing: Theme.spacingS
        StyledText {
            text: "Location code"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            text: "Three letters above the time (e.g. CUP). Leave empty to use weather city or timezone."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }
        EHTextField {
            id: locField
            width: parent.width
            placeholderText: "Auto"
            text: cfg.locationCode !== undefined && cfg.locationCode !== null ? cfg.locationCode : ""
            maximumLength: 8
            onEditingFinished: {
                const u = text.trim().toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3)
                root.updateConfig("locationCode", u)
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        StyledText {
            text: "Background opacity"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        EHSlider {
            id: opacitySlider
            width: parent.width
            height: 24
            value: Math.round((cfg.transparency ?? 0.88) * 100)
            minimum: 0
            maximum: 100
            unit: "%"
            showValue: true
            wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            property real pendingValue: value
            Timer {
                id: updateTimer
                interval: 50
                onTriggered: root.updateConfig("transparency", opacitySlider.pendingValue / 100)
            }
            onSliderValueChanged: newValue => {
                pendingValue = newValue
                updateTimer.restart()
            }
            onSliderDragFinished: finalValue => {
                updateTimer.stop()
                root.updateConfig("transparency", finalValue / 100)
            }
        }
    }

    EHToggle {
        width: parent.width
        text: "Use wallpaper accent"
        description: "Tint the time and tick progress with the wallpaper primary color"
        checked: cfg.wallpaperColors ?? false
        onToggled: checked => root.updateConfig("wallpaperColors", checked)
    }
}
