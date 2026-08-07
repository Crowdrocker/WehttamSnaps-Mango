pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property int refCount: 0
    property int updateInterval: refCount > 0 ? 5000 : 30000
    property bool isUpdating: false
    property bool dgopAvailable: false
    property bool nvmlAvailable: false

    property var moduleRefCounts: ({})
    property var enabledModules: []
    property var gpuPciIds: []
    property var gpuPciIdRefCounts: ({})
    property int processLimit: 20
    // FIX #13: removed duplicate `processSort` — `currentSort` is the single source of truth
    property bool noCpu: false

    property string cpuCursor: ""
    property string procCursor: ""
    property int cpuSampleCount: 0
    property int processSampleCount: 0

    property real cpuUsage: 0
    property real cpuFrequency: 0
    property real cpuTemperature: 0
    property int cpuCores: 1
    property string cpuModel: ""
    property var perCoreCpuUsage: []

    property real memoryUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    property real freeMemoryMB: 0
    property real availableMemoryMB: 0
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0

    property real networkRxRate: 0
    property real networkTxRate: 0
    property var lastNetworkStats: null
    property var networkInterfaces: []

    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var lastDiskStats: null
    property var diskMounts: []
    property var diskDevices: []

    property var processes: []
    property var allProcesses: []
    property string currentSort: "cpu"
    property var availableGpus: []

    // FIX #4: real timestamps for accurate rate calculations
    property real lastNetworkTimestamp: 0
    property real lastDiskTimestamp: 0

    property string kernelVersion: ""
    property string distribution: ""
    property string hostname: ""
    property string architecture: ""
    property string loadAverage: ""
    property int processCount: 0
    property int threadCount: 0
    property string bootTime: ""
    property string motherboard: ""
    property string biosVersion: ""

    property int historySize: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: ({ "rx": [], "tx": [] })
    property var diskHistory: ({ "read": [], "write": [] })

    // FIX #10: icon memo cache — avoids recomputing on every render
    property var _iconCache: ({})

    // ── Ref counting ──────────────────────────────────────────────────────────

    function addRef(modules = null) {
        refCount++
        let modulesChanged = false

        if (modules) {
            const modulesToAdd = Array.isArray(modules) ? modules : [modules]
            for (const module of modulesToAdd) {
                moduleRefCounts[module] = (moduleRefCounts[module] || 0) + 1
                if (enabledModules.indexOf(module) === -1) {
                    enabledModules.push(module)
                    modulesChanged = true
                }
            }
        }

        if (modulesChanged || refCount === 1) {
            enabledModules = enabledModules.slice()
            moduleRefCounts = Object.assign({}, moduleRefCounts)
            updateAllStats()
        } else if (gpuPciIds.length > 0 && refCount > 0) {
            updateAllStats()
        }
    }

    function removeRef(modules = null) {
        refCount = Math.max(0, refCount - 1)
        let modulesChanged = false

        if (modules) {
            const modulesToRemove = Array.isArray(modules) ? modules : [modules]
            for (const module of modulesToRemove) {
                const currentCount = moduleRefCounts[module] || 0
                if (currentCount > 1) {
                    moduleRefCounts[module] = currentCount - 1
                } else if (currentCount === 1) {
                    delete moduleRefCounts[module]
                    const index = enabledModules.indexOf(module)
                    if (index > -1) {
                        enabledModules.splice(index, 1)
                        modulesChanged = true
                    }
                }
            }
        }

        if (modulesChanged) {
            enabledModules = enabledModules.slice()
            moduleRefCounts = Object.assign({}, moduleRefCounts)
            if (!enabledModules.includes("cpu")) {
                cpuCursor = ""
                cpuSampleCount = 0
            }
            if (!enabledModules.includes("processes")) {
                procCursor = ""
                processSampleCount = 0
            }
        }
    }

    // ── GPU PCI ID management ─────────────────────────────────────────────────

    function setGpuPciIds(pciIds) {
        gpuPciIds = Array.isArray(pciIds) ? pciIds : []
    }

    function addGpuPciId(pciId) {
        gpuPciIdRefCounts[pciId] = (gpuPciIdRefCounts[pciId] || 0) + 1
        if (!gpuPciIds.includes(pciId))
            gpuPciIds = gpuPciIds.concat([pciId])
        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts)
    }

    function removeGpuPciId(pciId) {
        const currentCount = gpuPciIdRefCounts[pciId] || 0
        if (currentCount > 1) {
            gpuPciIdRefCounts[pciId] = currentCount - 1
        } else if (currentCount === 1) {
            delete gpuPciIdRefCounts[pciId]
            const index = gpuPciIds.indexOf(pciId)
            if (index > -1) {
                const next = gpuPciIds.slice()
                next.splice(index, 1)
                gpuPciIds = next
            }
            if (availableGpus && availableGpus.length > 0) {
                availableGpus = availableGpus.map(g =>
                    g.pciId === pciId ? Object.assign({}, g, { "temperature": 0 }) : g
                )
            }
        }
        gpuPciIdRefCounts = Object.assign({}, gpuPciIdRefCounts)
    }

    // ── Process options ───────────────────────────────────────────────────────

    // FIX #13: writes to currentSort — the one sort property
    function setProcessOptions(limit = 20, sort = "cpu", disableCpu = false) {
        processLimit = limit
        currentSort = sort
        noCpu = disableCpu
    }

    // ── Shared GPU merge helper (FIX #9) ──────────────────────────────────────
    // Merges incomingGpus into availableGpus.
    // `fields`   — field names to copy from incoming onto matched existing entries.
    // `defaults` — { field: defaultValue } used when inserting new GPU entries.
    function mergeGpuData(incomingGpus, fields, defaults) {
        if (!incomingGpus || incomingGpus.length === 0) return

        if (availableGpus && availableGpus.length > 0) {
            const updated = availableGpus.slice()
            for (const incoming of incomingGpus) {
                let found = false
                for (let i = 0; i < updated.length; i++) {
                    const existing = updated[i]
                    if (existing.pciId === incoming.pciId ||
                        (existing.vendor && incoming.vendor && existing.vendor === incoming.vendor)) {
                        const patch = {}
                        for (const f of fields)
                            patch[f] = (incoming[f] !== undefined && incoming[f] !== null)
                                ? incoming[f] : (existing[f] || 0)
                        updated[i] = Object.assign({}, existing, patch)
                        found = true
                        break
                    }
                }
                if (!found) {
                    const entry = {}
                    for (const key of Object.keys(defaults))
                        entry[key] = incoming[key] !== undefined ? incoming[key] : defaults[key]
                    updated.push(entry)
                }
            }
            availableGpus = updated
        } else {
            availableGpus = incomingGpus.map(gpu => {
                const entry = {}
                for (const key of Object.keys(defaults))
                    entry[key] = gpu[key] !== undefined ? gpu[key] : defaults[key]
                return entry
            })
            for (const gpu of incomingGpus)
                if (gpu.pciId) addGpuPciId(gpu.pciId)
        }
    }

    // ── Core update ───────────────────────────────────────────────────────────

    function updateAllStats() {
        if (dgopAvailable && refCount > 0 && enabledModules.length > 0) {
            isUpdating = true
            dgopProcess.running = true
        } else {
            isUpdating = false
        }
    }

    function initializeGpuMetadata() {
        if (!dgopAvailable) return
        gpuInitProcess.running = true
    }

    function initializeGpuMetadataWithNVML() {
        if (!nvmlAvailable) return
        nvmlGpuProcess.running = true
    }

    function initializeGpuMetadataWithIntel() {
        intelGpuProcess.running = true
    }

    // ── Command builder ───────────────────────────────────────────────────────

    function buildDgopCommand() {
        if (enabledModules.length === 0) return []

        const cmd = ["dgop", "meta", "--json"]
        const finalModules = []

        // FIX #3: single pass, no double-push of gpu-temp
        for (const module of enabledModules) {
            if (module === "gpu") {
                if (gpuPciIds.length > 0) finalModules.push("gpu-temp")
            } else {
                finalModules.push(module)
            }
        }

        if (enabledModules.includes("all")) {
            cmd.push("--modules", "all")
        } else if (finalModules.length > 0) {
            cmd.push("--modules", finalModules.join(","))
        } else {
            return []
        }

        if ((enabledModules.includes("cpu") || enabledModules.includes("all")) && cpuCursor)
            cmd.push("--cpu-cursor", cpuCursor)
        if ((enabledModules.includes("processes") || enabledModules.includes("all")) && procCursor)
            cmd.push("--proc-cursor", procCursor)

        if (gpuPciIds.length > 0)
            cmd.push("--gpu-pci-ids", gpuPciIds.join(","))

        if (enabledModules.includes("processes") || enabledModules.includes("all")) {
            cmd.push("--limit", "100")
            // FIX #12: use currentSort not hardcoded "cpu"
            cmd.push("--sort", currentSort)
            if (noCpu) cmd.push("--no-cpu")
        }

        return cmd
    }

    // ── Data parser ───────────────────────────────────────────────────────────

    function parseData(data) {
        if (data.cpu) {
            const cpu = data.cpu
            cpuSampleCount++
            cpuUsage = cpu.usage || 0
            cpuFrequency = cpu.frequency || 0
            cpuTemperature = cpu.temperature || 0
            cpuCores = cpu.count || 1
            cpuModel = cpu.model || ""
            perCoreCpuUsage = cpu.coreUsage || []
            addToHistory(cpuHistory, cpuUsage)
            if (cpu.cursor) cpuCursor = cpu.cursor
        }

        if (data.memory) {
            const mem = data.memory
            const totalKB = mem.total || 0
            const availableKB = mem.available || 0
            totalMemoryMB = totalKB / 1024
            availableMemoryMB = availableKB / 1024
            freeMemoryMB = (mem.free || 0) / 1024
            usedMemoryMB = totalMemoryMB - availableMemoryMB
            memoryUsage = totalKB > 0 ? ((totalKB - availableKB) / totalKB) * 100 : 0
            totalMemoryKB = totalKB
            usedMemoryKB = totalKB - availableKB
            totalSwapKB = mem.swaptotal || 0
            usedSwapKB = (mem.swaptotal || 0) - (mem.swapfree || 0)
            addToHistory(memoryHistory, memoryUsage)
        }

        if (data.network && Array.isArray(data.network)) {
            networkInterfaces = data.network
            let totalRx = 0
            let totalTx = 0
            for (const iface of data.network) {
                totalRx += iface.rx || 0
                totalTx += iface.tx || 0
            }
            if (lastNetworkStats) {
                // FIX #4: real elapsed time, not the requested interval
                const now = Date.now()
                const timeDiff = lastNetworkTimestamp > 0
                    ? Math.max(0.1, (now - lastNetworkTimestamp) / 1000)
                    : updateInterval / 1000
                networkRxRate = Math.max(0, (totalRx - lastNetworkStats.rx) / timeDiff)
                networkTxRate = Math.max(0, (totalTx - lastNetworkStats.tx) / timeDiff)
                addToHistory(networkHistory.rx, networkRxRate / 1024)
                addToHistory(networkHistory.tx, networkTxRate / 1024)
            }
            lastNetworkStats = { "rx": totalRx, "tx": totalTx }
            lastNetworkTimestamp = Date.now()
        }

        if (data.disk && Array.isArray(data.disk)) {
            diskDevices = data.disk
            let totalRead = 0
            let totalWrite = 0
            for (const disk of data.disk) {
                totalRead  += (disk.read  || 0) * 512
                totalWrite += (disk.write || 0) * 512
            }
            if (lastDiskStats) {
                // FIX #4: real elapsed time
                const now = Date.now()
                const timeDiff = lastDiskTimestamp > 0
                    ? Math.max(0.1, (now - lastDiskTimestamp) / 1000)
                    : updateInterval / 1000
                diskReadRate  = Math.max(0, (totalRead  - lastDiskStats.read)  / timeDiff)
                diskWriteRate = Math.max(0, (totalWrite - lastDiskStats.write) / timeDiff)
                addToHistory(diskHistory.read,  diskReadRate  / (1024 * 1024))
                addToHistory(diskHistory.write, diskWriteRate / (1024 * 1024))
            }
            lastDiskStats = { "read": totalRead, "write": totalWrite }
            lastDiskTimestamp = Date.now()
        }

        if (data.diskmounts)
            diskMounts = data.diskmounts || []

        if (data.processes && Array.isArray(data.processes)) {
            processSampleCount++
            allProcesses = data.processes.map(proc => ({
                "pid":           proc.pid || 0,
                "ppid":          proc.ppid || 0,
                "cpu":           processSampleCount >= 2 ? (proc.cpu || 0) : 0,
                "memoryPercent": proc.memoryPercent || proc.pssPercent || 0,
                "memoryKB":      proc.memoryKB || proc.pssKB || 0,
                "command":       proc.command || "",
                "fullCommand":   proc.fullCommand || "",
                "displayName":   (proc.command && proc.command.length > 15)
                                     ? proc.command.substring(0, 15) + "..."
                                     : (proc.command || "")
            }))
            applySorting()

            // FIX #6: check both locations for proc cursor
            if (data.processes.cursor)
                procCursor = data.processes.cursor
            else if (data.cursor)
                procCursor = data.cursor
        }

        // FIX #9: use shared helper instead of inline duplicate
        const gpuData = (data.gpu && data.gpu.gpus) || data.gpus
        if (gpuData && Array.isArray(gpuData)) {
            mergeGpuData(gpuData, ["temperature"], {
                "driver": "", "vendor": "", "displayName": "Unknown GPU",
                "fullName": "Unknown GPU", "pciId": "", "temperature": 0
            })
        }

        if (data.system) {
            const sys = data.system
            loadAverage  = sys.loadavg   || ""
            processCount = sys.processes || 0
            threadCount  = sys.threads   || 0
            bootTime     = sys.boottime  || ""
        }

        if (data.hardware) {
            const hw = data.hardware
            hostname      = hw.hostname || ""
            kernelVersion = hw.kernel   || ""
            distribution  = hw.distro   || ""
            architecture  = hw.arch     || ""
            motherboard   = (hw.bios && hw.bios.motherboard) || ""
            biosVersion   = (hw.bios && hw.bios.version)     || ""
        }

        isUpdating = false
    }

    // ── History ───────────────────────────────────────────────────────────────

    function addToHistory(array, value) {
        array.push(value)
        if (array.length > historySize)
            array.shift()
    }

    // ── Process helpers ───────────────────────────────────────────────────────

    // FIX #10: memoized icon lookup
    function getProcessIcon(command) {
        if (_iconCache[command] !== undefined)
            return _iconCache[command]

        const cmd = command.toLowerCase()
        let icon = "memory"
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser") || cmd.includes("chromium"))
            icon = "web"
        else if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim"))
            icon = "code"
        else if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh"))
            icon = "terminal"
        else if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify"))
            icon = "music_note"
        else if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv"))
            icon = "play_circle"
        else if (cmd.includes("systemd") || cmd.includes("elogind") || cmd.includes("kernel") || cmd.includes("kthread") || cmd.includes("kworker"))
            icon = "settings"

        _iconCache[command] = icon
        return icon
    }

    function formatCpuUsage(cpu) {
        return (cpu || 0).toFixed(1) + "%"
    }

    // FIX #15: one unified formatter replaces two near-identical functions
    function formatMemory(memoryKB, allowKB = false) {
        const mem = memoryKB || 0
        if (mem === 0) return "--"
        if (allowKB && mem < 1024) return mem.toFixed(0) + " KB"
        if (mem < 1024 * 1024) return (mem / 1024).toFixed(1) + " MB"
        return (mem / (1024 * 1024)).toFixed(1) + " GB"
    }

    // Thin wrappers so existing callers don't break
    function formatMemoryUsage(memoryKB)  { return formatMemory(memoryKB, true)  }
    function formatSystemMemory(memoryKB) { return formatMemory(memoryKB, false) }

    function killProcess(pid) {
        if (pid > 0) Quickshell.execDetached("kill", [pid.toString()])
    }

    function setSortBy(newSortBy) {
        if (newSortBy !== currentSort) {
            currentSort = newSortBy
            applySorting()
        }
    }

    function applySorting() {
        if (!allProcesses || allProcesses.length === 0) return

        const sorted = allProcesses.slice()
        sorted.sort((a, b) => {
            switch (currentSort) {
                case "cpu":    return (b.cpu || 0) - (a.cpu || 0)
                case "memory": return (b.memoryKB || 0) - (a.memoryKB || 0)
                case "name":   return (a.command || "").toLowerCase()
                                          .localeCompare((b.command || "").toLowerCase())
                case "pid":    return (a.pid || 0) - (b.pid || 0)
                default:       return 0
            }
        })

        processes = sorted.slice(0, processLimit)
    }

    // ── Timers ────────────────────────────────────────────────────────────────

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.dgopAvailable && root.refCount > 0 && root.enabledModules.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateAllStats()
    }

    Timer {
        id: nvmlUpdateTimer
        interval: 2000
        running: root.nvmlAvailable && root.refCount > 0 && root.enabledModules.includes("gpu")
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (availableGpus && availableGpus.length > 0)
                nvmlGpuProcess.running = true
        }
    }

    // FIX #1 + #2: only runs when an Intel GPU is actually in availableGpus
    Timer {
        id: intelUpdateTimer
        interval: 2000
        running: root.refCount > 0
                 && root.enabledModules.includes("gpu")
                 && root.availableGpus.some(g => g.vendor === "Intel")
        repeat: true
        triggeredOnStart: true
        onTriggered: intelGpuProcess.running = true
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: dgopProcess
        command: root.buildDgopCommand()
        running: false
        onCommandChanged: {
            if (running) {
                Qt.callLater(() => {
                    if (dgopProcess.running) dgopProcess.running = false
                })
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                isUpdating = false
                if (typeof LoggingService !== 'undefined')
                    LoggingService.warn("DgopService", "dgop process exited with error", { exitCode: exitCode })
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        parseData(JSON.parse(text.trim()))
                    } catch (e) {
                        if (typeof LoggingService !== 'undefined')
                            LoggingService.error("DgopService", "Failed to parse dgop output", { error: e.message, outputLength: text.length })
                    }
                }
                isUpdating = false
            }
        }
    }

    Process {
        id: gpuInitProcess
        command: ["dgop", "gpu", "--json"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0 && typeof LoggingService !== 'undefined')
                LoggingService.warn("DgopService", "GPU init process exited with error", { exitCode: exitCode })
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        parseData(JSON.parse(text.trim()))
                    } catch (e) {
                        if (typeof LoggingService !== 'undefined')
                            LoggingService.error("DgopService", "Failed to parse GPU init output", { error: e.message })
                    }
                }
            }
        }
    }

    // FIX #9: uses shared mergeGpuData — no more inline duplicate logic
    Process {
        id: nvmlGpuProcess
        command: [nvmlPythonPath, nvmlScriptPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const data = JSON.parse(text.trim())
                        if (data.gpus && Array.isArray(data.gpus)) {
                            mergeGpuData(data.gpus, ["temperature"], {
                                "driver": "nvidia", "vendor": "NVIDIA",
                                "displayName": "Unknown GPU", "fullName": "Unknown GPU",
                                "pciId": "", "temperature": 0
                            })
                        }
                    } catch (e) {}
                }
            }
        }
    }

    // FIX #9: uses shared mergeGpuData
    Process {
        id: intelGpuProcess
        command: [nvmlPythonPath, intelScriptPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const data = JSON.parse(text.trim())
                        if (data.gpus && Array.isArray(data.gpus)) {
                            mergeGpuData(data.gpus,
                                ["temperature", "memoryUsed", "memoryTotal", "memoryUsedMB", "memoryTotalMB"],
                                {
                                    "driver": "i915", "vendor": "Intel",
                                    "displayName": "Intel GPU", "fullName": "Intel GPU",
                                    "pciId": "", "temperature": 0,
                                    "memoryUsed": 0, "memoryTotal": 0,
                                    "memoryUsedMB": 0, "memoryTotalMB": 0
                                }
                            )
                        }
                    } catch (e) {}
                }
            }
        }
    }

    // FIX #11: removed empty onExited handlers from nvml/intel/osRelease processes
    Process {
        id: osReleaseProcess
        command: ["cat", "/etc/os-release"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        let prettyName = ""
                        let name = ""
                        for (const line of text.trim().split('\n')) {
                            const t = line.trim()
                            if (t.startsWith('PRETTY_NAME='))
                                prettyName = t.substring(12).replace(/^["']|["']$/g, '')
                            else if (t.startsWith('NAME='))
                                name = t.substring(5).replace(/^["']|["']$/g, '')
                        }
                        distribution = prettyName || name || "Linux"
                    } catch (e) {
                        distribution = "Linux"
                    }
                }
            }
        }
    }

    Process {
        id: dgopCheckProcess
        command: ["which", "dgop"]
        running: false
        onExited: exitCode => {
            dgopAvailable = (exitCode === 0)
            if (dgopAvailable) {
                initializeGpuMetadata()
                if (SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.length > 0) {
                    for (const pciId of SessionData.enabledGpuPciIds) addGpuPciId(pciId)
                    if (refCount > 0 && enabledModules.length > 0) updateAllStats()
                }
            }
        }
    }

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string nvmlPythonPath: "python3"
    readonly property string nvmlScriptPath: configDir + "/quickshell/scripts/nvidia_gpu_temp.py"
    readonly property string amdScriptPath:  configDir + "/quickshell/scripts/amd_gpu_temp.py"
    readonly property string intelScriptPath: configDir + "/quickshell/scripts/intel_gpu_temp.py"

    Process {
        id: nvmlCheckProcess
        command: [nvmlPythonPath, "-c", "import pynvml; print('NVML available')"]
        running: false
        onExited: exitCode => {
            nvmlAvailable = (exitCode === 0)
            if (!dgopAvailable) {
                if (nvmlAvailable)
                    initializeGpuMetadataWithNVML()
                else
                    initializeGpuMetadataWithIntel()
            }
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    Component.onCompleted: {
        dgopCheckProcess.running = true
        nvmlCheckProcess.running = true
        osReleaseProcess.running = true
    }

    // FIX #14: removed redundant running guards — these are all safe no-ops
    Component.onDestruction: {
        updateTimer.stop()
        nvmlUpdateTimer.stop()
        intelUpdateTimer.stop()
        dgopProcess.running     = false
        gpuInitProcess.running  = false
        nvmlGpuProcess.running  = false
        intelGpuProcess.running = false
    }
}
