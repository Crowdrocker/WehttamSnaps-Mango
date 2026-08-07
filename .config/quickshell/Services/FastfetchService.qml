pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // System info
    property string osName: ""
    property string hostname: ""
    property string kernelVersion: ""
    property string uptime: ""
    property string architecture: ""
    
    // Software
    property string shell: ""
    property string shellVersion: ""
    property string packages: ""
    property string packageManager: ""
    
    // Display
    property string resolution: ""
    property string desktopEnvironment: ""
    property string windowManager: ""
    property string theme: ""
    property string icons: ""
    property string fonts: ""
    
    // Hardware
    property string cpu: ""
    property string gpu: ""
    property string memory: ""
    property string disk: ""
    property string localIp: ""
    
    property bool isLoading: false
    property bool isReady: false

    function refreshAll() {
        isLoading = true
        isReady = false
        
        // Get basic system info
        refreshSystem()
        refreshUptime()
        refreshShell()
        refreshPackages()
        refreshDisplay()
        refreshDesktop()
        refreshHardware()
        refreshNetwork()
    }

    function refreshSystem() {
        systemProcess.running = true
    }

    function refreshUptime() {
        uptimeProcess.running = true
    }

    function refreshShell() {
        shellProcess.running = true
    }

    function refreshPackages() {
        // Try different package managers
        packageDetectProcess.running = true
    }

    function refreshDisplay() {
        getResolution()
    }

    function refreshDesktop() {
        desktopProcess.running = true
        wmProcess.running = true
        themeProcess.running = true
    }

    function refreshHardware() {
        // These will be populated from HardwareService and DgopService
        hardwareProcess.running = true
    }

    function refreshNetwork() {
        ipProcess.running = true
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        
        const parts = []
        if (days > 0) parts.push(`${days}d`)
        if (hours > 0) parts.push(`${hours}h`)
        if (minutes > 0) parts.push(`${minutes}m`)
        
        return parts.length > 0 ? parts.join(" ") : `${seconds}s`
    }

    Component.onCompleted: {
        refreshAll()
    }

    Process {
        id: systemProcess
        running: false
        command: ["sh", "-c", "uname -a"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    root.hostname = parts[1]
                    root.kernelVersion = parts[2]
                    root.architecture = parts[11] || parts[parts.length - 1] || ""
                }
                
                osProcess.running = true
            }
        }
    }

    Process {
        id: osProcess
        running: false
        command: ["sh", "-c", "cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | cut -d'=' -f2 | tr -d '\"' || cat /etc/os-release 2>/dev/null | grep '^NAME=' | cut -d'=' -f2 | tr -d '\"' || echo 'Linux'"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.osName = text.trim() || "Linux"
                checkReady()
            }
        }
    }

    Process {
        id: uptimeProcess
        running: false
        command: ["cat", "/proc/uptime"]

        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = parseInt(text.split(" ")[0])
                root.uptime = formatUptime(seconds)
                checkReady()
            }
        }
    }

    Process {
        id: shellProcess
        running: false
        command: ["sh", "-c", "echo \"$SHELL\" | xargs basename"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.shell = text.trim() || "Unknown"
                shellVersionProcess.running = true
            }
        }
    }

    Process {
        id: shellVersionProcess
        running: false
        command: ["sh", "-c", "if [ -n \"$SHELL\" ]; then $SHELL --version 2>&1 | head -1 || echo ''; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                const version = text.trim()
                if (version) {
                    const match = version.match(/(\d+\.\d+(?:\.\d+)?)/)
                    if (match) {
                        root.shellVersion = match[1]
                    } else {
                        root.shellVersion = ""
                    }
                }
                checkReady()
            }
        }
    }

    // Count packages by parsing full output lines, same strategy as PackageManagerService.
    // Each process collects raw output and counts non-empty/valid lines rather than
    // piping through wc -l, which returns 0 on empty streams.

    Process {
        id: dpkgProcess
        running: false
        // Same command as PackageManagerService _parseAptInstalled: dpkg -l | grep '^ii'
        command: ["sh", "-c", "dpkg -l 2>/dev/null | grep '^ii'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().startsWith("ii "))
                root.packages = lines.length.toString()
                root.packageManager = "dpkg"
                checkReady()
            }
        }
    }

    Process {
        id: pacmanProcess
        running: false
        // Same command as PackageManagerService getInstalledPackages pacman branch
        command: ["sh", "-c", "pacman -Q 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "pacman"
                checkReady()
            }
        }
    }

    Process {
        id: dnfProcess
        running: false
        // Same command as PackageManagerService getInstalledPackages dnf branch
        command: ["sh", "-c", "dnf list --installed --quiet 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // dnf list output has a header line "Installed Packages" — skip it
                const lines = text.split("\n").filter(l => {
                    const t = l.trim()
                    return t.length > 0 && !t.startsWith("Installed") && !t.startsWith("Last metadata")
                })
                root.packages = lines.length.toString()
                root.packageManager = "dnf"
                checkReady()
            }
        }
    }

    Process {
        id: aptProcess
        running: false
        command: ["sh", "-c", "dpkg -l 2>/dev/null | grep '^ii'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().startsWith("ii "))
                root.packages = lines.length.toString()
                root.packageManager = "apt"
                checkReady()
            }
        }
    }

    Process {
        id: rpmProcess
        running: false
        command: ["sh", "-c", "rpm -qa 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "rpm"
                checkReady()
            }
        }
    }

    Process {
        id: emergeProcess
        running: false
        command: ["sh", "-c", "qlist -I 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "emerge"
                checkReady()
            }
        }
    }

    Process {
        id: xbpsProcess
        running: false
        command: ["sh", "-c", "xbps-query -l 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "xbps"
                checkReady()
            }
        }
    }

    Process {
        id: apkProcess
        running: false
        command: ["sh", "-c", "apk list -I 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "apk"
                checkReady()
            }
        }
    }

    Process {
        id: packageDetectProcess
        running: false
        command: ["sh", "-c", "command -v nix-env >/dev/null 2>&1 && echo 'nix-env' || command -v pacman >/dev/null 2>&1 && echo 'pacman' || command -v dnf >/dev/null 2>&1 && echo 'dnf' || command -v apt >/dev/null 2>&1 && echo 'apt' || command -v dpkg >/dev/null 2>&1 && echo 'dpkg' || command -v rpm >/dev/null 2>&1 && echo 'rpm' || command -v emerge >/dev/null 2>&1 && echo 'emerge' || command -v xbps-query >/dev/null 2>&1 && echo 'xbps' || command -v apk >/dev/null 2>&1 && echo 'apk' || echo 'none'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const pm = text.trim()
                if (pm === "nix-env") {
                    nixEnvProcess.running = true
                } else if (pm === "pacman") {
                    pacmanProcess.running = true
                } else if (pm === "dnf") {
                    dnfProcess.running = true
                } else if (pm === "apt") {
                    aptProcess.running = true
                } else if (pm === "dpkg") {
                    dpkgProcess.running = true
                } else if (pm === "rpm") {
                    rpmProcess.running = true
                } else if (pm === "emerge") {
                    emergeProcess.running = true
                } else if (pm === "xbps") {
                    xbpsProcess.running = true
                } else if (pm === "apk") {
                    apkProcess.running = true
                } else {
                    root.packages = "Unknown"
                    root.packageManager = "Unknown"
                    checkReady()
                }
            }
        }
    }

    Process {
        id: nixEnvProcess
        running: false
        command: ["sh", "-c", "nix-env -q 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0)
                root.packages = lines.length.toString()
                root.packageManager = "nix-env"
                checkReady()
            }
        }
    }

    function getResolution() {
        if (typeof Quickshell !== "undefined" && Quickshell.screens && Quickshell.screens.length > 0) {
            const screen = Quickshell.screens[0]
            root.resolution = `${screen.width}x${screen.height}`
            checkReady()
        } else {
            resolutionProcess.running = true
        }
    }

    Process {
        id: resolutionProcess
        running: false
        command: ["sh", "-c", "if command -v xrandr >/dev/null 2>&1; then xrandr --current 2>/dev/null | grep '*' | head -1 | awk '{print $1}'; elif command -v wayland-info >/dev/null 2>&1; then wayland-info 2>/dev/null | grep -i resolution | head -1; else echo ''; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                let res = text.trim()
                root.resolution = res || "Unknown"
                checkReady()
            }
        }
    }

    Process {
        id: desktopProcess
        running: false
        command: ["sh", "-c", "echo \"$XDG_CURRENT_DESKTOP\" | tr '[:upper:]' '[:lower:]' || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.desktopEnvironment = text.trim() || "Unknown"
                checkReady()
            }
        }
    }

    Process {
        id: wmProcess
        running: false
        command: ["sh", "-c", "if [ -n \"$XDG_CURRENT_DESKTOP\" ]; then echo \"$XDG_CURRENT_DESKTOP\"; elif pgrep -x hyprland >/dev/null; then echo 'Hyprland'; elif pgrep -x sway >/dev/null; then echo 'Sway'; elif pgrep -x i3 >/dev/null; then echo 'i3'; elif pgrep -x bspwm >/dev/null; then echo 'bspwm'; elif pgrep -x dwm >/dev/null; then echo 'dwm'; elif pgrep -x openbox >/dev/null; then echo 'Openbox'; elif pgrep -x fluxbox >/dev/null; then echo 'Fluxbox'; elif pgrep -x awesome >/dev/null; then echo 'Awesome'; elif pgrep -x xfwm4 >/dev/null; then echo 'XFWM4'; elif pgrep -x kwin >/dev/null; then echo 'KWin'; elif pgrep -x mutter >/dev/null; then echo 'Mutter'; elif pgrep -x marco >/dev/null; then echo 'Marco'; else echo 'Unknown'; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.windowManager = text.trim() || "Unknown"
                checkReady()
            }
        }
    }

    Process {
        id: themeProcess
        running: false
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d \"'\" || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.theme = text.trim() || "Unknown"
                iconsProcess.running = true
            }
        }
    }

    Process {
        id: iconsProcess
        running: false
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d \"'\" || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.icons = text.trim() || "Unknown"
                fontsProcess.running = true
            }
        }
    }

    Process {
        id: fontsProcess
        running: false
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d \"'\" || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.fonts = text.trim() || "Unknown"
                checkReady()
            }
        }
    }

    Process {
        id: hardwareProcess
        running: false
        command: ["sh", "-c", "lscpu | grep 'Model name' | cut -d':' -f2 | xargs"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.cpu = text.trim() || "Unknown"
                checkReady()
            }
        }
    }

    Process {
        id: ipProcess
        running: false
        command: ["sh", "-c", "ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo ''"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.localIp = text.trim() || "Unknown"
                checkReady()
            }
        }
    }

    function checkReady() {
        // Simple check - in a real implementation you'd track which processes completed
        Qt.callLater(() => {
            if (root.osName && root.hostname && root.kernelVersion) {
                root.isLoading = false
                root.isReady = true
            }
        })
    }

    // Timer to refresh periodically
    Timer {
        interval: 60000 // Refresh every minute
        running: true
        repeat: true
        onTriggered: {
            refreshUptime()
            refreshNetwork()
        }
    }
}
