import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: darkDashTab

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
            // DARK DASH
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: darkDashSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: darkDashSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "dashboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Dark Dash"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Opacity and visual effects for the Dark Dash popout"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.darkDashTransparency * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashTransparency(newValue / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.darkDashBorderOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashBorderOpacity(newValue / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.darkDashBorderThickness; minimum: 0; maximum: 10; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashBorderThickness(newValue) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Tab Bar Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.darkDashTabBarOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashTabBarOpacity(newValue / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Content Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.darkDashContentBackgroundOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashContentBackgroundOpacity(newValue / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Animated Tint Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.darkDashAnimatedTintOpacity * 100); minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => SettingsData.setDarkDashAnimatedTintOpacity(newValue / 100) }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Tint Animation"
                        description: "Animate the color tint effect on Dark Dash"
                        checked: SettingsData.darkDashTintAnimateEnabled
                        onToggled: checked => SettingsData.setDarkDashTintAnimateEnabled(checked)
                    }
                }
            }
        }
    }
}
