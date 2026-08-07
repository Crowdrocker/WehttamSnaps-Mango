import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: bluetoothTab

    Component.onCompleted: {
        if (BluetoothService && BluetoothService.adapter && BluetoothService.adapter.enabled) {
            BluetoothService.adapter.discovering = true
        }
    }

    Component.onDestruction: {
        if (BluetoothService && BluetoothService.adapter && BluetoothService.adapter.discovering) {
            BluetoothService.adapter.discovering = false
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // ADAPTER
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: adapterSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: adapterSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "bluetooth"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - toggleSwitch.width - Theme.spacingM * 2
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Bluetooth"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: BluetoothService.available
                                    ? (BluetoothService.enabled ? "Enabled" : "Disabled")
                                    : "Not Available"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        Rectangle {
                            id: toggleSwitch
                            width: 48
                            height: 28
                            radius: 14
                            color: BluetoothService.enabled ? Theme.primary : Theme.surfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                            visible: BluetoothService.available

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                x: BluetoothService.enabled ? 20 : 4
                                Behavior on x { NumberAnimation { duration: 200 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (BluetoothService.adapter) {
                                        BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: BluetoothService.discovering ? "Scanning for devices..." : "Tap to scan for devices"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: BluetoothService.enabled
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // PAIRED DEVICES
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: pairedDevicesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: BluetoothService.enabled && BluetoothService.pairedDevices && BluetoothService.pairedDevices.length > 0

                Column {
                    id: pairedDevicesSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "bluetooth_connected"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Paired Devices"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: BluetoothService.pairedDevices || []

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: deviceRow.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: deviceMouseArea.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                                border.color: modelData.connected ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: modelData.connected ? 2 : 1

                                RowLayout {
                                    id: deviceRow
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top; anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    EHIcon {
                                        name: BluetoothService.getDeviceIcon(modelData)
                                        size: Theme.iconSize
                                        color: modelData.connected ? Theme.primary : Theme.surfaceText
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: modelData.name || modelData.deviceName || "Unknown Device"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: modelData.connected ? Font.Medium : Font.Normal
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: modelData.connected ? "Connected" : "Paired"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                visible: modelData.batteryAvailable && modelData.battery > 0
                                            }
                                            StyledText {
                                                text: modelData.battery + "%"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                visible: modelData.batteryAvailable && modelData.battery > 0
                                            }
                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                visible: modelData.signalStrength > 0
                                            }
                                            EHIcon {
                                                name: BluetoothService.getSignalIcon(modelData)
                                                size: 14
                                                color: Theme.surfaceVariantText
                                                visible: modelData.signalStrength > 0
                                            }
                                        }
                                    }

                                    Row {
                                        spacing: Theme.spacingS

                                        Rectangle {
                                            width: connectButtonText.implicitWidth + Theme.spacingM * 2
                                            height: 32
                                            radius: 16
                                            color: connectButtonMouseArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                : "transparent"
                                            border.color: modelData.connected ? Theme.error : Theme.primary
                                            border.width: 1
                                            visible: !BluetoothService.isDeviceBusy(modelData)

                                            StyledText {
                                                id: connectButtonText
                                                anchors.centerIn: parent
                                                text: modelData.connected ? "Disconnect" : "Connect"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: modelData.connected ? Theme.error : Theme.primary
                                            }

                                            MouseArea {
                                                id: connectButtonMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.connected) modelData.disconnect()
                                                    else BluetoothService.connectDeviceWithTrust(modelData)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: forgetButtonText.implicitWidth + Theme.spacingM * 2
                                            height: 32
                                            radius: 16
                                            color: forgetButtonMouseArea.containsMouse
                                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
                                                : "transparent"
                                            border.color: Theme.error
                                            border.width: 1
                                            visible: !BluetoothService.isDeviceBusy(modelData)

                                            StyledText {
                                                id: forgetButtonText
                                                anchors.centerIn: parent
                                                text: "Forget"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.error
                                            }

                                            MouseArea {
                                                id: forgetButtonMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.forget()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: deviceMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: !BluetoothService.isDeviceBusy(modelData) ? 180 : 0
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.connected) modelData.disconnect()
                                        else BluetoothService.connectDeviceWithTrust(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // AVAILABLE DEVICES
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: availableDevicesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: BluetoothService.enabled

                Column {
                    id: availableDevicesSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM

                        EHIcon {
                            name: "bluetooth_searching"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Available Devices"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.iconSize - refreshButton.width - Theme.spacingM * 2
                        }

                        EHActionButton {
                            id: refreshButton
                            iconName: "refresh"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.primary
                            circular: true
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !BluetoothService.discovering
                            onClicked: {
                                if (BluetoothService.adapter && BluetoothService.adapter.enabled) {
                                    BluetoothService.adapter.discovering = true
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: BluetoothService.devices && BluetoothService.devices.values

                        Repeater {
                            model: {
                                if (!BluetoothService.devices || !BluetoothService.devices.values) return []
                                return BluetoothService.sortDevices(
                                    BluetoothService.devices.values.filter(dev => dev && !dev.paired && !dev.trusted)
                                )
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: availableDeviceRow.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: availableDeviceMouseArea.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, index % 2 === 0 ? 0.3 : 0.2)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 1

                                RowLayout {
                                    id: availableDeviceRow
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top; anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    EHIcon {
                                        name: BluetoothService.getDeviceIcon(modelData)
                                        size: Theme.iconSize
                                        color: Theme.surfaceText
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: modelData.name || modelData.deviceName || "Unknown Device"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: BluetoothService.getSignalStrength(modelData)
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                            EHIcon {
                                                name: BluetoothService.getSignalIcon(modelData)
                                                size: 14
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: pairButtonText.implicitWidth + Theme.spacingM * 2
                                        height: 32
                                        radius: 16
                                        color: pairButtonMouseArea.containsMouse
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            : "transparent"
                                        border.color: Theme.primary
                                        border.width: 1
                                        visible: !BluetoothService.isDeviceBusy(modelData) && BluetoothService.canConnect(modelData)

                                        StyledText {
                                            id: pairButtonText
                                            anchors.centerIn: parent
                                            text: "Connect"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                        }

                                        MouseArea {
                                            id: pairButtonMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: BluetoothService.connectDeviceWithTrust(modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: availableDeviceMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: !BluetoothService.isDeviceBusy(modelData) && BluetoothService.canConnect(modelData) ? 40 : 0
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!BluetoothService.isDeviceBusy(modelData) && BluetoothService.canConnect(modelData)) {
                                            BluetoothService.connectDeviceWithTrust(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: "No devices found. Make sure your device is in pairing mode and tap the refresh button."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        visible: !BluetoothService.devices || !BluetoothService.devices.values ||
                                 BluetoothService.devices.values.filter(dev => dev && !dev.paired && !dev.trusted).length === 0
                    }
                }
            }
        }
    }
}
