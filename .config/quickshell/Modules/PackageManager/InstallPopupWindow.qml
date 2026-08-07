import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: installPopup

    objectName:  "installPopupWindow"
    title:       _isBatch
        ? (_removeCount > 0 && _installCount === 0 ? "Remove Packages"
           : _installCount > 0 && _removeCount === 0 ? "Install Packages"
           : "Apply Changes")
        : (pkgInstalled ? "Remove Package" : "Install Package")

    minimumSize: Qt.size(480, 500)
    implicitWidth: 540
    implicitHeight: 640
    backgroundColor: Theme.surfaceContainer
    visible: false

    // ── Single-package display fields (first pkg, also used for single mode) ─
    property string pkgName:        ""
    property string pkgVersion:     ""
    property string pkgSource:      ""
    property string pkgDescription: ""
    property string pkgNewVersion:  ""
    property bool   pkgInstalled:   false

    // ── Operation state ──────────────────────────────────────────────────────
    property bool   isInstalling:   false
    property bool   installDone:    false
    property bool   installSuccess: false
    property string installLog:     ""

    // ── Batch state ──────────────────────────────────────────────────────────
    property var  _allPkgs:      []
    property bool _isBatch:      false
    property int  _installCount: 0
    property int  _removeCount:  0

    signal batchCompleted()

    // ── Public API ───────────────────────────────────────────────────────────
    function openPackage(pkg) {
        if (!pkg) return
        openPackages([pkg])
    }

    function openPackages(pkgs) {
        if (!pkgs || pkgs.length === 0) return

        _allPkgs      = pkgs.slice()
        _isBatch      = pkgs.length > 1
        _installCount = pkgs.filter(p => !p.installed).length
        _removeCount  = pkgs.filter(p =>  p.installed).length

        const first    = pkgs[0]
        pkgName        = first.name        || ""
        pkgVersion     = first.version     || ""
        pkgSource      = first.source      || ""
        pkgDescription = first.description || ""
        pkgNewVersion  = first.newVersion  || ""
        pkgInstalled   = first.installed   || false

        _reset()
        visible = true

        if (_isBatch) Qt.callLater(function() { _runBatch() })
    }

    function _reset() {
        isInstalling   = false
        installDone    = false
        installSuccess = false
        installLog     = ""
        terminalOutput = ""
    }

    // ── Command builders ─────────────────────────────────────────────────────
    function _buildSingleCmd(action) {
        const safeName  = pkgName.replace(/'/g, "'\\''")
        const aurHelper = PackageManagerService.aurHelper || "yay"
        if (pkgSource === "pacman") {
            return action === "install"
                ? "pkexec pacman -S --noconfirm '" + safeName + "'"
                : "pkexec pacman -R --noconfirm '" + safeName + "'"
        } else if (pkgSource === "aur") {
            return action === "install"
                ? aurHelper + " -S --noconfirm '" + safeName + "'"
                : aurHelper + " -R --noconfirm '" + safeName + "'"
        } else if (pkgSource === "apt") {
            return action === "install"
                ? "pkexec apt-get install -y '" + safeName + "'"
                : "pkexec apt-get remove -y '"  + safeName + "'"
        } else if (pkgSource === "dnf") {
            return action === "install"
                ? "pkexec dnf install --skip-file-locks -y '" + safeName + "'"
                : "pkexec dnf remove --skip-file-locks -y '"  + safeName + "'"
        } else if (pkgSource === "flatpak") {
            return action === "install"
                ? "pkexec flatpak install -y flathub '" + safeName + "'"
                : "pkexec flatpak remove -y '" + safeName + "'"
        }
        return ""
    }

    function _buildBatchCmd() {
        const aurHelper = PackageManagerService.aurHelper || "yay"
        const groups    = {}
        for (const pkg of _allPkgs) {
            const key = pkg.source + ":" + (pkg.installed ? "remove" : "install")
            if (!groups[key])
                groups[key] = { source: pkg.source, action: pkg.installed ? "remove" : "install", names: [] }
            groups[key].names.push("'" + pkg.name.replace(/'/g, "'\\''") + "'")
        }
        const cmds = []
        for (const key of Object.keys(groups)) {
            const g     = groups[key]
            const names = g.names.join(" ")
            if (g.source === "pacman") {
                cmds.push(g.action === "install" ? "pkexec pacman -S --noconfirm " + names : "pkexec pacman -R --noconfirm " + names)
            } else if (g.source === "aur") {
                const aurHelper2 = PackageManagerService.aurHelper || "yay"
                cmds.push(g.action === "install" ? aurHelper2 + " -S --noconfirm " + names : aurHelper2 + " -R --noconfirm " + names)
            } else if (g.source === "apt") {
                cmds.push(g.action === "install" ? "pkexec apt-get install -y " + names : "pkexec apt-get remove -y " + names)
            } else if (g.source === "dnf") {
                cmds.push(g.action === "install" ? "pkexec dnf install --skip-file-locks -y " + names : "pkexec dnf remove --skip-file-locks -y " + names)
            } else if (g.source === "flatpak") {
                cmds.push(g.action === "install" ? "pkexec flatpak install -y flathub " + names : "pkexec flatpak remove -y " + names)
            }
        }
        return cmds.join(" && ")
    }

    // ── Runners ──────────────────────────────────────────────────────────────
    function _runSingle(action) {
        const inner = _buildSingleCmd(action)
        if (inner === "") { installLog = "Unsupported source: " + pkgSource; return }
        _launch(inner, (action === "install" ? "Installing" : "Removing") + " " + pkgName + "…")
    }

    function _runBatch() {
        const inner = _buildBatchCmd()
        if (inner === "") { installLog = "Nothing to do."; return }
        const label = (_removeCount > 0 && _installCount === 0)
            ? "Removing " + _removeCount + " package" + (_removeCount > 1 ? "s" : "") + "…"
            : (_installCount > 0 && _removeCount === 0)
                ? "Installing " + _installCount + " package" + (_installCount > 1 ? "s" : "") + "…"
                : "Applying " + _allPkgs.length + " changes…"
        _launch(inner, label)
    }

    function _launch(inner, label) {
        isInstalling   = true
        installDone    = false
        installSuccess = false
        terminalOutput = ""
        installLog     = label

        const logFile  = installPopup._logFile
        const wrapped  = "{ " + inner + "; } > " + logFile + " 2>&1; exit $?"
        const terminal = PackageManagerService._getTerminal()

        Qt.callLater(function() {
            var cp = Qt.createQmlObject(
                'import Quickshell.Io; Process { command: ["sh", "-c", "truncate -s 0 ' + logFile + ' 2>/dev/null || true"] }',
                installPopup, "clearProc")
            if (cp) cp.running = true
        })

        console.log("[InstallPopup] launch:", inner)
        installProc.command = [terminal, "-e", "bash", "-c", wrapped]
        installProc.running = true
        tailTimer.start()
    }

    function _doInstall() {
        if (pkgName === "" || pkgSource === "") return
        _runSingle("install")
    }

    function _doRemove() {
        if (pkgName === "" || pkgSource === "") return
        _runSingle("remove")
    }

    // ── I/O plumbing ─────────────────────────────────────────────────────────
    property string _logFile:       "/tmp/eh-install-output.log"
    property string terminalOutput: ""

    StdioCollector {
        id: installCollector
        onTextChanged: installPopup.terminalOutput = installCollector.text
    }
    StdioCollector {
        id: installErrCollector
        onTextChanged: installPopup.terminalOutput = installCollector.text + installErrCollector.text
    }
    Process {
        id: tailProc
        command: ["tail", "-f", installPopup._logFile]
        stdout:  installCollector
        stderr:  installErrCollector
    }
    Process {
        id: installProc
        onExited: function(code) {
            tailProc.running = false
            installPopup.installDone    = true
            installPopup.installSuccess = (code === 0)
            if (code === 0) {
                installPopup.terminalOutput += "\n[" + (installPopup._isBatch ? "Done" : installPopup.pkgInstalled ? "Removal" : "Installation") + " complete!]\n"
                installPopup.installLog = installPopup._isBatch ? "All operations complete." : (installPopup.pkgInstalled ? "Removal complete." : "Installation complete.")
            } else {
                installPopup.terminalOutput += "\n[Failed — exit code: " + code + "]\n"
                installPopup.installLog = (installPopup.pkgInstalled ? "Removal" : "Installation") + " failed (exit code " + code + ")"
            }
            installPopup.isInstalling = false
            PackageManagerService.getInstalledPackages(false)
            if (installPopup._isBatch) installPopup.batchCompleted()
        }
    }
    Timer {
        id: tailTimer
        interval: 800; repeat: false
        onTriggered: tailProc.running = true
    }

    // ── Display helpers ──────────────────────────────────────────────────────
    function sourceColor(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"
            case "aur":     return "#a9e34b"
            case "apt":     return "#FF9F43"
            case "dnf":     return "#EF5350"
            case "flatpak": return "#9775fa"
            default:        return Theme.surfaceVariantText
        }
    }
    function sourceIcon(s) {
        switch (s) {
            case "pacman":  return "deployed_code"
            case "aur":     return "code"
            case "apt":     return "terminal"
            case "dnf":     return "package_2"
            case "flatpak": return "apps"
            default:        return "inventory_2"
        }
    }
    function sourceLabel(s) {
        switch (s) {
            case "pacman":  return "PACMAN"
            case "aur":     return "AUR"
            case "apt":     return "APT"
            case "dnf":     return "DNF"
            case "flatpak": return "FLATPAK"
            default:        return s.toUpperCase()
        }
    }
    function sourceDistro(s) {
        switch (s) {
            case "pacman":  return "Arch Linux"
            case "aur":     return "AUR (Arch User Repo)"
            case "apt":     return "Debian / Ubuntu"
            case "dnf":     return "Fedora / RHEL"
            case "flatpak": return "Flatpak"
            default:        return "System"
        }
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    FloatingWindowControls { id: winCtrl; targetWindow: installPopup }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (!installPopup.isInstalling) installPopup.hide()

        // ── Title bar ─────────────────────────────────────────────────────────
        Item {
            id: titleBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 44; z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       winCtrl.tryStartMove()
                onDoubleClicked: winCtrl.tryToggleMaximize()
            }
            Rectangle { anchors.fill: parent; color: Theme.surfaceContainer; opacity: 0.6 }

            RowLayout {
                anchors { left: parent.left; leftMargin: Theme.spacingL; verticalCenter: parent.verticalCenter }
                spacing: Theme.spacingM

                Text {
                    text: installPopup._isBatch
                        ? (installPopup._removeCount > 0 && installPopup._installCount === 0 ? "delete_sweep" : "download_for_offline")
                        : (installPopup.pkgInstalled ? "delete" : "download")
                    font.family: "Material Symbols Rounded"; font.pixelSize: Theme.iconSize
                    color: (installPopup._removeCount > 0 && installPopup._installCount === 0) ? "#EF5350" : Theme.primary
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: {
                        if (!installPopup._isBatch)
                            return installPopup.pkgInstalled ? "Remove Package" : "Install Package"
                        if (installPopup._removeCount > 0 && installPopup._installCount === 0)
                            return "Remove " + installPopup._removeCount + " Package" + (installPopup._removeCount > 1 ? "s" : "")
                        if (installPopup._installCount > 0 && installPopup._removeCount === 0)
                            return "Install " + installPopup._installCount + " Package" + (installPopup._installCount > 1 ? "s" : "")
                        return "Apply Changes (" + installPopup._allPkgs.length + ")"
                    }
                    font.pixelSize: Theme.fontSizeXLarge; font.weight: Font.Medium; color: Theme.surfaceText
                }

                Row {
                    visible: installPopup._isBatch
                    spacing: 6; Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        visible: installPopup._installCount > 0
                        height: 22; radius: 11; width: installChipLbl.implicitWidth + 16
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40); border.width: 1
                        StyledText { id: installChipLbl; anchors.centerIn: parent; text: installPopup._installCount + " install"; font.pixelSize: Theme.fontSizeXS; font.weight: Font.Bold; color: Theme.primary }
                    }
                    Rectangle {
                        visible: installPopup._removeCount > 0
                        height: 22; radius: 11; width: removeChipLbl.implicitWidth + 16
                        color: Qt.rgba(0.937, 0.325, 0.314, 0.15)
                        border.color: Qt.rgba(0.937, 0.325, 0.314, 0.40); border.width: 1
                        StyledText { id: removeChipLbl; anchors.centerIn: parent; text: installPopup._removeCount + " remove"; font.pixelSize: Theme.fontSizeXS; font.weight: Font.Bold; color: "#EF5350" }
                    }
                }

                Rectangle {
                    visible: !installPopup._isBatch && installPopup.pkgSource !== ""
                    height: 22; width: sourceBadgeText.implicitWidth + Theme.spacingM * 2; radius: 11
                    Layout.alignment: Qt.AlignVCenter
                    color: Qt.rgba(Qt.color(installPopup.sourceColor(installPopup.pkgSource)).r, Qt.color(installPopup.sourceColor(installPopup.pkgSource)).g, Qt.color(installPopup.sourceColor(installPopup.pkgSource)).b, 0.15)
                    border.color: Qt.rgba(Qt.color(installPopup.sourceColor(installPopup.pkgSource)).r, Qt.color(installPopup.sourceColor(installPopup.pkgSource)).g, Qt.color(installPopup.sourceColor(installPopup.pkgSource)).b, 0.40); border.width: 1
                    StyledText { id: sourceBadgeText; anchors.centerIn: parent; text: installPopup.sourceLabel(installPopup.pkgSource); font.pixelSize: Theme.fontSizeXS; font.weight: Font.Bold; font.letterSpacing: 0.6; color: installPopup.sourceColor(installPopup.pkgSource) }
                }
            }

            EHActionButton {
                anchors { right: parent.right; rightMargin: Theme.spacingM; verticalCenter: parent.verticalCenter }
                circular: false; iconName: "close"; iconSize: Theme.iconSize - 4; iconColor: Theme.surfaceText
                enabled: !installPopup.isInstalling
                onClicked: installPopup.hide()
            }
        }

        // ── Action bar (pinned bottom) ─────────────────────────────────────────
        Rectangle {
            id: actionBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 52; color: Theme.surfaceContainer
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12); border.width: 1

            RowLayout {
                anchors { left: parent.left; leftMargin: Theme.spacingL; right: parent.right; rightMargin: Theme.spacingL; verticalCenter: parent.verticalCenter }
                spacing: Theme.spacingM

                StyledText {
                    text: installPopup._isBatch ? installPopup._allPkgs.length + " packages" : (installPopup.pkgName || "")
                    font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 88; height: 36; radius: 8
                    color: cancelArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25); border.width: 1
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: "close"; font.family: "Material Symbols Rounded"; font.pixelSize: 15; color: Theme.surfaceVariantText; Layout.alignment: Qt.AlignVCenter }
                        StyledText { text: installPopup.installDone ? "Close" : "Cancel"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: installPopup.hide() }
                }

                Rectangle {
                    visible: !installPopup._isBatch && !installPopup.installDone
                    width: 88; height: 36; radius: 8
                    color: actionArea.containsMouse ? (installPopup.pkgInstalled ? Qt.darker("#EF5350", 1.1) : Qt.darker(Theme.primary, 1.1)) : (installPopup.pkgInstalled ? "#EF5350" : Theme.primary)
                    opacity: installPopup.isInstalling ? 0.5 : 1.0
                    RowLayout { anchors.centerIn: parent; spacing: 6
                        Text { text: installPopup.pkgInstalled ? "delete" : "download"; font.family: "Material Symbols Rounded"; font.pixelSize: 15; color: Theme.onPrimary; Layout.alignment: Qt.AlignVCenter }
                        StyledText { text: installPopup.pkgInstalled ? "Remove" : "Install"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.onPrimary }
                    }
                    MouseArea { id: actionArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !installPopup.isInstalling
                        onClicked: installPopup.pkgInstalled ? installPopup._doRemove() : installPopup._doInstall()
                    }
                }
            }
        }

        // ── Body: between title bar and action bar ────────────────────────────
        Item {
            anchors {
                top: titleBar.bottom; left: parent.left; right: parent.right; bottom: actionBar.top
            }

            // Bottom panel: terminal output / completion / hint (height is dynamic)
            Column {
                id: bottomPanel
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.spacingL }
                spacing: Theme.spacingM

                // Live terminal output
                Rectangle {
                    visible: installPopup.isInstalling || installPopup.installDone
                    width: parent.width; height: 130
                    radius: Theme.cornerRadius
                    color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1; clip: true

                    Rectangle {
                        id: logHeader
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 28; radius: Theme.cornerRadius
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: parent.radius; color: parent.color }
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM } spacing: Theme.spacingS
                            Text {
                                text: installPopup.isInstalling ? "hourglass_empty" : (installPopup.installSuccess ? "check_circle" : "error")
                                font.family: "Material Symbols Rounded"; font.pixelSize: 13
                                color: installPopup.isInstalling ? Theme.primary : (installPopup.installSuccess ? "#4CAF50" : "#EF5350")
                                Layout.alignment: Qt.AlignVCenter
                                RotationAnimation on rotation { running: installPopup.isInstalling; loops: Animation.Infinite; from: 0; to: 360; duration: 1200; easing.type: Easing.Linear }
                            }
                            StyledText {
                                text: installPopup.installLog; font.pixelSize: Theme.fontSizeXS; font.weight: Font.Medium
                                color: installPopup.installDone ? (installPopup.installSuccess ? "#4CAF50" : "#EF5350") : Theme.surfaceText
                                Layout.fillWidth: true
                            }
                        }
                    }
                    Flickable {
                        anchors { top: logHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.spacingS }
                        contentHeight: logText.implicitHeight; contentWidth: width; clip: true; boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        TextEdit {
                            id: logText; width: parent.width; text: installPopup.terminalOutput
                            font.pixelSize: 11; font.family: "monospace"
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
                            readOnly: true; wrapMode: TextEdit.Wrap; selectByKeyboard: false
                            onTextChanged: {
                                var f = parent
                                f.contentY = Math.max(0, f.contentHeight - f.height)
                            }
                        }
                    }
                }

                // Completion banner
                Rectangle {
                    visible: installPopup.installDone
                    width: parent.width; implicitHeight: completionRow.implicitHeight + Theme.spacingM * 2; radius: Theme.cornerRadius
                    color: installPopup.installSuccess ? Qt.rgba(0.298, 0.686, 0.314, 0.10) : Qt.rgba(0.937, 0.325, 0.314, 0.10)
                    border.color: installPopup.installSuccess ? Qt.rgba(0.298, 0.686, 0.314, 0.45) : Qt.rgba(0.937, 0.325, 0.314, 0.45); border.width: 1
                    RowLayout {
                        id: completionRow
                        anchors { fill: parent; margins: Theme.spacingM }
                        spacing: Theme.spacingS
                        Text { text: installPopup.installSuccess ? "check_circle" : "error"; font.family: "Material Symbols Rounded"; font.pixelSize: 22; color: installPopup.installSuccess ? "#4CAF50" : "#EF5350"; Layout.alignment: Qt.AlignVCenter }
                        Column {
                            Layout.fillWidth: true; spacing: 2
                            StyledText {
                                text: installPopup.installSuccess
                                    ? (installPopup._isBatch ? "All " + installPopup._allPkgs.length + " operations complete" : (installPopup.pkgInstalled ? "Removal complete" : "Installation complete"))
                                    : (installPopup._isBatch ? "Operation failed — check the log above" : (installPopup.pkgInstalled ? "Removal failed" : "Installation failed"))
                                font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold
                                color: installPopup.installSuccess ? "#4CAF50" : "#EF5350"
                            }
                            StyledText {
                                visible: !installPopup._isBatch
                                text: installPopup.installSuccess ? (installPopup.pkgInstalled ? installPopup.pkgName + " was removed successfully." : installPopup.pkgName + " was installed successfully.") : installPopup.installLog
                                font.pixelSize: Theme.fontSizeXS; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                            }
                        }
                    }
                }

                // Pre-operation hint
                StyledText {
                    visible: !installPopup.isInstalling && !installPopup.installDone
                    text: installPopup._isBatch
                        ? "All packages will be processed in one command. You will be prompted for your password once."
                        : "This will open a terminal and run the install with pkexec. You will be prompted for your password."
                    font.pixelSize: Theme.fontSizeXS; color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap; width: parent.width
                }
            }

            // Scrollable package list fills the space above the bottom panel
            Flickable {
                id: pkgListScroller
                anchors {
                    top: parent.top;       topMargin:    Theme.spacingL
                    left: parent.left;     leftMargin:   Theme.spacingL
                    right: parent.right;   rightMargin:  Theme.spacingL
                    bottom: bottomPanel.top; bottomMargin: Theme.spacingM
                }
                clip: true
                contentHeight: pkgListCol.implicitHeight
                contentWidth:  width
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                Column {
                    id: pkgListCol
                    width: pkgListScroller.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: installPopup._allPkgs

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property string _src:      modelData.source || ""
                            readonly property string _accent:   installPopup.sourceColor(_src)
                            readonly property bool   _isRemove: modelData.installed || false

                            width:         pkgListCol.width
                            implicitHeight: pkgRow.implicitHeight + Theme.spacingM + Theme.spacingS
                            radius: 8

                            color: _isRemove
                                ? Qt.rgba(0.937, 0.325, 0.314, 0.06)
                                : Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.06)
                            border.color: _isRemove
                                ? Qt.rgba(0.937, 0.325, 0.314, 0.20)
                                : Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.22)
                            border.width: 1

                            // Staggered fade-in
                            opacity: 0
                            Component.onCompleted: cardFade.start()
                            NumberAnimation on opacity { id: cardFade; to: 1; duration: 200; from: 0; easing.type: Easing.OutCubic }

                            RowLayout {
                                id: pkgRow
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Theme.spacingS + 2; rightMargin: Theme.spacingS + 2
                                }
                                spacing: Theme.spacingS

                                // Source icon bubble
                                Rectangle {
                                    width: 34; height: 34; radius: 8
                                    Layout.alignment: Qt.AlignVCenter
                                    color:        Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.15)
                                    border.color: Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.35)
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text:  installPopup.sourceIcon(_src)
                                        font.family:    "Material Symbols Rounded"
                                        font.pixelSize: 19
                                        color: _accent
                                    }
                                }

                                // Text content
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    // Name + action badge + source badge
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: modelData.name || ""
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight:    Font.SemiBold
                                            color:          Theme.surfaceText
                                            elide:          Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            height: 18; radius: 9; width: actionLbl.implicitWidth + 10
                                            color:        _isRemove ? Qt.rgba(0.937, 0.325, 0.314, 0.15) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            border.color: _isRemove ? Qt.rgba(0.937, 0.325, 0.314, 0.40) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            border.width: 1; Layout.alignment: Qt.AlignVCenter
                                            StyledText { id: actionLbl; anchors.centerIn: parent; text: _isRemove ? "REMOVE" : "INSTALL"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5; color: _isRemove ? "#EF5350" : Theme.primary }
                                        }

                                        Rectangle {
                                            height: 18; radius: 9; width: srcLbl.implicitWidth + 10
                                            color:        Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.12)
                                            border.color: Qt.rgba(Qt.color(_accent).r, Qt.color(_accent).g, Qt.color(_accent).b, 0.35)
                                            border.width: 1; Layout.alignment: Qt.AlignVCenter
                                            StyledText { id: srcLbl; anchors.centerIn: parent; text: installPopup.sourceLabel(_src); font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5; color: _accent }
                                        }
                                    }

                                    // Description
                                    StyledText {
                                        visible: (modelData.description || "") !== ""
                                        text:    modelData.description || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:   Theme.surfaceVariantText
                                        width:   parent.width
                                        elide:   Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    // Version · size
                                    Row {
                                        spacing: 6

                                        StyledText {
                                            visible: (modelData.version || "") !== ""
                                            text:    "v" + (modelData.version || "")
                                            font.pixelSize: Theme.fontSizeXS
                                            color:   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                        }
                                        StyledText {
                                            visible: (modelData.version || "") !== "" && (modelData.size || "") !== ""
                                            text:    "·"
                                            font.pixelSize: Theme.fontSizeXS
                                            color:   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                                        }
                                        StyledText {
                                            visible: (modelData.size || "") !== ""
                                            text:    modelData.size || ""
                                            font.pixelSize: Theme.fontSizeXS
                                            color:   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
