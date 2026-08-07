import QtQuick
import QtQuick.Controls
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

    visible: powerMenuVisible
    screen: Quickshell.screens[1] ?? Quickshell.screens[0]
    implicitWidth: 400
    implicitHeight: 320
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            powerMenuVisible = false
        }
    }

    Rectangle {
        width: Math.min(320, parent.width - Theme.spacingL * 2)
        height: 320
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: (SettingsData.topBarHeight * SettingsData.topbarScale) + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                              Theme.outline.b, 0.08)
        border.width: 1
        opacity: powerMenuVisible ? 1 : 0
        scale: powerMenuVisible ? 1 : 0.85

        MouseArea {

            anchors.fill: parent
            onClicked: {

            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width

                StyledText {
                    text: "Power Options"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 150
                    height: 1
                }

                EHActionButton {
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: {
                        powerMenuVisible = false
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: logoutArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                              Theme.primary.g,
                                                              Theme.primary.b,
                                                              0.08) : Qt.rgba(
                                                          Theme.surfaceVariant.r,
                                                          Theme.surfaceVariant.g,
                                                          Theme.surfaceVariant.b,
                                                          0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(4, parent.height * 0.15)
                        height: parent.height * 0.6

                        EHIcon {
                            name: "logout"
                            size: Math.min(parent.height * 0.5, 24)
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: logoutArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerActionRequested(
                                        "logout", "Log Out",
                                        "Are you sure you want to log out?")
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: suspendArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                               Theme.primary.g,
                                                               Theme.primary.b,
                                                               0.08) : Qt.rgba(
                                                           Theme.surfaceVariant.r,
                                                           Theme.surfaceVariant.g,
                                                           Theme.surfaceVariant.b,
                                                           0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(4, parent.height * 0.15)
                        height: parent.height * 0.6

                        EHIcon {
                            name: "bedtime"
                            size: Math.min(parent.height * 0.5, 24)
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: suspendArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerActionRequested(
                                        "suspend", "Suspend",
                                        "Are you sure you want to suspend the system?")
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: rebootArea.containsMouse ? Qt.rgba(Theme.warning.r,
                                                              Theme.warning.g,
                                                              Theme.warning.b,
                                                              0.08) : Qt.rgba(
                                                          Theme.surfaceVariant.r,
                                                          Theme.surfaceVariant.g,
                                                          Theme.surfaceVariant.b,
                                                          0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(4, parent.height * 0.15)
                        height: parent.height * 0.6

                        EHIcon {
                            name: "restart_alt"
                            size: Math.min(parent.height * 0.5, 24)
                            color: rebootArea.containsMouse ? Theme.warning : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: rebootArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerActionRequested(
                                        "reboot", "Reboot",
                                        "Are you sure you want to reboot the system?")
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: powerOffArea.containsMouse ? Qt.rgba(Theme.error.r,
                                                                Theme.error.g,
                                                                Theme.error.b,
                                                                0.08) : Qt.rgba(
                                                            Theme.surfaceVariant.r,
                                                            Theme.surfaceVariant.g,
                                                            Theme.surfaceVariant.b,
                                                            0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(4, parent.height * 0.15)
                        height: parent.height * 0.6

                        EHIcon {
                            name: "power_settings_new"
                            size: Math.min(parent.height * 0.5, 24)
                            color: powerOffArea.containsMouse ? Theme.error : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: powerOffArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerActionRequested(
                                        "poweroff", "Power Off",
                                        "Are you sure you want to power off the system?")
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }
}
