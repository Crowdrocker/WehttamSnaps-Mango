pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../Common/ShellUtils.js" as ShellUtils

Singleton {
    id: root

    property bool accountsServiceAvailable: false
    property string systemProfileImage: ""
    property string profileImage: ""
    property bool settingsPortalAvailable: false
    property int systemColorScheme: 0
    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)

    function init() {
    }

    function getSystemProfileImage() {
        systemProfileCheckProcess.running = true
    }

    function setProfileImage(imagePath) {
        if (typeof imagePath !== 'string') {
            if (typeof LoggingService !== 'undefined') {
                LoggingService.warn("PortalService", "setProfileImage called with invalid type", { type: typeof imagePath })
            }
            return
        }
        
        profileImage = imagePath
        saveProfileSettings()
        if (accountsServiceAvailable && imagePath) {
            setSystemProfileImage(imagePath)
        }
    }

    function getSystemColorScheme() {
        systemColorSchemeCheckProcess.running = true
    }

    function setLightMode(isLightMode) {
        if (settingsPortalAvailable) {
            setSystemColorScheme(isLightMode)
        }
    }

    function setSystemColorScheme(isLightMode) {
        if (!settingsPortalAvailable) {
            return
        }

        const colorScheme = isLightMode ? "prefer-light" : "prefer-dark"
        const script = `gsettings set org.gnome.desktop.interface color-scheme '${colorScheme}'`

        systemColorSchemeSetProcess.command = ["bash", "-c", script]
        systemColorSchemeSetProcess.running = true
    }

    function setSystemProfileImage(imagePath) {
        if (!accountsServiceAvailable || !imagePath || typeof imagePath !== 'string') {
            if (typeof LoggingService !== 'undefined' && imagePath) {
                LoggingService.warn("PortalService", "setSystemProfileImage called with invalid input", { 
                    accountsServiceAvailable: accountsServiceAvailable,
                    imagePathType: typeof imagePath 
                })
            }
            return
        }
        
        if (imagePath.length > 4096) {
            if (typeof LoggingService !== 'undefined') {
                LoggingService.error("PortalService", "Image path too long", { length: imagePath.length })
            }
            return
        }
        
        if (!ShellUtils.isValidPath(imagePath)) {
            if (typeof LoggingService !== 'undefined') {
                LoggingService.warn("PortalService", "Invalid image path", { path: imagePath })
            }
            return
        }
        
        const escapedPath = ShellUtils.escapeShellArg(imagePath)
        const script = `dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:${escapedPath}`

        systemProfileSetProcess.command = ["bash", "-c", script]
        systemProfileSetProcess.running = true
    }

    Component.onCompleted: {
        loadProfileSettings()
        checkAccountsService()
        checkSettingsPortal()
    }

    function loadProfileSettings() {
        parseProfileSettings(profileFile.text())
    }

    function parseProfileSettings(content) {
        try {
            if (content && content.trim()) {
                var settings = JSON.parse(content)
                if (settings.profileImage && settings.profileImage !== "") {
                    profileImage = settings.profileImage
                }
            }
        } catch (e) {
        }
    }

    function saveProfileSettings() {
        profileFile.setText(JSON.stringify({
            "profileImage": profileImage
        }, null, 2))
    }

    FileView {
        id: profileFile

        path: `${Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericStateLocation))}/EventHorizon/profile.json`
        blockLoading: true
        blockWrites: false
        watchChanges: true
        onLoaded: {
            parseProfileSettings(profileFile.text())
        }
    }

    function checkAccountsService() {
        accountsServiceCheckProcess.running = true
    }

    function checkSettingsPortal() {
        settingsPortalCheckProcess.running = true
    }

    Process {
        id: accountsServiceCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName string:\"$USER\""]
        running: false

        onExited: exitCode => {
            root.accountsServiceAvailable = (exitCode === 0)
            if (root.accountsServiceAvailable) {
                root.getSystemProfileImage()
            }
        }
    }

    Process {
        id: systemProfileCheckProcess
        command: ["bash", "-c", "dbus-send --system --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.DBus.Properties.Get string:org.freedesktop.Accounts.User string:IconFile"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/string\s+"([^"]+)"/)
                if (match && match[1] && match[1] !== "" && match[1] !== "/var/lib/AccountsService/icons/") {
                    root.systemProfileImage = match[1]

                    if (!root.profileImage || root.profileImage === "") {
                        root.profileImage = root.systemProfileImage
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemProfileImage = ""
            }
        }
    }

    Process {
        id: systemProfileSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                root.getSystemProfileImage()
            }
        }
    }

    Process {
        id: settingsPortalCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        onExited: exitCode => {
            root.settingsPortalAvailable = (exitCode === 0)
            if (root.settingsPortalAvailable) {
                root.getSystemColorScheme()
            }
        }
    }

    Process {
        id: systemColorSchemeCheckProcess
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop", "--object-path", "/org/freedesktop/portal/desktop", "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/uint32 (\d+)/)
                if (match && match[1]) {
                    root.systemColorScheme = parseInt(match[1])

                    if (typeof Theme !== "undefined") {
                        const shouldBeLightMode = (root.systemColorScheme === 2)
                        if (Theme.isLightMode !== shouldBeLightMode) {
                            Theme.isLightMode = shouldBeLightMode
                            if (typeof SessionData !== "undefined") {
                                SessionData.setLightMode(shouldBeLightMode)
                            }
                        }
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.systemColorScheme = 0
            }
        }
    }

    Process {
        id: systemColorSchemeSetProcess
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                                 root.getSystemColorScheme()
                             })
            }
        }
    }

    IpcHandler {
        target: "profile"

        function getImage(): string {
            return root.profileImage
        }

        function setImage(path: string): string {
            if (!path || typeof path !== 'string' || path.length === 0) {
                return "ERROR: No path provided"
            }
            
            if (path.length > 4096) {
                return "ERROR: Path too long (max 4096 characters)"
            }

            const absolutePath = path.startsWith("/") ? path : `${StandardPaths.writableLocation(StandardPaths.HomeLocation)}/${path}`

            try {
                root.setProfileImage(absolutePath)
                return "SUCCESS: Profile image set to " + absolutePath
            } catch (e) {
                if (typeof LoggingService !== 'undefined') {
                    LoggingService.error("PortalService", "Failed to set profile image via IPC", { error: e.message, path: path })
                }
                return "ERROR: Failed to set profile image: " + e.toString()
            }
        }

        function clearImage(): string {
            root.setProfileImage("")
            return "SUCCESS: Profile image cleared"
        }
    }

    Component.onDestruction: {
        const processes = [
            accountsServiceCheckProcess, systemProfileCheckProcess, systemProfileSetProcess,
            settingsPortalCheckProcess, systemColorSchemeCheckProcess, systemColorSchemeSetProcess
        ]
        for (const proc of processes) {
            if (proc && proc.running) {
                proc.running = false
            }
        }
    }
}
