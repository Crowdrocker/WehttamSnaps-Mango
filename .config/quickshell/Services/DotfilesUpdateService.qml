pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    // ─── Version ────────────────────────────────────────────────────────────
    property string currentVersion: "5.0.0"
    property string latestVersion: ""
    property string releaseNotes: ""
    property string downloadUrl: ""
    property string releaseName: "The End"
    property string publishedAt: ""

    // ─── State ──────────────────────────────────────────────────────────────
    property bool updateAvailable: false
    property bool isChecking: false
    property bool isDownloading: false
    property bool isInstalling: false
    property bool isBackingUp: false
    property bool isRestoring: false
    property real downloadProgress: 0

    // ─── Status / Error ─────────────────────────────────────────────────────
    property string statusMessage: "Ready"
    property bool hasError: false
    property string errorMessage: ""

    // ─── Backup tracking ────────────────────────────────────────────────────
    property string lastBackupPath: ""
    property var backupList: []

    // ─── Install options ───────────────────────────────────────────────────────
    property bool installBoth: true  // true = hypr + quickshell, false = quickshell only

    // ─── Paths ──────────────────────────────────────────────────────────────
    // NOTE: upstream repo renamed/migrated; old Event-Horizon-Dotfiles now 404.
    readonly property string githubApiUrl: "https://api.github.com/repos/ryzendew/Event-Horizon-Dotfiles-Issue/releases/latest"
    readonly property string homeDir: Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    readonly property string configHome: homeDir + "/.config"
    readonly property string cacheDir: homeDir + "/.cache/EventHorizon/Updates"
    readonly property string hyprDir: configHome + "/hypr"
    readonly property string hyprBakDir: configHome + "/hypr.bak"
    readonly property string quickshellDir: configHome + "/quickshell"
    readonly property string quickshellBakDir: configHome + "/quickshell.bak"
    readonly property string niriDir: configHome + "/niri"
    readonly property string mangoDir: configHome + "/mango"

    // ─── Busy guard ─────────────────────────────────────────────────────────
    readonly property bool isBusy: isChecking || isDownloading || isInstalling || isBackingUp || isRestoring

    // ────────────────────────────────────────────────────────────────────────
    //  Centralised logger — prepends a timestamp to every line
    // ────────────────────────────────────────────────────────────────────────
    function log(msg) {
        var ts = new Date().toISOString()
        console.log("[DotfilesUpdateService " + ts + "] " + msg)
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Processes
    // ════════════════════════════════════════════════════════════════════════

    Process {
        id: checkUpdatesProcess
        running: false

        onExited: exitCode => {
            root.log("checkUpdatesProcess exited with code " + exitCode)
            root.log("checkUpdatesProcess stdout length: " + stdout.text.length + " chars")
            if (stdout.text.length > 0)
                root.log("checkUpdatesProcess stdout (first 500 chars): " + stdout.text.substring(0, 500))
            if (stderr && stderr.text && stderr.text.length > 0)
                root.log("checkUpdatesProcess stderr (first 500 chars): " + stderr.text.substring(0, 500))

            isChecking = false
            if (exitCode === 0) {
                root.log("GitHub API fetch succeeded — attempting JSON parse")
                try {
                    root.parseGitHubResponse(stdout.text)
                    hasError = false
                    errorMessage = ""
                    root.log("GitHub JSON parsed successfully")
                } catch (e) {
                    hasError = true
                    errorMessage = "Failed to parse GitHub response: " + e.message
                    statusMessage = "Check failed"
                    root.log("ERROR parsing GitHub JSON: " + e.message)
                }
            } else {
                hasError = true
                // curl 22 usually means HTTP error (403/404/rate-limited), not "no internet".
                // If GitHub returns JSON body, surface its `message` for actionable debugging.
                var detail = ""
                var raw = (stdout.text || "").trim()
                if (raw.length > 0) {
                    try {
                        var j = JSON.parse(raw)
                        if (j && j.message)
                            detail = String(j.message)
                    } catch (e) { /* ignore */ }
                }
                var err = (stderr && stderr.text) ? stderr.text.trim() : ""
                if (!detail && err.length > 0)
                    detail = err.split("\n")[0]

                errorMessage = "curl exited with code " + exitCode + (detail ? (" — " + detail) : "")
                statusMessage = "Check failed"
                root.log("ERROR: curl failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: backupProcess
        running: false

        onExited: exitCode => {
            root.log("backupProcess exited with code " + exitCode)
            root.log("backupProcess stdout: " + stdout.text.trim())
            isBackingUp = false
            if (exitCode === 0) {
                statusMessage = "Backup saved to hypr.bak and quickshell.bak"
                root.log("Backup completed successfully")
                root.refreshBackupList()
            } else {
                hasError = true
                errorMessage = "Backup failed (exit " + exitCode + ")"
                statusMessage = "Backup failed!"
                root.log("ERROR: backup failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: restoreProcess
        running: false

        onExited: exitCode => {
            root.log("restoreProcess exited with code " + exitCode)
            root.log("restoreProcess stdout: " + stdout.text.trim())
            isRestoring = false
            if (exitCode === 0) {
                statusMessage = "Restore complete — please restart Quickshell"
                root.log("Restore completed successfully")
            } else {
                hasError = true
                errorMessage = "Restore failed (exit " + exitCode + ")"
                statusMessage = "Restore failed!"
                root.log("ERROR: restore failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: downloadProcess
        running: false

        onExited: exitCode => {
            root.log("downloadProcess exited with code " + exitCode)
            root.log("downloadProcess stdout: " + stdout.text.trim())
            isDownloading = false
            if (exitCode === 0) {
                statusMessage = "Download complete. Installing…"
                downloadProgress = 100
                root.log("Download completed — handing off to installUpdate()")
                root.installUpdate()
            } else {
                hasError = true
                errorMessage = "Download failed (exit " + exitCode + ")"
                statusMessage = "Download failed!"
                root.log("ERROR: download failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: installProcess
        running: false

        onExited: exitCode => {
            root.log("installProcess exited with code " + exitCode)
            // Always dump the full install log so every step is visible
            var installLog = stdout.text.trim()
            if (installLog.length > 0) {
                root.log("=== installProcess stdout BEGIN ===")
                var lines = installLog.split("\n")
                for (var i = 0; i < lines.length; i++)
                    root.log("  install| " + lines[i])
                root.log("=== installProcess stdout END ===")
            } else {
                root.log("installProcess stdout was EMPTY (no output captured)")
            }

            isInstalling = false
            if (exitCode === 0) {
                root.log("Install succeeded — reading installed version and reloading")
                root.readInstalledVersion()
                updateAvailable = false
                root.refreshBackupList()
                statusMessage = "Update installed! Reloading…"
                Qt.callLater(function() { Quickshell.reload(true) })
            } else {
                hasError = true
                errorMessage = "Install failed (exit " + exitCode + ")"
                statusMessage = "Install failed!"
                root.log("ERROR: install script failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: listBackupsProcess
        running: false

        onExited: exitCode => {
            root.log("listBackupsProcess exited with code " + exitCode)
            root.log("listBackupsProcess stdout: '" + stdout.text.trim() + "'")
            if (exitCode === 0) {
                var lines = stdout.text.trim().split("\n").filter(l => l.length > 0)
                var hyprFound = lines.indexOf("hypr.bak") !== -1
                var qsFound   = lines.indexOf("quickshell.bak") !== -1
                root.log("Backup scan — hypr.bak found: " + hyprFound + "  quickshell.bak found: " + qsFound)
                backupList = (hyprFound || qsFound)
                    ? [{ label: "hypr.bak + quickshell.bak", hypr: hyprFound, quickshell: qsFound }]
                    : []
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: deleteBackupProcess
        running: false

        onExited: exitCode => {
            root.log("deleteBackupProcess exited with code " + exitCode)
            if (exitCode === 0) {
                root.refreshBackupList()
                statusMessage = "Backup deleted"
                root.log("Backup deleted successfully")
            } else {
                hasError = true
                errorMessage = "Failed to delete backup"
                root.log("ERROR: deleteBackupProcess failed — exit code " + exitCode)
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: readVersionProcess
        running: false

        onExited: exitCode => {
            root.log("readVersionProcess exited with code " + exitCode)
            var raw = stdout.text.trim()
            root.log("readVersionProcess raw output: '" + raw + "'")
            if (exitCode === 0 && raw.length > 0) {
                currentVersion = raw.replace(/^v/i, "").trim()
                root.log("Installed version resolved to: " + currentVersion)
            } else {
                root.log("WARNING: could not read installed version — keeping fallback: " + currentVersion)
            }
        }

        stdout: StdioCollector {}
    }

    function readInstalledVersion() {
        var selfPath = quickshellDir + "/Services/DotfilesUpdateService.qml"
        root.log("readInstalledVersion() — reading from: " + selfPath)
        readVersionProcess.command = [
            "sh", "-c",
            "grep -m1 \"property string currentVersion\" \"$0\" | awk -F'\"' '{print $2}'",
            selfPath
        ]
        readVersionProcess.running = true
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Public API
    // ════════════════════════════════════════════════════════════════════════

    function checkForUpdates() {
        root.log("checkForUpdates() called — isBusy=" + isBusy)
        if (isBusy) { root.log("checkForUpdates() aborted — service is busy"); return }
        isChecking = true
        hasError = false
        errorMessage = ""
        statusMessage = "Checking for updates…"
        root.log("Fetching GitHub API: " + githubApiUrl)
        // GitHub API increasingly expects a User-Agent; without it, some setups get 403 and curl exit 22.
        // Keep output quiet but show real error via stderr collector above.
        checkUpdatesProcess.command = ["curl",
            "-sS", "-f", "-L",
            "--connect-timeout", "10",
            "--max-time", "20",
            "--retry", "2",
            "--retry-delay", "1",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: 2022-11-28",
            "-H", "User-Agent: quickshell-dotfiles-updater",
            githubApiUrl]
        checkUpdatesProcess.running = true
    }

    function createBackup() {
        root.log("createBackup() called — isBusy=" + isBusy)
        if (isBusy) { root.log("createBackup() aborted — service is busy"); return }
        isBackingUp = true
        hasError = false
        errorMessage = ""
        statusMessage = "Creating backup…"
        root.log("Backing up: " + hyprDir + " → " + hyprBakDir)
        root.log("Backing up: " + quickshellDir + " → " + quickshellBakDir)

        backupProcess.command = [
            "sh", "-c",
            "{ [ -d \"" + hyprDir + "\" ] && rm -rf \"" + hyprBakDir + "\" && cp -a \"" + hyprDir + "\" \"" + hyprBakDir + "\" || true; } && " +
            "{ [ -d \"" + quickshellDir + "\" ] && rm -rf \"" + quickshellBakDir + "\" && cp -a \"" + quickshellDir + "\" \"" + quickshellBakDir + "\" || true; } && " +
            "echo done"
        ]
        backupProcess.running = true
    }

    function restoreBackup() {
        root.log("restoreBackup() called — isBusy=" + isBusy)
        if (isBusy) { root.log("restoreBackup() aborted — service is busy"); return }
        isRestoring = true
        hasError = false
        errorMessage = ""
        statusMessage = "Restoring from backup…"
        root.log("Restoring: " + hyprBakDir + " → " + hyprDir)
        root.log("Restoring: " + quickshellBakDir + " → " + quickshellDir)

        restoreProcess.command = [
            "sh", "-c",
            "{ [ -d \"" + hyprBakDir + "\" ] && rm -rf \"" + hyprDir + "\" && cp -a \"" + hyprBakDir + "\" \"" + hyprDir + "\" || true; } && " +
            "{ [ -d \"" + quickshellBakDir + "\" ] && rm -rf \"" + quickshellDir + "\" && cp -a \"" + quickshellBakDir + "\" \"" + quickshellDir + "\" || true; } && " +
            "echo done"
        ]
        restoreProcess.running = true
    }

    function deleteBackup() {
        root.log("deleteBackup() called")
        root.log("Deleting: " + hyprBakDir + " and " + quickshellBakDir)
        deleteBackupProcess.command = [
            "sh", "-c",
            "rm -rf \"" + hyprBakDir + "\" \"" + quickshellBakDir + "\""
        ]
        deleteBackupProcess.running = true
    }

    function refreshBackupList() {
        root.log("refreshBackupList() — checking for .bak dirs in " + configHome)
        listBackupsProcess.command = [
            "sh", "-c",
            "{ [ -d \"" + hyprBakDir + "\" ] && echo hypr.bak || true; } && " +
            "{ [ -d \"" + quickshellBakDir + "\" ] && echo quickshell.bak || true; }"
        ]
        listBackupsProcess.running = true
    }

    function downloadAndInstall() {
        root.log("downloadAndInstall() called — isBusy=" + isBusy + "  updateAvailable=" + updateAvailable)
        if (isBusy || !updateAvailable) {
            root.log("downloadAndInstall() aborted — isBusy=" + isBusy + " updateAvailable=" + updateAvailable)
            return
        }

        // Don’t block on a confirmation dialog (UI may not implement it).
        // Default: install compositor config + quickshell.
        installBoth = true
        root.startDownload()
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Download (separated so it can be called after confirmation)
    // ════════════════════════════════════════════════════════════════════════

    property bool showInstallConfirmDialog: false
    property var installConfirmCallback: null

    function startDownload() {
        root.log("startDownload() called — installBoth=" + installBoth)
        isDownloading = true
        downloadProgress = 0
        hasError = false
        errorMessage = ""
        statusMessage = "Downloading v" + latestVersion + "…"

        var zipName = downloadUrl.substring(downloadUrl.lastIndexOf("/") + 1)
        var zipPath = cacheDir + "/" + zipName
        root.log("downloadAndInstall() — latestVersion: " + latestVersion)
        root.log("downloadAndInstall() — downloadUrl:   " + downloadUrl)
        root.log("downloadAndInstall() — zipName:       " + zipName)
        root.log("downloadAndInstall() — zipPath:       " + zipPath)
        root.log("downloadAndInstall() — cacheDir:      " + cacheDir)

        downloadProcess.command = [
            "sh", "-c",
            "mkdir -p \"" + cacheDir + "\" && curl -L --progress-bar -o \"" + zipPath + "\" \"" + downloadUrl + "\""
        ]
        root.log("downloadAndInstall() — spawning download process")
        downloadProcess.running = true
    }

    function reloadQuickshell() {
        root.log("reloadQuickshell() called")
        Quickshell.reload(true)
    }

    function cancelOperation() {
        root.log("cancelOperation() called")
        if (checkUpdatesProcess.running) { checkUpdatesProcess.running = false; isChecking = false;  root.log("  cancelled: checkUpdatesProcess") }
        if (backupProcess.running)       { backupProcess.running = false;        isBackingUp = false; root.log("  cancelled: backupProcess") }
        if (restoreProcess.running)      { restoreProcess.running = false;       isRestoring = false; root.log("  cancelled: restoreProcess") }
        if (downloadProcess.running)     { downloadProcess.running = false;      isDownloading = false; root.log("  cancelled: downloadProcess") }
        if (installProcess.running)      { installProcess.running = false;       isInstalling = false;  root.log("  cancelled: installProcess") }
        statusMessage = "Operation cancelled"
    }

    // ════════════════════════════════════════════════════════════════════════
    //  Internal helpers
    // ════════════════════════════════════════════════════════════════════════

    function parseGitHubResponse(raw) {
        root.log("parseGitHubResponse() — raw length: " + raw.length)
        var json = JSON.parse(raw)

        latestVersion = json.tag_name ? json.tag_name.replace(/^v/, "") : "0.0.0"
        releaseName   = json.name  || ("v" + latestVersion)
        releaseNotes  = json.body  || "No release notes available."
        publishedAt   = json.published_at || ""

        root.log("parseGitHubResponse() — tag_name raw:  " + json.tag_name)
        root.log("parseGitHubResponse() — latestVersion: " + latestVersion)
        root.log("parseGitHubResponse() — releaseName:   " + releaseName)
        root.log("parseGitHubResponse() — publishedAt:   " + publishedAt)
        root.log("parseGitHubResponse() — assets count:  " + (json.assets ? json.assets.length : 0))

        downloadUrl = ""
        if (json.assets && json.assets.length > 0) {
            for (var i = 0; i < json.assets.length; i++) {
                var a = json.assets[i]
                root.log("parseGitHubResponse() — asset[" + i + "]: name=" + a.name + "  url=" + a.browser_download_url)
                if (a.browser_download_url &&
                    (a.name.endsWith(".zip") || a.name.endsWith(".tar.gz"))) {
                    downloadUrl = a.browser_download_url
                    root.log("parseGitHubResponse() — selected asset: " + a.name + "  url=" + downloadUrl)
                    break
                }
            }
            if (!downloadUrl)
                root.log("parseGitHubResponse() — WARNING: no .zip/.tar.gz asset found in release assets")
        } else {
            root.log("parseGitHubResponse() — no assets array; will try zipball_url fallback")
        }

        if (!downloadUrl && json.zipball_url) {
            downloadUrl = json.zipball_url
            root.log("parseGitHubResponse() — using zipball_url fallback: " + downloadUrl)
        }

        if (!downloadUrl)
            root.log("parseGitHubResponse() — ERROR: downloadUrl is empty — no asset or zipball_url available")

        root.log("parseGitHubResponse() — final downloadUrl: " + downloadUrl)

        updateAvailable = compareVersions(latestVersion, currentVersion) > 0
        root.log("parseGitHubResponse() — currentVersion=" + currentVersion + "  latestVersion=" + latestVersion + "  updateAvailable=" + updateAvailable)

        if (updateAvailable) {
            statusMessage = "Update available — v" + latestVersion
        } else {
            statusMessage = "You're up to date  ✓"
        }
    }

    function installUpdate() {
        root.log("installUpdate() called")
        root.log("installUpdate() — downloadUrl:   " + downloadUrl)
        root.log("installUpdate() — latestVersion: " + latestVersion)
        root.log("installUpdate() — cacheDir:      " + cacheDir)
        root.log("installUpdate() — hyprDir:       " + hyprDir)
        root.log("installUpdate() — niriDir:       " + niriDir)
        root.log("installUpdate() — mangoDir:      " + mangoDir)
        root.log("installUpdate() — quickshellDir: " + quickshellDir)

        isInstalling = true
        statusMessage = "Installing v" + latestVersion + "…"

        var zipName    = downloadUrl.substring(downloadUrl.lastIndexOf("/") + 1)
        var zipPath    = cacheDir + "/" + zipName
        var extractDir = cacheDir + "/extract"

        root.log("installUpdate() — zipName:    " + zipName)
        root.log("installUpdate() — zipPath:    " + zipPath)
        root.log("installUpdate() — extractDir: " + extractDir)

        // Decide which compositor config folder to update (if any).
        // Hyprland: ~/.config/hypr
        // Niri:     ~/.config/niri
        // MangoWM:  ~/.config/mango
        var compositor = "hypr"
        if (typeof CompositorService !== "undefined") {
            if (CompositorService.isNiri) compositor = "niri"
            else if (CompositorService.isMango) compositor = "mango"
            else if (CompositorService.isHyprland) compositor = "hypr"
        }
        root.log("installUpdate() — detected compositor: " + compositor + " (installBoth=" + installBoth + ")")

        // ── Verbose install script ───────────────────────────────────────────
        // Every step echoes its own status so the installProcess stdout log
        // shows exactly where success/failure occurred.
        var script =
            // ── Step 1: clean up any previous extract dir
            "echo '[INSTALL] Step 1: removing old extractDir' && " +
            "rm -rf \"" + extractDir + "\" && " +
            "echo '[INSTALL] Step 1: done' && " +

            // ── Step 2: create fresh extract dir
            "echo '[INSTALL] Step 2: creating extractDir: " + extractDir + "' && " +
            "mkdir -p \"" + extractDir + "\" && " +
            "echo '[INSTALL] Step 2: done' && " +

            // ── Step 3: verify zip exists and print its size
            "echo '[INSTALL] Step 3: verifying zip exists' && " +
            "ls -lh \"" + zipPath + "\" && " +
            "echo '[INSTALL] Step 3: zip found' && " +

            // ── Step 4: list zip contents (no extraction yet)
            "echo '[INSTALL] Step 4: listing zip contents (first 40 lines)' && " +
            "unzip -l \"" + zipPath + "\" | head -40 && " +
            "echo '[INSTALL] Step 4: done' && " +

            // ── Step 5: actually extract
            "echo '[INSTALL] Step 5: extracting zip to extractDir' && " +
            "unzip -o \"" + zipPath + "\" -d \"" + extractDir + "\" && " +
            "echo '[INSTALL] Step 5: extraction complete' && " +

            // ── Step 6: show the top-level extracted structure
            "echo '[INSTALL] Step 6: top-level contents of extractDir' && " +
            "ls -la \"" + extractDir + "\" && " +
            "echo '[INSTALL] Step 6: done' && " +

            // ── Step 7: find the single top-level wrapper folder the zip creates
            //    e.g. extract/Event-Horizon-Dotfiles-main/ → that IS the INNER dir
            "echo '[INSTALL] Step 7: finding wrapper folder inside extractDir' && " +
            "INNER=$(find \"" + extractDir + "\" -maxdepth 1 -mindepth 1 -type d | head -1) && " +
            "if [ -z \"$INNER\" ]; then " +
            "  echo '[INSTALL] Step 7: WARNING — no subdirectory found, falling back to extractDir root' && " +
            "  INNER=\"" + extractDir + "\"; " +
            "fi && " +
            "echo '[INSTALL] Step 7: INNER resolved to: '\"$INNER\" && " +

            // ── Step 8: show what's inside INNER
            "echo '[INSTALL] Step 8: contents of INNER dir' && " +
            "ls -la \"$INNER\" && " +
            "echo '[INSTALL] Step 8: done' && " +

            // ── Step 9: install compositor config (hypr/niri/mango) when enabled
            "COMPOSITOR=\"" + compositor + "\" && " +
            "echo '[INSTALL] Step 9: compositor detected: '\"$COMPOSITOR\" && " +
            "if [ \"" + (installBoth ? "1" : "0") + "\" != \"1\" ]; then " +
            "  echo '[INSTALL] Step 9: skipping compositor config (quickshell-only install)'; " +
            "else " +
            "  if [ \"$COMPOSITOR\" = \"hypr\" ]; then " +
            "    echo '[INSTALL] Step 9(hypr): installing ~/.config/hypr (preserve monitors.lua)' && " +
            "    KEEP_MON=\"" + hyprDir + "/monitors.lua\" && " +
            "    TMP_MON=\"" + cacheDir + "/keep-monitors.lua\" && " +
            "    if [ -f \"$KEEP_MON\" ]; then cp -a \"$KEEP_MON\" \"$TMP_MON\" && echo '[INSTALL] Step 9(hypr): saved monitors.lua'; else rm -f \"$TMP_MON\" 2>/dev/null || true; fi && " +
            "    rm -rf \"" + hyprBakDir + "\" && " +
            "    if [ -d \"" + hyprDir + "\" ]; then cp -a \"" + hyprDir + "\" \"" + hyprBakDir + "\" && echo '[INSTALL] Step 9(hypr): backup done'; else echo '[INSTALL] Step 9(hypr): no existing hyprDir to back up'; fi && " +
            "    rm -rf \"" + hyprDir + "\" && " +
            "    if [ -d \"$INNER/hypr\" ]; then cp -a \"$INNER/hypr\" \"" + hyprDir + "\" && echo '[INSTALL] Step 9(hypr): hypr installed'; else echo '[INSTALL] Step 9(hypr): WARNING — no hypr dir in release — skipping'; fi && " +
            "    if [ -f \"$TMP_MON\" ]; then cp -a \"$TMP_MON\" \"$KEEP_MON\" && echo '[INSTALL] Step 9(hypr): restored monitors.lua'; fi; " +
            "  elif [ \"$COMPOSITOR\" = \"niri\" ]; then " +
            "    echo '[INSTALL] Step 9(niri): installing ~/.config/niri (preserve eh/outputs.kdl)' && " +
            "    KEEP_OUT=\"" + niriDir + "/eh/outputs.kdl\" && " +
            "    TMP_OUT=\"" + cacheDir + "/keep-niri-outputs.kdl\" && " +
            "    if [ -f \"$KEEP_OUT\" ]; then mkdir -p \"" + cacheDir + "\" && cp -a \"$KEEP_OUT\" \"$TMP_OUT\" && echo '[INSTALL] Step 9(niri): saved outputs.kdl'; else rm -f \"$TMP_OUT\" 2>/dev/null || true; fi && " +
            "    if [ -d \"$INNER/niri\" ]; then rm -rf \"" + niriDir + "\" && cp -a \"$INNER/niri\" \"" + niriDir + "\" && echo '[INSTALL] Step 9(niri): niri installed'; else echo '[INSTALL] Step 9(niri): WARNING — no niri dir in release — skipping'; fi && " +
            "    if [ -f \"$TMP_OUT\" ]; then mkdir -p \"" + niriDir + "/eh\" && cp -a \"$TMP_OUT\" \"$KEEP_OUT\" && echo '[INSTALL] Step 9(niri): restored outputs.kdl'; fi; " +
            "  elif [ \"$COMPOSITOR\" = \"mango\" ]; then " +
            "    echo '[INSTALL] Step 9(mango): installing ~/.config/mango (preserve monitors.conf)' && " +
            "    KEEP_MON=\"" + mangoDir + "/monitors.conf\" && " +
            "    TMP_MON=\"" + cacheDir + "/keep-mango-monitors.conf\" && " +
            "    if [ -f \"$KEEP_MON\" ]; then cp -a \"$KEEP_MON\" \"$TMP_MON\" && echo '[INSTALL] Step 9(mango): saved monitors.conf'; else rm -f \"$TMP_MON\" 2>/dev/null || true; fi && " +
            "    if [ -d \"$INNER/mango\" ]; then rm -rf \"" + mangoDir + "\" && cp -a \"$INNER/mango\" \"" + mangoDir + "\" && echo '[INSTALL] Step 9(mango): mango installed'; else echo '[INSTALL] Step 9(mango): WARNING — no mango dir in release — skipping'; fi && " +
            "    if [ -f \"$TMP_MON\" ]; then cp -a \"$TMP_MON\" \"$KEEP_MON\" && echo '[INSTALL] Step 9(mango): restored monitors.conf'; fi; " +
            "  else " +
            "    echo '[INSTALL] Step 9: WARNING — unknown compositor; not updating hypr/niri/mango'; " +
            "  fi; " +
            "fi && " +

            // ── Step 10: install quickshell
            "echo '[INSTALL] Step 10: checking for quickshell in INNER' && " +
            "if [ -d \"$INNER/quickshell\" ]; then " +
            "  echo '[INSTALL] Step 10a: quickshell found — removing old backup' && " +
            "  rm -rf \"" + quickshellBakDir + "\" && " +
            "  if [ -d \"" + quickshellDir + "\" ]; then " +
            "    echo '[INSTALL] Step 10b: backing up existing quickshellDir' && " +
            "    cp -a \"" + quickshellDir + "\" \"" + quickshellBakDir + "\" && " +
            "    echo '[INSTALL] Step 10b: backup done'; " +
            "  else " +
            "    echo '[INSTALL] Step 10b: no existing quickshellDir to back up'; " +
            "  fi && " +
            "  echo '[INSTALL] Step 10c: removing old quickshellDir' && " +
            "  rm -rf \"" + quickshellDir + "\" && " +
            "  echo '[INSTALL] Step 10d: copying new quickshell from INNER' && " +
            "  cp -a \"$INNER/quickshell\" \"" + quickshellDir + "\" && " +
            "  echo '[INSTALL] Step 10d: quickshell installed'; " +
            "else " +
            "  echo '[INSTALL] Step 10: WARNING — no quickshell dir found in INNER — skipping'; " +
            "fi && " +

            "echo '[INSTALL] ALL STEPS COMPLETE — extracted folder kept at: " + cacheDir + "/extract'"

        root.log("installUpdate() — spawning installProcess")
        installProcess.command = ["sh", "-c", script]
        installProcess.running = true
    }

    function compareVersions(v1, v2) {
        root.log("compareVersions() — v1=" + v1 + "  v2=" + v2)
        var a = v1.split(".").map(Number)
        var b = v2.split(".").map(Number)
        for (var i = 0; i < Math.max(a.length, b.length); i++) {
            var x = a[i] || 0, y = b[i] || 0
            if (x > y) { root.log("compareVersions() → v1 > v2 (1)"); return 1 }
            if (x < y) { root.log("compareVersions() → v1 < v2 (-1)"); return -1 }
        }
        root.log("compareVersions() → equal (0)")
        return 0
    }

    Component.onCompleted: {
        root.log("Component.onCompleted — initialising DotfilesUpdateService")
        root.log("  homeDir:        " + homeDir)
        root.log("  configHome:     " + configHome)
        root.log("  cacheDir:       " + cacheDir)
        root.log("  hyprDir:        " + hyprDir)
        root.log("  quickshellDir:  " + quickshellDir)
        root.log("  currentVersion: " + currentVersion + " (fallback — will be overwritten by readInstalledVersion)")
        readInstalledVersion()
        refreshBackupList()
    }
}
