import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals

Item {
    id: networkTab

    property var parentModal: null

    property bool dnsMethodAuto: true
    property int ipv4MethodIndex: 0
    property int ipv6MethodIndex: 0
    property int proxyMethodIndex: 0
    property int macAddressIndex: 0

    // Section collapse state
    property bool ethernetExpanded: true
    property bool vpnExpanded: true
    property bool dnsExpanded: false
    property bool ipExpanded: false
    property bool proxyExpanded: false
    property bool advancedExpanded: false

    ConnectionEditModal { id: connectionEditModal }
    VpnAddModal { id: vpnAddModal }
    NetworkAddModal { id: networkAddModal }

    function getVpnAddModal() { return vpnAddModal }
    function getConnectionEditModal() { return connectionEditModal }

    function deleteVpnConnection(uuid, name) {
        deleteVpnProcess.command = ["nmcli", "connection", "delete", "uuid", uuid]
        deleteVpnProcess.running = true
        deleteVpnProcess.connectionName = name
    }

    Process {
        id: deleteVpnProcess
        running: false
        command: []
        property string connectionName: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("VPN '" + connectionName + "' deleted")
                if (VpnService) VpnService.refreshAll()
            } else {
                ToastService.showError("Failed to delete VPN connection")
            }
        }
    }

    Process {
        id: addEthernetProcess
        running: false
        command: ["nmcli", "connection", "add", "type", "ethernet", "con-name", "Ethernet", "ifname", "*"]
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("New ethernet connection created")
                NetworkService.refreshNetworkState()
            } else {
                ToastService.showError("Failed to create ethernet connection")
            }
        }
    }

    Process {
        id: findEthernetConnection
        running: false
        command: ["bash", "-c",
            "ETH_CONN=$(nmcli -t -f NAME,UUID connection show | grep ':802-3-ethernet$' | cut -d: -f1 | head -1); " +
            "ETH_UUID=$(nmcli -t -f NAME,UUID connection show | grep ':802-3-ethernet$' | cut -d: -f2 | head -1); " +
            "if [ -n \"$ETH_CONN\" ]; then echo \"$ETH_CONN:$ETH_UUID\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(':')
                if (parts.length >= 2) connectionEditModal.show(parts[0], parts[1])
            }
        }
    }

    Component.onCompleted: {
        if (NetworkService) {
            NetworkService.refreshNetworkState()
            if (NetworkService.wifiEnabled) NetworkService.scanWifiNetworks()
        }
    }

    // ── Reusable inline components ─────────────────────────────────────────

    // Pill segmented control
    component SegmentedControl: Rectangle {
        id: segCtrl
        property var options: []
        property int selectedIndex: 0
        signal selectionChanged(int idx)

        implicitWidth: segRow.implicitWidth + 6
        implicitHeight: segRow.implicitHeight + 6
        radius: Theme.cornerRadius * 0.75
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        border.width: 1

        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: segCtrl.options
                Rectangle {
                    property bool sel: segCtrl.selectedIndex === index
                    property bool hov: segMa.containsMouse
                    width: segLbl.implicitWidth + Theme.spacingM * 2
                    height: Math.max(segLbl.implicitHeight + Theme.spacingXS * 2, 28)
                    radius: Theme.cornerRadius * 0.6
                    color: sel ? Theme.primary : (hov ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }

                    StyledText {
                        id: segLbl
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: sel ? Font.Medium : Font.Normal
                        color: sel ? Theme.onPrimary : Theme.surfaceText
                    }
                    MouseArea {
                        id: segMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: segCtrl.selectionChanged(index)
                    }
                }
            }
        }
    }

    // Labelled text field
    component FieldRow: RowLayout {
        property string label: ""
        property string placeholder: ""
        property alias fieldText: fi.text
        property int labelWidth: 110
        width: parent ? parent.width : 0
        spacing: Theme.spacingM

        StyledText {
            text: label; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65
            Layout.preferredWidth: labelWidth; Layout.alignment: Qt.AlignVCenter
        }
        Rectangle {
            Layout.fillWidth: true; height: 34
            radius: Theme.cornerRadius * 0.5
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
            border.width: fi.activeFocus ? 1 : 0; border.color: Theme.primary
            Behavior on border.width { NumberAnimation { duration: Theme.shorterDuration } }

            TextField {
                id: fi; anchors.fill: parent
                anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS
                font.pixelSize: Theme.fontSizeSmall; placeholderText: placeholder
                background: Rectangle { color: "transparent" }
                color: Theme.surfaceText
            }
        }
    }

    // Primary filled button
    component PrimaryButton: Rectangle {
        id: pb
        property string label: "Apply"
        signal clicked
        property bool hov: pbMa.containsMouse
        implicitWidth: pbLbl.implicitWidth + Theme.spacingL * 2; implicitHeight: 34
        radius: Theme.cornerRadius * 0.5
        color: hov ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85) : Theme.primary
        Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
        StyledText { id: pbLbl; anchors.centerIn: parent; text: pb.label; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.onPrimary }
        MouseArea { id: pbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }

    // Ghost outlined button
    component GhostButton: Rectangle {
        id: gb
        property string label: ""
        property color labelColor: Theme.surfaceText
        signal clicked
        property bool hov: gbMa.containsMouse
        implicitWidth: gbLbl.implicitWidth + Theme.spacingL * 2; implicitHeight: 34
        radius: Theme.cornerRadius * 0.5
        color: hov ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35) : "transparent"
        border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
        Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
        StyledText { id: gbLbl; anchors.centerIn: parent; text: gb.label; font.pixelSize: Theme.fontSizeSmall; color: gb.labelColor }
        MouseArea { id: gbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gb.clicked() }
    }

    // Section card wrapper — collapsible
    component SectionCard: Item {
        id: sc
        property string iconName: ""
        property string title: ""
        property bool expanded: true
        signal toggleRequested
        default property alias headerExtra: headerExtraSlot.data
        property alias bodySlot: bodyContainer.data

        width: parent ? parent.width : 0
        height: scRect.height

        Rectangle {
            id: scRect
            width: parent.width
            height: scInner.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

            Column {
                id: scInner
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: Theme.spacingL
                spacing: 0

                RowLayout {
                    width: parent.width; height: 36; spacing: Theme.spacingM
                    EHIcon { name: sc.iconName; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                    StyledText { text: sc.title; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }
                    Item { Layout.fillWidth: true }
                    Item { id: headerExtraSlot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height; Layout.alignment: Qt.AlignVCenter }
                    Item {
                        width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                        EHIcon { anchors.centerIn: parent; name: sc.expanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sc.toggleRequested() }
                    }
                }

                Item {
                    width: parent.width
                    height: sc.expanded ? bodyContainer.implicitHeight + Theme.spacingM : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: bodyContainer
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingM
                    }
                }
            }
        }
    }

    // ── Main scrollable layout ─────────────────────────────────────────────

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingM

            // ─────────────── ETHERNET ────────────────────────────────────
            Item {
                width: parent.width
                height: ethRect.height

                Rectangle {
                    id: ethRect
                    width: parent.width
                    height: ethInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: ethInner
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL
                        spacing: 0

                        // Header
                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM

                            EHIcon { name: "cable"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }

                            StyledText {
                                text: "Ethernet"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Status dot
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                Layout.alignment: Qt.AlignVCenter
                                color: NetworkService.ethernetConnected ? "#4CAF50" : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.22)
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }

                            Item { Layout.fillWidth: true }

                             // New connection button
                             GhostButton {
                                 label: "+ New Connection"; implicitHeight: 30
                                 Layout.alignment: Qt.AlignVCenter
                                 onClicked: networkAddModal.show()
                             }

                            Item {
                                width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.ethernetExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.ethernetExpanded = !networkTab.ethernetExpanded }
                            }
                        }

                        // Collapsible body
                        Item {
                            width: parent.width
                            height: networkTab.ethernetExpanded ? ethBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: ethBody
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                // No device state
                                Item {
                                    width: parent.width
                                    height: 40
                                    visible: NetworkService.ethernetInterface === ""
                                    Row {
                                        anchors.centerIn: parent; spacing: Theme.spacingS
                                        EHIcon { name: "info"; size: 16; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35); anchors.verticalCenter: parent.verticalCenter }
                                        StyledText { text: "No ethernet device detected"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.4; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }

                                // Device card
                                Rectangle {
                                    width: parent.width
                                    height: ethDevRow.implicitHeight + Theme.spacingM * 2
                                    radius: Theme.cornerRadius * 0.6
                                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                    visible: NetworkService.ethernetInterface !== ""

                                    RowLayout {
                                        id: ethDevRow
                                        anchors.left: parent.left; anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                        spacing: Theme.spacingM

                                        Column {
                                            Layout.fillWidth: true; spacing: 3

                                            Row {
                                                spacing: Theme.spacingS

                                                StyledText {
                                                    text: NetworkService.ethernetDeviceName || NetworkService.ethernetInterface || "Ethernet"
                                                    font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Status pill
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: ethPillLbl.implicitWidth + 10; height: ethPillLbl.implicitHeight + 4
                                                    radius: height / 2
                                                    color: NetworkService.ethernetConnected
                                                        ? Qt.rgba(0.298, 0.686, 0.314, 0.15)
                                                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                                                    Behavior on color { ColorAnimation { duration: 300 } }

                                                    StyledText {
                                                        id: ethPillLbl; anchors.centerIn: parent
                                                        text: NetworkService.ethernetConnected ? "Connected" : "Disconnected"
                                                        font.pixelSize: 11
                                                        color: NetworkService.ethernetConnected ? "#4CAF50" : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                                    }
                                                }
                                            }

                                            // Sub-row: interface + IP (only when connected)
                                            Row {
                                                spacing: Theme.spacingS; visible: NetworkService.ethernetConnected
                                                StyledText { text: NetworkService.ethernetInterface; font.pixelSize: Theme.fontSizeSmall; opacity: 0.45 }
                                                StyledText { text: "·"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.25; visible: NetworkService.ethernetIP !== "" }
                                                StyledText { text: NetworkService.ethernetIP; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; opacity: 0.85; visible: NetworkService.ethernetIP !== "" }
                                            }
                                        }

                                        // Edit (only when connected)
                                        GhostButton {
                                            label: "Edit"; implicitHeight: 30
                                            visible: NetworkService.ethernetConnected
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                if (NetworkService.ethernetConnectionUuid)
                                                    connectionEditModal.show("", NetworkService.ethernetConnectionUuid)
                                                else
                                                    findEthernetConnection.running = true
                                            }
                                        }

                                        // Connect / Disconnect — contextual style
                                        Rectangle {
                                            id: ethBtn
                                            property bool isConn: NetworkService.ethernetConnected
                                            property bool hov: ethBtnMa.containsMouse
                                            implicitWidth: ethBtnLbl.implicitWidth + Theme.spacingL * 2
                                            implicitHeight: 30
                                            radius: Theme.cornerRadius * 0.5
                                            Layout.alignment: Qt.AlignVCenter

                                            // Disconnect = outlined destructive; Connect = filled primary
                                            color: isConn
                                                ? (hov ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent")
                                                : (hov ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85) : Theme.primary)

                                            border.width: isConn ? 1 : 0
                                            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.55)

                                            Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }

                                            StyledText {
                                                id: ethBtnLbl; anchors.centerIn: parent
                                                text: ethBtn.isConn ? "Disconnect" : "Connect"
                                                font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                                                color: ethBtn.isConn ? Theme.error : Theme.onPrimary
                                            }

                                            MouseArea {
                                                id: ethBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: NetworkService.toggleNetworkConnection("ethernet")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── VPN ─────────────────────────────────────────
            Item {
                width: parent.width
                height: vpnRect.height

                Rectangle {
                    id: vpnRect
                    width: parent.width
                    height: vpnInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: vpnInner
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL
                        spacing: 0

                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM

                            EHIcon { name: "vpn_key"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                            StyledText { text: "VPN"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }

                            Rectangle {
                                visible: VpnService && VpnService.activeConnections && VpnService.activeConnections.length > 0
                                width: vpnBadge.implicitWidth + 8; height: vpnBadge.implicitHeight + 4; radius: height / 2
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18); Layout.alignment: Qt.AlignVCenter
                                StyledText { id: vpnBadge; anchors.centerIn: parent; text: VpnService && VpnService.activeConnections ? VpnService.activeConnections.length.toString() : "0"; font.pixelSize: 11; color: Theme.primary }
                            }

                            Item { Layout.fillWidth: true }

                            GhostButton {
                                label: "+ Add VPN"; implicitHeight: 30; Layout.alignment: Qt.AlignVCenter
                                onClicked: { const m = getVpnAddModal(); if (m) m.show() }
                            }

                            Item {
                                width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.vpnExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.vpnExpanded = !networkTab.vpnExpanded }
                            }
                        }

                        Item {
                            width: parent.width
                            height: networkTab.vpnExpanded ? vpnBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: vpnBody
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                // Active connections
                                Column {
                                    width: parent.width; spacing: Theme.spacingXS
                                    visible: VpnService && VpnService.activeConnections && VpnService.activeConnections.length > 0

                                    StyledText { text: "ACTIVE"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2; opacity: 0.4; bottomPadding: 2 }

                                    Repeater {
                                        model: VpnService ? VpnService.activeConnections : []
                                        Rectangle {
                                            width: parent.width
                                            height: vpnActiveRow.implicitHeight + Theme.spacingM * 2
                                            radius: Theme.cornerRadius * 0.6
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
                                            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

                                            RowLayout {
                                                id: vpnActiveRow
                                                anchors.left: parent.left; anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                                spacing: Theme.spacingM

                                                Rectangle { width: 8; height: 8; radius: 4; color: "#4CAF50"; Layout.alignment: Qt.AlignVCenter }

                                                Column {
                                                    Layout.fillWidth: true; spacing: 2
                                                    StyledText { text: modelData.name || "Unknown"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium }
                                                    Row {
                                                        spacing: Theme.spacingS
                                                        StyledText { text: modelData.state || "active"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.5 }
                                                        StyledText { text: VpnService && modelData.uuid ? "· " + VpnService.getConnectionDuration(modelData.uuid) : ""; font.pixelSize: Theme.fontSizeSmall; opacity: 0.5; visible: text !== "" }
                                                    }
                                                }

                                                // Disconnect — outlined destructive
                                                Rectangle {
                                                    property bool hov: dActMa.containsMouse
                                                    implicitWidth: dActLbl.implicitWidth + Theme.spacingL * 2; implicitHeight: 28
                                                    radius: Theme.cornerRadius * 0.5; Layout.alignment: Qt.AlignVCenter
                                                    color: hov ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent"
                                                    border.width: 1; border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.5)
                                                    Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
                                                    StyledText { id: dActLbl; anchors.centerIn: parent; text: "Disconnect"; font.pixelSize: Theme.fontSizeSmall; color: Theme.error }
                                                    MouseArea { id: dActMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (VpnService) VpnService.disconnect(modelData.uuid || modelData.name) } }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Divider
                                Rectangle {
                                    width: parent.width; height: 1
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                    visible: VpnService && VpnService.activeConnections && VpnService.activeConnections.length > 0
                                             && VpnService.profiles && VpnService.profiles.length > 0
                                }

                                // Profiles
                                Column {
                                    width: parent.width; spacing: Theme.spacingXS

                                    StyledText { text: "PROFILES"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2; opacity: 0.4; bottomPadding: 2 }

                                    Repeater {
                                        model: VpnService ? VpnService.profiles : []
                                        Rectangle {
                                            width: parent.width
                                            height: vpnProfRow.implicitHeight + Theme.spacingM * 2
                                            radius: Theme.cornerRadius * 0.6
                                            color: vpnProfHov.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                            border.width: VpnService && VpnService.isActiveUuid(modelData.uuid) ? 1 : 0
                                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                            Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
                                            MouseArea { id: vpnProfHov; anchors.fill: parent; hoverEnabled: true }

                                            RowLayout {
                                                id: vpnProfRow
                                                anchors.left: parent.left; anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                                spacing: Theme.spacingM

                                                EHIcon { name: "vpn_key"; size: 18; opacity: 0.55; Layout.alignment: Qt.AlignVCenter }

                                                Column {
                                                    Layout.fillWidth: true; spacing: 2
                                                    StyledText { text: modelData.name || "Unknown"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium }
                                                    Row {
                                                        spacing: Theme.spacingXS
                                                        StyledText { text: modelData.type || "vpn"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.5 }
                                                        StyledText { text: modelData.serviceType ? " · " + modelData.serviceType : ""; font.pixelSize: Theme.fontSizeSmall; opacity: 0.5 }
                                                    }
                                                }

                                                EHActionButton {
                                                    buttonSize: 28; circular: true
                                                    iconName: (modelData.autoconnect || false) ? "link" : "link_off"; iconSize: 15
                                                    iconColor: (modelData.autoconnect || false) ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    onClicked: {
                                                        if (VpnService) {
                                                            const ns = !(modelData.autoconnect || false)
                                                            VpnService.setAutoconnect(modelData.uuid, ns)
                                                            ToastService.showInfo((ns ? "Auto-connect on: " : "Auto-connect off: ") + modelData.name)
                                                        }
                                                    }
                                                }

                                                GhostButton {
                                                    label: "Edit"; implicitHeight: 28; Layout.alignment: Qt.AlignVCenter
                                                    visible: !(VpnService && VpnService.isActiveUuid(modelData.uuid))
                                                    onClicked: { const m = getConnectionEditModal(); if (m) m.show(modelData.name, modelData.uuid) }
                                                }

                                                EHActionButton {
                                                    buttonSize: 28; circular: true; iconName: "delete"; iconSize: 15
                                                    iconColor: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.65)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    visible: !(VpnService && VpnService.isActiveUuid(modelData.uuid))
                                                    onClicked: deleteVpnConnection(modelData.uuid, modelData.name)
                                                }

                                                // Connect / Disconnect toggle
                                                Rectangle {
                                                    property bool isActive: VpnService && VpnService.isActiveUuid(modelData.uuid)
                                                    property bool hov: vpnCMa.containsMouse
                                                    implicitWidth: vpnCLbl.implicitWidth + Theme.spacingL * 2; implicitHeight: 28
                                                    radius: Theme.cornerRadius * 0.5; Layout.alignment: Qt.AlignVCenter
                                                    color: isActive
                                                        ? (hov ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent")
                                                        : (hov ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85) : Theme.primary)
                                                    border.width: isActive ? 1 : 0
                                                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.5)
                                                    Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
                                                    StyledText { id: vpnCLbl; anchors.centerIn: parent; text: parent.isActive ? "Disconnect" : "Connect"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: parent.isActive ? Theme.error : Theme.onPrimary }
                                                    MouseArea {
                                                        id: vpnCMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { if (VpnService) { if (VpnService.isActiveUuid(modelData.uuid)) VpnService.disconnect(modelData.uuid); else VpnService.connect(modelData.uuid) } }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: "No VPN profiles configured"
                                        font.pixelSize: Theme.fontSizeSmall; opacity: 0.4
                                        visible: !VpnService || !VpnService.profiles || VpnService.profiles.length === 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── DNS ─────────────────────────────────────────
            Item {
                width: parent.width; height: dnsRect.height
                Rectangle {
                    id: dnsRect; width: parent.width
                    height: dnsInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: dnsInner; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL; spacing: 0

                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM
                            EHIcon { name: "dns"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                            StyledText { text: "DNS"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }
                            Item { Layout.fillWidth: true }
                            Item { width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.dnsExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.dnsExpanded = !networkTab.dnsExpanded }
                            }
                        }

                        Item {
                            width: parent.width
                            height: networkTab.dnsExpanded ? dnsBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: dnsBody; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM; spacing: Theme.spacingM

                                RowLayout {
                                    width: parent.width
                                    StyledText { text: "Method"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                    Item { Layout.fillWidth: true }
                                    SegmentedControl { options: ["Automatic", "Manual"]; selectedIndex: networkTab.dnsMethodAuto ? 0 : 1; onSelectionChanged: idx => networkTab.dnsMethodAuto = (idx === 0); Layout.alignment: Qt.AlignVCenter }
                                }

                                Column {
                                    width: parent.width; spacing: Theme.spacingS; visible: !networkTab.dnsMethodAuto
                                    FieldRow { id: dnsPrimary; label: "Primary DNS"; placeholder: "8.8.8.8" }
                                    FieldRow { id: dnsSecondary; label: "Secondary DNS"; placeholder: "8.8.4.4" }
                                    Row {
                                        spacing: Theme.spacingS; topPadding: Theme.spacingXS
                                        StyledText { text: "Presets:"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
                                        Repeater {
                                            model: [
                                                { name: "Cloudflare", primary: "1.1.1.1", secondary: "1.0.0.1" },
                                                { name: "Google", primary: "8.8.8.8", secondary: "8.8.4.4" },
                                                { name: "Quad9", primary: "9.9.9.9", secondary: "149.112.112.112" },
                                                { name: "OpenDNS", primary: "208.67.222.222", secondary: "208.67.220.220" }
                                            ]
                                            GhostButton {
                                                label: modelData.name; implicitHeight: 28
                                                onClicked: { dnsPrimary.fieldText = modelData.primary; dnsSecondary.fieldText = modelData.secondary }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    width: parent.width; Item { Layout.fillWidth: true }
                                    PrimaryButton {
                                        label: "Apply DNS"
                                        onClicked: {
                                            if (!networkTab.dnsMethodAuto && dnsPrimary.fieldText.trim()) {
                                                NetworkService.setDnsServers("", dnsPrimary.fieldText.trim(), dnsSecondary.fieldText.trim())
                                            } else {
                                                const cn = NetworkService.networkStatus === "wifi" ? NetworkService.wifiConnectionUuid
                                                         : NetworkService.networkStatus === "ethernet" ? NetworkService.ethernetConnectionUuid : ""
                                                if (cn) { Quickshell.execDetached(["nmcli", "connection", "modify", cn, "ipv4.dns", "", "ipv4.dns-search", ""]); ToastService.showInfo("DNS reset to automatic") }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── IP CONFIGURATION ────────────────────────────
            Item {
                width: parent.width; height: ipRect.height
                Rectangle {
                    id: ipRect; width: parent.width
                    height: ipInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: ipInner; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL; spacing: 0

                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM
                            EHIcon { name: "settings_ethernet"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                            StyledText { text: "IP Configuration"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }
                            Item { Layout.fillWidth: true }
                            Item { width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.ipExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.ipExpanded = !networkTab.ipExpanded }
                            }
                        }

                        Item {
                            width: parent.width
                            height: networkTab.ipExpanded ? ipBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: ipBody; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM; spacing: Theme.spacingL

                                // IPv4
                                Column {
                                    width: parent.width; spacing: Theme.spacingM
                                    StyledText { text: "IPv4"; font.pixelSize: Math.round(isFinite(Theme.fontSizeMedium) ? Theme.fontSizeMedium : 14); font.weight: Font.SemiBold }
                                    RowLayout {
                                        width: parent.width
                                        StyledText { text: "Method"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                        Item { Layout.fillWidth: true }
                                        SegmentedControl { options: ["Automatic", "Manual", "Link-Local"]; selectedIndex: networkTab.ipv4MethodIndex; onSelectionChanged: idx => networkTab.ipv4MethodIndex = idx; Layout.alignment: Qt.AlignVCenter }
                                    }
                                    Column {
                                        width: parent.width; spacing: Theme.spacingS; visible: networkTab.ipv4MethodIndex === 1
                                        FieldRow { id: ipv4Addr; label: "IP Address"; placeholder: "192.168.1.100/24" }
                                        FieldRow { id: ipv4Gw; label: "Gateway"; placeholder: "192.168.1.1" }
                                    }
                                    RowLayout { width: parent.width; Item { Layout.fillWidth: true }
                                        PrimaryButton { label: "Apply IPv4"; onClicked: { const m = networkTab.ipv4MethodIndex === 0 ? "auto" : networkTab.ipv4MethodIndex === 1 ? "manual" : "link-local"; NetworkService.setIpv4Config("", m, networkTab.ipv4MethodIndex === 1 ? ipv4Addr.fieldText.trim() : "", networkTab.ipv4MethodIndex === 1 ? ipv4Gw.fieldText.trim() : "") } }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1) }

                                // IPv6
                                Column {
                                    width: parent.width; spacing: Theme.spacingM
                                    StyledText { text: "IPv6"; font.pixelSize: Math.round(isFinite(Theme.fontSizeMedium) ? Theme.fontSizeMedium : 14); font.weight: Font.SemiBold }
                                    RowLayout {
                                        width: parent.width
                                        StyledText { text: "Method"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                        Item { Layout.fillWidth: true }
                                        SegmentedControl { options: ["Automatic", "Manual", "Ignore"]; selectedIndex: networkTab.ipv6MethodIndex; onSelectionChanged: idx => networkTab.ipv6MethodIndex = idx; Layout.alignment: Qt.AlignVCenter }
                                    }
                                    Column {
                                        width: parent.width; spacing: Theme.spacingS; visible: networkTab.ipv6MethodIndex === 1
                                        FieldRow { id: ipv6Addr; label: "IPv6 Address"; placeholder: "2001:db8::1/64" }
                                        FieldRow { id: ipv6Gw; label: "Gateway"; placeholder: "2001:db8::1" }
                                    }
                                    RowLayout { width: parent.width; Item { Layout.fillWidth: true }
                                        PrimaryButton { label: "Apply IPv6"; onClicked: { const m = networkTab.ipv6MethodIndex === 0 ? "auto" : networkTab.ipv6MethodIndex === 1 ? "manual" : "ignore"; NetworkService.setIpv6Config("", m, networkTab.ipv6MethodIndex === 1 ? ipv6Addr.fieldText.trim() : "", networkTab.ipv6MethodIndex === 1 ? ipv6Gw.fieldText.trim() : "") } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── PROXY ───────────────────────────────────────
            Item {
                width: parent.width; height: proxyRect.height
                Rectangle {
                    id: proxyRect; width: parent.width
                    height: proxyInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: proxyInner; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL; spacing: 0

                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM
                            EHIcon { name: "swap_horiz"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                            StyledText { text: "Proxy"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }
                            Item { Layout.fillWidth: true }
                            Item { width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.proxyExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.proxyExpanded = !networkTab.proxyExpanded }
                            }
                        }

                        Item {
                            width: parent.width
                            height: networkTab.proxyExpanded ? proxyBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: proxyBody; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM; spacing: Theme.spacingM

                                RowLayout {
                                    width: parent.width
                                    StyledText { text: "Method"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                    Item { Layout.fillWidth: true }
                                    SegmentedControl { options: ["None", "Manual", "Automatic"]; selectedIndex: networkTab.proxyMethodIndex; onSelectionChanged: idx => networkTab.proxyMethodIndex = idx; Layout.alignment: Qt.AlignVCenter }
                                }

                                Column {
                                    width: parent.width; spacing: Theme.spacingS; visible: networkTab.proxyMethodIndex === 1
                                    FieldRow { id: httpProxy; label: "HTTP Proxy"; placeholder: "proxy.example.com:8080" }
                                    FieldRow { id: httpsProxy; label: "HTTPS Proxy"; placeholder: "proxy.example.com:8080" }
                                    FieldRow { id: ftpProxy; label: "FTP Proxy"; placeholder: "proxy.example.com:21" }
                                    FieldRow { id: socksProxy; label: "SOCKS Proxy"; placeholder: "proxy.example.com:1080" }
                                    FieldRow { id: noProxy; label: "No Proxy"; placeholder: "localhost,127.0.0.1,*.local" }
                                }

                                Column {
                                    width: parent.width; spacing: Theme.spacingS; visible: networkTab.proxyMethodIndex === 2
                                    FieldRow { id: pacUrl; label: "PAC URL"; placeholder: "http://proxy.example.com/proxy.pac" }
                                }

                                RowLayout { width: parent.width; Item { Layout.fillWidth: true }
                                    PrimaryButton {
                                        label: "Apply Proxy"
                                        onClicked: {
                                            const m = networkTab.proxyMethodIndex === 0 ? "none" : networkTab.proxyMethodIndex === 1 ? "manual" : "auto"
                                            if (m === "manual") NetworkService.setProxyConfig("", m, httpProxy.fieldText.trim(), httpsProxy.fieldText.trim(), ftpProxy.fieldText.trim(), socksProxy.fieldText.trim(), noProxy.fieldText.trim())
                                            else NetworkService.setProxyConfig("", m, "", "", "", "", "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── ADVANCED ────────────────────────────────────
            Item {
                width: parent.width; height: advRect.height
                Rectangle {
                    id: advRect; width: parent.width
                    height: advInner.implicitHeight + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                    Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                    Column {
                        id: advInner; anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.margins: Theme.spacingL; spacing: 0

                        RowLayout {
                            width: parent.width; height: 36; spacing: Theme.spacingM
                            EHIcon { name: "tune"; size: 18; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                            StyledText { text: "Advanced"; font.pixelSize: Math.round(isFinite(Theme.fontSizeLarge) ? Theme.fontSizeLarge : 16); font.weight: Font.SemiBold; Layout.alignment: Qt.AlignVCenter }
                            Item { Layout.fillWidth: true }
                            Item { width: 28; height: 28; Layout.alignment: Qt.AlignVCenter
                                EHIcon { anchors.centerIn: parent; name: networkTab.advancedExpanded ? "expand_less" : "expand_more"; size: 18; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45) }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: networkTab.advancedExpanded = !networkTab.advancedExpanded }
                            }
                        }

                        Item {
                            width: parent.width
                            height: networkTab.advancedExpanded ? advBody.implicitHeight + Theme.spacingM : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.InOutQuad } }

                            Column {
                                id: advBody; anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.topMargin: Theme.spacingM; spacing: Theme.spacingL

                                // MTU
                                Column {
                                    width: parent.width; spacing: Theme.spacingM
                                    StyledText { text: "MTU"; font.pixelSize: Math.round(isFinite(Theme.fontSizeMedium) ? Theme.fontSizeMedium : 14); font.weight: Font.SemiBold }
                                    RowLayout {
                                        width: parent.width; spacing: Theme.spacingM
                                        StyledText { text: "Value"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                        Rectangle {
                                            width: 120; height: 34; radius: Theme.cornerRadius * 0.5
                                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
                                            border.width: mtuInput.activeFocus ? 1 : 0; border.color: Theme.primary
                                             TextField {
                                                 id: mtuInput
                                                 anchors.fill: parent
                                                 anchors.margins: Theme.spacingS
                                                 font.pixelSize: Theme.fontSizeSmall
                                                 placeholderText: "1500"
                                                 validator: IntValidator { bottom: 576; top: 9000 }
                                                 background: Rectangle { color: "transparent" }
                                                 color: Theme.surfaceText
                                             }
                                        }
                                        StyledText { text: "576 – 9000"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.38; Layout.alignment: Qt.AlignVCenter }
                                        Item { Layout.fillWidth: true }
                                        PrimaryButton { label: "Apply MTU"; onClicked: { if (mtuInput.text.trim()) { const v = parseInt(mtuInput.text.trim()); if (v >= 576 && v <= 9000) NetworkService.setMtu("", v); else ToastService.showError("MTU must be 576 – 9000"); } } }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1) }

                                // MAC Address
                                Column {
                                    width: parent.width; spacing: Theme.spacingM
                                    StyledText { text: "MAC Address"; font.pixelSize: Math.round(isFinite(Theme.fontSizeMedium) ? Theme.fontSizeMedium : 14); font.weight: Font.SemiBold }
                                    RowLayout {
                                        width: parent.width
                                        StyledText { text: "Mode"; font.pixelSize: Theme.fontSizeSmall; opacity: 0.65; Layout.alignment: Qt.AlignVCenter }
                                        Item { Layout.fillWidth: true }
                                        SegmentedControl { options: ["Default", "Cloned"]; selectedIndex: networkTab.macAddressIndex; onSelectionChanged: idx => networkTab.macAddressIndex = idx; Layout.alignment: Qt.AlignVCenter }
                                    }
                                    FieldRow { id: clonedMac; label: "Cloned MAC"; placeholder: "aa:bb:cc:dd:ee:ff"; visible: networkTab.macAddressIndex === 1 }
                                    RowLayout { width: parent.width; Item { Layout.fillWidth: true }
                                        PrimaryButton { label: "Apply MAC"; onClicked: { if (networkTab.macAddressIndex === 0) NetworkService.setClonedMac("", ""); else if (clonedMac.fieldText.trim()) NetworkService.setClonedMac("", clonedMac.fieldText.trim()) } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
