pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common

Singleton {
    id: root

    property bool hasUwsm: false
    property bool isElogind: false
    property bool hibernateSupported: false
    property bool inhibitorAvailable: true
    property bool idleInhibited: false
    property string inhibitReason: "Keep system awake"
    property string nvidiaCommand: ""

    Component.onCompleted: {
        detectUwsmProcess.running = true
        detectElogindProcess.running = true
        detectHibernateProcess.running = true
        detectPrimeRunProcess.running = true
    }


    Process {
        id: detectUwsmProcess
        running: false
        command: ["which", "uwsm"]

        onExited: function (exitCode) {
            hasUwsm = (exitCode === 0)
        }
    }

    Process {
        id: detectElogindProcess
        running: false
        command: ["sh", "-c", "ps -eo comm= | grep -E '^(elogind|elogind-daemon)$'"]

        onExited: function (exitCode) {
            isElogind = (exitCode === 0)
        }
    }

    Process {
        id: detectHibernateProcess
        running: false
        command: ["grep", "-q", "disk", "/sys/power/state"]

        onExited: function (exitCode) {
            hibernateSupported = (exitCode === 0)
        }
    }

    Process {
        id: detectPrimeRunProcess
        running: false
        command: ["which", "prime-run"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "prime-run";
            } else {
                detectNvidiaOffloadProcess.running = true;
            }
        }
    }

    Process {
        id: detectNvidiaOffloadProcess
        running: false
        command: ["which", "nvidia-offload"]

        onExited: function (exitCode) {
            if (exitCode === 0) {
                nvidiaCommand = "nvidia-offload";
            }
        }
    }

    Process {
        id: uwsmLogout
        command: ["uwsm", "stop"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().toLowerCase().includes("not running")) {
                    _logout()
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                return
            }
            _logout()
        }
    }

    function escapeShellArg(arg) {
        return "'" + arg.replace(/'/g, "'\\''") + "'";
    }

    function needsShellExecution(prefix) {
        if (!prefix || prefix.length === 0)
            return false;
        return /[;&|<>()$`\\"']/.test(prefix);
    }

    function launchDesktopEntry(desktopEntry, useNvidia) {
        let cmd = desktopEntry.command;
        if (useNvidia && nvidiaCommand) {
            cmd = [nvidiaCommand].concat(cmd);
        }

        const userPrefix = SessionData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("EH_DEFAULT_LAUNCH_PREFIX") || "";
        const cursorPrefix = typeof SessionData.getCursorEnvPrefix !== "undefined" ? SessionData.getCursorEnvPrefix() : "";

        let prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        if (cursorPrefix) {
            prefix = prefix.length > 0 ? `${cursorPrefix} ${prefix}` : cursorPrefix;
        }

        const workDir = desktopEntry.workingDirectory || Quickshell.env("HOME");
        const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
        const shellCmd = prefix.length > 0 ? `${prefix} ${escapedCmd}` : escapedCmd;

        if (desktopEntry.runInTerminal) {
            const terminal = Quickshell.env("TERMINAL") || "xterm";
            Quickshell.execDetached({
                command: [terminal, "-e", "sh", "-c", shellCmd],
                workingDirectory: workDir
            });
            return;
        }

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            Quickshell.execDetached({
                command: ["sh", "-c", shellCmd],
                workingDirectory: workDir
            });
            return;
        }

        if (prefix.length > 0) {
            cmd = prefix.split(" ").concat(cmd);
        }

        Quickshell.execDetached({
            command: cmd,
            workingDirectory: workDir
        });
    }

    function launchDesktopAction(desktopEntry, action, useNvidia) {
        let cmd = action.command;
        if (useNvidia && nvidiaCommand) {
            cmd = [nvidiaCommand].concat(cmd);
        }

        const userPrefix = SessionData.launchPrefix?.trim() || "";
        const defaultPrefix = Quickshell.env("EH_DEFAULT_LAUNCH_PREFIX") || "";
        const cursorPrefix = typeof SessionData.getCursorEnvPrefix !== "undefined" ? SessionData.getCursorEnvPrefix() : "";

        let prefix = userPrefix.length > 0 ? userPrefix : defaultPrefix;
        if (cursorPrefix) {
            prefix = prefix.length > 0 ? `${cursorPrefix} ${prefix}` : cursorPrefix;
        }

        if (prefix.length > 0 && needsShellExecution(prefix)) {
            const escapedCmd = cmd.map(arg => escapeShellArg(arg)).join(" ");
            const shellCmd = `${prefix} ${escapedCmd}`;

            Quickshell.execDetached({
                command: ["sh", "-c", shellCmd],
                workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME")
            });
        } else {
            if (prefix.length > 0) {
                const launchPrefix = prefix.split(" ");
                cmd = launchPrefix.concat(cmd);
            }

            Quickshell.execDetached({
                command: cmd,
                workingDirectory: desktopEntry.workingDirectory || Quickshell.env("HOME")
            });
        }
    }

    function logout() {
        if (hasUwsm) {
            uwsmLogout.running = true
            return
        }
        _logout()
    }

    function _logout() {
        if (CompositorService.isNiri) {
            NiriService.quit()
            return
        }

        if (CompositorService.isMango) {
            Quickshell.execDetached(["mmsg", "dispatch", "quit"])
            return
        }

        Hyprland.dispatch("hl.dsp.exit()")
    }

    function suspend() {
        if (CompositorService.isNiri) {
            NiriService.suspend()
            return
        }
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "suspend"])
    }

    function hibernate() {
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "hibernate"])
    }

    function reboot() {
        if (CompositorService.isNiri) {
            NiriService.reboot()
            return
        }
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "reboot"])
    }

    function poweroff() {
        if (CompositorService.isNiri) {
            NiriService.shutdown()
            return
        }
        Quickshell.execDetached([isElogind ? "loginctl" : "systemctl", "poweroff"])
    }

    signal inhibitorChanged

    function enableIdleInhibit() {
        if (idleInhibited) {
            return
        }
        idleInhibited = true
        inhibitorChanged()
    }

    function disableIdleInhibit() {
        if (!idleInhibited) {
            return
        }
        idleInhibited = false
        inhibitorChanged()
    }

    function toggleIdleInhibit() {
        if (idleInhibited) {
            disableIdleInhibit()
        } else {
            enableIdleInhibit()
        }
    }

    function setInhibitReason(reason) {
        inhibitReason = reason

        if (idleInhibited) {
            const wasActive = idleInhibited
            idleInhibited = false

            Qt.callLater(() => {
                             if (wasActive) {
                                 idleInhibited = true
                             }
                         })
        }
    }

    Process {
        id: idleInhibitProcess

        command: {
            if (!idleInhibited) {
                return ["true"]
            }

            return [isElogind ? "elogind-inhibit" : "systemd-inhibit", "--what=idle", "--who=quickshell", `--why=${inhibitReason}`, "--mode=block", "sleep", "infinity"]
        }

        running: idleInhibited

        onExited: function (exitCode) {
            if (idleInhibited && exitCode !== 0) {
                idleInhibited = false
                ToastService.showWarning("Idle inhibitor failed")
            }
        }
    }

    IpcHandler {
        function toggle(): string {
            root.toggleIdleInhibit()
            return root.idleInhibited ? "Idle inhibit enabled" : "Idle inhibit disabled"
        }

        function enable(): string {
            root.enableIdleInhibit()
            return "Idle inhibit enabled"
        }

        function disable(): string {
            root.disableIdleInhibit()
            return "Idle inhibit disabled"
        }

        function status(): string {
            return root.idleInhibited ? "Idle inhibit is enabled" : "Idle inhibit is disabled"
        }

        function reason(newReason: string): string {
            if (!newReason) {
                return `Current reason: ${root.inhibitReason}`
            }

            root.setInhibitReason(newReason)
            return `Inhibit reason set to: ${newReason}`
        }

        target: "inhibit"
    }

    Component.onDestruction: {
        if (detectUwsmProcess.running) {
            detectUwsmProcess.running = false
        }
        if (detectElogindProcess.running) {
            detectElogindProcess.running = false
        }
        if (detectHibernateProcess.running) {
            detectHibernateProcess.running = false
        }
        if (uwsmLogout.running) {
            uwsmLogout.running = false
        }
    }
}
