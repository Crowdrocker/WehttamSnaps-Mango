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

    function getOpacityValue()            { return cfg.hasOwnProperty("opacity")             ? cfg.opacity             : SettingsData.desktopMediaPlayerOpacity }
    function getFontScaleValue()          { return cfg.hasOwnProperty("fontScale")            ? cfg.fontScale            : SettingsData.desktopMediaPlayerFontScale }
    function getButtonScaleValue()        { return cfg.hasOwnProperty("buttonScale")          ? cfg.buttonScale          : SettingsData.desktopMediaPlayerButtonScale }
    function getBoldFontValue()           { return cfg.hasOwnProperty("boldFont")             ? cfg.boldFont             : SettingsData.desktopMediaPlayerBoldFont }
    function getArtScaleValue()           { return cfg.hasOwnProperty("artScale")             ? cfg.artScale             : SettingsData.desktopMediaPlayerArtScale }
    function getVisualizerIntensityValue(){ return cfg.hasOwnProperty("visualizerIntensity")  ? cfg.visualizerIntensity  : SettingsData.desktopMediaPlayerVisualizerIntensity }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round(root.getOpacityValue() * 100)
            minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: newValue => {
                if (root.instanceId) root.updateConfig("opacity", newValue / 100)
                else SettingsData.setDesktopMediaPlayerOpacity(newValue)
            }
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Font Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round(root.getFontScaleValue() * 100)
            minimum: 50; maximum: 200; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: newValue => {
                if (root.instanceId) root.updateConfig("fontScale", newValue / 100)
                else SettingsData.setDesktopMediaPlayerFontScale(newValue)
            }
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Button Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round(root.getButtonScaleValue() * 100)
            minimum: 50; maximum: 200; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: newValue => {
                if (root.instanceId) root.updateConfig("buttonScale", newValue / 100)
                else SettingsData.setDesktopMediaPlayerButtonScale(newValue)
            }
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Album Art & Visualizer Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round(root.getArtScaleValue() * 100)
            minimum: 50; maximum: 200; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: newValue => {
                if (root.instanceId) root.updateConfig("artScale", newValue / 100)
                else SettingsData.setDesktopMediaPlayerArtScale(newValue)
            }
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Visualizer Intensity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round((root.getVisualizerIntensityValue() - 0.5) / 1.5 * 100)
            minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: newValue => {
                var intensity = 0.5 + (newValue / 100) * 1.5
                if (root.instanceId) root.updateConfig("visualizerIntensity", intensity)
                else SettingsData.setDesktopMediaPlayerVisualizerIntensity(intensity)
            }
        }
    }

    EHToggle {
        width: parent.width
        text: "Bold Font"
        description: "Use bold weight for track title and artist text"
        checked: root.getBoldFontValue()
        onToggled: checked => {
            if (root.instanceId) root.updateConfig("boldFont", checked)
            else SettingsData.setDesktopMediaPlayerBoldFont(checked)
        }
    }
}
