pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Common

Singleton {
    id: root

    // -------------------------------------------------------------------------
    // Derived state from Quickshell.Networking
    // -------------------------------------------------------------------------

    readonly property var _wifiDev: {
        const devices = Networking.devices?.values ?? []
        return devices.find(d => d.type === DeviceType.Wifi) ?? null
    }

    readonly property var _wiredDev: {
        const devices = Networking.devices?.values ?? []
        return devices.find(d => d.type === DeviceType.Wired) ?? null
    }

    readonly property string networkStatus: {
        if (_wiredDev && _wiredDev.connected) return "ethernet"
        if (_wifiDev  && _wifiDev.connected)  return "wifi"
        return "disconnected"
    }

    // Ethernet
    readonly property bool   ethernetConnected: _wiredDev ? _wiredDev.connected : false
    readonly property string ethernetInterface: _wiredDev ? _wiredDev.name      : ""
    // IP / UUID still come from nmcli helpers below (QS doesn't expose these yet)
    property string ethernetIP:             ""
    property string ethernetConnectionUuid: ""
    // Hardware name via lspci (e.g. "AQtion AQC113 10G") — fetched when interface appears
    property string ethernetDeviceName:     ""

    // WiFi device-level
    readonly property bool   wifiConnected:  _wifiDev ? _wifiDev.connected  : false
    readonly property bool   wifiEnabled:    _wifiDev !== null
    readonly property string wifiInterface:  _wifiDev ? _wifiDev.name        : ""
    property string wifiIP:              ""
    property string wifiConnectionUuid:  ""

    // WiFi active network
    readonly property var _activeWifiNet: {
        if (!_wifiDev) return null
        const nets = _wifiDev.networks?.values ?? []
        // explicit dependency to trigger re-eval when connection state changes
        const _conn = _wifiDev.connected
        return nets.find(n => n.connected) ?? null
    }

    readonly property string currentWifiSSID:    _activeWifiNet ? _activeWifiNet.ssid     : ""
    readonly property int    wifiSignalStrength:  _activeWifiNet ? _activeWifiNet.strength : 0

    readonly property var wifiSignalIcon: {
        const s = wifiSignalStrength
        if (!wifiConnected)  return "signal_wifi_off"
        if (s >= 80)         return "signal_wifi_4_bar"
        if (s >= 60)         return "network_wifi_3_bar"
        if (s >= 40)         return "network_wifi_2_bar"
        if (s >= 20)         return "network_wifi_1_bar"
        return "signal_wifi_0_bar"
    }

    // WiFi network list — built from Quickshell WifiDevice
    readonly property var wifiNetworks: {
        if (!_wifiDev) return []
        const nets = _wifiDev.networks?.values ?? []
        // explicit dependency to trigger re-eval when connection state changes
        const _conn = _wifiDev.connected
        return nets.map(n => ({
            ssid:      n.ssid,
            signal:    n.strength,
            secured:   n.security !== WifiSecurityType.None,
            connected: n.connected,
            saved:     savedWifiSsids.indexOf(n.ssid) !== -1
        })).sort((a, b) => b.signal - a.signal)
    }

    // -------------------------------------------------------------------------
    // Action-related state (unchanged from original)
    // -------------------------------------------------------------------------

    property var    savedConnections:    []
    property var    ssidToConnectionName: ({})
    property string userPreference:      "auto"
    property bool   isConnecting:        false
    property string connectingSSID:      ""
    property string connectionError:     ""
    property bool   isScanning:          false
    property bool   autoScan:            false
    property bool   wifiAvailable:       true
    property bool   changingPreference:  false
    property string targetPreference:    ""
    property var    savedWifiNetworks:   []
    property var    savedWifiSsids:      []
    property string connectionStatus:    ""
    property string lastConnectionError: ""
    property bool   passwordDialogShouldReopen: false
    property bool   autoRefreshEnabled:  false
    property string wifiPassword:        ""
    property string forgetSSID:          ""
    property string networkInfoSSID:     ""
    property string networkInfoDetails:  ""
    property bool   networkInfoLoading:  false

    signal networksUpdated
    signal connectionChanged

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]

    // -------------------------------------------------------------------------
    // Ref-counting (kept for compatibility)
    // -------------------------------------------------------------------------

    property int refCount: 0

    function addRef() {
        refCount++
        if (refCount === 1) _loadSavedConnections()
    }

    function removeRef() {
        if (refCount > 0) refCount--
    }

    // -------------------------------------------------------------------------
    // React to Quickshell network state changes
    // -------------------------------------------------------------------------

    property var _deviceTrigger: Networking.devices
    on_DeviceTriggerChanged: root.connectionChanged()

    Connections {
        target: root._wifiDev
        ignoreUnknownSignals: true
        function onNetworksChanged() { root.networksUpdated() }
        function onConnectedChanged() { root.connectionChanged() }
    }

    Connections {
        target: root._wiredDev
        ignoreUnknownSignals: true
        function onConnectedChanged() { root.connectionChanged() }
    }

    // Trigger IP/UUID refresh when connection state changes
    onConnectionChanged: _refreshIpAndUuid()

    // Fetch hardware name when wired interface becomes known
    onEthernetInterfaceChanged: {
        if (ethernetInterface !== "") _fetchEthernetDeviceName()
    }

    // -------------------------------------------------------------------------
    // Supplemental nmcli helpers (IP, UUID, saved connections — not in QS API)
    // -------------------------------------------------------------------------

    function _fetchEthernetDeviceName() {
        ethernetDeviceNameFetcher.command = lowPriorityCmd.concat([
            "bash", "-c",
            "pci=$(cat /sys/class/net/" + ethernetInterface + "/device/uevent 2>/dev/null" +
            " | grep PCI_SLOT_NAME | cut -d= -f2 | cut -c6-);" +
            " if [ -n \"$pci\" ]; then lspci | grep -i ethernet | grep \"$pci\"" +
            " | sed 's/.*: //' | sed 's/Aquantia Corp. //' | sed 's/ NBase-T.*/ 10G/'" +
            " | cut -c1-20; fi"
        ])
        ethernetDeviceNameFetcher.running = true
    }

    Process {
        id: ethernetDeviceNameFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (name !== "") root.ethernetDeviceName = name
            }
        }
    }

    function _refreshIpAndUuid() {
        ipFetcher.running = true
    }

    function _loadSavedConnections() {
        savedConnectionLoader.running = true
    }

    // Fetch IPs and UUIDs via nmcli
    Process {
        id: ipFetcher
        running: false
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f",
            "DEVICE,TYPE,STATE,IP4.ADDRESS,CONNECTION,CONNECTION-UUID",
            "device", "show"])
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                let device = "", type = "", state = "", ip = "", conn = "", uuid = ""
                const flush = () => {
                    if (type === "ethernet" && state === "connected") {
                        root.ethernetIP             = ip.split("/")[0] ?? ""
                        root.ethernetConnectionUuid = uuid
                        // ethernetDeviceName comes from lspci, not nmcli
                    } else if (type === "wifi" && state === "connected") {
                        root.wifiIP             = ip.split("/")[0] ?? ""
                        root.wifiConnectionUuid = uuid
                    }
                }
                for (const line of lines) {
                    const [key, val] = line.split(":").map(s => s.trim())
                    if (!key) { flush(); device = type = state = ip = conn = uuid = ""; continue }
                    if (key === "GENERAL.DEVICE")      device = val
                    if (key === "GENERAL.TYPE")        type   = val
                    if (key === "GENERAL.STATE")       state  = val.includes("connected") ? "connected" : val
                    if (key === "IP4.ADDRESS[1]")      ip     = val
                    if (key === "GENERAL.CONNECTION")  conn   = val
                    if (key === "GENERAL.CON-PATH")    {} // ignore
                    if (key === "GENERAL.CON-UUID")    uuid   = val
                }
                flush()
            }
        }
    }

    // Load saved wifi connections
    Process {
        id: savedConnectionLoader
        running: false
        command: lowPriorityCmd.concat(["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE",
            "connection", "show"])
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = []
                const nameMap = {}
                for (const line of text.split("\n")) {
                    if (!line) continue
                    const parts = line.split(":")
                    if (parts.length < 4) continue
                    const [name, uuid, type] = parts
                    if (type === "802-11-wireless") {
                        saved.push({ ssid: name, uuid })
                        nameMap[name] = name
                    }
                }
                root.savedConnections  = saved
                root.savedWifiSsids    = saved.map(s => s.ssid)
                root.savedWifiNetworks = saved
                root.ssidToConnectionName = nameMap
            }
        }
    }

    // -------------------------------------------------------------------------
    // Scan
    // -------------------------------------------------------------------------

    function scanWifi() {
        if (!_wifiDev || root.isScanning) return
        root.isScanning = true
        wifiScanner.running = true
    }

    function scanWifiNetworks() { scanWifi() }

    Process {
        id: wifiScanner
        running: false
        command: lowPriorityCmd.concat(["nmcli", "dev", "wifi", "rescan"])
        onExited: {
            root.isScanning = false
            // Quickshell WifiDevice auto-updates its networks list via NM DBus
            root.networksUpdated()
        }
    }

    function startAutoScan() {
        root.autoScan = true
        autoScanTimer.start()
    }

    function stopAutoScan() {
        root.autoScan = false
        autoScanTimer.stop()
    }

    Timer {
        id: autoScanTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: if (root.autoScan) root.scanWifi()
    }

    // -------------------------------------------------------------------------
    // Connect / Disconnect / Forget / Toggle radio
    // -------------------------------------------------------------------------

    function connectToWifi(ssid, password) {
        if (root.isConnecting) return
        root.isConnecting  = true
        root.connectingSSID = ssid
        root.connectionError = ""
        root.connectionStatus = "connecting"

        if (!password && root.ssidToConnectionName[ssid]) {
            wifiConnector.command = lowPriorityCmd.concat(
                ["nmcli", "connection", "up", root.ssidToConnectionName[ssid]])
        } else if (password) {
            wifiConnector.command = lowPriorityCmd.concat(
                ["nmcli", "dev", "wifi", "connect", ssid, "password", password])
        } else {
            wifiConnector.command = lowPriorityCmd.concat(
                ["nmcli", "dev", "wifi", "connect", ssid])
        }
        wifiConnector.running = true
    }

    Process {
        id: wifiConnector
        running: false
        property bool connectionSucceeded: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("successfully")) {
                    wifiConnector.connectionSucceeded = true
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionError  = ""
                    root.connectionStatus = "connected"
                    if (root.userPreference === "wifi" || root.userPreference === "auto")
                        root.setConnectionPriority("wifi")
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.connectionError     = text
                root.lastConnectionError = text
                if (!wifiConnector.connectionSucceeded && text.trim() !== "") {
                    if (text.includes("password") || text.includes("authentication")) {
                        root.connectionStatus = "invalid_password"
                        root.passwordDialogShouldReopen = true
                    } else {
                        root.connectionStatus = "failed"
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0 || wifiConnector.connectionSucceeded) {
                if (!wifiConnector.connectionSucceeded) {
                    ToastService.showInfo(`Connected to ${root.connectingSSID}`)
                    root.connectionStatus = "connected"
                }
            } else {
                if (root.connectionStatus === "")
                    root.connectionStatus = "failed"
                if (root.connectionStatus === "invalid_password")
                    ToastService.showError(`Invalid password for ${root.connectingSSID}`)
                else
                    ToastService.showError(`Failed to connect to ${root.connectingSSID}`)
            }
            wifiConnector.connectionSucceeded = false
            root.isConnecting  = false
            root.connectingSSID = ""
            root._refreshIpAndUuid()
        }
    }

    function disconnectWifi() {
        if (!root.wifiInterface) return
        wifiDisconnector.command = lowPriorityCmd.concat(
            ["nmcli", "dev", "disconnect", root.wifiInterface])
        wifiDisconnector.running = true
    }

    Process {
        id: wifiDisconnector
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("Disconnected from WiFi")
                root.connectionStatus = ""
                root._refreshIpAndUuid()
                root.scanWifi()
            }
        }
    }

    function forgetWifiNetwork(ssid) {
        root.forgetSSID = ssid
        const connName = root.ssidToConnectionName[ssid] || ssid
        networkForgetter.command = lowPriorityCmd.concat(
            ["nmcli", "connection", "delete", connName])
        networkForgetter.running = true
    }

    Process {
        id: networkForgetter
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo(`Forgot network ${root.forgetSSID}`)
                root.savedConnections  = root.savedConnections.filter(s => s.ssid !== root.forgetSSID)
                root.savedWifiNetworks = root.savedWifiNetworks.filter(s => s.ssid !== root.forgetSSID)
                root.savedWifiSsids    = root.savedWifiSsids.filter(s => s !== root.forgetSSID)
                root.networksUpdated()
            }
            root.forgetSSID = ""
        }
    }

    function toggleWifiRadio() {
        // Use Networking.wifiEnabled setter directly — no nmcli process needed
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function enableWifiDevice() {
        if (!root.wifiInterface) return
        Quickshell.execDetached(["nmcli", "dev", "set", root.wifiInterface, "managed", "yes"])
    }

    // -------------------------------------------------------------------------
    // Preference / priority helpers (unchanged logic, still use nmcli)
    // -------------------------------------------------------------------------

    function setNetworkPreference(preference) {
        root.userPreference = preference
        if (preference === "wifi")     setConnectionPriority("wifi")
        else if (preference === "ethernet") setConnectionPriority("ethernet")
    }

    function setConnectionPriority(type) {
        if (!root.wifiConnectionUuid && !root.ethernetConnectionUuid) return
        if (type === "wifi" && root.wifiConnectionUuid) {
            Quickshell.execDetached(lowPriorityCmd.concat(
                ["nmcli", "connection", "modify", root.wifiConnectionUuid,
                 "ipv4.route-metric", "100"]))
        } else if (type === "ethernet" && root.ethernetConnectionUuid) {
            Quickshell.execDetached(lowPriorityCmd.concat(
                ["nmcli", "connection", "modify", root.ethernetConnectionUuid,
                 "ipv4.route-metric", "100"]))
        }
    }

    function connectToWifiAndSetPreference(ssid, password) {
        root.userPreference = "wifi"
        connectToWifi(ssid, password)
    }

    function toggleNetworkConnection(type) {
        if (type === "wifi") {
            if (root.wifiConnected) disconnectWifi()
            else scanWifi()
        } else if (type === "ethernet") {
            if (root.ethernetConnected)
                Quickshell.execDetached(lowPriorityCmd.concat(
                    ["nmcli", "dev", "disconnect", root.ethernetInterface]))
        }
    }

    // -------------------------------------------------------------------------
    // Network info popup helper
    // -------------------------------------------------------------------------

    function fetchNetworkInfo(ssid) {
        root.networkInfoSSID    = ssid
        root.networkInfoDetails = ""
        root.networkInfoLoading = true
        networkInfoFetcher.command = lowPriorityCmd.concat(
            ["nmcli", "-t", "-f", "SSID,SIGNAL,FREQ,SECURITY,BSSID",
             "dev", "wifi", "list"])
        networkInfoFetcher.running = true
    }

    function getNetworkInfo(ssid) {
        const network = root.wifiNetworks.find(n => n.ssid === ssid)
        if (!network) return {}
        return {
            ssid:     ssid,
            signal:   network.signal,
            security: network.security,
            saved:    network.saved
        }
    }

    Process {
        id: networkInfoFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l)
                const bands = []
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 5) continue
                    const [ssid, signal, freq, security, bssid] = parts
                    if (ssid !== root.networkInfoSSID) continue
                    const band = freq.includes("5") ? "5 GHz" : "2.4 GHz"
                    bands.push({ band, signal: parseInt(signal) || 0, bssid, security })
                }
                bands.sort((a, b) => b.signal - a.signal)
                let details = ""
                for (const b of bands) {
                    const connected = b.bssid === root._activeWifiNet?.bssid
                    details += (connected ? "● " : "  ") +
                        b.band + (connected ? " (Connected)" : "") +
                        " - " + b.signal + "%\n"
                }
                root.networkInfoDetails = details.trim()
                root.networkInfoLoading = false
            }
        }
        onExited: exitCode => { if (exitCode !== 0) root.networkInfoLoading = false }
    }

    // -------------------------------------------------------------------------
    // Advanced connection config (DNS, IP, IPv6, proxy, MTU, MAC)
    // These still use nmcli — QS has no write API for these
    // -------------------------------------------------------------------------

    function setDnsServers(connectionName, primaryDns, secondaryDns) {
        const dns = secondaryDns ? `${primaryDns},${secondaryDns}` : primaryDns
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "modify", connectionName, "ipv4.dns", dns]))
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    function setIpv4Config(connectionName, method, address, gateway) {
        const args = ["nmcli", "connection", "modify", connectionName,
                      "ipv4.method", method]
        if (method === "manual") {
            args.push("ipv4.addresses", address, "ipv4.gateway", gateway)
        }
        Quickshell.execDetached(lowPriorityCmd.concat(args))
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    function setIpv6Config(connectionName, method, address, gateway) {
        const args = ["nmcli", "connection", "modify", connectionName,
                      "ipv6.method", method]
        if (method === "manual") {
            args.push("ipv6.addresses", address, "ipv6.gateway", gateway)
        }
        Quickshell.execDetached(lowPriorityCmd.concat(args))
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    function setProxyConfig(connectionName, method, httpProxy, httpsProxy, ftpProxy, socksProxy, noProxy) {
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "modify", connectionName,
             "proxy.method", method,
             "proxy.browser-only", "no"]))
        if (method !== "none") {
            if (httpProxy)  Quickshell.execDetached(lowPriorityCmd.concat(
                ["nmcli", "connection", "modify", connectionName, "proxy.pac-url", httpProxy]))
        }
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    function setMtu(connectionName, mtu) {
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "modify", connectionName,
             "ethernet.mtu", String(mtu)]))
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    function setClonedMac(connectionName, macAddress) {
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "modify", connectionName,
             "ethernet.cloned-mac-address", macAddress]))
        Quickshell.execDetached(lowPriorityCmd.concat(
            ["nmcli", "connection", "up", connectionName]))
    }

    // -------------------------------------------------------------------------
    // Compat stubs (were internal impl details, kept so nothing breaks)
    // -------------------------------------------------------------------------

    function refreshNetworkState()   { _refreshIpAndUuid() }
    function initializeDBusMonitors() {}
    function updatePrimaryConnection() {}
    function updateDeviceStates()    {}
    function updateActiveConnections() {}
    function updateWifiState()       {}
}
