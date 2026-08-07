import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    property string deviceName: ""
    property bool   showingDeviceName: false
    property var    lastSink:   null
    property var    lastSource: null

    // Unified sizing — all slider OSDs share these dimensions
    osdWidth:  Math.min(300, Screen.width - Theme.spacingL * 2)
    osdHeight: showingDeviceName
        ? Theme.spacingM * 2 + Theme.iconSize + Theme.spacingXS + 16
        : Theme.spacingM * 2 + Theme.iconSize
    autoHideInterval:     3000
    enableMouseInteraction: true

    // ── Logic ─────────────────────────────────────────────────────────────────

    property var currentSink:   AudioService.sink
    property var currentSource: AudioService.source

    Connections {
        target: AudioService
        function onVolumeChanged() {
            root.showingDeviceName = false
            root.show()
        }
        function onSinkChanged() {
            if (AudioService.sink && AudioService.sink !== root.lastSink) {
                root.lastSink    = AudioService.sink
                root.deviceName  = AudioService.displayName(AudioService.sink)
                root.showingDeviceName = true
                root.show()
            }
        }
    }

    onCurrentSinkChanged: {
        if (currentSink && currentSink !== lastSink) {
            lastSink   = currentSink
            deviceName = AudioService.displayName(currentSink)
            showingDeviceName = true
            show()
        }
    }

    onOsdHidden: {
        showingDeviceName = false
        deviceName = ""
    }

    Component.onCompleted: {
        lastSink   = AudioService.sink
        lastSource = AudioService.source
    }

    // ── Content ───────────────────────────────────────────────────────────────

    content: Item {
        anchors.fill: parent

        // Device name — fades in above the slider row when switching devices
        StyledText {
            visible:  root.showingDeviceName && root.deviceName !== ""
            text:     root.deviceName
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: Theme.spacingXS; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
            height:   visible ? 16 : 0
            font.pixelSize: Theme.fontSizeSmall - 1
            color:    Theme.surfaceVariantText
            elide:    Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
        }

        // Icon + slider row
        Row {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: root.showingDeviceName ? 8 : 0
                leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS
            height: Theme.iconSize

            // Mute button icon
            Rectangle {
                width:  Theme.iconSize; height: Theme.iconSize
                radius: Theme.iconSize / 2
                color:  muteArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                EHIcon {
                    anchors.centerIn: parent
                    name:  AudioService.muted ? "volume_off" : "volume_up"
                    size:  Theme.iconSize - 2
                    color: AudioService.muted ? Theme.error : Theme.primary
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        AudioService.suppressOutputOSD()
                        AudioService.setOutputMuted(!AudioService.muted)
                    }
                    onContainsMouseChanged: setChildHovered(containsMouse || volumeSlider.containsMouse)
                }
            }

            // Volume slider — fills remaining space
            EHSlider {
                id:     volumeSlider
                width:  parent.width - Theme.iconSize - Theme.spacingS
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter

                minimum: 0
                maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                enabled: !!AudioService.sink?.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: AudioService.sink?.audio
                    ? Math.min(SettingsData.audioVolumeOverdrive ? 150 : 100,
                               Math.round(AudioService.sink.audio.volume * 100))
                    : 0

                Binding {
                    target:   volumeSlider
                    property: "value"
                    value:    AudioService.sink?.audio
                        ? Math.min(SettingsData.audioVolumeOverdrive ? 150 : 100,
                                   Math.round(AudioService.sink.audio.volume * 100))
                        : 0
                    when: !volumeSlider.isDragging
                }

                onSliderValueChanged: newValue => {
                    if (AudioService.sink?.audio) {
                        AudioService.suppressOutputOSD()
                        AudioService.setVolume(newValue / 100)
                        root.hideTimer.restart()
                    }
                }

                onContainsMouseChanged: setChildHovered(containsMouse || muteArea.containsMouse)
            }
        }
    }
}
