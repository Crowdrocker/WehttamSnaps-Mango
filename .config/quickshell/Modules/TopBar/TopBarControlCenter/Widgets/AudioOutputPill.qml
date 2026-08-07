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

    readonly property bool isMuted: !defaultSink || defaultSink.audio.muted
    readonly property real vol:     defaultSink?.audio ? defaultSink.audio.volume : 0

    // ── Card shell ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Theme.surfaceContainer.r,
                       Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, 0.92)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        border.width: 1

        // Scroll-to-change-volume anywhere on card
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: ev => {
                if (!root.defaultSink) return
                var v = root.defaultSink.audio.volume * 100
                v = ev.angleDelta.y > 0 ? Math.min(100, v + 5) : Math.max(0, v - 5)
                root.defaultSink.audio.muted  = false
                root.defaultSink.audio.volume = v / 100
                AudioService.volumeChanged()
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Header row ────────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 10

                // Circular mute toggle button
                Rectangle {
                    id: iconCircle
                    width: 36; height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isMuted ? Qt.rgba(Theme.surfaceVariant.r,
                                                  Theme.surfaceVariant.g,
                                                  Theme.surfaceVariant.b, 1)
                                        : Theme.primary
                    Behavior on color { ColorAnimation { duration: 160 } }

                    EHIcon {
                        anchors.centerIn: parent
                        name: root.isMuted ? "volume_off"
                             : root.vol < 0.34 ? "volume_down" : "volume_up"
                        size: 18
                        color: root.isMuted
                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            : "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.defaultSink)
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                        }
                    }
                }

                // Label column
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - iconCircle.width - pctLabel.implicitWidth - 20
                    spacing: 1

                    StyledText {
                        text: "Sound"
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Bold
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                    }

                    StyledText {
                        property string raw: root.defaultSink
                            ? (root.defaultSink.description || "Audio Output") : "No device"
                        text: raw.replace(" Analog Stereo", "")
                                 .replace(" Digital Stereo (IEC958)", "")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                // Volume readout
                StyledText {
                    id: pctLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isMuted ? "Muted" : Math.round(root.vol * 100) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                }
            }

            // ── Slider ────────────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 26

                Rectangle {
                    id: trackBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.1)

                    // Filled fill
                    Rectangle {
                        width: root.isMuted ? 0
                            : Math.max(trackBg.radius * 2, trackBg.width * root.vol)
                        height: parent.height
                        radius: parent.radius
                        color: root.isMuted
                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.15)
                            : Theme.primary
                        Behavior on width { NumberAnimation { duration: 60 } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }

                // Thumb knob
                Rectangle {
                    x: Math.max(0, Math.min(trackBg.width - width,
                           trackBg.width * root.vol - width / 2))
                    Behavior on x { NumberAnimation { duration: 60 } }
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11
                    color: "white"
                    border.color: Qt.rgba(0, 0, 0, 0.12)
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    onPressed:  setVol(mouseX)
                    onPositionChanged: if (pressed) setVol(mouseX)
                    function setVol(mx) {
                        if (!root.defaultSink) return
                        root.defaultSink.audio.muted  = false
                        root.defaultSink.audio.volume = Math.max(0, Math.min(1, mx / trackBg.width))
                        AudioService.volumeChanged()
                    }
                }
            }
        }
    }
}
