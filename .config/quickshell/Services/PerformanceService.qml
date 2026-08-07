pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var modes: [
        {
            "id": "power-saver",
            "name": "Powersave",
            "icon": "battery_saver",
            "color": "#00BCD4"
        },
        {
            "id": "balanced",
            "name": "Balanced",
            "icon": "balance",
            "color": "#FFC107"
        },
        {
            "id": "performance",
            "name": "Performance",
            "icon": "speed",
            "color": "#8BC34A"
        }
    ]

    property string currentMode: ""
    property bool isChanging: false
    property bool hasPowerProfiles: false
    property bool usingPowerProfilesCtl: false
    property bool usingTunedAdm: false
    property var tunedProfiles: []

    signal modeChanged(string newMode)

    Timer {
        id: profileCheckTimer
        interval: 5000
        running: hasPowerProfiles
        repeat: true
        onTriggered: {
            if (hasPowerProfiles) {
                profileCheckProcess.running = true
            }
        }
    }

    Process {
        id: profileCheckProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0 && stdout) {
                var profile = stdout.trim()
                if (usingTunedAdm) {
                    var parts = profile.split(":")
                    profile = (parts.length > 1 ? parts[parts.length - 1] : profile).trim()
                    profile = normalizeModeFromProfile(profile)
                }
                if (profile && profile !== currentMode && !isChanging) {
                    currentMode = profile
                    modeChanged(profile)
                }
            }
        }
    }

    Process {
        id: detectPowerProfilesProcess
        running: false
        command: ["which", "powerprofilesctl"]

        onExited: exitCode => {
            usingPowerProfilesCtl = (exitCode === 0)
            if (usingPowerProfilesCtl) {
                usingTunedAdm = false
                hasPowerProfiles = true
                profileCheckProcess.command = ["powerprofilesctl", "get"]
                profileCheckProcess.running = true
            } else {
                detectTunedAdmProcess.running = true
            }
        }
    }

    Process {
        id: detectTunedAdmProcess
        running: false
        command: ["which", "tuned-adm"]

        onExited: exitCode => {
            usingTunedAdm = (exitCode === 0)
            usingPowerProfilesCtl = false
            hasPowerProfiles = usingTunedAdm
            if (usingTunedAdm) {
                profileCheckProcess.command = ["tuned-adm", "active"]
                profileCheckProcess.running = true
                tunedListProcess.running = true
            }
        }
    }

    Process {
        id: tunedListProcess
        running: false
        command: ["tuned-adm", "list"]

        onExited: exitCode => {
            if (exitCode !== 0 || !stdout) {
                tunedProfiles = []
                return
            }

            var lines = stdout.split("\n")
            var profiles = []
            var activeProfile = ""

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line) continue

                if (line.toLowerCase().startsWith("current active profile")) {
                    var parts = line.split(":")
                    activeProfile = (parts.length > 1 ? parts[parts.length - 1] : "").trim()
                    continue
                }

                if (line.startsWith("*")) {
                    var name = line.replace("*", "").trim()
                    if (name) {
                        profiles.push(name)
                        activeProfile = activeProfile || name
                    }
                } else if (line.startsWith("-")) {
                    var name = line.replace("-", "").trim()
                    if (name) {
                        profiles.push(name)
                    }
                }
            }

            tunedProfiles = profiles
            if (activeProfile) {
                var mode = normalizeModeFromProfile(activeProfile)
                if (mode && mode !== currentMode && !isChanging) {
                    currentMode = mode
                    modeChanged(mode)
                }
            }
        }
    }

    function setMode(modeId) {
        if (!hasPowerProfiles) {
            return
        }
        if (isChanging) return
        
        isChanging = true
        
        switch(modeId) {
            case "power-saver":
                applyPowerSaverSettings()
                break
            case "balanced":
                applyBalancedSettings()
                break
            case "performance":
                applyPerformanceSettings()
                break
        }
        
        // Immediately update our internal state and emit change
        currentMode = modeId
        modeChanged(modeId)
        
        // Check the actual profile after a short delay to verify
        Qt.callLater(() => {
            profileCheckProcess.running = true
            isChanging = false
        }, 1000)
    }

    function applyPowerSaverSettings() {
        if (!hasPowerProfiles) return
        if (usingPowerProfilesCtl) {
            Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
        } else if (usingTunedAdm) {
            Quickshell.execDetached(["tuned-adm", "profile", tunedProfileForMode("power-saver")])
        }
    }

    function applyBalancedSettings() {
        if (!hasPowerProfiles) return
        if (usingPowerProfilesCtl) {
            Quickshell.execDetached(["powerprofilesctl", "set", "balanced"])
        } else if (usingTunedAdm) {
            Quickshell.execDetached(["tuned-adm", "profile", tunedProfileForMode("balanced")])
        }
    }

    function applyPerformanceSettings() {
        if (!hasPowerProfiles) return
        if (usingPowerProfilesCtl) {
            Quickshell.execDetached(["powerprofilesctl", "set", "performance"])
        } else if (usingTunedAdm) {
            Quickshell.execDetached(["tuned-adm", "profile", tunedProfileForMode("performance")])
        }
    }

    function normalizeModeFromProfile(profile) {
        var lower = String(profile).toLowerCase()
        if (lower.includes("power") && lower.includes("save")) return "power-saver"
        if (lower.includes("balance")) return "balanced"
        if (lower.includes("perf")) return "performance"
        return "balanced"
    }

    function tunedProfileForMode(modeId) {
        var available = tunedProfiles || []
        function hasProfile(name) {
            return available.includes(name)
        }
        if (modeId === "power-saver") {
            if (hasProfile("powersave")) return "powersave"
            if (hasProfile("power-saver")) return "power-saver"
            return "balanced"
        }
        if (modeId === "performance") {
            if (hasProfile("performance")) return "performance"
            if (hasProfile("throughput-performance")) return "throughput-performance"
            if (hasProfile("latency-performance")) return "latency-performance"
            return "balanced"
        }
        if (hasProfile("balanced")) return "balanced"
        return available.length > 0 ? available[0] : "balanced"
    }

    function getCurrentModeInfo() {
        for (var i = 0; i < modes.length; i++) {
            if (modes[i].id === currentMode) {
                return modes[i]
            }
        }
        return modes[1]
    }

    IpcHandler {
        target: "performance"

        function setmode(mode: string): string {
            if (["power-saver", "balanced", "performance"].includes(mode)) {
                root.setMode(mode)
                return `Performance mode set to ${mode}`
            }
            return "Invalid mode. Use: power-saver, balanced, or performance"
        }

        function getmode(): string {
            return root.currentMode
        }

        function listmodes(): string {
            return JSON.stringify(root.modes)
        }
    }

    Component.onCompleted: {
        detectPowerProfilesProcess.running = true
        if (usingTunedAdm) {
            profileCheckProcess.command = ["tuned-adm", "active"]
        }
    }
}
