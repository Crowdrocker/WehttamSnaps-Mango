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
        if (!instanceId) return
        var updates = {}
        updates[key] = value
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates)
    }

    function getRotationValue() {
        if (cfg && cfg.hasOwnProperty("rotation")) return cfg.rotation
        return SettingsData.desktopCavaRotation
    }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    // ── Rotation ─────────────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM

        EHIcon { name: "rotate_right"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Rotation"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }

        Item { width: parent.width - parent.children[0].width - parent.children[1].width - rotationLabel.width - rotateBtn.width - Theme.spacingM * 4; height: 1 }

        EHActionButton {
            id: rotateBtn
            iconName: "rotate_right"; iconSize: Theme.iconSizeSmall
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                var newRotation = (root.getRotationValue() + 90) % 360
                if (root.instanceId) root.updateConfig("rotation", newRotation)
                else SettingsData.setDesktopCavaRotation(newRotation)
            }
        }

        StyledText {
            id: rotationLabel
            text: root.getRotationValue() + "°"
            font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Visualizer Intensity ──────────────────────────────────────────────
    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Visualizer Intensity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            id: intensitySlider
            width: parent.width; height: 24
            value: Math.round((cfg.visualizerIntensity ?? 1.0) * 100)
            minimum: 50; maximum: 200; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            property real pendingValue: value
            Timer { id: intensityTimer; interval: 50; onTriggered: root.updateConfig("visualizerIntensity", intensitySlider.pendingValue / 100) }
            onSliderValueChanged: newValue => { pendingValue = newValue; intensityTimer.restart() }
            onSliderDragFinished: finalValue => { intensityTimer.stop(); root.updateConfig("visualizerIntensity", finalValue / 100) }
        }
    }

    // ── Bar Count ─────────────────────────────────────────────────────────
    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Bar Count"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            id: barCountSlider
            width: parent.width; height: 24
            value: cfg.barCount ?? 40
            minimum: 10; maximum: 100; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            property real pendingValue: value
            Timer { id: barCountTimer; interval: 50; onTriggered: root.updateConfig("barCount", Math.round(barCountSlider.pendingValue)) }
            onSliderValueChanged: newValue => { pendingValue = newValue; barCountTimer.restart() }
            onSliderDragFinished: finalValue => { barCountTimer.stop(); root.updateConfig("barCount", Math.round(finalValue)) }
        }
    }

    // ── Toggles ───────────────────────────────────────────────────────────
    EHToggle {
        width: parent.width
        text: "Use Wallpaper Colors"
        description: "Tint bars using colors extracted from the current wallpaper"
        checked: cfg.wallpaperColors ?? false
        onToggled: checked => root.updateConfig("wallpaperColors", checked)
    }

    EHToggle {
        width: parent.width
        text: "Show Shadow"
        description: "Draw a drop shadow beneath the visualizer bars"
        checked: cfg.showShadow ?? true
        onToggled: checked => root.updateConfig("showShadow", checked)
    }
}
