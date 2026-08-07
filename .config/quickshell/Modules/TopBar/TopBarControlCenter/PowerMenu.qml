import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets

PanelWindow {
    id: root

    property bool powerMenuVisible: false
    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    visible: powerMenuVisible
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.powerMenuVisible = false
    }

    // ── Menu Card ───────────────────────────────────────────────────────────
    Rectangle {
        id: menuCard

        // Position: top-right, just below the bar
        width: 300
        height: menuCol.implicitHeight + Theme.spacingXL * 2
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: (SettingsData.topBarHeight * (SettingsData.topbarScale || 1)) + Theme.spacingS

        radius: Theme.cornerRadius + 2
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
        border.width: 1

        opacity: root.powerMenuVisible ? 1 : 0
        scale:  root.powerMenuVisible ? 1 : 0.92
        transformOrigin: Item.TopRight

        // Eat clicks so background MouseArea doesn't fire
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: menuCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Theme.spacingXL
                leftMargin: Theme.spacingL
                rightMargin: Theme.spacingL
            }
            spacing: Theme.spacingS

            // ── Header ──────────────────────────────────────────────────
            RowLayout {
                width: parent.width

                StyledText {
                    text: "Power"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.SemiBold
                    color: Theme.surfaceText
                    Layout.fillWidth: true
                }

                // Close button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeArea.containsMouse
                           ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                           : "transparent"

                    EHIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerMenuVisible = false
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                }
            }

            // ── Thin divider ─────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                Layout.topMargin: Theme.spacingS
            }

            Item { width: 1; height: Theme.spacingXS }

            // ── Power Buttons ─────────────────────────────────────────────
            // Each button: icon + label + subtle accent on hover

            component PowerButton : Rectangle {
                id: btn
                property string iconName: ""
                property string label: ""
                property color accentColor: Theme.primary
                property bool isDanger: false

                signal activated

                width: parent.width
                height: 52
                radius: Theme.cornerRadius
                color: {
                    if (btnArea.containsMouse) {
                        return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
                    }
                    return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                }
                border.width: btnArea.containsMouse ? 1 : 0
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.spacingL
                        rightMargin: Theme.spacingL
                    }
                    spacing: Theme.spacingM

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: btnArea.containsMouse
                               ? Qt.rgba(btn.accentColor.r, btn.accentColor.g, btn.accentColor.b, 0.18)
                               : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)

                        EHIcon {
                            anchors.centerIn: parent
                            name: btn.iconName
                            size: 18
                            color: btnArea.containsMouse ? btn.accentColor : Theme.surfaceText
                        }

                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                    }

                    StyledText {
                        text: btn.label
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: btnArea.containsMouse ? btn.accentColor : Theme.surfaceText
                        Layout.fillWidth: true

                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                    }

                    EHIcon {
                        name: "chevron_right"
                        size: 16
                        color: btnArea.containsMouse
                               ? Qt.rgba(btn.accentColor.r, btn.accentColor.g, btn.accentColor.b, 0.7)
                               : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.4)

                        Behavior on color {
                            ColorAnimation { duration: Theme.shortDuration }
                        }
                    }
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btn.activated()
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.shortDuration }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Theme.shortDuration }
                }
            }

            // Lock
            PowerButton {
                iconName: "lock"
                label: "Lock Screen"
                accentColor: Theme.primary
                onActivated: {
                    root.powerMenuVisible = false
                    root.lockRequested()
                }
            }

            // Logout
            PowerButton {
                iconName: "logout"
                label: "Log Out"
                accentColor: Theme.primary
                onActivated: {
                    root.powerMenuVisible = false
                    root.powerActionRequested("logout", "Log Out", "Are you sure you want to log out?")
                }
            }

            // Suspend
            PowerButton {
                iconName: "bedtime"
                label: "Suspend"
                accentColor: Theme.primary
                onActivated: {
                    root.powerMenuVisible = false
                    root.powerActionRequested("suspend", "Suspend", "Are you sure you want to suspend the system?")
                }
            }

            // Thin divider before danger actions
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
            }

            // Restart
            PowerButton {
                iconName: "restart_alt"
                label: "Restart"
                accentColor: Theme.warning
                onActivated: {
                    root.powerMenuVisible = false
                    root.powerActionRequested("reboot", "Restart", "Are you sure you want to restart the system?")
                }
            }

            // Shut Down
            PowerButton {
                iconName: "power_settings_new"
                label: "Shut Down"
                accentColor: Theme.error
                onActivated: {
                    root.powerMenuVisible = false
                    root.powerActionRequested("poweroff", "Shut Down", "Are you sure you want to shut down?")
                }
            }

            Item { width: 1; height: Theme.spacingXS }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
        }
    }
}
