import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: bordersShadowsTab

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
            // BORDERS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: bordersSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: bordersSection

                    property bool advancedMode: SettingsData.borderAdvancedControls
                    property real combinedBorderLevel: {
                        const values = [
                            SettingsData.controlCenterBorderOpacity,
                            SettingsData.settingsBorderOpacity,
                            SettingsData.weatherPopupBorderOpacity,
                            SettingsData.controlCenterBorderThickness / 10,
                            SettingsData.settingsBorderThickness / 10,
                            SettingsData.weatherPopupBorderThickness / 10
                        ]
                        var sum = 0
                        for (var i = 0; i < values.length; ++i) sum += values[i]
                        return values.length ? sum / values.length : 0
                    }

                    function setCombinedBorderLevel(level) {
                        const clamped = Math.max(0, Math.min(1, level))
                        const thickness = Math.round(clamped * 10)
                        SettingsData.setControlCenterBorderOpacity(clamped)
                        SettingsData.setSettingsBorderOpacity(clamped)
                        SettingsData.setWeatherPopupBorderOpacity(clamped)
                        SettingsData.setControlCenterBorderThickness(thickness)
                        SettingsData.setSettingsBorderThickness(thickness)
                        SettingsData.setWeatherPopupBorderThickness(thickness)
                    }

                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "border_style"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Borders"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Customize border styles for UI components"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Advanced Controls"
                        description: "Configure each panel's border opacity and thickness individually"
                        checked: bordersSection.advancedMode
                        onToggled: checked => { bordersSection.advancedMode = checked; SettingsData.borderAdvancedControls = checked; SettingsData.saveSettings() }
                    }

                    // Simple mode
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        visible: !bordersSection.advancedMode
                        StyledText { text: "Border Intensity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(bordersSection.combinedBorderLevel * 100)
                            minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => bordersSection.setCombinedBorderLevel(newValue / 100)
                        }
                    }

                    // Advanced mode
                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: bordersSection.advancedMode

                        // Control Center Border
                        EHToggle {
                            width: parent.width
                            text: "Enable Control Center Border"
                            description: "Show a border around the control center"
                            checked: SettingsData.controlCenterBorderEnabled
                            onToggled: checked => SettingsData.setControlCenterBorderEnabled(checked)
                        }

                        EHToggle {
                            width: parent.width
                            text: "Control Center Dynamic Border Colors"
                            description: "Use matugen colors for the control center border"
                            checked: SettingsData.controlCenterDynamicBorderColors
                            onToggled: checked => SettingsData.setControlCenterDynamicBorderColors(checked)
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Control Center Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.controlCenterBorderOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setControlCenterBorderOpacity(newValue / 100) }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Control Center Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.controlCenterBorderThickness; minimum: 0; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setControlCenterBorderThickness(newValue) }
                        }

                        // Weather Popup Border
                        EHToggle {
                            width: parent.width
                            text: "Enable Weather Popup Border"
                            description: "Show a border around the weather popup"
                            checked: SettingsData.weatherPopupBorderEnabled
                            onToggled: checked => SettingsData.setWeatherPopupBorderEnabled(checked)
                        }

                        EHToggle {
                            width: parent.width
                            text: "Weather Popup Dynamic Border Colors"
                            description: "Use matugen colors for the weather popup border"
                            checked: SettingsData.weatherPopupDynamicBorderColors
                            onToggled: checked => SettingsData.setWeatherPopupDynamicBorderColors(checked)
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Weather Popup Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.weatherPopupBorderOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setWeatherPopupBorderOpacity(newValue / 100) }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Weather Popup Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.weatherPopupBorderThickness; minimum: 0; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setWeatherPopupBorderThickness(newValue) }
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Settings Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.settingsBorderOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setSettingsBorderOpacity(newValue / 100) }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Settings Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.settingsBorderThickness; minimum: 0; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setSettingsBorderThickness(newValue) }
                        }
                    }
                }
            }
        }
    }
}
