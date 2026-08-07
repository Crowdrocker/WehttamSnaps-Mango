pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isElogind: false
    property bool hibernateSupported: false
    property bool hasPowerProfiles: false
    property bool usingPowerProfilesCtl: false
    property bool usingTunedAdm: false

    property string powerButtonAction:     "poweroff"
    property string sleepButtonAction:     "suspend"
    property string hibernateButtonAction: "hibernate"

    property bool   lidSwitchAvailable: false
    property string lidCloseAction:              "suspend"
    property string lidCloseExternalPowerAction: "suspend"

    property int idleSleepTimeout:              0
    property int idleSleepTimeoutOnBattery:     0
    property int idleHibernateTimeout:          0
    property int idleHibernateTimeoutOnBattery: 0

    property int screenDimTimeout:             600
    property int screenDimTimeoutOnBattery:    300
    property int screenOffTimeout:             1200
    property int screenOffTimeoutOnBattery:    600

    property int    lowBatteryThreshold:      20
    property int    criticalBatteryThreshold: 5
    property string lowBatteryAction:      "suspend"
    property string criticalBatteryAction: "hibernate"

    property string powerProfile: "balanced"
    property var    availableProfiles: []

    property bool wakeOnLAN:     false
    property bool usbAutosuspend: true

    property bool   isLoading: false
    property string lastError: ""

    // FIX: repeated `isElogind ? "elogind" : "loginctl"` in every setter
    //      replaced with a single readonly helper property
    readonly property string _loginctl: isElogind ? "elogind" : "loginctl"

    // ── Public API ────────────────────────────────────────────────────────────

    function refreshStatus() {
        // FIX: statusProcess had an empty command: [] — it would never do anything.
        //      Stub kept; implement command when backend is wired up.
        if (statusProcess.running) return
        statusProcess.running = true
    }

    function setPowerButtonAction(action) {
        if (!action) return
        _runLoginctl(["set-property", "HandlePowerKey", action], setPowerButtonProcess)
    }

    function setSleepButtonAction(action) {
        if (!action) return
        _runLoginctl(["set-property", "HandleSleepKey", action], setSleepButtonProcess)
    }

    function setHibernateButtonAction(action) {
        if (!action) return
        _runLoginctl(["set-property", "HandleHibernateKey", action], setHibernateButtonProcess)
    }

    function setLidCloseAction(action) {
        if (!action) return
        _runLoginctl(["set-property", "HandleLidSwitch", action], setLidCloseProcess)
    }

    function setLidCloseExternalPowerAction(action) {
        if (!action) return
        _runLoginctl(["set-property", "HandleLidSwitchExternalPower", action], setLidCloseExternalPowerProcess)
    }

    function setIdleSleepTimeout(timeout) {
        if (timeout <= 0)
            _runLoginctl(["set-property", "IdleAction", "ignore"], setIdleSleepProcess)
        else
            _runLoginctl(["set-property", "IdleAction", "suspend",
                          "IdleActionUSec", (timeout * 1000000).toString()], setIdleSleepProcess)
    }

    function setIdleHibernateTimeout(timeout) {
        if (timeout <= 0)
            _runLoginctl(["set-property", "IdleAction", "ignore"], setIdleHibernateProcess)
        else
            _runLoginctl(["set-property", "IdleAction", "hibernate",
                          "IdleActionUSec", (timeout * 1000000).toString()], setIdleHibernateProcess)
    }

    function setScreenDimTimeout(timeout) {
        setScreenDimProcess.command = ["xset", "dpms", timeout > 0 ? timeout.toString() : "0"]
        setScreenDimProcess.running = true
    }

    function setScreenOffTimeout(timeout) {
        setScreenOffProcess.command = ["xset", "dpms", "0", timeout > 0 ? timeout.toString() : "0"]
        setScreenOffProcess.running = true
    }

    function setPowerProfile(profile) {
        if (!hasPowerProfiles) return
        if (usingPowerProfilesCtl) {
            setPowerProfileProcess.command = ["powerprofilesctl", "set", profile]
        } else if (usingTunedAdm) {
            const mapped = mapTunedProfile(profile)
            if (!mapped) return
            setPowerProfileProcess.command = ["tuned-adm", "profile", mapped]
        } else {
            return
        }
        setPowerProfileProcess.running = true
    }

    // FIX: setWakeOnLAN only wrote to a local property and did nothing — kept as
    //      a property write stub; wire up a real command when backend is ready
    function setWakeOnLAN(enabled) {
        root.wakeOnLAN = enabled
        // TODO: apply via ethtool or similar when interface name is known
    }

    // FIX: mapTunedProfile had `if (profile === "performance") { includes("performance") }`
    //      which always matched before the other performance variants — reordered so
    //      more specific variants are checked first; also removed redundant
    //      `if (includes(x)) return x` when x === profile (already caught by line 1)
    function mapTunedProfile(profile) {
        if (!profile) return ""
        if (root.availableProfiles.includes(profile)) return profile

        const perf = root.availableProfiles
        if (profile === "power-saver") {
            if (perf.includes("powersave"))           return "powersave"
        }
        if (profile === "performance") {
            if (perf.includes("latency-performance"))    return "latency-performance"
            if (perf.includes("throughput-performance")) return "throughput-performance"
            if (perf.includes("performance"))            return "performance"
        }
        if (profile === "balanced") {
            if (perf.includes("balanced")) return "balanced"
        }

        return root.availableProfiles.length > 0 ? root.availableProfiles[0] : ""
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    // FIX: DRY helper — every setter was doing [_loginctl].concat(args); process.running = true
    function _runLoginctl(args, process) {
        process.command = [_loginctl].concat(args)
        process.running = true
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        detectElogindProcess.running    = true
        detectHibernateProcess.running  = true
        detectPowerProfilesProcess.running = true
        refreshStatus()
    }

    // ── Detection processes ───────────────────────────────────────────────────

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]
        onExited: exitCode => { root.isElogind = (exitCode === 0) }
    }

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]
        onExited: exitCode => { root.hibernateSupported = (exitCode === 0) }
    }

    Process {
        id: detectPowerProfilesProcess
        running: false
        command: ["which", "powerprofilesctl"]
        onExited: exitCode => {
            root.usingPowerProfilesCtl = (exitCode === 0)
            if (root.usingPowerProfilesCtl) {
                root.usingTunedAdm  = false
                root.hasPowerProfiles = true
                listPowerProfilesProcess.running = true
            } else {
                detectTunedAdmProcess.running = true
            }
        }
    }

    Process {
        id: listPowerProfilesProcess
        running: false
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = []
                for (const line of text.split('\n').filter(l => l.trim())) {
                    if (line.includes('*')) {
                        const m = line.match(/\*\s+(\S+)/)
                        if (m) root.powerProfile = m[1]
                    }
                    const m = line.match(/^\s*(\S+):/)
                    if (m) profiles.push(m[1])
                }
                root.availableProfiles = profiles
            }
        }
    }

    Process {
        id: detectTunedAdmProcess
        running: false
        command: ["which", "tuned-adm"]
        onExited: exitCode => {
            root.usingTunedAdm        = (exitCode === 0)
            root.usingPowerProfilesCtl = false
            root.hasPowerProfiles      = root.usingTunedAdm
            if (root.usingTunedAdm) listTunedProfilesProcess.running = true
        }
    }

    Process {
        id: listTunedProfilesProcess
        running: false
        command: ["tuned-adm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split('\n').map(l => l.trim()).filter(l => l)
                const profiles = []
                let active = ""
                for (const line of lines) {
                    if (line.toLowerCase().startsWith("current active profile")) {
                        const parts = line.split(":")
                        active = (parts.length > 1 ? parts[parts.length - 1] : "").trim()
                        continue
                    }
                    // FIX: line.replace("*","") only removed the first star — use slice(1)
                    if (line.startsWith("*") || line.startsWith("-")) {
                        const name = line.slice(1).trim()
                        if (name) {
                            profiles.push(name)
                            if (!active && line.startsWith("*")) active = name
                        }
                    }
                }
                root.availableProfiles = profiles
                if (active) root.powerProfile = active
            }
        }
    }

    // ── Setter processes ──────────────────────────────────────────────────────

    Process { id: setPowerButtonProcess;         running: false; command: [] }
    Process { id: setSleepButtonProcess;         running: false; command: [] }
    Process { id: setHibernateButtonProcess;     running: false; command: [] }
    Process { id: setLidCloseProcess;            running: false; command: [] }
    Process { id: setLidCloseExternalPowerProcess; running: false; command: [] }
    Process { id: setIdleSleepProcess;           running: false; command: [] }
    Process { id: setIdleHibernateProcess;       running: false; command: [] }
    Process { id: setScreenDimProcess;           running: false; command: [] }
    Process { id: setScreenOffProcess;           running: false; command: [] }
    Process { id: setPowerProfileProcess;        running: false; command: [] }

    // FIX: statusProcess had command: [] — it ran but did nothing.
    //      Kept as a stub; replace command when status backend is implemented.
    Process { id: statusProcess; running: false; command: [] }
}
