import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: rootDetail

    /** Inline under CompoundPill: one list shell, no nested device cards */
    property bool compactEmbed: false

    property bool hasVolumeSliderInCC: {
        const widgets = SettingsData.controlCenterWidgets || []
        return widgets.some(widget => widget.id === "volumeSlider")
    }

    readonly property int _sinkCount: {
        const s = AudioService.sinks
        return (s && s.length !== undefined) ? s.length : 0
    }

    /** Content-sized total for CompoundPill Loader (caps match scroll viewport range). */
    readonly property real compactNaturalHeight:
        Theme.spacingS + Math.min(480, Math.max(104, flickInner.implicitHeight)) + Theme.spacingS

    implicitHeight: compactEmbed
        ? compactNaturalHeight
        : headerRow.height + (!hasVolumeSliderInCC ? volumeSlider.height : 0)
            + (volumeSlider.visible ? Theme.spacingS : Theme.spacingM) + flickInner.implicitHeight + Theme.spacingM * 2

    /** Pill Loader assigns min height — stretch embedded list vertically to fill. */
    height: compactEmbed
        ? (parent && parent.height > 0 ? Math.max(compactNaturalHeight, parent.height) : implicitHeight)
        : undefined

    radius: compactEmbed ? 0 : Theme.cornerRadius
    color: compactEmbed
        ? "transparent"
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
    border.color: compactEmbed ? "transparent" : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: compactEmbed ? 0 : 1

    Row {
        id: headerRow
        visible: !compactEmbed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: compactEmbed ? 0 : 40

        StyledText {
            id: headerText
            text: "Audio Devices"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: 500
            anchors.verticalCenter: parent.verticalCenter
            renderType: Text.QtRendering
            antialiasing: true
            smooth: true
            layer.enabled: false
        }
    }

    Row {
        id: volumeSlider
        visible: !compactEmbed && !hasVolumeSliderInCC
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingXS
        height: compactEmbed ? 0 : 35
        spacing: 0

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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: compactEmbed ? 0 : Theme.spacingM
        anchors.rightMargin: compactEmbed ? 0 : Theme.spacingM
        anchors.top: compactEmbed ? parent.top : (volumeSlider.visible ? volumeSlider.bottom : headerRow.bottom)
        anchors.topMargin: compactEmbed ? Theme.spacingS : (volumeSlider.visible ? Theme.spacingS : Theme.spacingM)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: compactEmbed ? Theme.spacingS : Theme.spacingM
        contentWidth: width
        contentHeight: flickInner.implicitHeight
        clip: true

        Item {
            id: flickInner
            width: parent.width
            height: compactEmbed ? parent.height : implicitHeight
            readonly property real shellPad: Theme.spacingXS
            implicitHeight: compactEmbed
                ? (audioColumn.y + audioColumn.height + shellPad + Theme.spacingS)
                : audioColumn.height

            Rectangle {
                id: unifiedListShell
                visible: rootDetail.compactEmbed
                anchors.fill: parent
                anchors.margins: parent.shellPad
                radius: Theme.cornerRadius * 0.55
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                               Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                z: 0
            }

            Column {
                id: audioColumn
                width: rootDetail.compactEmbed ? (parent.width - Theme.spacingM * 2 - parent.shellPad * 2) : parent.width
                x: rootDetail.compactEmbed ? (parent.shellPad + Theme.spacingM) : 0
                y: rootDetail.compactEmbed ? (parent.shellPad + Theme.spacingS) : 0
                spacing: rootDetail.compactEmbed ? 0 : Theme.spacingS
                z: 1

                Repeater {
                    model: AudioService.sinks

                    delegate: Item {
                        id: delRoot
                        required property var modelData
                        required property int index

                        width: audioColumn.width
                        height: rootDetail.compactEmbed
                            ? (deviceRow.height + Theme.spacingM)
                            : Math.max(50, deviceRow.height + Theme.spacingM * 2)

                        readonly property bool isActive: modelData !== null && modelData === AudioService.sink

                        PwObjectTracker { objects: modelData ? [modelData] : [] }

                        Rectangle {
                            id: cardChrome
                            visible: !rootDetail.compactEmbed
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: rowMouse.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                            border.color: isActive ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: isActive ? 2 : 1
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
                        }

                        Rectangle {
                            visible: rootDetail.compactEmbed
                            anchors.fill: parent
                            color: {
                                if (!rootDetail.compactEmbed)
                                    return "transparent"
                                if (isActive)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                if (rowMouse.containsMouse)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                return index % 2 === 0
                                    ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                                    : "transparent"
                            }
                            radius: 0
                        }

                        Row {
                            id: deviceRow
                            anchors.verticalCenter: parent.verticalCenter
                            x: rootDetail.compactEmbed ? 0 : Theme.spacingM
                            width: parent.width - (rootDetail.compactEmbed ? 0 : Theme.spacingM * 2)
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
                                    font.weight: isActive ? 500 : 400
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

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: rootDetail.compactEmbed ? Theme.spacingS : 0
                            anchors.rightMargin: rootDetail.compactEmbed ? Theme.spacingS : 0
                            height: 1
                            visible: rootDetail.compactEmbed && index < rootDetail._sinkCount - 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 2
                            onClicked: {
                                if (modelData) {
                                    Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
