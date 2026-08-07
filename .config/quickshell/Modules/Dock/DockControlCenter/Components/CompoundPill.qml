import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Details

Rectangle {
    id: widgetRoot
    property var widgetData:  ({})
    property int widgetIndex: 0
    property int cardRadius: 16
    property real cardBorderAlpha: 0.08
    property real cardBgAlpha: 0.28
    property bool editMode: false
    property var cardBg: "transparent"
    property var cardBorder: "transparent"
    property var model: null
    property var gridRoot: null

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    property var widgetDef: widgetRoot.model?.getWidgetForId(widgetData.id || "")
    property bool isAudioWidget:       (widgetData.id || "") === "audioOutput" || (widgetData.id || "") === "audioInput"
    property bool isVolumeMixerWidget: (widgetData.id || "") === "volumeMixer"
    readonly property bool volumeMixerExpanded: isVolumeMixerWidget && gridRoot
        && gridRoot.expandedSection === "volumeMixer"
        && gridRoot.expandedWidgetIndex === widgetIndex
    readonly property bool audioExpanded: isAudioWidget && gridRoot
        && gridRoot.expandedSection === (widgetData.id || "")
        && gridRoot.expandedWidgetIndex === widgetIndex

    width:  parent.width
    implicitHeight: {
        // Use scaled sizes so the grid can size correctly at any dock scale.
        // For the volume mixer, prefer the real content height so the background
        // always contains the stream cards.
        if (isVolumeMixerWidget) return (column.implicitHeight + (Theme.spacingXS + 1) + Theme.spacingS)
        if (isAudioWidget)
            return Math.max(widgetRoot.spx(100),
                            column.implicitHeight + (Theme.spacingXS + 1) + Theme.spacingS)
        return spx(56)
    }
    radius: widgetRoot.cardRadius

    color:  widgetRoot.cardBg
    border.color: widgetRoot.cardBorder
    border.width: 1
    clip:     true

        property bool isActive: {
            switch (widgetData.id || "") {
            case "wifi": {
                if (NetworkService.wifiToggling) return false
                if (NetworkService.networkStatus === "ethernet") return true
                if (NetworkService.networkStatus === "wifi")     return true
                return NetworkService.wifiEnabled
            }
            case "bluetooth":  return !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled)
            case "audioOutput": return !!(AudioService.sink   && !AudioService.sink.audio.muted)
            case "audioInput":  return !!(AudioService.source && !AudioService.source.audio.muted)
            case "volumeMixer": {
                const outputCount = (ApplicationAudioService.applicationStreams || []).length
                const inputCount  = (ApplicationAudioService.applicationInputStreams || []).length
                return outputCount > 0 || inputCount > 0
            }
            case "hdrToggle": return HdrService.hdrEnabled
            default: return false
            }
        }

        Column {
            id: column
            anchors {
                left:        parent.left
                right:       parent.right
                top:         parent.top
                topMargin:   Theme.spacingXS + 1
                leftMargin:  (widgetData.id === "wifi" || widgetData.id === "bluetooth")
                                 ? Math.max(2, Theme.cornerRadius / 2)
                                 : Theme.spacingM
                rightMargin: (widgetData.id === "wifi" || widgetData.id === "bluetooth")
                                 ? Math.max(2, Theme.cornerRadius / 2)
                                 : Theme.spacingM
            }
            spacing: Theme.spacingXS

            RowLayout {
                id: iconTextRow
                spacing: (widgetData.id === "wifi" || widgetData.id === "bluetooth") ? 2 : 10
                width: parent.width

                Item {
                    Layout.preferredWidth:  Theme.iconSize
                    Layout.preferredHeight: Theme.iconSize
                    Layout.alignment: Qt.AlignVCenter
                    property bool isBluetooth: (widgetData.id || "") === "bluetooth"

                    EHIcon {
                        name: {
                            switch (widgetData.id || "") {
                            case "wifi": {
                                if (NetworkService.wifiToggling)                         return "sync"
                                if (NetworkService.networkStatus === "ethernet")          return "cable"
                                if (NetworkService.networkStatus === "wifi")              return NetworkService.wifiSignalIcon
                                return "wifi_off"
                            }
                            case "bluetooth": {
                                if (!BluetoothService.available)                         return "bluetooth_disabled"
                                if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) return "bluetooth_disabled"
                                const primaryDevice = (() => {
                                    if (!BluetoothService.adapter || !BluetoothService.adapter.devices) return null
                                    let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                                    for (let device of devices) {
                                        if (device && device.connected) return device
                                    }
                                    return null
                                })()
                                if (primaryDevice) return BluetoothService.getDeviceIcon(primaryDevice)
                                return "bluetooth"
                            }
                            case "audioOutput": {
                                if (!AudioService.sink)                                  return "volume_off"
                                const vol  = AudioService.sink.audio.volume
                                const mute = AudioService.sink.audio.muted
                                if (mute || vol === 0.0) return "volume_off"
                                if (vol <= 0.33)        return "volume_down"
                                return "volume_up"
                            }
                            case "audioInput":    return (AudioService.source?.audio.muted ?? true) ? "mic_off" : "mic"
                            case "volumeMixer": {
                                const oc = (ApplicationAudioService.applicationStreams || []).length
                                const ic = (ApplicationAudioService.applicationInputStreams || []).length
                                return (ic > 0 && oc === 0) ? "mic" : "volume_up"
                            }
                            case "hdrToggle":     return HdrService.hdrEnabled ? "hdr_on" : "hdr_off"
                            default:              return widgetDef?.icon || "help"
                            }
                        }
                        size: Theme.iconSize
                        color: widgetRoot.isActive ? Theme.primary : Theme.surfaceText
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: bluetoothIconMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        visible: parent.isBluetooth
                        z: 20
                        onClicked: {
                            if (widgetRoot.editMode) return
                            if (BluetoothService.available && BluetoothService.adapter) {
                                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        text: {
                            switch (widgetData.id || "") {
                            case "wifi": {
                                if (NetworkService.wifiToggling) return NetworkService.wifiEnabled ? "Disabling..." : "Enabling..."
                                if (NetworkService.networkStatus === "ethernet")
                                    return NetworkService.ethernetDeviceName || NetworkService.ethernetInterface || "Ethernet"
                                if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID) {
                                    const s = NetworkService.currentWifiSSID
                                    return s.length > 14 ? s.substring(0, 14) + "…" : s
                                }
                                return NetworkService.wifiEnabled ? "Not connected" : "Wi-Fi off"
                            }
                            case "bluetooth": {
                                if (!BluetoothService.available)                                             return "Bluetooth"
                                if (!BluetoothService.adapter || !BluetoothService.adapter.enabled)         return "Disabled"
                                const btDev = (() => {
                                    if (!BluetoothService.adapter || !BluetoothService.adapter.devices) return null
                                    for (let d of BluetoothService.adapter.devices.values) {
                                        if (d && d.connected) return d
                                    }
                                    return null
                                })()
                                if (btDev) {
                                    const n = btDev.name || btDev.deviceName || ""
                                    return n.length > 16 ? n.substring(0, 16) + "…" : n || "Connected"
                                }
                                return "No device"
                            }
                            case "audioOutput":  return AudioService.sink?.description   || "No output"
                            case "audioInput":   return AudioService.source?.description || "No input"
                            case "volumeMixer":  return "Volume Mixer"
                            case "hdrToggle":    return HdrService.hdrEnabled ? "HDR On" : "HDR Off"
                            default:             return widgetDef?.text || "Unknown"
                            }
                        }
                        font.pixelSize: Math.max(12, widgetRoot.spx(14))
                        font.weight: 500
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Math.max(10, widgetRoot.spx(11))
                        color:          Theme.surfaceText
                        opacity:        0.45
                        elide:          Text.ElideRight
                        visible:        text.length > 0
                        text: {
                            const id = widgetData.id || ""
                            if (id === "wifi"
                                    && NetworkService.networkStatus === "ethernet"
                                    && NetworkService.ethernetConnected)
                                return NetworkService.ethernetInterface || ""
                            if (id === "bluetooth"
                                    && BluetoothService.available
                                    && !!(BluetoothService.adapter && BluetoothService.adapter.enabled)) {
                                if (!BluetoothService.adapter || !BluetoothService.adapter.devices) return ""
                                for (let d of BluetoothService.adapter.devices.values) {
                                    if (d && d.connected) {
                                        const typeMap = {
                                            "headset": "Headset", "speaker": "Speaker",
                                            "mouse": "Mouse", "keyboard": "Keyboard",
                                            "smartphone": "Phone", "watch": "Watch",
                                            "tv": "Display", "bluetooth": "Device"
                                        }
                                        return typeMap[BluetoothService.getDeviceIcon(d)] || "Device"
                                    }
                                }
                                const n = BluetoothService.pairedDevices.length
                                return n > 0 ? n + " paired device" + (n > 1 ? "s" : "") : "No paired devices"
                            }
                            return ""
                        }
                    }
                }
            }

            Item {
                visible: isAudioWidget
                width:  parent.width
                height: Math.max(widgetRoot.spx(22), Theme.spacingM + 10)

                EHSlider {
                    anchors.fill: parent
                    enabled: {
                        if ((widgetData.id || "") === "audioOutput")
                            return !!(AudioService.sink   && !AudioService.sink.audio.muted)
                        if ((widgetData.id || "") === "audioInput")
                            return !!(AudioService.source && !AudioService.source.audio.muted)
                        return false
                    }
                    value: {
                        if ((widgetData.id || "") === "audioOutput")
                            return (AudioService.sink?.audio.volume   ?? 0) * 100
                        if ((widgetData.id || "") === "audioInput")
                            return (AudioService.source?.audio.volume ?? 0) * 100
                        return 0
                    }
                    showValue:        false
                    thumbOutlineColor: Theme.surfaceContainer
                    trackColor: {
                        const alpha = Theme.getContentBackgroundAlpha() * 0.55
                        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
                    }
                    onSliderValueChanged: function(newValue) {
                        if ((widgetData.id || "") === "audioOutput" && AudioService.sink)
                            AudioService.sink.audio.volume   = newValue / 100.0
                        else if ((widgetData.id || "") === "audioInput" && AudioService.source)
                            AudioService.source.audio.volume = newValue / 100.0
                    }
                }
            }

            Item {
                visible:  isAudioWidget
                width:    parent.width
                height:   Theme.spacingS + 2
            }

            Item {
                visible: isVolumeMixerWidget && !volumeMixerExpanded
                width:  parent.width
                height: isVolumeMixerWidget && !volumeMixerExpanded ? streamCol.implicitHeight : 0

                Column {
                    id: streamCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: Theme.spacingS

                    Repeater {
                        model: {
                            const out = ApplicationAudioService.applicationStreams || []
                            return out.slice(0, 2)
                        }

                        Rectangle {
                            id: streamCard
                            required property var modelData
                            required property int index

                            PwObjectTracker {
                                objects: modelData ? [modelData] : []
                            }

                            property var  nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                            property real appVolume: (nodeAudio && nodeAudio.volume !== undefined)
                                                 ? nodeAudio.volume
                                                 : 0.0
                            property string iconPath: ApplicationAudioService.getApplicationIcon(modelData)
                            property string appName:  ApplicationAudioService.getApplicationName(modelData)

                            width:  parent ? parent.width : 0
                            height: cardInner.implicitHeight + Theme.spacingXS * 2
                            radius: 8
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.28)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                            border.width: 1

                            Column {
                                id: cardInner
                                anchors {
                                    left:           parent.left
                                    right:          parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin:     Theme.spacingS
                                    rightMargin:    Theme.spacingS
                                }
                                spacing: 3

                                Row {
                                    width:   parent.width
                                    spacing: Theme.spacingXS

                                    Item {
                                        width:  14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: appIconImg
                                            anchors.fill: parent
                                            source:       iconPath
                                            sourceSize:   Qt.size(28, 28)
                                            smooth:       true
                                            mipmap:       true
                                            fillMode:     Image.PreserveAspectFit
                                            asynchronous: true
                                        }
                                        EHIcon {
                                            anchors.fill: parent
                                            name:    "apps"
                                            size:    14
                                            color:   Theme.primary
                                            visible: appIconImg.status !== Image.Ready
                                        }
                                    }

                                    StyledText {
                                        width:          parent.width - 14 - parent.spacing
                                        text:           appName
                                        font.pixelSize: 11
                                        font.weight:    500
                                        color:          Theme.surfaceText
                                        elide:          Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                EHSlider {
                                    width:  parent.width
                                    height: 14

                                    enabled: nodeAudio && modelData && modelData.ready !== false
                                    minimum: 0
                                    maximum: 100
                                    value:   Math.round(appVolume * 100)

                                    showValue:        false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    trackColor: Qt.rgba(
                                        Theme.surfaceVariant.r,
                                        Theme.surfaceVariant.g,
                                        Theme.surfaceVariant.b,
                                        Theme.getContentBackgroundAlpha() * 0.55
                                    )

                                    onSliderValueChanged: function(newValue) {
                                        if (nodeAudio && modelData && modelData.ready !== false) {
                                            try {
                                                nodeAudio.volume = newValue / 100.0
                                            } catch (e) {
                                                console.log("Failed to set volume:", e)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: {
                            const oc    = (ApplicationAudioService.applicationStreams       || []).length
                            const ic    = (ApplicationAudioService.applicationInputStreams  || []).length
                            const total = oc + ic
                            return total > 3 ? `+${total - 3} more` : (total === 0 ? "No apps" : "")
                        }
                        font.pixelSize: 11
                        color: Theme.surfaceTextMedium
                        visible: {
                            const oc = (ApplicationAudioService.applicationStreams       || []).length
                            const ic = (ApplicationAudioService.applicationInputStreams  || []).length
                            return (oc + ic) > 3 || (oc + ic) === 0
                        }
                        leftPadding: Theme.spacingS
                    }
                }
            }

            Loader {
                id: audioEmbedLoader
                width:  parent.width
                active: audioExpanded && !widgetRoot.gridRoot
                visible: active
                height: active ? implicitHeight : 0
                sourceComponent: (widgetData.id || "") === "audioOutput" ? audioOutEmbedComp : audioInEmbedComp
                onLoaded: {
                    if (item)
                        item.width = Qt.binding(function () { return audioEmbedLoader.width })
                }
            }

            VolumeMixer {
                visible: isVolumeMixerWidget && volumeMixerExpanded
                width:   parent.width
            }
        }

        Component {
            id: audioOutEmbedComp
            AudioOutputDetail {
                compactEmbed: true
            }
        }

        Component {
            id: audioInEmbedComp
            AudioInputDetail {
                compactEmbed: true
            }
        }

        Rectangle {
            id: connBadge
            property bool isEthernetConn: (widgetData.id || "") === "wifi"
                                       && NetworkService.networkStatus === "ethernet"
                                       && NetworkService.ethernetConnected
            property bool isBtEnabled: (widgetData.id || "") === "bluetooth"
                                        && BluetoothService.available
                                        && !!(BluetoothService.adapter && BluetoothService.adapter.enabled)
            property bool isBtConnected: isBtEnabled && (() => {
                if (!BluetoothService.adapter || !BluetoothService.adapter.devices) return false
                for (let d of BluetoothService.adapter.devices.values) {
                    if (d && d.connected) return true
                }
                return false
            })()
            visible: isEthernetConn || isBtEnabled
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.rightMargin: 8
            anchors.topMargin:   8
            width:  connBadgeLbl.implicitWidth + 10
            height: connBadgeLbl.implicitHeight + 5
            radius: height / 2
            z: 5
            color: (isEthernetConn || isBtConnected)
                ? Qt.rgba(0.298, 0.686, 0.314, 0.15)
                : Qt.rgba(1, 1, 1, 0.06)
            border.color: (isEthernetConn || isBtConnected)
                ? Qt.rgba(0.298, 0.686, 0.314, 0.25)
                : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            StyledText {
                id: connBadgeLbl
                anchors.centerIn: parent
                text: (connBadge.isEthernetConn || connBadge.isBtConnected)
                    ? "Connected" : "Disconnected"
                font.pixelSize: 10
                color: (connBadge.isEthernetConn || connBadge.isBtConnected)
                    ? "#4CAF50"
                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
            }
        }

        MouseArea {
            id: topSectionMouseArea
            anchors {
                left:        parent.left
                leftMargin:  (widgetData.id || "") === "bluetooth"
                                 ? (Math.max(2, Theme.cornerRadius / 2) + Theme.iconSize + 2)
                                 : 0
                right:       parent.right
                rightMargin: 0
                top:         parent.top
            }
            height: isAudioWidget || isVolumeMixerWidget
                ? (Theme.spacingXS + 30 + Theme.spacingXS)
                : parent.height
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: {
                if (widgetRoot.editMode) return
                if (isVolumeMixerWidget) {
                    const gp = mapToItem(null, 0, 0)
                    if (widgetRoot.gridRoot && widgetRoot.gridRoot.expandClicked)
                        widgetRoot.gridRoot.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                    return
                }
                if (isAudioWidget) {
                    const gp = mapToItem(null, 0, 0)
                    if (widgetRoot.gridRoot && widgetRoot.gridRoot.expandClicked)
                        widgetRoot.gridRoot.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                    return
                }
                if (!isAudioWidget && !isVolumeMixerWidget) {
                    const gp = mapToItem(null, 0, 0)
                    if (widgetRoot.gridRoot && widgetRoot.gridRoot.expandClicked)
                        widgetRoot.gridRoot.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                }
            }
            onPressed: function(mouse) {
                if (widgetRoot.editMode) return
                if ((widgetData.id || "") === "bluetooth") return
                switch (widgetData.id || "") {
                case "wifi": {
                    if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling)
                        NetworkService.toggleWifiRadio()
                    break
                }
                case "hdrToggle": HdrService.toggleHdr(); break
                }
            }
        }

        EditModeOverlay {
            anchors.fill: parent
            editMode:    widgetRoot.editMode
            widgetData:  parent.widgetData
            widgetIndex: parent.widgetIndex
            showSizeControls: true
            isSlider: false
            onRemoveWidget:     function(index)             { widgetRoot.gridRoot.removeWidget(index) }
            onToggleWidgetSize: function(index)             { widgetRoot.gridRoot.toggleWidgetSize(index) }
            onMoveWidget:       function(fromIndex, toIndex) { widgetRoot.gridRoot.moveWidget(fromIndex, toIndex) }
        }
    }