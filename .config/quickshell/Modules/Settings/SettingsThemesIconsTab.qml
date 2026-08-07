import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: settingsThemesIconsTab

    property var parentModal: null

    // Run detection once on component load
    Component.onCompleted: {
        SettingsData.detectAvailableIconThemes()
        SettingsData.detectAvailableGtkThemes()
        SettingsData.detectAvailableShellThemes()
        SettingsData.detectAvailableQtThemes()
        SettingsData.detectAvailableCursorThemes()
    }

    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingM

            StyledRect {
                width: parent.width
                height: contentColumn.childrenRect.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: contentColumn
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    y: Theme.spacingM
                    spacing: Theme.spacingM

                    // Compact warning
                    Rectangle {
                width: parent.width
                height: warningText.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    EHIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: warningText
                        font.pixelSize: Theme.fontSizeSmall
                        text: "These settings modify GTK and Qt configurations. Back up qt5ct.conf|qt6ct.conf and ~/.config/gtk-3.0|gtk-4.0 if needed."
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Icon Theme
            EHDropdown {
                width: parent.width
                text: "Icon Theme"
                description: "DarkShell & System Icons (requires restart)"
                currentValue: SettingsData.iconTheme
                enableFuzzySearch: true
                popupWidthOffset: 100
                maxPopupHeight: 236
                options: SettingsData.availableIconThemes
                onValueChanged: value => {
                    if (value === SettingsData.iconTheme) return
                    SettingsData.setIconTheme(value)
                    SettingsData.detectAvailableIconThemes()
                    ToastService.showInfo("Icon theme changed", "Press “Apply icons” to restart Quickshell and apply.")
                    if (Quickshell.env("QT_QPA_PLATFORMTHEME") != "gtk3" &&
                        Quickshell.env("QT_QPA_PLATFORMTHEME") != "qt6ct" &&
                        Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") != "qt6ct") {
                        ToastService.showError("Missing Environment Variables", "You need to set either:\nQT_QPA_PLATFORMTHEME=gtk3 OR\nQT_QPA_PLATFORMTHEME=qt6ct\nas environment variables, and then restart the shell.\n\nqt6ct requires qt6ct-kde to be installed.")
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: 40
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    EHIcon { name: "check"; size: Theme.iconSizeSmall; color: Theme.primary }
                    StyledText {
                        text: "Apply icons (restarts Quickshell)"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsData.applyAndRestartQuickshell()
                }
            }

            // GTK Theme
            EHDropdown {
                width: parent.width
                text: "GTK Theme"
                description: "GTK3/GTK4 Applications (requires restart)"
                currentValue: SettingsData.gtkTheme
                enableFuzzySearch: true
                popupWidthOffset: 100
                maxPopupHeight: 236
                options: SettingsData.availableGtkThemes
                onValueChanged: value => {
                    SettingsData.setGtkTheme(value)
                    SettingsData.detectAvailableGtkThemes()
                    ToastService.showInfo("GTK theme changed", "Restart GTK applications to see changes")
                }
            }

            // GNOME Shell Theme
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                EHDropdown {
                    width: parent.width
                    text: "GNOME Shell Theme"
                    description: SettingsData.userThemeExtensionAvailable && SettingsData.userThemeExtensionEnabled
                                ? "Shell Interface Theme (requires shell restart)"
                                : SettingsData.userThemeExtensionAvailable
                                ? "Shell Interface Theme (extension not enabled)"
                                : "Shell Interface Theme (CSS fallback, no extension)"
                    currentValue: SettingsData.shellTheme
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 236
                    options: SettingsData.availableShellThemes
                    onValueChanged: value => {
                        SettingsData.setShellTheme(value)
                        SettingsData.detectAvailableShellThemes()
                        if (SettingsData.userThemeExtensionAvailable && SettingsData.userThemeExtensionEnabled) {
                            ToastService.showInfo("Shell theme changed", "Restart GNOME Shell to see changes:\nPress Alt+F2, type 'r', then press Enter")
                        } else {
                            ToastService.showInfo("Shell theme changed (CSS only)", "Applied theme CSS without extension.\nNote: Only CSS is applied, not full theme assets.\nRestart GNOME Shell (Alt+F2, type 'r', Enter) to see changes.")
                        }
                    }
                }

                StyledText {
                    visible: !SettingsData.userThemeExtensionAvailable
                    text: "Note: Using CSS fallback. Only CSS styling is applied, not full theme assets. Install the user-theme extension for full theme support."
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.warning || "#ff9800"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                StyledText {
                    visible: SettingsData.userThemeExtensionAvailable && !SettingsData.userThemeExtensionEnabled
                    text: "Note: Extension is installed but not enabled. Enable it in GNOME Tweaks or Extensions app for full theme support."
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.warning || "#ff9800"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // QT Theme
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                EHDropdown {
                    width: parent.width
                    text: "QT Theme"
                    description: SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable
                                ? "QT5/QT6 Applications (requires restart)"
                                : "QT5/QT6 Applications (qt5ct/qt6ct not found)"
                    currentValue: SettingsData.qtTheme
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 236
                    options: SettingsData.availableQtThemes
                    onValueChanged: value => {
                        SettingsData.setQtTheme(value)
                        SettingsData.detectAvailableQtThemes()
                        if (SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable) {
                            ToastService.showInfo("QT theme changed", "Restart QT applications to see changes")
                        }
                    }
                }

                StyledText {
                    visible: !SettingsData.qt5ctAvailable && !SettingsData.qt6ctAvailable
                    text: "Note: Install qt5ct or qt6ct for QT theme support. Without these tools, theme changes will not be applied."
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.warning || "#ff9800"
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // Cursor Theme & Size
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                EHDropdown {
                    width: parent.width
                    text: "Cursor Theme"
                    description: "Mouse Cursor Appearance"
                    currentValue: SettingsData.cursorTheme
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 236
                    options: SettingsData.availableCursorThemes
                    onValueChanged: value => {
                        SettingsData.setCursorTheme(value, SettingsData.cursorSize)
                        SettingsData.detectAvailableCursorThemes()
                        ToastService.showInfo("Cursor theme changed", "Cursor theme updated. You may need to log out and back in for full effect.")
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    topPadding: Theme.spacingXS

                    StyledText {
                        text: "Cursor Size:"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    EHSlider {
                        width: parent.width - cursorSizeLabel.width - Theme.spacingS
                        height: 24
                        value: SettingsData.cursorSize
                        minimum: 16
                        maximum: 48
                        unit: "px"
                        showValue: true
                        wheelEnabled: false
                        anchors.verticalCenter: parent.verticalCenter
                        onSliderValueChanged: newValue => {
                            SettingsData.setCursorTheme(SettingsData.cursorTheme, newValue)
                            SettingsData.detectAvailableCursorThemes()
                            ToastService.showInfo("Cursor size changed", "Cursor size updated to " + newValue + "px")
                        }
                    }

                    StyledText {
                        id: cursorSizeLabel
                        text: SettingsData.cursorSize + "px"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
                }
            }
        }
    }
}
