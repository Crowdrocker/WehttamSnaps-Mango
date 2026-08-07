import QtQuick
import QtQuick.Controls
import Quickshell.Bluetooth
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var bluetoothCodecModalRef: null
    signal showCodecSelector(var device)

    function updateDeviceCodecDisplay(deviceAddress, codecName) {
        for (let i = 0; i < pairedRepeater.count; i++) {
            const item = pairedRepeater.itemAt(i)
            if (item?.modelData?.address === deviceAddress) { item.currentCodec = codecName; break }
        }
    }

    implicitHeight: contentCol.implicitHeight + 12 * 2
    radius:       12
    antialiasing: true
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity ?? 1.0)
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1

    Column {
        id: contentCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        // ── Header ────────────────────────────────────────────────────────────
        Row {
            width:   parent.width
            height:  36
            spacing: 10

            // Icon tile — matches CompoundPill / AudioOutputPill style
            Rectangle {
                width:  36; height: 36
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                antialiasing: true
                color: (BluetoothService.available && (BluetoothService.adapter?.enabled ?? false))
                    ? Theme.primary
                    : Qt.rgba(
                        (Theme.surfaceContainer || Qt.rgba(0.1,0.1,0.1,1)).r,
                        (Theme.surfaceContainer || Qt.rgba(0.1,0.1,0.1,1)).g,
                        (Theme.surfaceContainer || Qt.rgba(0.1,0.1,0.1,1)).b,
                        Theme.popupTransparency || 0.92)
                border.color: (BluetoothService.available && (BluetoothService.adapter?.enabled ?? false))
                    ? Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)
                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                EHIcon {
                    anchors.centerIn: parent
                    name: (BluetoothService.available && (BluetoothService.adapter?.enabled ?? false))
                        ? "bluetooth" : "bluetooth_disabled"
                    size: 18
                    color: (BluetoothService.available && (BluetoothService.adapter?.enabled ?? false))
                        ? Theme.primaryContainer : Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (BluetoothService.available && BluetoothService.adapter)
                            BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                    }
                }
            }

            // Title + subtitle
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - 10 - scanBtn.width - 10
                spacing: 1

                StyledText {
                    text: "Bluetooth"
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Medium
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                }
                StyledText {
                    width: parent.width
                    text: {
                        if (!BluetoothService.available || !BluetoothService.adapter) return "No adapter"
                        if (!BluetoothService.adapter.enabled) return "Disabled"
                        if (!BluetoothService.adapter.devices) return "Enabled"
                        const connected = BluetoothService.adapter.devices.values.find(d => d?.connected)
                        if (connected) return connected.name || connected.deviceName || "Connected"
                        const count = BluetoothService.pairedDevices.length
                        return count + " paired device" + (count !== 1 ? "s" : "")
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }
            }

            // Scan button
            Rectangle {
                id: scanBtn
                width:  scanRow.implicitWidth + 12 * 2
                height: 28
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                visible: BluetoothService.adapter?.enabled ?? false
                color: scanArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: scanRow
                    anchors.centerIn: parent
                    spacing: 4

                    EHIcon {
                        name:  BluetoothService.adapter?.discovering ? "stop" : "bluetooth_searching"
                        size:  14
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text:           BluetoothService.adapter?.discovering ? "Scanning" : "Scan"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: scanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (BluetoothService.adapter) {
                            try { BluetoothService.adapter.discovering = !BluetoothService.adapter.discovering }
                            catch (e) { console.debug("Bluetooth discovery toggle failed:", e.message) }
                        }
                    }
                }
            }
        }

        // ── No adapter / disabled states ──────────────────────────────────────
        Item {
            width:   parent.width
            height:  40
            visible: !BluetoothService.adapter
            StyledText {
                anchors.centerIn: parent
                text:           "No Bluetooth adapter found"
                font.pixelSize: Theme.fontSizeSmall
                color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
            }
        }

        Item {
            width:   parent.width
            height:  40
            visible: BluetoothService.adapter && !BluetoothService.adapter.enabled
            StyledText {
                anchors.centerIn: parent
                text:           "Bluetooth is disabled"
                font.pixelSize: Theme.fontSizeSmall
                color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
            }
        }

        // ── Paired devices ────────────────────────────────────────────────────
        Repeater {
            id: pairedRepeater
            model: {
                if (!BluetoothService.adapter?.devices) return []
                let devs = [...BluetoothService.adapter.devices.values.filter(d => d && (d.paired || d.trusted))]
                devs.sort((a, b) => {
                    if (a.connected && !b.connected) return -1
                    if (!a.connected && b.connected) return 1
                    return (b.signalStrength || 0) - (a.signalStrength || 0)
                })
                return devs
            }

            delegate: Rectangle {
                required property var modelData
                property string currentCodec: BluetoothService.deviceCodecs[modelData.address] || ""

                Component.onCompleted: {
                    if (modelData.connected && BluetoothService.isAudioDevice(modelData))
                        BluetoothService.refreshDeviceCodec(modelData)
                }

                width:  contentCol.width
                height: 50
                radius: 10
                antialiasing: true
                color: {
                    if (modelData.state === BluetoothDeviceState.Connecting)
                        return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.10)
                    if (modelData.connected)
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                    return deviceArea.containsMouse
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                }
                border.color: {
                    if (modelData.state === BluetoothDeviceState.Connecting)
                        return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.50)
                    if (modelData.connected)
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                    return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                }
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Row {
                    anchors {
                        left: parent.left; leftMargin: 10
                        right: optionsBtn.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 10

                    // Device type icon tile
                    Rectangle {
                        width: 30; height: 30
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true
                        color: modelData.connected
                            ? Theme.primary
                            : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                        border.color: modelData.connected
                            ? Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.18)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        EHIcon {
                            anchors.centerIn: parent
                            name: modelData.state === BluetoothDeviceState.Connecting
                                ? "sync" : BluetoothService.getDeviceIcon(modelData)
                            size: 15
                            color: modelData.connected ? Theme.primaryContainer : Theme.primary
                        }
                    }

                    // Name + status
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30 - parent.spacing
                        spacing: 2

                        StyledText {
                            width:          parent.width
                            text:           modelData.name || modelData.deviceName || "Unknown Device"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    Font.Medium
                            color:          Theme.surfaceText
                            elide:          Text.ElideRight
                        }
                        Row {
                            spacing: 4
                            StyledText {
                                text: {
                                    if (modelData.state === BluetoothDeviceState.Connecting) return "Connecting…"
                                    if (modelData.connected) return "Connected" + (currentCodec ? " · " + currentCodec : "")
                                    return "Paired"
                                }
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: modelData.connected
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                            }
                            StyledText {
                                text: {
                                    if (modelData.batteryAvailable && modelData.battery > 0)
                                        return "· " + Math.round(modelData.battery * 100) + "%"
                                    const btBat = BatteryService.bluetoothDevices.find(d =>
                                        d.name === (modelData.name || modelData.deviceName))
                                    return btBat ? "· " + btBat.percentage + "%" : ""
                                }
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                visible: text.length > 0
                            }
                        }
                    }
                }

                EHActionButton {
                    id: optionsBtn
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    iconName:   "more_horiz"
                    buttonSize: 26
                    onClicked: {
                        if (btContextMenu.visible) btContextMenu.close()
                        else {
                            btContextMenu.currentDevice = modelData
                            btContextMenu.popup(optionsBtn, -btContextMenu.width + optionsBtn.width, optionsBtn.height + 4)
                        }
                    }
                }

                MouseArea {
                    id: deviceArea
                    anchors { fill: parent; rightMargin: optionsBtn.width + 6 }
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: modelData.connected ? modelData.disconnect() : BluetoothService.connectDeviceWithTrust(modelData)
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────
        Rectangle {
            width:   parent.width
            height:  1
            color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
            visible: pairedRepeater.count > 0 && (availableRepeater.count > 0 || (BluetoothService.adapter?.discovering ?? false))
        }

        // ── Scanning spinner ──────────────────────────────────────────────────
        Item {
            width:   parent.width
            height:  48
            visible: (BluetoothService.adapter?.discovering ?? false) && availableRepeater.count === 0

            EHIcon {
                anchors.centerIn: parent
                name:  "sync"
                size:  20
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                RotationAnimation on rotation {
                    running: parent.visible
                    loops: Animation.Infinite; from: 0; to: 360; duration: 1500
                }
            }
        }

        // ── Available devices (flickable, capped at ~4 rows) ──────────────────
        Flickable {
            width:         parent.width
            height:        Math.min(availableCol.implicitHeight, 220)
            contentHeight: availableCol.implicitHeight
            clip:          true
            visible:       availableRepeater.count > 0

            Column {
                id: availableCol
                width:   parent.width
                spacing: 8

                Repeater {
                    id: availableRepeater
                    model: {
                        if (!(BluetoothService.adapter?.discovering) || !Bluetooth.devices) return []
                        const filtered = Bluetooth.devices.values.filter(d =>
                            d && !d.paired && !d.pairing && !d.blocked &&
                            (d.signalStrength === undefined || d.signalStrength > 0))
                        return BluetoothService.sortDevices(filtered)
                    }

                    delegate: Rectangle {
                        required property var modelData
                        property bool canConnect: BluetoothService.canConnect(modelData)
                        property bool isBusy:     BluetoothService.isDeviceBusy(modelData)

                        width:   availableCol.width
                        height:  50
                        radius:  10
                        antialiasing: true
                        opacity: canConnect ? 1 : 0.5
                        color: availArea.containsMouse && !isBusy
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                            : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors {
                                left: parent.left; leftMargin: 10
                                right: pairLabel.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 10

                            Rectangle {
                                width: 30; height: 30
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                                border.width: 1

                                EHIcon {
                                    anchors.centerIn: parent
                                    name:  BluetoothService.getDeviceIcon(modelData)
                                    size:  15
                                    color: Theme.primary
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30 - parent.spacing
                                spacing: 2

                                StyledText {
                                    width:          parent.width
                                    text:           modelData.name || modelData.deviceName || "Unknown Device"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight:    Font.Medium
                                    color:          Theme.surfaceText
                                    elide:          Text.ElideRight
                                }
                                StyledText {
                                    text: modelData.pairing ? "Pairing…"
                                        : modelData.blocked ? "Blocked"
                                        : BluetoothService.getSignalStrength(modelData)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                }
                            }
                        }

                        StyledText {
                            id: pairLabel
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text:           modelData.pairing ? "Pairing…" : (canConnect ? "Pair" : "")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    Font.Medium
                            color:          Theme.primary
                        }

                        MouseArea {
                            id: availArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  canConnect && !isBusy ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled:      canConnect && !isBusy
                            onClicked:    BluetoothService.connectDeviceWithTrust(modelData)
                        }
                    }
                }
            }
        }

    } // contentCol

    // ── Context menu ──────────────────────────────────────────────────────────
    Menu {
        id: btContextMenu
        width: 150
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        property var currentDevice: null

        background: Rectangle {
            color:        Theme.popupBackground()
            radius:       Theme.cornerRadius
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text:   btContextMenu.currentDevice?.connected ? "Disconnect" : "Connect"
            height: 32
            contentItem: StyledText { text: parent.text; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; leftPadding: Theme.spacingS; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"; radius: Theme.cornerRadius / 2 }
            onTriggered: {
                if (btContextMenu.currentDevice) {
                    btContextMenu.currentDevice.connected
                        ? btContextMenu.currentDevice.disconnect()
                        : BluetoothService.connectDeviceWithTrust(btContextMenu.currentDevice)
                }
            }
        }

        MenuItem {
            text:    "Audio Codec"
            height:  visible ? 32 : 0
            visible: btContextMenu.currentDevice && BluetoothService.isAudioDevice(btContextMenu.currentDevice) && btContextMenu.currentDevice.connected
            contentItem: StyledText { text: parent.text; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; leftPadding: Theme.spacingS; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"; radius: Theme.cornerRadius / 2 }
            onTriggered: { if (btContextMenu.currentDevice) root.showCodecSelector(btContextMenu.currentDevice) }
        }

        MenuItem {
            text:   "Forget Device"
            height: 32
            contentItem: StyledText { text: parent.text; font.pixelSize: Theme.fontSizeSmall; color: Theme.error; leftPadding: Theme.spacingS; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08) : "transparent"; radius: Theme.cornerRadius / 2 }
            onTriggered: { if (btContextMenu.currentDevice) btContextMenu.currentDevice.forget() }
        }
    }
}
