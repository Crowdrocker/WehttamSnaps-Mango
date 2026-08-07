import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property bool hasInputVolumeSliderInCC: {
        const widgets = SettingsData.controlCenterWidgets || []
        return widgets.some(widget => widget.id === "inputVolumeSlider")
    }

    implicitHeight: headerRow.height + (hasInputVolumeSliderInCC ? 0 : volumeSlider.height) + audioContent.height + Theme.spacingM
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
            text: "Input Devices"
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
        visible: !hasInputVolumeSliderInCC

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
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.source.audio.muted = !AudioService.source.audio.muted
                    }
                }
            }

            EHIcon {
                anchors.centerIn: parent
                name: {
                    if (!AudioService.source || !AudioService.source.audio) return "mic_off"
                    let muted = AudioService.source.audio.muted
                    return muted ? "mic_off" : "mic"
                }
                size: Theme.iconSize
                color: AudioService.source && AudioService.source.audio && !AudioService.source.audio.muted && AudioService.source.audio.volume > 0 ? Theme.primary : Theme.surfaceText
            }
        }

        EHSlider {
            id: volumeSliderControl
            readonly property real actualVolumePercent: AudioService.source && AudioService.source.audio ? Math.round(AudioService.source.audio.volume * 100) : 0

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
            enabled: AudioService.source && AudioService.source.audio
            minimum: 0
            maximum: 100
            showValue: true
            unit: "%"
            valueOverride: actualVolumePercent
            thumbOutlineColor: Theme.surfaceVariant

            onSliderValueChanged: function(newValue) {
                if (AudioService.source && AudioService.source.audio) {
                    SessionData.suppressOSDTemporarily()
                    AudioService.source.audio.volume = newValue / 100
                    if (newValue > 0 && AudioService.source.audio.muted) {
                        AudioService.source.audio.muted = false
                    }
                    AudioService.inputVolumeChanged()
                }
            }
        }

        Binding {
            target: volumeSliderControl
            property: "value"
            value: AudioService.source && AudioService.source.audio ? Math.min(100, Math.round(AudioService.source.audio.volume * 100)) : 0
            when: !volumeSliderControl.isDragging
        }
    }
    
    EHFlickable {
        id: audioContent
        anchors.top: hasInputVolumeSliderInCC ? headerRow.bottom : volumeSlider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: hasInputVolumeSliderInCC ? Theme.spacingM : Theme.spacingS
        contentHeight: audioColumn.height
        clip: true
        
        Column {
            id: audioColumn
            width: parent.width
            spacing: Theme.spacingS
            
            Repeater {
                model: AudioService.sources

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    // FIX: PwObjectTracker keeps reference alive during node removal
                    PwObjectTracker { objects: modelData ? [modelData] : [] }

                    // FIX: all modelData accesses now guarded
                    readonly property bool isActive: modelData !== null && modelData === AudioService.source

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
                                if (!modelData) return "mic"
                                const name = modelData.name || ""
                                if (name.includes("bluez") || name.includes("usb")) return "headset"
                                return "mic"
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
                                Pipewire.preferredDefaultAudioSource = modelData
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