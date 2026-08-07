import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: soundTab

    // ── Shared card colour helper — mirrors RenderTab's card style ────────────
    function cardColor() {
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
    }
    function cardBorder() {
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + Theme.spacingL

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════════
            // SECTION 1 — System Volume
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: systemVolumeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: systemVolumeSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Section header — same pattern as RenderTab
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon {
                            name: AudioService.muted ? "volume_off" : "volume_up"
                            size: Theme.iconSize
                            color: AudioService.muted ? Theme.error : Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "System Volume"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: Theme.spacingXS; height: 1 }
                        StyledText {
                            text: AudioService.sink ? AudioService.displayName(AudioService.sink) : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }

                    // Output slider row  (Loader keeps existing widget)
                    Loader {
                        width: parent.width
                        source: "../../Modules/ControlCenter/Widgets/AudioSliderRow.qml"
                    }

                    // Mute toggle row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: AudioService.muted ? "Muted" : "Unmuted"
                            font.pixelSize: Theme.fontSizeMedium
                            color: AudioService.muted ? Theme.error : Theme.surfaceText
                            Layout.fillWidth: true
                        }

                        // Round mute button — same style as original but consistent size
                        Rectangle {
                            width: Theme.iconSize + Theme.spacingM * 2
                            height: Theme.iconSize + Theme.spacingM * 2
                            radius: height / 2
                            color: muteArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                            EHIcon {
                                anchors.centerIn: parent
                                name: AudioService.muted ? "volume_off" : "volume_up"
                                size: Theme.iconSize
                                color: AudioService.muted ? Theme.error : Theme.primary
                            }

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    AudioService.suppressOutputOSD()
                                    AudioService.setOutputMuted(!AudioService.muted)
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION 2 — Microphone / Input
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: inputVolumeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: inputVolumeSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon {
                            name: AudioService.inputMuted ? "mic_off" : "mic"
                            size: Theme.iconSize
                            color: AudioService.inputMuted ? Theme.error : Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Microphone"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: Theme.spacingXS; height: 1 }
                        StyledText {
                            text: AudioService.source ? AudioService.displayName(AudioService.source) : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }

                    Loader {
                        width: parent.width
                        source: "../../Modules/ControlCenter/Widgets/InputAudioSliderRow.qml"
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION 3 — Audio Settings
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: audioSettingsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: audioSettingsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Audio Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Volume Overdrive"
                        description: "Allow volumes above 100% (up to 150%)"
                        checked: SettingsData.audioVolumeOverdrive
                        onToggled: checked => { SettingsData.audioVolumeOverdrive = checked }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION 4 — Application Streams
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: appStreamsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: appStreamsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "apps"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Applications"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { Layout.fillWidth: true; height: 1 }
                        StyledText {
                            text: `${ApplicationAudioService.applicationStreams.length} active`
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    UDivider { width: parent.width }

                    // Per-app stream cards
                    Repeater {
                        model: ApplicationAudioService.applicationStreams

                        delegate: StyledRect {
                            required property PwNode modelData

                            width: parent.width
                            height: appRow.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            // Consistent with device row style — no alternating colors
                            color: appHover.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: soundTab.cardBorder()
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                            PwObjectTracker { objects: modelData ? [modelData] : [] }

                            property PwNodeAudio nodeAudio: modelData?.audio ?? null
                            property real  appVolume: nodeAudio?.volume ?? 0.0
                            property bool  appMuted:  nodeAudio?.muted  ?? false

                            MouseArea { id: appHover; anchors.fill: parent; hoverEnabled: true }

                            RowLayout {
                                id: appRow
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                // App icon with fallback
                                Item {
                                    Layout.preferredWidth: Theme.iconSize + 8
                                    Layout.preferredHeight: Theme.iconSize + 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        anchors.fill: parent
                                        source: ApplicationAudioService.getApplicationIcon(modelData)
                                        sourceSize.width: (Theme.iconSize + 8) * 2
                                        sourceSize.height: (Theme.iconSize + 8) * 2
                                        smooth: true
                                        mipmap: true
                                        fillMode: Image.PreserveAspectFit
                                        cache: true
                                        asynchronous: true

                                        EHIcon {
                                            anchors.fill: parent
                                            name: "apps"
                                            size: Theme.iconSize
                                            color: Theme.primary
                                            visible: parent.status === Image.Error
                                                  || parent.status === Image.Null
                                                  || parent.source === ""
                                        }
                                    }
                                }

                                // Name + device + slider
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: modelData ? ApplicationAudioService.getApplicationName(modelData) : ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: (!appMuted && nodeAudio !== null && modelData.ready) ? Font.Medium : Font.Normal
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: {
                                            const dev = ApplicationAudioService.getCurrentOutputDevice(modelData)
                                            return dev ? (dev.description || dev.name || "Default") : "Default"
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    EHSlider {
                                        Layout.fillWidth: true
                                        minimum: 0
                                        maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value: Math.round(appVolume * 100)
                                        showValue: true
                                        unit: "%"
                                        enabled: nodeAudio !== null && modelData.ready
                                        onSliderValueChanged: function(v) {
                                            if (nodeAudio && modelData.ready)
                                                nodeAudio.volume = v / 100.0
                                        }
                                    }
                                }

                                // Mute button
                                Rectangle {
                                    Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                                    Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: height / 2
                                    color: appMuteArea.containsMouse
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                                    EHIcon {
                                        anchors.centerIn: parent
                                        name: appMuted ? "volume_off" : "volume_up"
                                        size: Theme.iconSize - 4
                                        color: appMuted ? Theme.error : Theme.primary
                                    }

                                    MouseArea {
                                        id: appMuteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (nodeAudio && modelData.ready)
                                                nodeAudio.muted = !appMuted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    StyledText {
                        text: "No applications currently playing audio"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: ApplicationAudioService.applicationStreams.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION 5 — Output Devices
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: outputDevicesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: outputDevicesSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "speaker"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Output Devices"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    UDivider { width: parent.width }

                    Repeater {
                        model: Pipewire.nodes?.values
                            ? Pipewire.nodes.values.filter(n => n && n?.ready && n.audio && n.isSink && !n.isStream)
                            : []

                        delegate: StyledRect {
                            required property var modelData
                            required property int index

                            // FIX: keep node alive during delegate lifecycle
                            PwObjectTracker { objects: modelData ? [modelData] : [] }

                            // FIX: guard modelData accesses
                            readonly property bool isActive: modelData !== null && modelData === AudioService.sink
                            readonly property string devIcon: {
                                if (!modelData) return "speaker"
                                const nm = modelData.name ?? ""
                                if (nm.includes("bluez")) return "headset"
                                if (nm.includes("hdmi"))  return "tv"
                                if (nm.includes("usb"))   return "headset"
                                return "speaker"
                            }

                            width: parent.width
                            height: 52
                            radius: Theme.cornerRadius
                            color: rowHover.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: isActive
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: isActive ? 2 : 1
                            Behavior on color        { ColorAnimation { duration: Theme.shortDuration } }
                            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin:  Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                EHIcon {
                                    name: devIcon
                                    size: Theme.iconSize - 4
                                    color: isActive ? Theme.primary : Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    StyledText {
                                        text: AudioService.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: isActive ? Font.Medium : Font.Normal
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: isActive ? "Active" : "Available"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: isActive ? Theme.primary : Theme.surfaceVariantText
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                }

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: Theme.primary
                                    visible: isActive
                                    opacity: 0.85
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (modelData) Pipewire.preferredDefaultAudioSink = modelData }
                            }
                        }
                    }

                    StyledText {
                        text: "No output devices available"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: (Pipewire.nodes?.values ?? []).filter(n => n?.ready && n.audio && n.isSink && !n.isStream).length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION 6 — Input Devices
            // ════════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: inputDevicesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: soundTab.cardColor()
                border.color: soundTab.cardBorder()
                border.width: 1

                Column {
                    id: inputDevicesSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "mic"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Input Devices"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    UDivider { width: parent.width }

                    Repeater {
                        model: Pipewire.nodes?.values
                            ? Pipewire.nodes.values.filter(n => n && n?.ready && n.audio && !n.isSink && !n.isStream)
                            : []

                        delegate: StyledRect {
                            required property var modelData
                            required property int index

                            // FIX: keep node alive during delegate lifecycle
                            PwObjectTracker { objects: modelData ? [modelData] : [] }

                            // FIX: guard modelData accesses
                            readonly property bool isActive: modelData !== null && modelData === AudioService.source
                            readonly property string devIcon: {
                                if (!modelData) return "mic"
                                const nm = modelData.name ?? ""
                                return (nm.includes("bluez") || nm.includes("usb")) ? "headset" : "mic"
                            }

                            width: parent.width
                            height: 52
                            radius: Theme.cornerRadius
                            color: rowHover.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: isActive
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: isActive ? 2 : 1
                            Behavior on color        { ColorAnimation { duration: Theme.shortDuration } }
                            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin:  Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                EHIcon {
                                    name: devIcon
                                    size: Theme.iconSize - 4
                                    color: isActive ? Theme.primary : Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    StyledText {
                                        text: AudioService.displayName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: isActive ? Font.Medium : Font.Normal
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: isActive ? "Active" : "Available"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: isActive ? Theme.primary : Theme.surfaceVariantText
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                }

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: Theme.primary
                                    visible: isActive
                                    opacity: 0.85
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (modelData) Pipewire.preferredDefaultAudioSource = modelData }
                            }
                        }
                    }

                    StyledText {
                        text: "No input devices available"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: (Pipewire.nodes?.values ?? []).filter(n => n?.ready && n.audio && !n.isSink && !n.isStream).length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                    }
                }
            }

        } // mainColumn
    } // EHFlickable
}
