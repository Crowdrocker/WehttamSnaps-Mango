pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// NOTE: CPU frequency data is provided exclusively by DgopService.
// This service exists only to expose IPC handlers for external tooling
// and as a passthrough for manual reads if DGOP is unavailable.
// The polling timer is intentionally disabled.

Singleton {
    id: root

    property real   currentFrequency: 0.0
    property real   maxFrequency: 0.0
    property string governor: ""
    // FIX: removed isChanging — it was set nowhere and read nowhere
    // FIX: removed frequencyChanged signal — emitted only inside the disabled timer

    // FIX: removed Timer entirely — it was running: false with a comment saying
    //      it is permanently disabled. Keeping a dead timer adds noise and the
    //      onTriggered body is unreachable. If re-enabling is ever needed, add
    //      the timer back with `running: true`.

    // FIX: removed Component.onCompleted — body was a commented-out call, nothing else

    // One-shot read used by external callers who want a fresh value without DGOP
    function updateCpuInfo() {
        try {
            const freqFile = Quickshell.readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq")
            if (freqFile) {
                const mhz = parseInt(freqFile.trim()) / 1000.0
                if (mhz > 0 && mhz !== currentFrequency) currentFrequency = mhz
            }
        } catch (e) {}

        try {
            const govFile = Quickshell.readFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
            if (govFile) {
                const g = govFile.trim()
                if (g !== governor) governor = g
            }
        } catch (e) {}

        try {
            const maxFile = Quickshell.readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
            if (maxFile) {
                const mhz = parseInt(maxFile.trim()) / 1000.0
                if (mhz > 0 && mhz !== maxFrequency) maxFrequency = mhz
            }
        } catch (e) {}
    }

    IpcHandler {
        target: "cpufreq"
        function getfreq(): string    { return root.currentFrequency.toFixed(2) }
        function getgovernor(): string { return root.governor }
        function getmaxfreq(): string  { return root.maxFrequency.toFixed(2) }
    }
}
