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

    property var defaultSource: AudioService.source
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
            visible: defaultSource !== null && defaultSource.audio !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (defaultSource && defaultSource.audio) {
                    defaultSource.audio.muted = !defaultSource.audio.muted
                }
            }
        }

        EHIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSource || !defaultSource.audio) return "mic_off"

                let muted = defaultSource.audio.muted
                return muted ? "mic_off" : "mic"
            }
            size: Theme.iconSize
            color: defaultSource && defaultSource.audio && !defaultSource.audio.muted ? Theme.primary : Theme.surfaceText
        }
    }

    EHSlider {
        id: micSlider
        readonly property real actualVolumePercent: defaultSource && defaultSource.audio ? Math.round(defaultSource.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingM * 2) - root.spacing
        enabled: defaultSource !== null && defaultSource.audio !== null
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
            if (defaultSource && defaultSource.audio) {
                SessionData.suppressOSDTemporarily()
                defaultSource.audio.volume = newValue / 100.0
                if (newValue > 0 && defaultSource.audio.muted) {
                    defaultSource.audio.muted = false
                }
            }
        }
    }

    Binding {
        target: micSlider
        property: "value"
        value: defaultSource && defaultSource.audio ? Math.min(micSlider.maximum, Math.round(defaultSource.audio.volume * 100)) : 0
        when: !micSlider.isDragging
    }
}
