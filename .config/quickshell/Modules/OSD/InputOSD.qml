import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    property string deviceName: ""
    property bool   showingDeviceName: false
    property var    lastSource: null

    // Matches VolumeOSD sizing exactly
    osdWidth:  Math.min(300, Screen.width - Theme.spacingL * 2)
    osdHeight: showingDeviceName
        ? Theme.spacingM * 2 + Theme.iconSize + Theme.spacingXS + 16
        : Theme.spacingM * 2 + Theme.iconSize
    autoHideInterval:     3000
    enableMouseInteraction: true

    // ── Logic ─────────────────────────────────────────────────────────────────

    property var  currentSource:      AudioService.source
    property real currentInputVolume: AudioService.inputVolume

    Connections {
        target: AudioService
        function onInputMutedChanged() { root.updateDeviceName(); root.show() }
        function onSourceChanged() {
            if (AudioService.source && AudioService.source !== root.lastSource) {
                root.lastSource = AudioService.source
                root.updateDeviceName()
                root.show()
            }
        }
    }

    onCurrentInputVolumeChanged: { updateDeviceName(); show() }

    onCurrentSourceChanged: {
        if (currentSource && currentSource !== lastSource) {
            lastSource = currentSource
            updateDeviceName()
            show()
        }
    }

    function updateDeviceName() {
        if (AudioService.source) {
            deviceName = AudioService.displayName(AudioService.source)
            showingDeviceName = deviceName !== ""
        } else {
            deviceName = ""
            showingDeviceName = false
        }
    }

    onOsdHidden: { showingDeviceName = false; deviceName = "" }

    Component.onCompleted: {
        lastSource = AudioService.source
        updateDeviceName()
    }

    // ── Content ───────────────────────────────────────────────────────────────

    content: Item {
        anchors.fill: parent

        StyledText {
            visible: root.showingDeviceName && root.deviceName !== ""
            text:    root.deviceName
            anchors { top: parent.top; left: parent.left; right: parent.right
                      topMargin: Theme.spacingXS; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
            height:  visible ? 16 : 0
            font.pixelSize: Theme.fontSizeSmall - 1
            color:   Theme.surfaceVariantText
            elide:   Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: root.showingDeviceName ? 8 : 0
                leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS
            height:  Theme.iconSize

            // Mic mute button
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
                    name:  AudioService.inputMuted ? "mic_off" : "mic"
                    size:  Theme.iconSize - 2
                    color: AudioService.inputMuted ? Theme.error : Theme.primary
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: AudioService.setInputMuted(!AudioService.inputMuted)
                    onContainsMouseChanged: setChildHovered(containsMouse || volumeSlider.containsMouse)
                }
            }

            EHSlider {
                id:     volumeSlider
                width:  parent.width - Theme.iconSize - Theme.spacingS
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter

                minimum: 0
                maximum: 100
                enabled: !!AudioService.source?.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: AudioService.source?.audio
                    ? Math.round(AudioService.source.audio.volume * 100)
                    : 0

                Binding {
                    target:   volumeSlider
                    property: "value"
                    value:    AudioService.source?.audio
                        ? Math.round(AudioService.source.audio.volume * 100)
                        : 0
                    when: !volumeSlider.isDragging
                }

                onSliderValueChanged: newValue => {
                    if (AudioService.source?.audio) {
                        AudioService.suppressInputOSD()
                        AudioService.setInputVolume(newValue / 100)
                        root.hideTimer.restart()
                    }
                }

                onContainsMouseChanged: setChildHovered(containsMouse || muteArea.containsMouse)
            }
        }
    }
}
