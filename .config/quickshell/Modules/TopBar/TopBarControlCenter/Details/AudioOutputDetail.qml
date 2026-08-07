import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property bool hasVolumeSliderInCC: {
        const widgets = SettingsData.controlCenterWidgets || []
        return widgets.some(widget => widget.id === "volumeSlider")
    }

    implicitHeight: headerRow.height + (!hasVolumeSliderInCC ? volumeSlider.height : 0) + audioContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    
    
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40
        
        StyledText {
            id: headerText
            text: "Audio Devices"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
            layer.enabled: false
        }
    }

    Row {
        id: volumeSlider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingXS
        height: 35
        spacing: 0
        visible: !hasVolumeSliderInCC

        Rectangle {
            width: Theme.iconSize + Theme.spacingS * 2
            height: Theme.iconSize + Theme.spacingS * 2
            anchors.verticalCenter: parent.verticalCenter
            radius: (Theme.iconSize + Theme.spacingS * 2) / 2
            color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
            

            Behavior on color {
                ColorAnimation { duration: Theme.shortDuration }
            }

            MouseArea {
                id: iconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                    }
                }
            }

            EHIcon {
                anchors.centerIn: parent
                name: {
                    if (!AudioService.sink || !AudioService.sink.audio) return "volume_off"
                    let muted = AudioService.sink.audio.muted
                    let volume = AudioService.sink.audio.volume
                    if (muted || volume === 0.0) return "volume_off"
                    if (volume <= 0.33) return "volume_down"
                    if (volume <= 0.66) return "volume_up"
                    return "volume_up"
                }
                size: Theme.iconSize
                color: AudioService.sink && AudioService.sink.audio && !AudioService.sink.audio.muted && AudioService.sink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
            }
        }

        EHSlider {
            id: volumeSliderControl
            readonly property real actualVolumePercent: AudioService.sink && AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
            enabled: AudioService.sink && AudioService.sink.audio
            minimum: 0
            maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
            showValue: true
            unit: "%"
            valueOverride: actualVolumePercent
            thumbOutlineColor: Theme.surfaceVariant

            onSliderValueChanged: function(newValue) {
                if (AudioService.sink && AudioService.sink.audio) {
                    SessionData.suppressOSDTemporarily()
                    AudioService.sink.audio.volume = newValue / 100
                    if (newValue > 0 && AudioService.sink.audio.muted) {
                        AudioService.sink.audio.muted = false
                    }
                    // volumeChanged signal is automatically emitted when volume property changes
                }
            }
        }

        Binding {
            target: volumeSliderControl
            property: "value"
            value: AudioService.sink && AudioService.sink.audio ? Math.min(SettingsData.audioVolumeOverdrive ? 150 : 100, Math.round(AudioService.sink.audio.volume * 100)) : 0
            when: !volumeSliderControl.isDragging
        }
    }

    EHFlickable {
        id: audioContent
        anchors.top: volumeSlider.visible ? volumeSlider.bottom : headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: volumeSlider.visible ? Theme.spacingS : Theme.spacingM
        contentHeight: audioColumn.height
        clip: true
        
        Column {
            id: audioColumn
            width: parent.width
            spacing: Theme.spacingS
            
            Repeater {
                model: AudioService.sinks

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    // FIX: PwObjectTracker keeps reference alive during node removal
                    PwObjectTracker { objects: modelData ? [modelData] : [] }

                    // FIX: all modelData accesses now guarded
                    readonly property bool isActive: modelData !== null && modelData === AudioService.sink

                    width: parent.width
                    height: Math.max(50, deviceContent.height + Theme.spacingM * 2)
                    radius: Theme.cornerRadius
                    color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                    border.color: isActive ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: isActive ? 2 : 1
                    

                    Row {
                        id: deviceContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        EHIcon {
                            name: {
                                if (!modelData) return "speaker"
                                const name = modelData.name || ""
                                if (name.includes("bluez") || name.includes("usb")) return "headset"
                                if (name.includes("hdmi")) return "tv"
                                return "speaker"
                            }
                            size: Theme.iconSize - 4
                            color: isActive ? Theme.primary : Theme.surfaceText
                            anchors.top: parent.top
                        }

                        Column {
                            anchors.top: parent.top
                            width: parent.width - parent.spacing - (Theme.iconSize - 4)
                            spacing: Theme.spacingXS
                            layer.enabled: false

                            StyledText {
                                text: modelData ? AudioService.displayName(modelData) : ""
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: isActive ? Font.Medium : Font.Normal
                                width: parent.width
                                wrapMode: Text.WordWrap
                                renderType: Text.QtRendering
                                antialiasing: true
                                smooth: true
                            }

                            StyledText {
                                text: isActive ? "Active" : "Available"
                                font.pixelSize: Theme.fontSizeSmall
                                color: isActive ? Theme.primary : Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                                renderType: Text.QtRendering
                                antialiasing: true
                                smooth: true
                            }
                        }
                    }
                    
                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData) {
                                Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.shortDuration }
                    }
                }
            }
        }
    }
}