// Subset of shell settings for Event Horizon dash (full app: Settings modal).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    EHFlickable {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        anchors.topMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight + Theme.spacingM

        Column {
            id: col
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: "Quick settings"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: 600
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Common toggles; open the full app for everything else."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            StyledText {
                text: "Weather"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            StyledRect {
                width: parent.width
                height: weatherInner.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Math.min(1, 0.28 * SettingsData.desktopEventHorizonChromeBackgroundOpacity))
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                border.width: 1

                Column {
                    id: weatherInner
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        text: "Enable weather"
                        description: "Top bar, dash weather tab, and widgets"
                        checked: SettingsData.weatherEnabled
                        onToggled: c => SettingsData.setWeatherEnabled(c)
                    }
                    EHToggle {
                        width: parent.width
                        visible: SettingsData.weatherEnabled
                        text: "Fahrenheit"
                        description: "Temperature units"
                        checked: SettingsData.useFahrenheit
                        onToggled: c => SettingsData.setTemperatureUnit(c)
                    }
                }
            }

            StyledText {
                text: "Event Horizon"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            StyledRect {
                width: parent.width
                height: ehInner.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Math.min(1, 0.28 * SettingsData.desktopEventHorizonChromeBackgroundOpacity))
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                border.width: 1

                Column {
                    id: ehInner
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        text: "Tint animation"
                        description: "Animated surface tint on this dash"
                        checked: SettingsData.darkDashTintAnimateEnabled
                        onToggled: c => SettingsData.setDarkDashTintAnimateEnabled(c)
                    }
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXXS
                        StyledText {
                            text: "Shell transparency"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            width: parent.width
                            text: "Outer dash fill strength (alpha in the shell color only)."
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }
                        EHSlider {
                            width: parent.width
                            minimum: 35
                            maximum: 100
                            leftIcon: "opacity"
                            unit: "%"
                            value: Math.round(SettingsData.desktopEventHorizonTransparency * 100)
                            onSliderValueChanged: v => SettingsData.setDesktopEventHorizonTransparency(v / 100)
                            onSliderDragFinished: v => SettingsData.setDesktopEventHorizonTransparency(v / 100)
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXXS
                        StyledText {
                            text: "Panel & card backgrounds"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            width: parent.width
                            text: "Main rounded shell, tab strip, home tiles, and weather/calendar fills. Text and icons stay fully opaque."
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }
                        EHSlider {
                            width: parent.width
                            minimum: 0
                            maximum: 100
                            leftIcon: "layers"
                            unit: "%"
                            value: Math.round(SettingsData.desktopEventHorizonChromeBackgroundOpacity * 100)
                            onSliderValueChanged: v => SettingsData.setDesktopEventHorizonChromeBackgroundOpacity(v / 100)
                            onSliderDragFinished: v => SettingsData.setDesktopEventHorizonChromeBackgroundOpacity(v / 100)
                        }
                    }
                }
            }

            StyledText {
                text: "Appearance & time"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            StyledRect {
                width: parent.width
                height: lookInner.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Math.min(1, 0.28 * SettingsData.desktopEventHorizonChromeBackgroundOpacity))
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                border.width: 1

                Column {
                    id: lookInner
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        visible: typeof SessionData !== "undefined"
                        text: "Light mode"
                        description: "Session color scheme preference"
                        checked: typeof SessionData !== "undefined" && SessionData.isLightMode
                        onToggled: c => {
                            if (typeof SessionData !== "undefined")
                                SessionData.setLightMode(c)
                        }
                    }
                    EHToggle {
                        width: parent.width
                        text: "24-hour clock"
                        description: "System clock format"
                        checked: SettingsData.use24HourClock
                        onToggled: c => SettingsData.setClockFormat(c)
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: Math.max(44, openRow.implicitHeight + Theme.spacingM * 2)
                radius: Theme.cornerRadiusSmall
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Math.min(1, 0.12 * SettingsData.desktopEventHorizonChromeBackgroundOpacity))
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                RowLayout {
                    id: openRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "open_in_new"
                        size: 22
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: "Open full Settings"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: 600
                            color: Theme.primary
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: "Wallpaper, displays, Hyprland, and all other categories"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ModalManager.openSettingsRequested()
                }
            }
        }
    }
}
