pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Services

Singleton {
    id: root

    // ── UPower CLI scrape (GNOME extension style) ────────────────────────────
    // Some bluetooth devices expose battery to UPower but not via the Quickshell UPower model.
    // This mirrors: `upower -e` + `upower -i <dev>` parsing.
    property var _upowerScrapedDevices: []
    // Debug/health info for the scrape pipeline
    property int  upowerScrapeCount: 0
    property int  upowerScrapeExitCode: -999
    property string upowerScrapeLastRun: ""
    property var upowerScrapePaths: []
    property string upowerScrapeFirstModel: ""
    property string upowerScrapeFirstPercentage: ""
    property string upowerScrapeFirstJson: ""

    function _parsePercent(value) {
        if (value === undefined || value === null) return -1
        const s = ("" + value).trim()
        const m = s.match(/(\d+)\s*%/)
        if (m && m[1] !== undefined) return Math.max(0, Math.min(100, parseInt(m[1], 10)))
        // Sometimes UPower provides a raw float fraction in some outputs
        const n = Number(s)
        if (!Number.isNaN(n)) {
            if (n > 0 && n <= 1) return Math.round(n * 100)
            if (n >= 0 && n <= 100) return Math.round(n)
        }
        return -1
    }

    function refreshUpowerScrape() {
        if (upowerProbe.running) return
        upowerProbe.running = true
    }

    Timer {
        id: upowerRefreshTimer
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.refreshUpowerScrape()
    }

    Component.onCompleted: refreshUpowerScrape()

    Process {
        id: upowerProbe
        // Print blocks prefixed with a device marker so we can parse without bash JSON building.
        command: [
            "sh", "-c",
            "upower -e 2>/dev/null | while read -r dev; do " +
            "  echo \"===DEVICE $dev\"; " +
            "  upower -i \"$dev\" 2>/dev/null; " +
            "done"
        ]

        property var devices: []
        property var current: null

        onStarted: {
            devices = []
            current = null
        }

        onExited: (exitCode, exitStatus) => {
            // flush last device block
            if (current) devices = devices.concat([current])
            // Store parsed results even if empty; avoids stale data
            root._upowerScrapedDevices = devices
            root.upowerScrapeCount = (devices && devices.length) ? devices.length : 0
            root.upowerScrapeExitCode = exitCode
            root.upowerScrapeLastRun = (new Date()).toLocaleString()
            root.upowerScrapePaths = (devices || []).map(d => d?.path || "")
            root.upowerScrapeFirstModel = (devices && devices.length) ? String(devices[0]?.model || "") : ""
            root.upowerScrapeFirstPercentage = (devices && devices.length) ? String(devices[0]?.percentage || "") : ""
            try {
                const s = (devices && devices.length) ? JSON.stringify(devices[0]) : ""
                root.upowerScrapeFirstJson = s ? s.slice(0, 240) : ""
            } catch (e) {
                root.upowerScrapeFirstJson = ""
            }
            // Ensure future refresh cycles can run and bindings re-evaluate cleanly
            current = null
            upowerProbe.running = false
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: lineRaw => {
                // Avoid String.trimEnd() (not available in this QML JS runtime)
                const line = ("" + lineRaw).replace(/\s+$/, "")
                if (line.startsWith("===DEVICE ")) {
                    // flush previous
                    if (upowerProbe.current) upowerProbe.devices = upowerProbe.devices.concat([upowerProbe.current])
                    upowerProbe.current = { path: line.substring("===DEVICE ".length).trim() }
                    return
                }
                if (!upowerProbe.current) return

                // Some UPower blocks (e.g. phones) indent fields; be extra-tolerant.
                // If we ever miss the generic key:value parse below, still capture percentage/model.
                const pctM = line.match(/percentage:\s*([0-9]+%)/i)
                if (pctM && pctM[1]) upowerProbe.current["percentage"] = pctM[1]
                const modelM = line.match(/model:\s*(.+)\s*$/i)
                if (modelM && modelM[1]) upowerProbe.current["model"] = modelM[1].trim()

                const m = line.match(/^\s*([^:]+):\s*(.*)\s*$/)
                if (!m) return
                const key = (m[1] || "").trim().toLowerCase().replace(/\s+/g, "_")
                const value = (m[2] || "").trim()
                upowerProbe.current[key] = value
            }
        }
    }

    readonly property UPowerDevice device: {
        UPower.devices.values.find(dev => dev.isLaptopBattery) || null
    }
    readonly property bool batteryAvailable: device && device.ready

    // FIX: device.percentage is already 0-100. Original code did * 100 → wrong (e.g. 85 → 8500).
    readonly property real batteryLevel: batteryAvailable ? Math.round(device.percentage) : 0

    // FIX: some devices report changeRate == 0 even while charging; drop that guard.
    readonly property bool isCharging: batteryAvailable && device.state === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: batteryAvailable && (device.state !== UPowerDeviceState.Discharging && device.state !== UPowerDeviceState.Empty)
    readonly property bool isLowBattery: batteryAvailable && batteryLevel <= 20
    readonly property string batteryHealth: {
        if (!batteryAvailable) {
            return "N/A"
        }

        if (device.healthSupported && device.healthPercentage > 0) {
            return `${Math.round(device.healthPercentage)}%`
        }

        return "N/A"
    }
    readonly property real batteryCapacity: batteryAvailable && device.energyCapacity > 0 ? device.energyCapacity : 0
    readonly property string batteryStatus: {
        if (!batteryAvailable) {
            return "No Battery"
        }

        if (device.state === UPowerDeviceState.Charging && device.changeRate <= 0) {
            return "Plugged In"
        }

        return UPowerDeviceState.toString(device.state)
    }
    readonly property bool suggestPowerSaver: batteryAvailable && isLowBattery && UPower.onBattery && (typeof PowerProfiles !== "undefined" && PowerProfiles.profile !== PowerProfile.PowerSaver)

    // Devices other than the system laptop battery.
    // Includes Bluetooth (via UPower/CLI/BlueZ) and other UPower-powered devices (phones, UPS, etc).
    readonly property var devices: {
        const out = []
        const seen = new Set()

        // Prefer the CLI scrape when available, because it's the most reliable for phones/controllers.
        const scraped = root._upowerScrapedDevices || []
        for (let k = 0; k < scraped.length; k++) {
            const d = scraped[k]
            if (!d) continue
            if (String(d.path || "").includes("DisplayDevice")) continue
            const pct2 = root._parsePercent(d.percentage)
            // Allow 0% (still useful) but skip unknown
            if (pct2 < 0) continue

            const name = (d.model || d.native_path || d.vendor || "Device").trim()
            const key3 = (d.native_path || "").trim() || (d.serial || "").trim() || name || d.path || ("" + k)
            if (seen.has(key3)) continue
            seen.add(key3)

            out.push({
                       "name": name,
                       "percentage": pct2,
                       "type": (d.type || "upower_cli")
                   })
        }

        for (var i = 0; i < UPower.devices.count; i++) {
            const dev = UPower.devices.get(i)
            if (!dev || !dev.ready) continue
            if (dev.isLaptopBattery) continue
            // Skip aggregate / non-physical devices
            if (dev.nativePath && String(dev.nativePath).includes("DisplayDevice")) continue
            if (UPowerDeviceType.toString(dev.type).toLowerCase().includes("linepower")) continue

            // Include if it has meaningful percentage data. (Some devices report 0..1)
            const pct = Math.round((dev.percentage > 0 && dev.percentage <= 1) ? (dev.percentage * 100) : dev.percentage)
            if (!(pct > 0 && pct <= 100)) continue

            const key = dev.nativePath || dev.serial || dev.model || dev.objectPath || ("upower_" + i)
            if (seen.has(key)) continue
                seen.add(key)
                out.push({
                                   "name": dev.model || dev.vendor || UPowerDeviceType.toString(dev.type),
                                   "percentage": pct,
                                   // Store as a string so UI icon mapping works reliably
                                   "type": UPowerDeviceType.toString(dev.type)
                               })
        }

        // Fallback: some devices (incl. DualSense on some stacks) expose battery via BlueZ Battery1
        // but do not show up in UPower's device list. Quickshell.Bluetooth surfaces that as
        // `batteryAvailable` / `battery` on Bluetooth devices.
        // BlueZ devices: include paired/trusted devices even when battery is unknown,
        // so UI can show the device tile (percentage = -1 means unknown).
        const adapter = (typeof BluetoothService !== "undefined") ? BluetoothService.adapter : null
        const all = adapter?.devices?.values || []
        for (let j = 0; j < all.length; j++) {
            const d = all[j]
            if (!d) continue
            if (!(d.paired || d.trusted || d.connected)) continue

            const pct = (d.batteryAvailable && d.battery !== undefined && d.battery !== null)
                ? Math.round(d.battery)
                : -1

            const key2 = d.address || d.deviceAddress || d.name || d.deviceName || ("" + j)
            if (seen.has(key2)) continue
            seen.add(key2)

            out.push({
                               "name": d.name || d.deviceName || "Bluetooth Device",
                               "percentage": (pct > 0 ? pct : -1),
                               "type": "bluez"
                           })
        }

        return out
    }

    // Backward-compat alias (older widget versions referenced this name).
    readonly property var bluetoothDevices: devices

    function formatTimeRemaining() {
        if (!batteryAvailable) {
            return "Unknown"
        }

        const timeSeconds = isCharging ? device.timeToFull : device.timeToEmpty

        if (!timeSeconds || timeSeconds <= 0 || timeSeconds > 86400) {
            return "Unknown"
        }

        const hours = Math.floor(timeSeconds / 3600)
        const minutes = Math.floor((timeSeconds % 3600) / 60)

        if (hours > 0) {
            return `${hours}h ${minutes}m`
        }

        return `${minutes}m`
    }

    function getBatteryIcon() {
        if (!batteryAvailable) {
            return "power"
        }

        if (isCharging) {
            if (batteryLevel >= 90) {
                return "battery_charging_full"
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90"
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80"
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60"
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50"
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30"
            }
            return "battery_charging_20"
        }
        if (isPluggedIn) {
            if (batteryLevel >= 90) {
                return "battery_charging_full"
            }
            if (batteryLevel >= 80) {
                return "battery_charging_90"
            }
            if (batteryLevel >= 60) {
                return "battery_charging_80"
            }
            if (batteryLevel >= 50) {
                return "battery_charging_60"
            }
            if (batteryLevel >= 30) {
                return "battery_charging_50"
            }
            if (batteryLevel >= 20) {
                return "battery_charging_30"
            }
            return "battery_charging_20"
        }
        if (batteryLevel >= 95) {
            return "battery_full"
        }
        if (batteryLevel >= 85) {
            return "battery_6_bar"
        }
        if (batteryLevel >= 70) {
            return "battery_5_bar"
        }
        if (batteryLevel >= 55) {
            return "battery_4_bar"
        }
        if (batteryLevel >= 40) {
            return "battery_3_bar"
        }
        if (batteryLevel >= 25) {
            return "battery_2_bar"
        }
        return "battery_1_bar"
    }
}
