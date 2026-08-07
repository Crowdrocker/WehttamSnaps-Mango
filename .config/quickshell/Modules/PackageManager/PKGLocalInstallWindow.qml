import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

// ─────────────────────────────────────────────────────────────────────────────
//  PKGLocalInstallWindow
//  Popup install window for local .deb / .rpm / .zst packages.
//  Opens via PKGLocalInstallWindow.openFile(path) or .open()
// ─────────────────────────────────────────────────────────────────────────────

FloatingWindow {
    id: localInstallWindow

    objectName:      "pkgLocalInstallWindow"
    title:           "Install Local Package"

    IpcHandler {
        target: "event-horizon-local-install"

        function openPkg() {
            var path = ""
            try {
                path = Quickshell.readFile("/tmp/eh-pkg-file.txt").trim()
                Quickshell.execDetached(["sh", "-c", "rm -f /tmp/eh-pkg-file.txt"])
            } catch(e) {
                path = ""
            }
            
            if (path.length > 0) {
                localInstallWindow.openFile(path)
            } else {
                localInstallWindow.open()
            }
            return "INSTALL_OPENED"
        }

        function close() {
            localInstallWindow.hide()
            return "INSTALL_CLOSED"
        }
    }
    minimumSize:     Qt.size(520, 520)
    implicitWidth:   560
    implicitHeight:  600
    backgroundColor: Theme.surfaceContainer
    visible:         false

    // ── Public API ────────────────────────────────────────────────────────────
    function openFile(path) {
        filePath = path.trim()
        _reset()
        visible = true
        if (filePath !== "") _loadMeta()
    }

    function open() {
        _reset()
        visible = true
    }

    // ── Internal state ────────────────────────────────────────────────────────
    property string filePath:        ""
    property string detectedFormat:  ""   // "deb" | "rpm" | "zst" | ""
    property string pkgDisplayName:  ""
    property string pkgVersion:      ""
    property string pkgArch:         ""
    property string pkgMaintainer:   ""
    property string pkgDescription:  ""
    property string pkgSize:         ""
    property bool   metaLoaded:      false
    property bool   metaLoading:     false
    property bool   isInstalling:    false
    property bool   installDone:     false
    property bool   installSuccess:  false
    property string installLog:      ""
    property string errorMessage:    ""
    property bool   showConfirmation: false   // true = confirmation dialog, false = loading/install

    // ── Format helpers ────────────────────────────────────────────────────────
    function _ext(path) {
        const p = path.trim()
        if (p.endsWith(".deb"))     return "deb"
        if (p.endsWith(".rpm"))     return "rpm"
        if (p.endsWith(".zst") || p.endsWith(".tar.zst")) return "zst"
        return ""
    }

    function _fmtColor(fmt) {
        switch (fmt) {
            case "deb": return "#FF9F43"   // orange — Debian
            case "rpm": return "#EF5350"   // red    — Fedora
            case "zst": return "#74c0fc"   // blue   — Arch
            default:    return Theme.surfaceVariantText
        }
    }

    function _fmtLabel(fmt) {
        switch (fmt) {
            case "deb": return "DEB"
            case "rpm": return "RPM"
            case "zst": return "ZST"
            default:    return "PKG"
        }
    }

    function _fmtDistro(fmt) {
        switch (fmt) {
            case "deb": return "Debian / Ubuntu"
            case "rpm": return "Fedora / RHEL / openSUSE"
            case "zst": return "Arch Linux"
            default:    return "Unknown"
        }
    }

    function _fmtIcon(fmt) {
        switch (fmt) {
            case "deb": return "terminal"
            case "rpm": return "package_2"
            case "zst": return "deployed_code"
            default:    return "inventory_2"
        }
    }

    // ── Reset state ───────────────────────────────────────────────────────────
    function _reset() {
        detectedFormat    = ""
        pkgDisplayName    = ""
        pkgVersion        = ""
        pkgArch           = ""
        pkgMaintainer     = ""
        pkgDescription    = ""
        pkgSize           = ""
        metaLoaded        = false
        metaLoading       = false
        isInstalling      = false
        installDone       = false
        installSuccess    = false
        installLog        = ""
        errorMessage      = ""
        showConfirmation  = false
    }

    // ── Meta loading ──────────────────────────────────────────────────────────
    function _loadMeta() {
        const fmt = _ext(filePath)
        detectedFormat = fmt
        if (fmt === "") {
            errorMessage = "Unsupported file type. Only .deb, .rpm and .zst are supported."
            return
        }
        metaLoading = true
        errorMessage = ""

        if (fmt === "deb") {
            _runCmd("dpkg-deb -I '" + filePath + "' 2>/dev/null", function(out) {
                _parseDebMeta(out)
                metaLoading = false
                metaLoaded  = true
            })
        } else if (fmt === "rpm") {
            _runCmd("rpm -qip '" + filePath + "' 2>/dev/null", function(out) {
                _parseRpmMeta(out)
                metaLoading = false
                metaLoaded  = true
            })
        } else if (fmt === "zst") {
            _runCmd("bsdtar -xOf '" + filePath + "' .PKGINFO 2>/dev/null || tar -xOf '" + filePath + "' .PKGINFO 2>/dev/null", function(out) {
                _parseZstMeta(out)
                metaLoading = false
                metaLoaded  = true
            })
        }
    }

    function _parseDebMeta(raw) {
        const lines = raw.split("\n")
        for (const line of lines) {
            const t = line.trim()
            if (t.startsWith("Package:"))     pkgDisplayName  = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Version:"))     pkgVersion      = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Architecture:"))pkgArch         = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Maintainer:"))  pkgMaintainer   = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Description:")) pkgDescription  = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Installed-Size:")) {
                const kb = parseInt(t.split(":")[1].trim())
                pkgSize = isNaN(kb) ? "" : (kb > 1024 ? (kb/1024).toFixed(1) + " MB" : kb + " KB")
            }
        }
        if (!pkgDisplayName) pkgDisplayName = filePath.split("/").pop()
    }

    function _parseRpmMeta(raw) {
        const lines = raw.split("\n")
        for (const line of lines) {
            const t = line.trim()
            if (t.startsWith("Name"))        pkgDisplayName  = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Version"))     pkgVersion      = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Architecture"))pkgArch         = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Packager"))    pkgMaintainer   = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Summary"))     pkgDescription  = t.split(":").slice(1).join(":").trim()
            else if (t.startsWith("Size")) {
                const bytes = parseInt(t.split(":")[1].trim())
                if (!isNaN(bytes)) pkgSize = bytes > 1048576 ? (bytes/1048576).toFixed(1) + " MB" : (bytes/1024).toFixed(0) + " KB"
            }
        }
        if (!pkgDisplayName) pkgDisplayName = filePath.split("/").pop()
    }

    function _parseZstMeta(raw) {
        const lines = raw.split("\n")
        for (const line of lines) {
            const t = line.trim()
            if (t.startsWith("pkgname ="))   pkgDisplayName  = t.split("=").slice(1).join("=").trim()
            else if (t.startsWith("pkgver ="))     pkgVersion      = t.split("=").slice(1).join("=").trim()
            else if (t.startsWith("arch ="))       pkgArch         = t.split("=").slice(1).join("=").trim()
            else if (t.startsWith("packager ="))   pkgMaintainer   = t.split("=").slice(1).join("=").trim()
            else if (t.startsWith("pkgdesc ="))    pkgDescription  = t.split("=").slice(1).join("=").trim()
            else if (t.startsWith("size =")) {
                const bytes = parseInt(t.split("=")[1].trim())
                if (!isNaN(bytes)) pkgSize = bytes > 1048576 ? (bytes/1048576).toFixed(1) + " MB" : (bytes/1024).toFixed(0) + " KB"
            }
        }
        if (!pkgDisplayName) pkgDisplayName = filePath.split("/").pop()
    }

    // ── Install ───────────────────────────────────────────────────────────────
    property var _installer: Process {
        id: installerProc
        onExited: function(exitCode) {
            localInstallWindow.isInstalling   = false
            localInstallWindow.installDone    = true
            localInstallWindow.installSuccess = (exitCode === 0)
            // Terminal window handles live output; we just record the final result.
            if (exitCode !== 0) {
                localInstallWindow.installLog = "⚠  Terminal process exited with code " + exitCode
                    + ".\n\nCheck the terminal window for details."
            } else {
                localInstallWindow.installLog = "✓  Installation complete."
            }
        }
    }

    // Stdout/stderr collectors are not used for terminal-based installs
    // (the terminal emulator shows output directly to the user), but we
    // keep them as stubs so nothing else in the file needs to change.
    property var _stdoutCollector: StdioCollector {
        id: stdoutCol
    }

    property var _logTimer: Timer {
        id: logPoller
        interval: 250
        repeat:   false
        running:  false
    }

    function _doInstall() {
        if (filePath === "" || detectedFormat === "") return

        isInstalling   = true
        installDone    = false
        installSuccess = false
        installLog     = "Starting installation…\n"

        const safeFile = filePath.replace(/'/g, "'\\''")
        const terminal = PackageManagerService._getTerminal()

        // Build the inner pkexec command for each format.
        // We use the same terminal+pkexec pattern as PackageManagerService
        // (pkexec was removed — it has no TTY and can't show a password prompt
        // from a Quickshell Process context).
        let innerCmd = ""
        if (detectedFormat === "deb") {
            innerCmd = "dpkg -i '" + safeFile + "' && apt-get install -f -y"
        } else if (detectedFormat === "rpm") {
            // Try dnf first (handles deps), fall back to raw rpm
            innerCmd = "dnf install --skip-file-locks -y '" + safeFile + "' 2>/dev/null || rpm -ivh --force '" + safeFile + "'"
        } else if (detectedFormat === "zst") {
            innerCmd = "pacman -U --noconfirm '" + safeFile + "'"
        } else {
            isInstalling = false
            errorMessage = "Cannot install: unsupported format."
            return
        }

        const pkgLabel = pkgDisplayName || filePath.split("/").pop()
        const wrapped  = "pkexec sh -c '" + innerCmd.replace(/'/g, "'\\''") + "'"
                       + "; echo; echo '=== Install of " + pkgLabel + " complete. Press Enter to close ==='; read"

        console.log("[LocalInstall] Spawning terminal:", terminal, "cmd:", innerCmd)
        installerProc.command = [terminal, "-e", "bash", "-c", wrapped]
        installerProc.running = true
    }

    // ── Simple command runner ─────────────────────────────────────────────────
    function _runCmd(cmd, cb) {
        console.log("[_runCmd] creating Process for cmd:", cmd)
        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', localInstallWindow, "tmpProc")
        if (!proc) {
            console.log("[_runCmd] ERROR: Failed to create Process")
            return
        }
        console.log("[_runCmd] Process created")
        proc.command = ["sh", "-c", cmd]
        const col    = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc, "tmpCol")
        if (!col) {
            console.log("[_runCmd] ERROR: Failed to create StdioCollector")
            return
        }
        proc.stdout  = col
        col.onStreamFinished.connect(function() {
            console.log("[_runCmd] Stream finished, text length:", (col.text || "").length)
            cb(col.text || "")
            proc.destroy()
        })
        proc.running = true
        console.log("[_runCmd] Process started")
    }

    // ── Window controls ───────────────────────────────────────────────────────
    FloatingWindowControls {
        id: winCtrl
        targetWindow: localInstallWindow
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (!localInstallWindow.isInstalling) localInstallWindow.hide()

        // ── Title bar ─────────────────────────────────────────────────────────
        Item {
            id: titleBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 44
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       winCtrl.tryStartMove()
                onDoubleClicked: winCtrl.tryToggleMaximize()
            }

            Rectangle {
                anchors.fill: parent
                color:   Theme.surfaceContainer
                opacity: 0.6
            }

            RowLayout {
                anchors {
                    left: parent.left; leftMargin: Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingM

                EHIcon {
                    name:  "install_desktop"
                    size:  Theme.iconSize
                    color: Theme.primary
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text:           "Install Local Package"
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight:    Font.Medium
                    color:          Theme.surfaceText
                }

                // Format badge — shown once format is detected
                Rectangle {
                    visible: localInstallWindow.detectedFormat !== ""
                    height:  22
                    width:   fmtBadgeText.implicitWidth + Theme.spacingM * 2
                    radius:  height / 2
                    color:   Qt.rgba(
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.15)
                    border.color: Qt.rgba(
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.55)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        id: fmtBadgeText
                        anchors.centerIn: parent
                        text:            localInstallWindow._fmtLabel(localInstallWindow.detectedFormat)
                        font.pixelSize:  Theme.fontSizeXS
                        font.weight:     Font.Bold
                        font.letterSpacing: 0.8
                        color:           localInstallWindow._fmtColor(localInstallWindow.detectedFormat)
                    }
                }
            }

            // Close button
            EHActionButton {
                anchors {
                    right: parent.right; rightMargin: Theme.spacingM
                    verticalCenter: parent.verticalCenter
                }
                circular:  false
                iconName:  "close"
                iconSize:  Theme.iconSize - 4
                iconColor: Theme.surfaceText
                enabled:   !localInstallWindow.isInstalling
                onClicked: localInstallWindow.hide()
            }
        }

        // ── Body ──────────────────────────────────────────────────────────────
        Flickable {
            anchors {
                top:    titleBar.bottom
                left:   parent.left
                right:  parent.right
                bottom: actionBar.top
            }
            clip:          true
            contentHeight: bodyCol.implicitHeight + Theme.spacingXL
            contentWidth:  width
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: bodyCol
                width:        parent.width
                spacing:      Theme.spacingL
                topPadding:   Theme.spacingL
                bottomPadding: Theme.spacingL

                // ── File path input ───────────────────────────────────────────
                Column {
                    width:   parent.width - Theme.spacingL * 2
                    x:       Theme.spacingL
                    spacing: Theme.spacingS

                    StyledText {
                        text:           "Package File Path"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    Rectangle {
                        width:  parent.width
                        height: 40
                        radius: 8
                        color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                        border.color: pathInput.activeFocus
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingS }
                            spacing: Theme.spacingXS

                            EHIcon {
                                name:  "folder_open"
                                size:  16
                                color: pathInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            TextInput {
                                id: pathInput
                                Layout.fillWidth: true
                                text:           localInstallWindow.filePath
                                font.pixelSize: Theme.fontSizeMedium
                                color:          Theme.surfaceText
                                clip:           true
                                enabled:        !localInstallWindow.isInstalling

                                StyledText {
                                    visible:        pathInput.text === ""
                                    text:           "/path/to/package.deb  (or .rpm / .zst)"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                onTextChanged: {
                                    localInstallWindow.filePath = text
                                }

                                Keys.onReturnPressed: _onPathConfirmed()
                                Keys.onEnterPressed:  _onPathConfirmed()
                            }

                            // Clear button
                            EHActionButton {
                                visible:   pathInput.text !== ""
                                circular:  false
                                iconName:  "close"
                                iconSize:  14
                                iconColor: Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: {
                                    pathInput.text = ""
                                    localInstallWindow._reset()
                                }
                            }

                            // Load button
                            Rectangle {
                                width:  60
                                height: 28
                                radius: 6
                                color:  loadArea.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 120 } }

                                StyledText {
                                    anchors.centerIn: parent
                                    text:           "Load"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight:    Font.Medium
                                    color:          Theme.primary
                                }

                                MouseArea {
                                    id: loadArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked:    _onPathConfirmed()
                                }
                            }
                        }
                    }

                    StyledText {
                        text:           "Tip: copy the full path from your file manager and paste it above."
                        font.pixelSize: Theme.fontSizeXS
                        color:          Theme.surfaceVariantText
                        opacity:        0.7
                    }
                }

                // ── Error message ─────────────────────────────────────────────
                Rectangle {
                    visible: localInstallWindow.errorMessage !== ""
                    width:   parent.width - Theme.spacingL * 2
                    x:       Theme.spacingL
                    implicitHeight: errRow.implicitHeight + Theme.spacingM * 2
                    radius:  Theme.cornerRadius
                    color:   Qt.rgba(0.937, 0.325, 0.314, 0.10)
                    border.color: Qt.rgba(0.937, 0.325, 0.314, 0.35)
                    border.width: 1

                    RowLayout {
                        id: errRow
                        anchors { fill: parent; margins: Theme.spacingM }
                        spacing: Theme.spacingS

                        EHIcon {
                            name:  "error"
                            size:  20
                            color: "#EF5350"
                            Layout.alignment: Qt.AlignTop
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text:           localInstallWindow.errorMessage
                            font.pixelSize: Theme.fontSizeSmall
                            color:          "#EF5350"
                            wrapMode:       Text.Wrap
                        }
                    }
                }

                // ── Loading spinner ───────────────────────────────────────────
                Item {
                    visible: localInstallWindow.metaLoading
                    width:   parent.width
                    height:  80

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        EHIcon {
                            name:  "hourglass_empty"
                            size:  28
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                            RotationAnimation on rotation {
                                running:  localInstallWindow.metaLoading
                                loops:    Animation.Infinite
                                from: 0; to: 360
                                duration: 1000
                                easing.type: Easing.Linear
                            }
                        }

                        StyledText {
                            text:           "Reading package metadata…"
                            font.pixelSize: Theme.fontSizeMedium
                            color:          Theme.surfaceVariantText
                        }
                    }
                }

                // ── Package info card ─────────────────────────────────────────
                Rectangle {
                    visible: localInstallWindow.metaLoaded
                    width:   parent.width - Theme.spacingL * 2
                    x:       Theme.spacingL
                    implicitHeight: pkgInfoCol.implicitHeight + Theme.spacingL * 2
                    radius:  10
                    color:   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                        Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.30)
                    border.width: 1

                    Column {
                        id: pkgInfoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                        spacing: Theme.spacingM

                        // Package header row
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingM

                            // Format icon bubble
                            Rectangle {
                                width:  44; height: 44; radius: 10
                                Layout.alignment: Qt.AlignVCenter
                                color: Qt.rgba(
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.15)
                                border.color: Qt.rgba(
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                                    Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.45)
                                border.width: 1

                                EHIcon {
                                    anchors.centerIn: parent
                                    name:  localInstallWindow._fmtIcon(localInstallWindow.detectedFormat)
                                    size:  24
                                    color: localInstallWindow._fmtColor(localInstallWindow.detectedFormat)
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    text:           localInstallWindow.pkgDisplayName || "Unknown Package"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight:    Font.Bold
                                    color:          Theme.surfaceText
                                    elide:          Text.ElideRight
                                    width:          parent.width
                                }

                                RowLayout {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        visible:        localInstallWindow.pkgVersion !== ""
                                        text:           "v" + localInstallWindow.pkgVersion
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        visible:        localInstallWindow.pkgArch !== ""
                                        text:           "·"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        visible:        localInstallWindow.pkgArch !== ""
                                        text:           localInstallWindow.pkgArch
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                    }
                                }
                            }

                            // Size badge
                            Rectangle {
                                visible: localInstallWindow.pkgSize !== ""
                                height:  24
                                width:   sizeLabel.implicitWidth + Theme.spacingM * 2
                                radius:  height / 2
                                Layout.alignment: Qt.AlignVCenter
                                color:   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.50)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1

                                StyledText {
                                    id: sizeLabel
                                    anchors.centerIn: parent
                                    text:           localInstallWindow.pkgSize
                                    font.pixelSize: Theme.fontSizeXS
                                    font.weight:    Font.Medium
                                    color:          Theme.surfaceVariantText
                                }
                            }
                        }

                        // Description
                        StyledText {
                            visible:        localInstallWindow.pkgDescription !== ""
                            text:           localInstallWindow.pkgDescription
                            font.pixelSize: Theme.fontSizeSmall
                            color:          Theme.surfaceVariantText
                            wrapMode:       Text.WordWrap
                            width:          parent.width
                        }

                        // Divider
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                        }

                        // Distro compatibility row
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            EHIcon {
                                name:  "info"
                                size:  14
                                color: localInstallWindow._fmtColor(localInstallWindow.detectedFormat)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text:           "Compatible with " + localInstallWindow._fmtDistro(localInstallWindow.detectedFormat)
                                font.pixelSize: Theme.fontSizeSmall
                                color:          Theme.surfaceVariantText
                                Layout.fillWidth: true
                            }

                            StyledText {
                                visible:        localInstallWindow.pkgMaintainer !== ""
                                text:           localInstallWindow.pkgMaintainer
                                font.pixelSize: Theme.fontSizeXS
                                color:          Theme.surfaceVariantText
                                opacity:        0.6
                                elide:          Text.ElideRight
                                Layout.maximumWidth: 200
                            }
                        }
                    }
                }

                // ── Confirmation Dialog ──────────────────────────────────────────
                Rectangle {
                    visible: localInstallWindow.showConfirmation && !localInstallWindow.isInstalling && !localInstallWindow.installDone
                    width:   parent.width - Theme.spacingL * 2
                    x:       Theme.spacingL
                    implicitHeight: confirmCol.implicitHeight + Theme.spacingXL * 2
                    radius:  Theme.cornerRadius
                    color:   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                    border.width: 1

                    Column {
                        id: confirmCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingXL }
                        spacing: Theme.spacingL

                        // Header
                        RowLayout {
                            spacing: Theme.spacingM
                            EHIcon {
                                name:  "help_outline"
                                size:  32
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text:           "Confirm Installation"
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight:    Font.Bold
                                color:          Theme.surfaceText
                            }
                        }

                        // Package summary card
                        Rectangle {
                            width:  parent.width
                            implicitHeight: pkgSummaryCol.implicitHeight + Theme.spacingL
                            radius: Theme.cornerRadius
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)

                            Column {
                                id: pkgSummaryCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                                spacing: Theme.spacingM

                                RowLayout {
                                    width: parent.width
                                    Rectangle {
                                        width:  56; height: 56; radius: 14
                                        color: Qt.rgba(
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.15)
                                        border.color: Qt.rgba(
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).r,
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).g,
                                            Qt.color(localInstallWindow._fmtColor(localInstallWindow.detectedFormat)).b, 0.45)
                                        border.width: 1
                                        EHIcon {
                                            anchors.centerIn: parent
                                            name:  localInstallWindow._fmtIcon(localInstallWindow.detectedFormat)
                                            size:  28
                                            color: localInstallWindow._fmtColor(localInstallWindow.detectedFormat)
                                        }
                                    }
                                        Column {
                                            Layout.fillWidth: true
                                            StyledText {
                                                text:           localInstallWindow.pkgDisplayName || "Unknown Package"
                                                font.pixelSize: Theme.fontSizeLarge
                                                font.weight:    Font.Bold
                                                color:          Theme.surfaceText
                                            }
                                        RowLayout {
                                            StyledText {
                                                visible:        localInstallWindow.pkgVersion !== ""
                                                text:           "Version " + localInstallWindow.pkgVersion
                                                font.pixelSize: Theme.fontSizeSmall
                                                color:          Theme.surfaceVariantText
                                            }
                                            StyledText {
                                                visible:        localInstallWindow.pkgSize !== ""
                                                text:           "· " + localInstallWindow.pkgSize
                                                font.pixelSize: Theme.fontSizeSmall
                                                color:          Theme.surfaceVariantText
                                            }
                                        }
                                    }
                                }

                                // Description
                                StyledText {
                                    visible:        localInstallWindow.pkgDescription !== ""
                                    width:          parent.width
                                    text:           localInstallWindow.pkgDescription
                                    font.pixelSize: Theme.fontSizeSmall
                                    color:          Theme.surfaceVariantText
                                    wrapMode:       Text.WordWrap
                                }
                            }
                        }

                        // Warning text
                        RowLayout {
                            spacing: Theme.spacingS
                            EHIcon {
                                name:  "warning"
                                size:  16
                                color: "#FF9F43"
                                Layout.alignment: Qt.AlignTop
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text:           "This will open a terminal and run the install with pkexec. You will be prompted for your password in the terminal window."
                                font.pixelSize: Theme.fontSizeSmall
                                color:          "#FF9F43"
                                wrapMode:       Text.Wrap
                            }
                        }
                    }
                }

                // ── Install progress / result ──────────────────────────────────
                Rectangle {
                    visible: localInstallWindow.isInstalling || localInstallWindow.installDone
                    width:   parent.width - Theme.spacingL * 2
                    x:       Theme.spacingL
                    implicitHeight: progressCol.implicitHeight + Theme.spacingL * 2
                    radius:  Theme.cornerRadius
                    color:   localInstallWindow.installDone
                        ? (localInstallWindow.installSuccess
                            ? Qt.rgba(0.298, 0.686, 0.314, 0.08)
                            : Qt.rgba(0.937, 0.325, 0.314, 0.08))
                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: localInstallWindow.installDone
                        ? (localInstallWindow.installSuccess
                            ? Qt.rgba(0.298, 0.686, 0.314, 0.40)
                            : Qt.rgba(0.937, 0.325, 0.314, 0.40))
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    Column {
                        id: progressCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                        spacing: Theme.spacingM

                        // Status header
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            EHIcon {
                                name: localInstallWindow.installDone
                                    ? (localInstallWindow.installSuccess ? "check_circle" : "error")
                                    : "download"
                                size:  22
                                color: localInstallWindow.installDone
                                    ? (localInstallWindow.installSuccess ? "#4CAF50" : "#EF5350")
                                    : Theme.primary
                                Layout.alignment: Qt.AlignVCenter

                                RotationAnimation on rotation {
                                    running:  localInstallWindow.isInstalling && !localInstallWindow.installDone
                                    loops:    Animation.Infinite
                                    from: 0; to: 360
                                    duration: 1200
                                    easing.type: Easing.Linear
                                }
                            }

                            StyledText {
                                text: localInstallWindow.installDone
                                    ? (localInstallWindow.installSuccess
                                        ? "Installation successful!"
                                        : "Installation failed")
                                    : ("Installing " + (localInstallWindow.pkgDisplayName || "package") + "…")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight:    Font.Medium
                                color: localInstallWindow.installDone
                                    ? (localInstallWindow.installSuccess ? "#4CAF50" : "#EF5350")
                                    : Theme.surfaceText
                                Layout.fillWidth: true
                            }
                        }

                        // Indeterminate progress bar (only while installing)
                        Rectangle {
                            visible: localInstallWindow.isInstalling && !localInstallWindow.installDone
                            width:   parent.width
                            height:  4
                            radius:  2
                            color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                            clip:    true

                            Rectangle {
                                id: progressBar
                                height:  parent.height
                                radius:  parent.radius
                                width:   parent.width * 0.35
                                x:       0
                                color:   Theme.primary

                                SequentialAnimation on x {
                                    running: localInstallWindow.isInstalling && !localInstallWindow.installDone
                                    loops:   Animation.Infinite
                                    NumberAnimation {
                                        from:     -progressBar.width
                                        to:       progressBar.parent.width
                                        duration: 1400
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        // Terminal-launched notice (shown while installing)
                        Rectangle {
                            visible: localInstallWindow.isInstalling
                            width:   parent.width
                            implicitHeight: termNoticeRow.implicitHeight + Theme.spacingM * 2
                            radius:  Theme.cornerRadius
                            color:   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                            border.width: 1

                            RowLayout {
                                id: termNoticeRow
                                anchors { fill: parent; margins: Theme.spacingM }
                                spacing: Theme.spacingM

                                EHIcon {
                                    name:  "terminal"
                                    size:  22
                                    color: Theme.primary
                                    Layout.alignment: Qt.AlignTop
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    StyledText {
                                        text:           "Terminal window opened"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight:    Font.Medium
                                        color:          Theme.surfaceText
                                    }

                                    StyledText {
                                        text:           "Enter your password in the terminal to authorise the install. This window will update when the terminal closes."
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                        wrapMode:       Text.WordWrap
                                        width:          parent.width
                                    }
                                }
                            }
                        }

                        // Result log (shown after terminal exits)
                        Rectangle {
                            visible: localInstallWindow.installDone && localInstallWindow.installLog !== ""
                            width:   parent.width
                            implicitHeight: resultLogText.implicitHeight + Theme.spacingM * 2
                            radius:  8
                            color:   Qt.rgba(0, 0, 0, 0.35)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            border.width: 1

                            StyledText {
                                id: resultLogText
                                anchors { fill: parent; margins: Theme.spacingM }
                                text:           localInstallWindow.installLog
                                font.pixelSize: Theme.fontSizeSmall
                                font.family:    "monospace"
                                color:          localInstallWindow.installSuccess ? "#4ADE80" : "#EF5350"
                                wrapMode:       Text.WrapAnywhere
                            }
                        }
                    }
                }

            } // bodyCol
        } // Flickable

        // ── Action bar ────────────────────────────────────────────────────────
        Rectangle {
            id: actionBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 52
            color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1

            RowLayout {
                anchors {
                    fill:         parent
                    leftMargin:   Theme.spacingL
                    rightMargin:  Theme.spacingL
                    topMargin:    Theme.spacingS
                    bottomMargin: Theme.spacingS
                }
                spacing: Theme.spacingM

                // Left: file name hint when loaded
                StyledText {
                    visible:        localInstallWindow.metaLoaded
                    text:           localInstallWindow.filePath.split("/").pop()
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.surfaceVariantText
                    elide:          Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Item { Layout.fillWidth: true; visible: !localInstallWindow.metaLoaded }

                // Cancel / Close
                Rectangle {
                    width:  84; height: 34
                    radius: 8
                    color:  cancelArea.containsMouse
                        ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.60)
                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    StyledText {
                        anchors.centerIn: parent
                        text:           localInstallWindow.installDone ? "Close" : "Cancel"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      !localInstallWindow.isInstalling
                        onClicked:    localInstallWindow.hide()
                    }
                }

                // Install button
                Rectangle {
                    width:  localInstallWindow.showConfirmation ? 136 : 116
                    height: 34
                    radius: 8
                    visible: localInstallWindow.metaLoaded && !localInstallWindow.installDone
                    enabled: localInstallWindow.showConfirmation
                        ? true
                        : (localInstallWindow.metaLoaded && !localInstallWindow.isInstalling && !localInstallWindow.installDone)
                    opacity: enabled ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    color: installBtnArea.containsMouse && enabled
                        ? Qt.darker(Theme.primary, 1.1)
                        : Theme.primary
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        EHIcon {
                            name:  localInstallWindow.isInstalling ? "sync" : (localInstallWindow.showConfirmation ? "check" : "download")
                            size:  15
                            color: Theme.onPrimary
                            Layout.alignment: Qt.AlignVCenter

                            RotationAnimation on rotation {
                                running:  localInstallWindow.isInstalling
                                loops:   Animation.Infinite
                                from: 0; to: 360
                                duration: 1000
                                easing.type: Easing.Linear
                            }
                        }

                        StyledText {
                            text:           localInstallWindow.showConfirmation
                                ? "Install"
                                : (localInstallWindow.isInstalling ? "Installing…" : "Install")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    Font.Bold
                            color:          Theme.onPrimary
                        }
                    }

                    MouseArea {
                        id: installBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    if (parent.enabled) {
                            if (localInstallWindow.showConfirmation) {
                                localInstallWindow.showConfirmation = false
                                localInstallWindow._doInstall()
                            } else if (localInstallWindow.installDone) {
                                localInstallWindow.hide()
                            } else {
                                localInstallWindow.showConfirmation = true
                            }
                        }
                    }
                }

                // Back button (shown during confirmation)
                Rectangle {
                    width:  84; height: 34
                    radius: 8
                    visible: localInstallWindow.showConfirmation
                    color:  backBtnArea.containsMouse
                        ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.60)
                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    StyledText {
                        anchors.centerIn: parent
                        text:           "Back"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    MouseArea {
                        id: backBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    localInstallWindow.showConfirmation = false
                    }
                }
            }
        }
    }

    // ── Path confirmed helper ─────────────────────────────────────────────────
    function _onPathConfirmed() {
        if (filePath.trim() === "") return
        _reset()
        detectedFormat = _ext(filePath)
        if (detectedFormat === "") {
            errorMessage = "Unsupported format. Please choose a .deb, .rpm, or .zst file."
            return
        }
        _loadMeta()
    }
}
