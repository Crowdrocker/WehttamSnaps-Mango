pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var capabilities: ({})
    property bool loading: false
    property bool initialized: false
    property var _pendingRequests: []

    signal capabilitiesUpdated(var caps)

    function getCapabilities(monitorName) {
        if (capabilities[monitorName] !== undefined) {
            return capabilities[monitorName]
        }
        if (!_pendingRequests.includes(monitorName)) {
            _pendingRequests.push(monitorName)
        }
        if (!loading && initialized) {
            refreshCapabilities([monitorName])
        }
        return null
    }

    function refreshCapabilities(monitorNames) {
        if (loading) return
        loading = true
        var names = monitorNames || Object.keys(capabilities)
        if (names.length === 0) {
            loading = false
            return
        }
        capsProcess.monitorNames = names
        capsProcess.running = true
    }

    function refreshAllCapabilities() {
        monitorsProcess.running = true
    }

    Process {
        id: monitorsProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0 && stdout.text.trim()) {
                try {
                    var result = JSON.parse(stdout.text.trim())
                    if (result.monitors && Array.isArray(result.monitors)) {
                        refreshCapabilities(result.monitors)
                    }
                } catch (e) {
                    console.warn("Failed to parse monitors:", e)
                }
            }
        }
        stdout: StdioCollector {}
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/monitor-caps.py", "list"]
    }

    Process {
        id: capsProcess
        property var monitorNames: []
        running: false
        command: {
            var names = capsProcess.monitorNames || []
            if (names.length === 0) return ["echo", "{}"]
            var args = [Quickshell.env("HOME") + "/.config/quickshell/scripts/monitor-caps.py", "caps"].concat(names)
            return args
        }

        onExited: function(exitCode) {
            loading = false
            if (exitCode === 0 && stdout.text.trim()) {
                try {
                    var newCaps = JSON.parse(stdout.text.trim())
                    var updated = false
                    for (var name in newCaps) {
                        if (JSON.stringify(capabilities[name]) !== JSON.stringify(newCaps[name])) {
                            capabilities[name] = newCaps[name]
                            updated = true
                        }
                    }
                    if (updated) {
                        capabilitiesUpdated(capabilities)
                    }
                    initialized = true
                } catch (e) {
                    console.warn("Failed to parse capabilities:", e)
                }
            }
            if (!initialized) {
                initialized = true
            }
        }

        stdout: StdioCollector {}
    }

    Component.onCompleted: {
        refreshAllCapabilities()
    }
}
