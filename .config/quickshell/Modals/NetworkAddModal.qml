import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import qs.Widgets as Widgets

Widgets.FloatingWindow {
    id: root

    function close() {
        visible = false
    }

    function open() {
        reset()
        visible = true
    }

    property string connectionName: ""
    property string selectedDevice: ""
    property int ipv4Method: 0  // 0: auto, 1: manual
    property var availableDevices: ["Any (auto)"]
    property string ipv4Address: ""
    property string ipv4Gateway: ""
    property string ipv4Dns: ""
    property int ipv6Method: 0  // 0: auto, 1: manual
    property string ipv6Address: ""
    property string ipv6Gateway: ""
    property string ipv6Dns: ""

    property bool creating: false
    property string errorMessage: ""

    function show() {
        reset()
        deviceLister.running = true
        visible = true
    }

    function reset() {
        connectionName = ""
        selectedDevice = ""
        ipv4Method = 0
        ipv4Address = ""
        ipv4Gateway = ""
        ipv4Dns = ""
        ipv6Method = 0
        ipv6Address = ""
        ipv6Gateway = ""
        ipv6Dns = ""
        creating = false
        errorMessage = ""
    }

    function addConnection() {
        if (!connectionName.trim()) {
            errorMessage = "Connection name is required"
            return
        }
        if (!selectedDevice.trim()) {
            errorMessage = "Device is required"
            return
        }

        errorMessage = ""
        creating = true

        const device = (selectedDevice === "Any (auto)" || selectedDevice === "Any") ? "*" : selectedDevice.trim()
        let cmd = ["nmcli", "connection", "add", "type", "ethernet", "ifname", device, "con-name", connectionName.trim()]

        if (ipv4Method === 0) {
            cmd.push("ipv4.method", "auto")
        } else {
            cmd.push("ipv4.method", "manual")
            if (ipv4Address.trim()) {
                cmd.push("ipv4.addresses", ipv4Address.trim())
            }
            if (ipv4Gateway.trim()) {
                cmd.push("ipv4.gateway", ipv4Gateway.trim())
            }
            if (ipv4Dns.trim()) {
                cmd.push("ipv4.dns", ipv4Dns.trim())
            }
        }

        if (ipv6Method === 0) {
            cmd.push("ipv6.method", "auto")
        } else {
            cmd.push("ipv6.method", "manual")
            if (ipv6Address.trim()) {
                cmd.push("ipv6.addresses", ipv6Address.trim())
            }
            if (ipv6Gateway.trim()) {
                cmd.push("ipv6.gateway", ipv6Gateway.trim())
            }
            if (ipv6Dns.trim()) {
                cmd.push("ipv6.dns", ipv6Dns.trim())
            }
        }

        addConnectionProcess.command = cmd
        addConnectionProcess.running = true
    }

    visible: false
    title: "Add Network Connection"
    width: 600
    height: 700
    backgroundColor: Theme.surfaceContainer

    Widgets.FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }

    FocusScope {
        id: contentScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            root.close()
            event.accepted = true
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            clip: true

            Item {
                width: parent.width
                height: 48

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "settings_ethernet"
                        size: Theme.iconSize
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Add Network Connection"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Configure a new ethernet connection"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item { Layout.fillWidth: true }

                    EHActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineVariant
                opacity: 0.5
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: "Connection Name"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                EHTextField {
                    width: parent.width
                    height: 40
                    placeholderText: "My Ethernet Connection"
                    text: root.connectionName
                    onTextChanged: root.connectionName = text
                }

                StyledText {
                    text: "Network Interface"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                EHDropdown {
                    width: parent.width
                    text: "Network Interface"
                    options: root.availableDevices
                    currentValue: root.selectedDevice
                    onValueChanged: root.selectedDevice = value
                }

                StyledText {
                    text: "IPv4 Configuration"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: ["Automatic", "Manual"]

                        Rectangle {
                            property bool isSelected: root.ipv4Method === index

                            width: (parent.width - Theme.spacingS) / 2
                            height: 32
                            radius: Theme.cornerRadius * 0.5
                            color: isSelected ? Theme.primary : Theme.surfaceContainer
                            border.width: 1
                            border.color: isSelected ? Theme.primary : Theme.outlineVariant

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: isSelected ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.ipv4Method = index
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: root.ipv4Method === 1

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "IP Address"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHTextField {
                                width: parent.width
                                height: 40
                                placeholderText: "192.168.1.100/24"
                                text: root.ipv4Address
                                onTextChanged: root.ipv4Address = text
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Gateway"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHTextField {
                                width: parent.width
                                height: 40
                                placeholderText: "192.168.1.1"
                                text: root.ipv4Gateway
                                onTextChanged: root.ipv4Gateway = text
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "DNS Servers"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHTextField {
                            width: parent.width
                            height: 40
                            placeholderText: "8.8.8.8,8.8.4.4"
                            text: root.ipv4Dns
                            onTextChanged: root.ipv4Dns = text
                        }
                    }
                }

                StyledText {
                    text: "IPv6 Configuration"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: ["Automatic", "Manual"]

                        Rectangle {
                            property bool isSelected: root.ipv6Method === index

                            width: (parent.width - Theme.spacingS) / 2
                            height: 32
                            radius: Theme.cornerRadius * 0.5
                            color: isSelected ? Theme.primary : Theme.surfaceContainer
                            border.width: 1
                            border.color: isSelected ? Theme.primary : Theme.outlineVariant

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: isSelected ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.ipv6Method = index
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: root.ipv6Method === 1

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "IP Address"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHTextField {
                                width: parent.width
                                height: 40
                                placeholderText: "2001:db8::1/32"
                                text: root.ipv6Address
                                onTextChanged: root.ipv6Address = text
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Gateway"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHTextField {
                                width: parent.width
                                height: 40
                                placeholderText: "2001:db8::1"
                                text: root.ipv6Gateway
                                onTextChanged: root.ipv6Gateway = text
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "DNS Servers"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHTextField {
                            width: parent.width
                            height: 40
                            placeholderText: "2001:4860:4860::8888"
                            text: root.ipv6Dns
                            onTextChanged: root.ipv6Dns = text
                        }
                    }
                }

                StyledText {
                    text: root.errorMessage
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    visible: root.errorMessage !== ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 80
                        height: 40
                        radius: Theme.cornerRadius * 0.5
                        color: cancelMouseArea.containsMouse ? Theme.surfaceContainer : "transparent"
                        border.width: 1
                        border.color: Theme.outlineVariant

                        StyledText {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: cancelMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 40
                        radius: Theme.cornerRadius * 0.5
                        color: addMouseArea.containsMouse ? Theme.primaryContainer : Theme.primary
                        visible: !root.creating

                        StyledText {
                            anchors.centerIn: parent
                            text: "Add"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onPrimary
                        }

                        MouseArea {
                            id: addMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addConnection()
                        }
                    }

                    Item {
                        width: 80
                        height: 40
                        visible: root.creating

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            EHIcon {
                                name: "sync"
                                size: 16
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: root.creating
                                }
                            }

                            StyledText {
                                text: "Adding..."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: deviceLister
        running: false
        command: ["nmcli", "-t", "-f", "TYPE,DEVICE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devices = ["Any (auto)"]
                for (const line of text.split("\n")) {
                    if (!line) continue
                    const [type, name] = line.split(":")
                    if (type === "ethernet" && name) devices.push(name)
                }
                root.availableDevices = devices
            }
        }
    }

    Process {
        id: addConnectionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("successfully")) {
                    root.creating = false
                    ToastService.showInfo("Network connection created successfully")
                    root.close()
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.errorMessage = "Failed: " + text.trim()
            }
        }

        onExited: function(exitCode) {
            root.creating = false
            if (exitCode !== 0 && root.errorMessage === "") {
                root.errorMessage = "Failed to create connection (exit code " + exitCode + ")"
            }
        }
    }
}