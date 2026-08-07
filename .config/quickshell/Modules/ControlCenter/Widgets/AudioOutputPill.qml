import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var defaultSink: AudioService.sink

    readonly property bool isMuted: !defaultSink || (defaultSink && defaultSink.audio && defaultSink.audio.muted)
    readonly property real vol:     defaultSink && defaultSink.audio ? defaultSink.audio.volume : 0

    Rectangle {
        anchors.fill: parent
        radius: 12
        antialiasing: true
        color: {
            const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
        }
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
        border.width: 1

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                if (!root.defaultSink || !root.defaultSink.audio) return
                var v = root.defaultSink.audio.volume * 100
                v = ev.angleDelta.y > 0 ? Math.min(100, v + 5) : Math.max(0, v - 5)
                root.defaultSink.audio.muted  = false
                root.defaultSink.audio.volume = v / 100
                AudioService.volumeChanged()
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header row
            Row {
                width: parent.width
                spacing: 10

                // Semi-rounded mute button
                Rectangle {
                    id: iconTile
                    width: 36; height: 36
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isMuted
                        ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
                        : Theme.primary
                    border.color: root.isMuted
                        ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                        : Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)
                    border.width: 1
                    antialiasing: true
                    Behavior on color { ColorAnimation { duration: 150 } }

                    EHIcon {
                        anchors.centerIn: parent
                        name: root.isMuted ? "volume_off"
                             : root.vol < 0.34 ? "volume_down" : "volume_up"
                        size: 18
                        color: root.isMuted ? Theme.surfaceVariantText : Theme.primaryContainer
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.defaultSink && root.defaultSink.audio)
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - iconTile.width - pctLabel.implicitWidth - 20
                    spacing: 1

                    StyledText {
                        text: "Output"
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                    }

                    StyledText {
                        property string raw: root.defaultSink && root.defaultSink.description
                            ? root.defaultSink.description : "No device"
                        text: raw.replace(" Analog Stereo", "")
                                 .replace(" Digital Stereo (IEC958)", "")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                StyledText {
                    id: pctLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isMuted ? "Muted" : Math.round(root.vol * 100) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                }
            }

            // Slim slider track
            Item {
                width: parent.width
                height: 20

                Rectangle {
                    id: trackBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.10)

                    Rectangle {
                        width: root.isMuted ? 0
                            : Math.max(trackBg.radius * 2, trackBg.width * root.vol)
                        height: parent.height
                        radius: parent.radius
                        color: root.isMuted
                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12)
                            : Theme.primary
                        Behavior on width { NumberAnimation { duration: 60 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Thumb
                Rectangle {
                    x: Math.max(0, Math.min(trackBg.width - width,
                           trackBg.width * root.vol - width / 2))
                    Behavior on x { NumberAnimation { duration: 60 } }
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    antialiasing: true
                    color: "white"
                    border.color: Qt.rgba(0, 0, 0, 0.10)
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    onPressed:  setVol(mouseX)
                    onPositionChanged: if (pressed) setVol(mouseX)
                    function setVol(mx) {
                        if (!root.defaultSink || !root.defaultSink.audio) return
                        root.defaultSink.audio.muted  = false
                        root.defaultSink.audio.volume = Math.max(0, Math.min(1, mx / trackBg.width))
                        AudioService.volumeChanged()
                    }
                }
            }
        }
    }
}
