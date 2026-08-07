pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var availableUpdates: []
    property bool isChecking: false
    property bool hasError: false
    property string errorMessage: ""
    property string pkgManager: ""
    property string distribution: ""
    property bool distributionSupported: false
    property double _lastDnfRefreshMs: 0

    readonly property list<string> supportedDistributions: ["arch", "cachyos", "manjaro", "endeavouros", "fedora", "ubuntu", "debian", "linuxmint", "pop", "elementary", "pika"]
    readonly property list<string> aptDistributions: ["ubuntu", "debian", "linuxmint", "pop", "elementary", "pika"]
    readonly property bool isAptBased: aptDistributions.includes(distribution)
    readonly property int updateCount: availableUpdates.length
    readonly property bool helperAvailable: pkgManager !== "" && distributionSupported

    property bool flatpakAvailable: false
    property var flatpakUpdates: []
    property bool isCheckingFlatpak: false

    Process {
        id: distributionDetection
        command: ["sh", "-c", "cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'"]
        running: true

        onExited: (exitCode) => {
            if (exitCode === 0) {
                distribution = stdout.text.trim().toLowerCase()
                distributionSupported = supportedDistributions.includes(distribution)

                if (distributionSupported) {
                    helperDetection.running = true
                    flatpakDetection.running = true
                } else {
                }
            } else {
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: flatpakDetection
        command: ["sh", "-c", "which flatpak"]

        onExited: (exitCode) => {
            flatpakAvailable = (exitCode === 0)
            if (flatpakAvailable) {
                checkForFlatpakUpdates()
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: helperDetection
        // Detect available package managers / helpers.
        // We intentionally support "pacman" directly so Arch-based systems work
        // without requiring an AUR helper.
        command: ["sh", "-c", "which paru || which yay || which pacman || which dnf || which apt"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                const helperPath = stdout.text.trim()
                var detectedHelper = helperPath.split('/').pop()

                // apt-based distros don't use an AUR helper — use apt directly
                if (isAptBased) {
                    pkgManager = "apt"
                    checkForUpdates()
                } else if (SettingsData.aurHelper && SettingsData.aurHelper !== "") {
                    pkgManager = SettingsData.aurHelper
                    checkForUpdates()
                } else {
                    pkgManager = detectedHelper
                    checkForUpdates()
                }
            } else {
                if (!isAptBased && SettingsData.aurHelper && SettingsData.aurHelper !== "") {
                    pkgManager = SettingsData.aurHelper
                    checkForUpdates()
                } else {
                    // On Arch-based distros, fall back to pacman even if no helper is installed.
                    if (distribution === "arch" || distribution === "cachyos" || distribution === "manjaro" || distribution === "endeavouros") {
                        pkgManager = "pacman"
                        checkForUpdates()
                    }
                }
            }
        }

        stdout: StdioCollector {}
    }
    
    Connections {
        target: SettingsData
        function onAurHelperChanged() {
            if (!isAptBased && SettingsData.aurHelper && SettingsData.aurHelper !== "") {
                pkgManager = SettingsData.aurHelper
                if (distributionSupported) {
                    checkForUpdates()
                }
            }
        }
    }

    Process {
        id: updateChecker

        onExited: (exitCode) => {
            isChecking = false
            
            // Debug: log the exit code and output
            console.log("Update check exit code:", exitCode)
            console.log("Update check stdout:", stdout.text)
            console.log("Update check stderr:", stderr.text)
            
            // For dnf check-update: 100 = updates available, 0 = up to date, 1 = error
            // For pacman/apt shell wrappers we treat 0/1 as "parsed output"
            if (exitCode === 0 || exitCode === 1 || exitCode === 100) {
                parseUpdates(stdout.text)
                hasError = false
                errorMessage = ""
            } else {
                // Check if this is a permission error
                const output = stdout.text + stderr.text
                if (output.includes("permission denied") || output.includes("Requires root") || output.includes("authentication")) {
                    hasError = true
                    errorMessage = "Permission denied. Try using sudo or configure polkit."
                } else if (output.includes("pkexec") && output.includes("not found")) {
                    hasError = true
                    errorMessage = "pkexec not found. Please install polkit."
                } else {
                    hasError = true
                    errorMessage = "Failed to check for updates (exit code: " + exitCode + ")"
                }
            }
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // If the package manager blocks on locks / metadata, don't spin forever.
    Timer {
        id: checkWatchdog
        interval: 90 * 1000
        repeat: false
        running: isChecking
        onTriggered: {
            if (!isChecking) return
            if (updateChecker.running) updateChecker.running = false
            isChecking = false
            hasError = true
            errorMessage = "Update check timed out. Another package manager process may be holding a lock."
        }
    }

    Process {
        id: updater
        onExited: (exitCode) => {
            checkForUpdates()
        }
    }

    Process {
        id: flatpakUpdateChecker

        onExited: (exitCode) => {
            isCheckingFlatpak = false
            console.log("Flatpak check exit code:", exitCode)
            console.log("Flatpak stdout:", stdout.text)
            console.log("Flatpak stderr:", stderr.text)
            parseFlatpakUpdates(stdout.text)
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: flatpakUpdater

        onExited: (exitCode) => {
            checkForFlatpakUpdates()
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function checkForUpdates() {
        if (!distributionSupported || !pkgManager || isChecking) return

        isChecking = true
        hasError = false
        
        console.log("Checking for updates on distribution:", distribution, "with package manager:", pkgManager)
        
        // Use different commands based on package manager
        // Arch Linux: paru/yay -Qu
        // Fedora: dnf check-update
        // Debian/Ubuntu: apt list --upgradable
        if (pkgManager === "apt") {
            updateChecker.command = ["sh", "-c", "apt list --upgradable 2>/dev/null"]
        } else if (pkgManager === "dnf") {
            // Avoid a full repo refresh on every auto-check; it can be slow and look like a loop.
            // Refresh at most once every 6 hours; otherwise do a fast check-update.
            const now = Date.now()
            const shouldRefresh = !_lastDnfRefreshMs || (now - _lastDnfRefreshMs) > (6 * 60 * 60 * 1000)
            if (shouldRefresh) _lastDnfRefreshMs = now

            // Use argv (no shell) so stderr stays meaningful and we avoid string concat/spacing bugs.
            // dnf check-update semantics:
            // - exit 0: no updates
            // - exit 100: updates available
            // - exit 1+: errors
            const args = ["dnf", "-q", "check-update", "--skip-file-locks"]
            if (shouldRefresh)
                args.splice(3, 0, "--refresh")
            updateChecker.command = args
        } else {
            // Use pacman -Qu directly — works on all Arch-based distros without pacman-contrib.
            // --nocolor strips ANSI codes so the regex parser can match lines cleanly.
            updateChecker.command = ["sh", "-c", "pacman -Qu --nocolor 2>/dev/null"]
        }
        updateChecker.running = true
    }

    function parseUpdates(output) {
        const lines = output.trim().split('\n').filter(line => line.trim())
        const updates = []
        
        console.log("Parsing output lines:", lines.length)
        console.log("First 10 lines:", lines.slice(0, 10))

        for (const line of lines) {
            // Skip header/status lines (dnf, apt, paru/yay noise)
            if (line.startsWith("Fedora") || line.startsWith("Last") || line.startsWith("Extra") || 
                line.startsWith("Repository") || line.startsWith("Metadata") || line.includes("No packages") ||
                line.startsWith("Listing...") || line.startsWith("WARNING") ||
                line.startsWith("::") || line.startsWith("==>") || line.startsWith(" ->") ||
                line.startsWith("error:") || line.startsWith("there is nothing to do") ||
                line.startsWith("Repositories") || line.startsWith("Waiting") ||
                line.trim() === "" || line.includes("100%")) {
                continue
            }

            // Skip dnf section headers but keep the actual update lines
            if (line.trim() === "Upgrades" || line.trim() === "Obsoletes" || 
                line.trim() === "Installs" || line.trim() === "Removals") {
                continue
            }

            // apt format: package/suite version arch [upgradable from: oldver]
            // e.g. "curl/noble-updates 8.5.0-2ubuntu10.3 amd64 [upgradable from: 8.5.0-2ubuntu10.2]"
            const aptMatch = line.match(/^([a-zA-Z0-9_.+:-]+)\/\S+\s+(\S+)\s+\S+\s+\[upgradable from:\s+([^\]]+)\]/)
            if (aptMatch) {
                updates.push({
                    name: aptMatch[1],
                    currentVersion: aptMatch[3].trim(),
                    newVersion: aptMatch[2],
                    description: `${aptMatch[1]} ${aptMatch[3].trim()} → ${aptMatch[2]}`
                })
                continue
            }

            // Arch Linux format: package oldver -> newver
            const archMatch = line.match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/)
            if (archMatch) {
                updates.push({
                    name: archMatch[1],
                    currentVersion: archMatch[2],
                    newVersion: archMatch[3],
                    description: `${archMatch[1]} ${archMatch[2]} → ${archMatch[3]}`
                })
                continue
            }
            
            // Fedora dnf format (Fedora 40+): packagename.arch    version    repository
            // Example: kernel.x86_64    7.0.0-0.rc7.260409.7f87a5ea.356.vanilla.fc44    coprdep:...
            const fedoraMatch = line.match(/^([a-zA-Z0-9_+.-]+\.(?:x86_64|i686|aarch64|noarch|armv7hl|ppc64le|s390x))\s+([^\s]+)\s+(\S+)$/)
            if (fedoraMatch) {
                updates.push({
                    name: fedoraMatch[1],
                    currentVersion: "",
                    newVersion: fedoraMatch[2],
                    description: `${fedoraMatch[1]} → ${fedoraMatch[2]}`
                })
                continue
            }
            
            // Fedora dnf format without arch suffix (rare): package    version    repo
            const fedoraPlainMatch = line.match(/^([a-z][a-z0-9_]*)\s+([^\s]+)\s+(\S+)$/)
            if (fedoraPlainMatch && fedoraPlainMatch[1].length > 2 && !fedoraPlainMatch[1].includes('.')) {
                updates.push({
                    name: fedoraPlainMatch[1],
                    currentVersion: "",
                    newVersion: fedoraPlainMatch[2],
                    description: `${fedoraPlainMatch[1]} → ${fedoraPlainMatch[2]}`
                })
                continue
            }
            
            // Legacy Fedora format: packagename.arch    newversion    repository
            const fedoraLegacyMatch = line.match(/^([a-zA-Z0-9_.+-]+\.[a-zA-Z0-9_]+)\s+([a-zA-Z0-9_.:-]+)\s+(\S+)$/)
            if (fedoraLegacyMatch) {
                updates.push({
                    name: fedoraLegacyMatch[1],
                    currentVersion: "",
                    newVersion: fedoraLegacyMatch[2],
                    description: `${fedoraLegacyMatch[1]} → ${fedoraLegacyMatch[2]}`
                })
                continue
            }
            
            // Fedora dnf alternative format: package.oldver -> newver
            const fedoraSimpleMatch = line.match(/^([a-zA-Z0-9_.+-]+)\s+([a-zA-Z0-9_.:-]+)\s+->\s+([a-zA-Z0-9_.:-]+)$/)
            if (fedoraSimpleMatch) {
                updates.push({
                    name: fedoraSimpleMatch[1],
                    currentVersion: fedoraSimpleMatch[2],
                    newVersion: fedoraSimpleMatch[3],
                    description: `${fedoraSimpleMatch[1]} ${fedoraSimpleMatch[2]} → ${fedoraSimpleMatch[3]}`
                })
                continue
            }
        }

        console.log("Parsed updates:", updates.length, updates)
        availableUpdates = updates
    }

    function checkForFlatpakUpdates() {
        if (!flatpakAvailable || isCheckingFlatpak) return

        isCheckingFlatpak = true
        flatpakUpdateChecker.command = ["sh", "-c", "echo 'n' | flatpak update 2>&1"]
        flatpakUpdateChecker.running = true
    }

    function parseFlatpakUpdates(output) {
        const lines = output.trim().split('\n').filter(line => line.trim())
        const updates = []

        console.log("Flatpak update output:", output)

        for (const line of lines) {
            // Skip header/footer lines
            if (line.startsWith("Looking") || line.startsWith("Proceed") || 
                line.startsWith("Nothing") || line.startsWith("No ") ||
                line.includes("?]") || line.trim() === "") continue

            // Parse format: " 1.\t\torg.kde.Platform.Locale\t6.10\tu\tflathub\t< 400.7 MB (partial)"
            // Split on tabs, filter empty, then extract fields
            const parts = line.split('\t').map(p => p.trim()).filter(p => p !== "")

            if (parts.length >= 5) {
                // parts[0] = "1." (number with dot)
                // parts[1] = name (e.g., "org.kde.Platform.Locale")
                // parts[2] = branch (e.g., "6.10")
                // parts[3] = operation (e.g., "u")
                // parts[4] = origin (e.g., "flathub")
                // parts[5] = size info (e.g., "< 400.7 MB (partial)")

                const name = parts[1] || ""
                const branch = parts[2] || ""
                const operation = parts[3] || ""
                const origin = parts[4] || ""
                const sizeInfo = parts[5] || ""

                if (!name || name === "Name") continue

                // Check if it's a partial download
                const isPartial = sizeInfo.includes("partial")
                // Extract download size (remove the < and any annotations)
                const downloadSize = sizeInfo.replace("<", "").replace("(partial)", "").trim()

                updates.push({
                    name: name,
                    currentVersion: branch,
                    newVersion: branch,
                    branch: branch,
                    origin: origin,
                    downloadSize: downloadSize,
                    isPartial: isPartial,
                    operation: operation,
                    ref: "",
                    description: `${name} ${branch} (${origin})`
                })
            }
        }

        console.log("Parsed flatpak updates:", updates.length, updates)
        flatpakUpdates = updates
    }

    function runUpdatesFlatpak() {
        if (!flatpakAvailable || flatpakUpdates.length === 0) return

        const updateCommand = `flatpak update -y && echo "Flatpak updates complete! Press Enter to close..." && read`
        flatpakUpdater.command = buildTerminalCommand(updateCommand)
        flatpakUpdater.running = true
    }

    function runUpdates() {
        if (!distributionSupported || !pkgManager || updateCount === 0) return

        // Use different commands based on package manager
        // Arch Linux: paru/yay -Syu
        // Fedora: sudo dnf update
        // Debian/Ubuntu: sudo apt update && sudo apt upgrade
        let updateCommand
        if (pkgManager === "apt") {
            updateCommand = `sudo apt update && sudo apt upgrade -y && echo "Updates complete! Press Enter to close..." && read`
        } else if (pkgManager === "dnf") {
            updateCommand = `sudo dnf update --refresh -y && echo "Updates complete! Press Enter to close..." && read`
        } else {
            // Arch-based:
            // - pacman requires root; use sudo in terminal
            // - paru/yay are typically run as user (they call sudo internally when needed)
            if (pkgManager === "pacman")
                updateCommand = `sudo pacman -Syu && echo "Updates complete! Press Enter to close..." && read`
            else
                updateCommand = `${pkgManager} -Syu && echo "Updates complete! Press Enter to close..." && read`
        }

        updater.command = buildTerminalCommand(updateCommand)
        updater.running = true
    }

    function resolveTerminalBinary() {
        const t = (typeof SettingsData !== "undefined" && SettingsData.terminalEmulator && SettingsData.terminalEmulator !== "")
            ? String(SettingsData.terminalEmulator)
            : (Quickshell.env("TERMINAL") || "xterm")

        // otter-term isn't a conventional terminal emulator; it fails/crashes when invoked
        // like one (no stable -e interface). Fall back to a real terminal for command runs.
        if (t === "otter-term")
            return "ptyxis"
        return t
    }

    function buildTerminalCommand(shellCmd) {
        const terminal = resolveTerminalBinary()
        console.log("Running updates in terminal:", terminal)

        // Build a best-effort spawn command per terminal family.
        // If we don't recognize it, fall back to the common "-e sh -c" pattern.
        switch (terminal) {
        case "gnome-terminal":
            return [terminal, "--", "sh", "-c", shellCmd]
        case "ptyxis":
            // ptyxis supports -- (like gnome-terminal); fallback included below if it changes
            return [terminal, "--", "sh", "-c", shellCmd]
        case "konsole":
            return [terminal, "-e", "sh", "-c", shellCmd]
        case "wezterm":
            return [terminal, "start", "--", "sh", "-c", shellCmd]
        default:
            return [terminal, "-e", "sh", "-c", shellCmd]
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: distributionSupported && pkgManager
        onTriggered: checkForUpdates()
    }

    Timer {
        id: flatpakTimer
        interval: 30 * 60 * 1000
        repeat: true
        running: flatpakAvailable
        onTriggered: checkForFlatpakUpdates()
    }
}