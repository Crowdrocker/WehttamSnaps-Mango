import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Components
import "../utils/layout.js" as LayoutUtils

Column {
    id: root

    property bool editMode: false
    property string expandedSection: ""
    property int expandedWidgetIndex: -1
    property var model: null

    signal expandClicked(var widgetData, int globalIndex, real x, real y, real width, real height)
    signal removeWidget(int index)
    signal moveWidget(int fromIndex, int toIndex)
    signal toggleWidgetSize(int index)

    spacing: Theme.spacingM

    readonly property var _ccLayout: LayoutUtils.calculateRowsAndWidgets(root, expandedSection, expandedWidgetIndex)
    readonly property int expandedRowIndex: _ccLayout.expandedRowIndex
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.topbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    // ── Shared helpers ────────────────────────────────────────────────────

    // Base card style used by all pill widgets
    component CardRect : Rectangle {
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        border.width: 1
    }

    // Rows of widgets
    Repeater {
        model: root._ccLayout.rows

        Column {
            width: root.width
            spacing: Theme.spacingM
            property int rowIndex: index
            property var rowWidgets: modelData
            property bool isSliderOnlyRow: {
                const widgets = rowWidgets || []
                if (widgets.length === 0) return false
                return widgets.every(w => w.id === "volumeSlider" || w.id === "brightnessSlider" || w.id === "inputVolumeSlider")
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: rowWidgets || []

                    Item {
                        property var widgetData: modelData
                        property int globalWidgetIndex: {
                            const widgets = SettingsData.controlCenterWidgets || []
                            for (var i = 0; i < widgets.length; i++) {
                                if (widgets[i].id === modelData.id) return i
                            }
                            return -1
                        }
                        property int widgetWidth: {
                            const id = modelData.id || ""
                            if (id === "volumeMixer" || id === "media") return 100
                            return modelData.width || 50
                        }
                        width: {
                            const base = root.width
                            const sp = Theme.spacingM
                            if (widgetWidth <= 25)  return (base - sp * 3) / 4
                            if (widgetWidth <= 50)  return (base - sp) / 2
                            if (widgetWidth <= 75)  return (base - sp * 2) * 0.75
                            return base
                        }
                        height: {
                            const id = modelData.id || ""
                            if (id === "brightnessSlider")  return root.spx(85)
                            if (isSliderOnlyRow)            return root.spx(16)
                            if (id === "audioOutput" || id === "audioInput") {
                                const h = widgetLoader.item ? widgetLoader.item.implicitHeight : 0
                                return Math.max(root.spx(104), h > 0 ? h : root.spx(104))
                            }
                            if (id === "volumeMixer") {
                                if (widgetLoader.item && widgetLoader.item.implicitHeight > 0)
                                    return widgetLoader.item.implicitHeight
                                return root.spx(150)
                            }
                            if (id === "media")             return root.spx(72)
                            return root.spx(56)
                        }

                        Loader {
                            id: widgetLoader
                            anchors.fill: parent
                            property var widgetData: parent.widgetData
                            property int widgetIndex: parent.globalWidgetIndex
                            property int globalWidgetIndex: parent.globalWidgetIndex
                            property int widgetWidth: parent.widgetWidth

                            sourceComponent: {
                                const id = modelData.id || ""
                                if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput" || id === "volumeMixer" || id === "hdrToggle")
                                    return compoundPillComponent
                                if (id === "media")               return mediaPillComponent
                                if (id === "volumeSlider")        return audioSliderComponent
                                if (id === "brightnessSlider")    return brightnessSliderComponent
                                if (id === "inputVolumeSlider")   return inputAudioSliderComponent
                                if (id === "battery")             return widgetWidth <= 25 ? smallBatteryComponent : batteryPillComponent
                                if (id === "performance")         return performancePillComponent
                                return widgetWidth <= 25 ? smallToggleComponent : toggleButtonComponent
                            }
                        }
                    }
                }
            }

            // Expanded detail view
            DetailHost {
                width: parent.width
                height: active ? (root.spx(250) + Theme.spacingS) : 0
                property bool active: root.expandedSection !== "" && rowIndex === root.expandedRowIndex
                    && root.expandedSection !== "volumeMixer"
                visible: active
                expandedSection: root.expandedSection
            }
        }
    }

    // ── Compound pill (wifi, bt, audio, volumeMixer, hdr) ─────────────────
    Component {
        id: compoundPillComponent

        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            property bool isAudioWidget: (widgetData.id || "") === "audioOutput" || (widgetData.id || "") === "audioInput"
            property bool isVolumeMixerWidget: (widgetData.id || "") === "volumeMixer"
            readonly property bool volumeMixerExpanded: isVolumeMixerWidget && root.expandedSection === "volumeMixer"
                && root.expandedWidgetIndex === widgetIndex

            width: parent.width
            implicitHeight: isAudioWidget
                ? Math.max(root.spx(104), compoundCol.implicitHeight + Theme.spacingS * 2)
                : (isVolumeMixerWidget ? compoundCol.implicitHeight + Theme.spacingS * 2 : root.spx(56))
            height: implicitHeight

            property bool isActive: {
                switch (widgetData.id || "") {
                case "wifi":
                    if (NetworkService.wifiToggling) return false
                    return NetworkService.networkStatus === "ethernet" || NetworkService.networkStatus === "wifi" || NetworkService.wifiEnabled
                case "bluetooth":
                    return !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled)
                case "audioOutput":
                    return !!(AudioService.sink && !AudioService.sink.audio.muted)
                case "audioInput":
                    return !!(AudioService.source && !AudioService.source.audio.muted)
                case "volumeMixer":
                    return (ApplicationAudioService.applicationStreams || []).length > 0 || (ApplicationAudioService.applicationInputStreams || []).length > 0
                case "hdrToggle":
                    return HdrService.hdrEnabled
                default: return false
                }
            }

            // Active indicator strip on left edge
            Rectangle {
                visible: parent.isActive
                x: 0; y: Theme.cornerRadius
                width: 3
                height: parent.height - Theme.cornerRadius * 2
                radius: 2
                color: Theme.primary
                opacity: 0.8
            }

            Column {
                id: compoundCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: Theme.spacingS
                    leftMargin: Theme.spacingM
                    rightMargin: isAudioWidget ? (28 + Theme.spacingM) : Theme.spacingM
                }
                spacing: Theme.spacingXS

                // Icon + label row
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    Item {
                        width: 22; height: 22
                        Layout.alignment: Qt.AlignVCenter
                        property bool isBluetooth: (widgetData.id || "") === "bluetooth"

                        EHIcon {
                            anchors.centerIn: parent
                            name: {
                                switch (widgetData.id || "") {
                                case "wifi":
                                    if (NetworkService.wifiToggling) return "sync"
                                    if (NetworkService.networkStatus === "ethernet") return "settings_ethernet"
                                    if (NetworkService.networkStatus === "wifi") return NetworkService.wifiSignalIcon
                                    return "wifi_off"
                                case "bluetooth":
                                    if (!BluetoothService.available) return "bluetooth_disabled"
                                    if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) return "bluetooth_disabled"
                                    const primaryDev = (() => {
                                        if (!BluetoothService.adapter?.devices) return null
                                        for (let d of [...BluetoothService.adapter.devices.values.filter(d => d && (d.paired || d.trusted))]) {
                                            if (d?.connected) return d
                                        }
                                        return null
                                    })()
                                    return primaryDev ? BluetoothService.getDeviceIcon(primaryDev) : "bluetooth"
                                case "audioOutput":
                                    if (!AudioService.sink) return "volume_off"
                                    const vol = AudioService.sink.audio.volume
                                    if (AudioService.sink.audio.muted || vol === 0) return "volume_off"
                                    return vol <= 0.33 ? "volume_down" : "volume_up"
                                case "audioInput":
                                    return AudioService.source?.audio.muted ? "mic_off" : "mic"
                                case "volumeMixer":
                                    return "volume_up"
                                case "hdrToggle":
                                    return HdrService.hdrEnabled ? "hdr_on" : "hdr_off"
                                default: return widgetDef?.icon || "help"
                                }
                            }
                            size: 18
                            color: parent.parent.parent.parent.isActive ? Theme.primary : Theme.surfaceVariantText
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            visible: parent.isBluetooth
                            z: 20
                            onClicked: {
                                if (root.editMode) return
                                if (BluetoothService.available && BluetoothService.adapter)
                                    BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                            }
                        }
                    }

                    StyledText {
                        text: {
                            switch (widgetData.id || "") {
                            case "wifi":
                                if (NetworkService.wifiToggling) return NetworkService.wifiEnabled ? "Disabling…" : "Enabling…"
                                if (NetworkService.networkStatus === "ethernet") return "Ethernet"
                                if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID) {
                                    const s = NetworkService.currentWifiSSID
                                    return s.length > 14 ? s.substring(0, 14) + "…" : s
                                }
                                return NetworkService.wifiEnabled ? "Not connected" : "Wi-Fi off"
                            case "bluetooth":
                                if (!BluetoothService.available) return "Bluetooth"
                                return BluetoothService.adapter?.enabled ? "Bluetooth on" : "Disabled"
                            case "audioOutput":  return AudioService.sink?.description || "No output"
                            case "audioInput":   return AudioService.source?.description || "No input"
                            case "volumeMixer":  return "Volume Mixer"
                            case "hdrToggle":    return HdrService.hdrEnabled ? "HDR On" : "HDR Off"
                            default: return widgetDef?.text || "Unknown"
                            }
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Audio slider for output/input
                Item {
                    visible: isAudioWidget
                    width: parent.width
                    height: 14

                    EHSlider {
                        anchors.fill: parent
                        enabled: {
                            if ((widgetData.id || "") === "audioOutput") return !!(AudioService.sink?.audio)
                            if ((widgetData.id || "") === "audioInput")  return !!(AudioService.source?.audio)
                            return false
                        }
                        minimum: 0
                        maximum: 100
                        value: {
                            if ((widgetData.id || "") === "audioOutput") return AudioService.sink?.audio ? Math.min(100, Math.round(AudioService.sink.audio.volume * 100)) : 0
                            if ((widgetData.id || "") === "audioInput")  return AudioService.source?.audio ? Math.min(100, Math.round(AudioService.source.audio.volume * 100)) : 0
                            return 0
                        }
                        showValue: false
                        thumbOutlineColor: Theme.surfaceContainer
                        trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                        onSliderValueChanged: function(v) {
                            if ((widgetData.id || "") === "audioOutput") {
                                if (AudioService.sink?.audio) {
                                    SessionData.suppressOSDTemporarily()
                                    AudioService.sink.audio.volume = v / 100.0
                                    if (v > 0 && AudioService.sink.audio.muted) AudioService.sink.audio.muted = false
                                }
                            } else if ((widgetData.id || "") === "audioInput") {
                                if (AudioService.source?.audio) {
                                    SessionData.suppressOSDTemporarily()
                                    AudioService.source.audio.volume = v / 100.0
                                    if (v > 0 && AudioService.source.audio.muted) AudioService.source.audio.muted = false
                                }
                            }
                        }
                    }
                }

                // Volume mixer app list
                Column {
                    visible: isVolumeMixerWidget && !volumeMixerExpanded
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: (ApplicationAudioService.applicationStreams || []).slice(0, 2)

                        delegate: Row {
                            required property var modelData

                            property var nodeAudio: modelData?.audio ?? null
                            property real appVolume: nodeAudio?.volume ?? 0.0

                            width: parent.width
                            spacing: Theme.spacingS
                            height: 28

                            Image {
                                width: 16; height: 16
                                source: ApplicationAudioService.getApplicationIcon(modelData)
                                sourceSize.width: 64; sourceSize.height: 64
                                smooth: true; mipmap: true
                                fillMode: Image.PreserveAspectFit
                                cache: true; asynchronous: true
                                anchors.verticalCenter: parent.verticalCenter

                                EHIcon {
                                    anchors.fill: parent
                                    name: "volume_up"; size: 16
                                    color: nodeAudio && !nodeAudio.muted && appVolume > 0 ? Theme.primary : Theme.surfaceText
                                    visible: parent.status === Image.Error || parent.status === Image.Null || parent.source === ""
                                }
                            }

                            Item {
                                width: 110; height: parent.height
                                StyledText {
                                    text: ApplicationAudioService.getApplicationName(modelData)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                }
                            }

                            EHSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 16 - Theme.spacingS - 110 - Theme.spacingS
                                height: 14
                                enabled: !!(nodeAudio && modelData?.ready !== false)
                                minimum: 0; maximum: 100
                                value: Math.round(appVolume * 100)
                                showValue: false
                                thumbOutlineColor: Theme.surfaceContainer
                                trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                onSliderValueChanged: function(v) {
                                    if (nodeAudio && modelData?.ready !== false) {
                                        try { nodeAudio.volume = v / 100.0 } catch(e) {}
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: {
                            const total = (ApplicationAudioService.applicationStreams || []).length + (ApplicationAudioService.applicationInputStreams || []).length
                            return total === 0 ? "No apps" : (total > 2 ? `+${total - 2} more` : "")
                        }
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceVariantText
                        visible: {
                            const total = (ApplicationAudioService.applicationStreams || []).length + (ApplicationAudioService.applicationInputStreams || []).length
                            return total === 0 || total > 2
                        }
                        leftPadding: 20
                    }
                }

                VolumeMixer {
                    visible: isVolumeMixerWidget && volumeMixerExpanded
                    width:   parent.width
                }
            }

            // Settings / expand button (audio only; volume mixer uses title tap)
            Item {
                id: deviceSelectButton
                visible: isAudioWidget
                width: 28; height: 28
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                z: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: deviceSelectArea.containsMouse
                           ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                           : "transparent"

                    EHIcon {
                        anchors.centerIn: parent
                        name: "tune"
                        size: 15
                        color: deviceSelectArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    }

                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                }

                MouseArea {
                    id: deviceSelectArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 11
                    onClicked: {
                        if (root.editMode) return
                        const rect = compoundCol.parent
                        if (rect) {
                            const gp = rect.mapToItem(null, 0, 0)
                            root.expandClicked(widgetData, widgetIndex, gp.x, gp.y, rect.width, rect.height)
                        }
                    }
                }
            }

            // Main interaction area
            MouseArea {
                id: topSectionMouseArea
                anchors.left: parent.left
                anchors.leftMargin: (widgetData.id || "") === "bluetooth" ? (Math.max(2, Theme.cornerRadius / 2) + 22 + 2) : 0
                anchors.right: parent.right
                anchors.rightMargin: isAudioWidget ? (28 + Theme.spacingM) : 0
                anchors.top: parent.top
                height: isAudioWidget || isVolumeMixerWidget ? (Theme.spacingS + 28 + Theme.spacingXS) : parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.editMode) return
                    if (isVolumeMixerWidget) {
                        const gp = mapToItem(null, 0, 0)
                        root.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                        return
                    }
                    if (!isAudioWidget && !isVolumeMixerWidget) {
                        const gp = mapToItem(null, 0, 0)
                        root.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                    }
                }
                onPressed: (mouse) => {
                    if (root.editMode) return
                    if ((widgetData.id || "") === "bluetooth") return
                    switch (widgetData.id || "") {
                    case "wifi":
                        if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling)
                            NetworkService.toggleWifiRadio()
                        break
                    case "hdrToggle":
                        HdrService.toggleHdr()
                        break
                    }
                }
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Media ──────────────────────────────────────────────────────────────
    Component {
        id: mediaPillComponent
        MediaPill { width: parent.width; height: parent.height }
    }

    // ── Volume slider ──────────────────────────────────────────────────────
    Component {
        id: audioSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: 16

            AudioSliderRow {
                anchors.centerIn: parent
                width: parent.width; height: 14
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: true
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Brightness slider ──────────────────────────────────────────────────
    Component {
        id: brightnessSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: bs.implicitHeight

            BrightnessSliderRow { id: bs; width: parent.width }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: true
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Input volume slider ────────────────────────────────────────────────
    Component {
        id: inputAudioSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: 16

            InputAudioSliderRow {
                anchors.centerIn: parent
                width: parent.width; height: 14
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: true
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Battery (full) ─────────────────────────────────────────────────────
    Component {
        id: batteryPillComponent
        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: 56

            RowLayout {
                anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
                spacing: Theme.spacingS

                EHIcon {
                    name: BatteryService.charging ? "battery_charging_full" : (BatteryService.chargePercent < 20 ? "battery_alert" : "battery_full")
                    size: 18
                    color: BatteryService.charging ? Theme.primary : (BatteryService.chargePercent < 20 ? Theme.error : Theme.surfaceVariantText)
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: BatteryService.chargePercent ? Math.round(BatteryService.chargePercent) + "%" : "--%"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.editMode) {
                        const gp = mapToItem(null, 0, 0)
                        root.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                    }
                }
            }

            EditModeOverlay {
                anchors.fill: parent; editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Battery (small) ────────────────────────────────────────────────────
    Component {
        id: smallBatteryComponent
        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: 56

            EHIcon {
                anchors.centerIn: parent
                name: BatteryService.charging ? "battery_charging_full" : (BatteryService.chargePercent < 20 ? "battery_alert" : "battery_full")
                size: 20
                color: BatteryService.charging ? Theme.primary : (BatteryService.chargePercent < 20 ? Theme.error : Theme.surfaceVariantText)
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.editMode) {
                        const gp = mapToItem(null, 0, 0)
                        root.expandClicked(widgetData, widgetIndex, gp.x, gp.y, width, height)
                    }
                }
            }

            EditModeOverlay {
                anchors.fill: parent; editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Toggle button (full) ───────────────────────────────────────────────
    Component {
        id: toggleButtonComponent
        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width; height: 56

            property bool isActive: {
                switch (widgetData.id || "") {
                case "nightMode":     return DisplayService.nightModeEnabled || false
                case "darkMode":      return !SessionData.isLightMode
                case "doNotDisturb":  return SessionData.doNotDisturb || false
                case "idleInhibitor": return SessionService.idleInhibited || false
                default: return false
                }
            }

            Rectangle {
                visible: parent.isActive
                x: 0; y: Theme.cornerRadius
                width: 3; height: parent.height - Theme.cornerRadius * 2
                radius: 2; color: Theme.primary; opacity: 0.8
            }

            RowLayout {
                anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
                spacing: Theme.spacingS

                EHIcon {
                    name: {
                        switch (widgetData.id || "") {
                        case "nightMode":     return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                        case "darkMode":      return "contrast"
                        case "doNotDisturb":  return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                        case "idleInhibitor": return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                        default: return widgetDef?.icon || "help"
                        }
                    }
                    size: 18
                    color: parent.parent.isActive ? Theme.primary : Theme.surfaceVariantText
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: {
                        switch (widgetData.id || "") {
                        case "nightMode":     return "Night Mode"
                        case "darkMode":      return SessionData.isLightMode ? "Light" : "Dark"
                        case "doNotDisturb":  return "Do Not Disturb"
                        case "idleInhibitor": return SessionService.idleInhibited ? "Awake" : "Sleep"
                        default: return widgetDef?.text || "Unknown"
                        }
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                enabled: (widgetDef?.enabled ?? true) && !root.editMode
                onClicked: {
                    switch (widgetData.id || "") {
                    case "nightMode":     if (DisplayService.automationAvailable) DisplayService.toggleNightMode(); break
                    case "darkMode":      Theme.toggleLightMode(); break
                    case "doNotDisturb":  SessionData.setDoNotDisturb(!SessionData.doNotDisturb); break
                    case "idleInhibitor": SessionService.toggleIdleInhibit(); break
                    }
                }
            }

            EditModeOverlay {
                anchors.fill: parent; editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Toggle button (small / icon only) ─────────────────────────────────
    Component {
        id: smallToggleComponent
        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width; height: 56

            property bool isActive: {
                switch (widgetData.id || "") {
                case "nightMode":     return DisplayService.nightModeEnabled || false
                case "darkMode":      return !SessionData.isLightMode
                case "doNotDisturb":  return SessionData.doNotDisturb || false
                case "idleInhibitor": return SessionService.idleInhibited || false
                default: return false
                }
            }

            Rectangle {
                visible: parent.isActive
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.4; height: 2; radius: 1
                color: Theme.primary; opacity: 0.8
            }

            EHIcon {
                anchors.centerIn: parent
                name: {
                    switch (widgetData.id || "") {
                    case "nightMode":     return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                    case "darkMode":      return "contrast"
                    case "doNotDisturb":  return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                    case "idleInhibitor": return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                    default: return widgetDef?.icon || "help"
                    }
                }
                size: 20
                color: parent.isActive ? Theme.primary : Theme.surfaceVariantText
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                enabled: (widgetDef?.enabled ?? true) && !root.editMode
                onClicked: {
                    switch (widgetData.id || "") {
                    case "nightMode":     if (DisplayService.automationAvailable) DisplayService.toggleNightMode(); break
                    case "darkMode":      Theme.toggleLightMode(); break
                    case "doNotDisturb":  SessionData.setDoNotDisturb(!SessionData.doNotDisturb); break
                    case "idleInhibitor": SessionService.toggleIdleInhibit(); break
                    }
                }
            }

            EditModeOverlay {
                anchors.fill: parent; editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }

    // ── Performance pill ───────────────────────────────────────────────────
    Component {
        id: performancePillComponent
        CardRect {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width; height: 56

            RowLayout {
                anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
                spacing: Theme.spacingS

                EHIcon {
                    name: PerformanceService.getCurrentModeInfo().icon
                    size: 18
                    color: PerformanceService.getCurrentModeInfo().color
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: PerformanceService.isChanging ? "Changing…" : PerformanceService.getCurrentModeInfo().name
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                enabled: !root.editMode && !PerformanceService.isChanging
                onClicked: {
                    const modes = ["power-saver", "balanced", "performance"]
                    const next = (modes.indexOf(PerformanceService.currentMode) + 1) % modes.length
                    PerformanceService.setMode(modes[next])
                }
            }

            EditModeOverlay {
                anchors.fill: parent; editMode: root.editMode
                widgetData: parent.widgetData; widgetIndex: parent.widgetIndex
                showSizeControls: true; isSlider: false
                onRemoveWidget: (i) => root.removeWidget(i)
                onToggleWidgetSize: (i) => root.toggleWidgetSize(i)
                onMoveWidget: (f, t) => root.moveWidget(f, t)
            }
        }
    }
}