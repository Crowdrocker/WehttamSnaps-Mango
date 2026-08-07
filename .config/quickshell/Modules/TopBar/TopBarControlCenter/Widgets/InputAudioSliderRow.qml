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

    // Icon / mute button
    Rectangle {
        width: Theme.iconSize + Theme.spacingM * 2
        height: Theme.iconSize + Theme.spacingM * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingM * 2) / 2
        color: iconArea.containsMouse
               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
               : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            visible: defaultSource !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (defaultSource?.audio) defaultSource.audio.muted = !defaultSource.audio.muted
            }
        }

        EHIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSource) return "mic_off"
                if (defaultSource?.audio && (defaultSource.audio.muted || defaultSource.audio.volume === 0.0)) return "mic_off"
                return "mic"
            }
            size: Theme.iconSize
            color: defaultSource?.audio && !defaultSource.audio.muted && defaultSource.audio.volume > 0
                   ? Theme.primary : Theme.surfaceVariantText
        }
    }

    // Slider — Binding guarded by isDragging to prevent value fighting
    EHSlider {
        id: volumeSlider

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingM * 2) - root.spacing
        enabled: defaultSource !== null
        minimum: 0
        maximum: 100
        showValue: true
        unit: "%"
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: {
            if (root.sliderTrackColor.a > 0) return root.sliderTrackColor
            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                           Theme.getContentBackgroundAlpha() * 0.6)
        }

        Binding {
            target: volumeSlider
            property: "value"
            value: defaultSource?.audio ? Math.min(100, Math.round(defaultSource.audio.volume * 100)) : 0
            when: !volumeSlider.isDragging
        }

        onSliderValueChanged: function(newValue) {
            if (defaultSource?.audio) {
                SessionData.suppressOSDTemporarily()
                defaultSource.audio.volume = newValue / 100.0
                if (newValue > 0 && defaultSource.audio.muted)
                    defaultSource.audio.muted = false
            }
        }
    }
}
