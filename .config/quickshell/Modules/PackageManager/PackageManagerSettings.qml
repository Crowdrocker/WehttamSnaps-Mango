import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: pkgSettingsModal

    objectName: "packageManagerSettingsModal"
    title: "Package Manager Settings"
    minimumSize: Qt.size(420, 320)
    implicitWidth: 460
    implicitHeight: 370
    backgroundColor: Theme.surfaceContainer
    visible: false

    function open() {
        pkgSettingsModal.show()
    }

    function close() {
        pkgSettingsModal.hide()
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: pkgSettingsModal.close()

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL

            // ── Title ────────────────────────────────────────────────
            Row {
                spacing: Theme.spacingM

                EHIcon {
                    name: "settings"
                    size: 28
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Settings"
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.outlineMedium }

            // ── Terminal Emulator ────────────────────────────────────
            Column {
                width: parent.width
                spacing: Theme.spacingS

                // Label row + detection badge
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Terminal Emulator"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    // "N detected" badge — matches the AUR/pkg badges below
                    Rectangle {
                        visible: PackageManagerService.availableTerminals.length > 0
                        height: 22
                        width: detectedLabel.implicitWidth + Theme.spacingM * 2
                        radius: height / 2
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                        border.width: 1

                        StyledText {
                            id: detectedLabel
                            text: PackageManagerService.availableTerminals.length + " detected"
                            font.pixelSize: Theme.fontSizeXS
                            font.weight: Font.Bold
                            color: Theme.primary
                            anchors.centerIn: parent
                        }
                    }

                    // Scanning badge shown while detection hasn't finished
                    Rectangle {
                        visible: PackageManagerService.availableTerminals.length === 0
                        height: 22
                        width: scanLabel.implicitWidth + Theme.spacingM * 2
                        radius: height / 2
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
                        border.width: 1

                        StyledText {
                            id: scanLabel
                            text: "Scanning…"
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }
                    }
                }

                StyledText {
                    text: "Terminal used for interactive package operations (install, remove, upgrade)."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                // Native EHDropdown — matches every other dropdown in the UI
                EHDropdown {
                    width: parent.width
                    height: 44
                    text: ""
                    options: PackageManagerService.availableTerminals
                    currentValue: PackageManagerService.preferredTerminal
                    enabled: PackageManagerService.availableTerminals.length > 0
                    onValueChanged: value => {
                        PackageManagerService.preferredTerminal = value
                        // Also persist to SettingsData so it survives restarts
                        SettingsData.terminalEmulator = value
                        SettingsData.saveSettings()
                        console.log("[PKGSettings] Terminal set to:", value)
                    }
                }

                StyledText {
                    visible: PackageManagerService.availableTerminals.length === 0
                    text: "No terminals detected yet. Detection runs automatically at startup."
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.outlineMedium }

            // ── Current Package Manager Info ─────────────────────────
            Column {
                spacing: Theme.spacingS

                StyledText {
                    text: "Current Package Manager"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Row {
                    spacing: Theme.spacingM

                    Rectangle {
                        height: 24
                        width: pkgLabel.implicitWidth + Theme.spacingM * 2
                        radius: 12
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                        border.width: 1

                        StyledText {
                            id: pkgLabel
                            text: PackageManagerService.pkgManager.toUpperCase()
                            font.pixelSize: Theme.fontSizeXS
                            font.weight: Font.Bold
                            color: Theme.primary
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        visible: PackageManagerService.aurEnabled
                        height: 24
                        width: aurLabel.implicitWidth + Theme.spacingM * 2
                        radius: 12
                        color: Qt.rgba(0.686, 0.890, 0.294, 0.15)
                        border.color: Qt.rgba(0.686, 0.890, 0.294, 0.40)
                        border.width: 1

                        StyledText {
                            id: aurLabel
                            text: "AUR: " + PackageManagerService.aurHelper
                            font.pixelSize: Theme.fontSizeXS
                            font.weight: Font.Bold
                            color: "#a9e34b"
                            anchors.centerIn: parent
                        }
                    }
                }

                StyledText {
                    visible: PackageManagerService.flatpakAvailable
                    text: "Flatpak: Available"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            Item { height: 1 }

            // ── Close button ─────────────────────────────────────────
            Rectangle {
                width: 100
                height: 34
                radius: 8
                color: Theme.primary
                anchors.right: parent.right

                StyledText {
                    text: "Done"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.onPrimary
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pkgSettingsModal.close()
                }
            }
        }
    }

    FloatingWindowControls {
        targetWindow: pkgSettingsModal
    }
}
