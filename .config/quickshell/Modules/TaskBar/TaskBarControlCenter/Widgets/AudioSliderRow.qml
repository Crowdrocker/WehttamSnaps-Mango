import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    property var defaultSink: AudioService.sink
    property color sliderTrackColor: "transparent"

    height: 48
    spacing: Theme.spacingS

    Rectangle {
        width: Theme.iconSize + Theme.spacingM * 2
        height: Theme.iconSize + Theme.spacingM * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingM * 2) / 2
        color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"


        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration }
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            visible: defaultSink !== null && defaultSink.audio !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (defaultSink && defaultSink.audio) {
                    defaultSink.audio.muted = !defaultSink.audio.muted
                }
            }
        }

        EHIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSink || !defaultSink.audio) return "volume_off"

                let volume = defaultSink.audio.volume
                let muted = defaultSink.audio.muted

                if (muted || volume === 0.0) return "volume_off"
                if (volume <= 0.33) return "volume_down"
                return "volume_up"
            }
            size: Theme.iconSize
            color: defaultSink && defaultSink.audio && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
        }
    }

    EHSlider {
        id: volumeSlider
        readonly property real actualVolumePercent: defaultSink && defaultSink.audio ? Math.round(defaultSink.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingM * 2) - root.spacing
        enabled: defaultSink !== null && defaultSink.audio !== null
        minimum: 0
        maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
        showValue: true
        unit: "%"
        valueOverride: Math.min(maximum, actualVolumePercent)
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: {
            if (root.sliderTrackColor.a > 0) {
                return root.sliderTrackColor
            }
            const alpha = Theme.getContentBackgroundAlpha() * 0.60
            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
        }
        
        onSliderValueChanged: function(newValue) {
            if (defaultSink && defaultSink.audio) {
                SessionData.suppressOSDTemporarily()
                defaultSink.audio.volume = newValue / 100.0
                if (newValue > 0 && defaultSink.audio.muted) {
                    defaultSink.audio.muted = false
                }
                // volumeChanged signal is automatically emitted when volume property changes
            }
        }
    }

    Binding {
        target: volumeSlider
        property: "value"
        value: defaultSink && defaultSink.audio ? Math.min(volumeSlider.maximum, Math.round(defaultSink.audio.volume * 100)) : 0
        when: !volumeSlider.isDragging
    }
}
