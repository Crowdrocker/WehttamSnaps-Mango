import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool showInputs: true
    property bool showOutputs: true

    implicitHeight: mainColumn.implicitHeight
    width: parent.width

    Connections {
        target: typeof ApplicationAudioService !== "undefined" ? ApplicationAudioService : null
        function onStreamsChanged() {
            outputStreamsRepeater.model = ApplicationAudioService.applicationStreams || []
            inputStreamsRepeater.model = ApplicationAudioService.applicationInputStreams || []
        }
        function onApplicationVolumeChanged() {
            outputStreamsRepeater.model = ApplicationAudioService.applicationStreams || []
        }
    }

    Connections {
        target: typeof Pipewire !== "undefined" && Pipewire.nodes ? Pipewire.nodes : null
        function onValuesChanged() {
            Qt.callLater(() => {
                outputStreamsRepeater.model = ApplicationAudioService.applicationStreams || []
                inputStreamsRepeater.model = ApplicationAudioService.applicationInputStreams || []
            })
        }
    }

    // Timer only runs when component is visible to reduce CPU usage
    Timer {
        interval: 1000
        running: root.visible && (typeof ApplicationAudioService !== "undefined")
        repeat: true
        onTriggered: {
            outputStreamsRepeater.model = ApplicationAudioService.applicationStreams || []
            inputStreamsRepeater.model = ApplicationAudioService.applicationInputStreams || []
        }
    }

    Column {
        id: mainColumn
        width: parent.width
        spacing: Theme.spacingL

        StyledRect {
            width: parent.width
            height: outputSection.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            border.width: 1
            visible: root.showOutputs

            Column {
                id: outputSection
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "volume_up"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Output Applications"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    id: outputStreamsRepeater
                    model: ApplicationAudioService.applicationStreams || []

                    delegate: StyledRect {
                        required property var modelData

                        width: parent.width
                        height: appRow.implicitHeight + deviceRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: mouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        // Track individual node to ensure properties are bound
                        PwObjectTracker {
                            objects: modelData ? [modelData] : []
                        }

                        // Define audio properties for proper binding
                        property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                        property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
                        property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!modelData || !modelData.audio) return
                                if (ApplicationAudioService.isNodeReadyForVolumeControl && ApplicationAudioService.isNodeReadyForVolumeControl(modelData)) {
                                    ApplicationAudioService.toggleApplicationMute(modelData)
                                }
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            RowLayout {
                                id: appRow
                                width: parent.width
                                spacing: Theme.spacingM

                                EHIcon {
                                    id: appIcon
                                    name: ApplicationAudioService.getApplicationIcon(modelData)
                                    size: Theme.iconSize
                                    color: modelData && modelData.audio && !modelData.audio.muted && modelData.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: ApplicationAudioService.getApplicationName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: {
                                            const device = ApplicationAudioService.getCurrentOutputDevice(modelData)
                                            return device ? (device.description || device.name || "Default") : "Default"
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    EHSlider {
                                        id: volumeSlider
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 32
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: nodeAudio && modelData.ready
                                        minimum: 0
                                        maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value: Math.round(appVolume * 100)
                                        showValue: true
                                        unit: "%"

                                        onSliderValueChanged: function(newValue) {
                                            if (nodeAudio && modelData.ready) {
                                                nodeAudio.volume = newValue / 100.0;
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                id: deviceRow
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: (ApplicationAudioService.outputDevices || []).length > 1

                                StyledText {
                                    text: "Output Device:"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 110
                                }

                                EHDropdown {
                                    width: parent.width - 110 - Theme.spacingS
                                    text: "Select Output Device"
                                    options: {
                                        const devices = ApplicationAudioService.outputDevices || []
                                        return devices.map(device => device.description || device.name || "Unknown Device")
                                    }
                                    currentValue: {
                                        const currentDevice = ApplicationAudioService.getCurrentOutputDevice(modelData)
                                        return currentDevice ? (currentDevice.description || currentDevice.name || "Default") : "Default"
                                    }
                                    onValueChanged: function(selectedValue) {
                                        const devices = ApplicationAudioService.outputDevices || []
                                        const selectedDevice = devices.find(device => (device.description || device.name) === selectedValue)
                                        if (selectedDevice && modelData) {
                                            ApplicationAudioService.routeStreamToOutput(modelData, selectedDevice)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 4
                            height: parent.height
                            radius: 2
                            color: modelData && modelData.audio && modelData.audio.muted ? Theme.error : "transparent"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 2
                        }
                    }
                }

                StyledText {
                    text: "No applications with audio output"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: (ApplicationAudioService.applicationStreams || []).length === 0
                }
            }
        }


        StyledRect {
            width: parent.width
            height: inputSection.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            border.width: 1
            visible: root.showInputs

            Column {
                id: inputSection
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "mic"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Input Applications"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    id: inputStreamsRepeater
                    model: ApplicationAudioService.applicationInputStreams || []

                    delegate: StyledRect {
                        required property var modelData

                        width: parent.width
                        height: appRow.implicitHeight + deviceRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: mouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        // Track individual node to ensure properties are bound
                        PwObjectTracker {
                            objects: modelData ? [modelData] : []
                        }

                        // Define audio properties for proper binding
                        property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                        property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
                        property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!modelData || !modelData.audio) return
                                if (ApplicationAudioService.isNodeReadyForVolumeControl && ApplicationAudioService.isNodeReadyForVolumeControl(modelData)) {
                                    ApplicationAudioService.toggleApplicationInputMute(modelData)
                                }
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            RowLayout {
                                id: appRow
                                width: parent.width
                                spacing: Theme.spacingM

                                EHIcon {
                                    id: appIcon
                                    name: ApplicationAudioService.getApplicationIcon(modelData)
                                    size: Theme.iconSize
                                    color: modelData && modelData.audio && !modelData.audio.muted && modelData.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: ApplicationAudioService.getApplicationName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: {
                                            const device = ApplicationAudioService.getCurrentInputDevice(modelData)
                                            return device ? (device.description || device.name || "Default") : "Default"
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    EHSlider {
                                        id: volumeSlider
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 32
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: nodeAudio && modelData.ready
                                        minimum: 0
                                        maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value: Math.round(appVolume * 100)
                                        showValue: true
                                        unit: "%"

                                        onSliderValueChanged: function(newValue) {
                                            if (nodeAudio && modelData.ready) {
                                                nodeAudio.volume = newValue / 100.0;
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                id: deviceRow
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: (ApplicationAudioService.inputDevices || []).length > 1

                                StyledText {
                                    text: "Input Device:"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 110
                                }

                                EHDropdown {
                                    width: parent.width - 110 - Theme.spacingS
                                    text: "Select Input Device"
                                    options: {
                                        const devices = ApplicationAudioService.inputDevices || []
                                        return devices.map(device => device.description || device.name || "Unknown Device")
                                    }
                                    currentValue: {
                                        const currentDevice = ApplicationAudioService.getCurrentInputDevice(modelData)
                                        return currentDevice ? (currentDevice.description || currentDevice.name || "Default") : "Default"
                                    }
                                    onValueChanged: function(selectedValue) {
                                        const devices = ApplicationAudioService.inputDevices || []
                                        const selectedDevice = devices.find(device => (device.description || device.name) === selectedValue)
                                        if (selectedDevice && modelData) {
                                            ApplicationAudioService.routeStreamToInput(modelData, selectedDevice)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 4
                            height: parent.height
                            radius: 2
                            color: modelData && modelData.audio && modelData.audio.muted ? Theme.error : "transparent"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 2
                        }
                    }
                }

                StyledText {
                    text: "No applications with audio input"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: (ApplicationAudioService.applicationInputStreams || []).length === 0
                }
            }
        }
    }
}
