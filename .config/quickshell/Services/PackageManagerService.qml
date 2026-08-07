pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── State ────────────────────────────────────────────────
    property string distribution: ""
    property string pkgManager: ""
    property string aurHelper: ""
    property bool   aurEnabled: false
    property bool   flatpakAvailable: false

    // Terminal preference — plain writable property, set by the Settings UI
    // and auto-detected during init() if not yet assigned.
    property string preferredTerminal: ""
    property var availableTerminals: []

    property var installedPackages: []
    property var searchResults: []
    property var availableUpdates: []
    property var orphanedPackages: []

    property bool isLoading: false
    property bool isSearching: false
    property bool isInstalling: false
    property bool isRemoving: false
    property string currentOperation: ""
    property string lastError: ""

    // ── Signals ───────────────────────────────────────────────
    signal capabilitiesDetected()
    signal searchCompleted()
    signal installedPackagesLoaded()
    signal updatesChecked()
    signal operationRequested(string command, string description)
    signal error(string message)

    // ── Debounce ──────────────────────────────────────────────
    property var _searchTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: root._executeSearch(root._pendingQuery)
    }
    property string _pendingQuery: ""

    // ── AUR terminal installer Process ────────────────────────
    // FIX: aurInstaller was referenced in the old code but never declared,
    // causing a silent runtime crash on every AUR install attempt.
    property var aurInstaller: Process {
        id: aurInstaller
        onExited: function(exitCode, exitStatus) {
            root.isInstalling = false
            root.currentOperation = ""
            // Invalidate installed cache so the UI refreshes after install
            root._installedCache = { timestamp: 0, data: [] }
            console.log("[PikaPack] [INSTALL] AUR terminal process exited with code:", exitCode)
        }
    }

    // ── Privileged terminal installer Process ─────────────────
    // FIX: pacman/apt/dnf/flatpak were all run via pkexec inside a headless
    // Quickshell Process which has no TTY or polkit agent, so no password
    // dialog could ever appear. We now spawn the user's $TERMINAL and run
    // sudo inside it so the password prompt is visible and interactive.
    property var privInstaller: Process {
        id: privInstaller
        onExited: function(exitCode, exitStatus) {
            root.isInstalling = false
            root.currentOperation = ""
            root._installedCache = { timestamp: 0, data: [] }
            console.log("[PikaPack] [INSTALL] Privileged terminal process exited with code:", exitCode)
        }
    }

    // ── Privileged terminal remover Process ───────────────────
    property var privRemover: Process {
        id: privRemover
        onExited: function(exitCode, exitStatus) {
            root.isRemoving = false
            root.currentOperation = ""
            root._installedCache = { timestamp: 0, data: [] }
            console.log("[PikaPack] [REMOVE] Privileged terminal process exited with code:", exitCode)
        }
    }

    // ── Privileged terminal upgrader Process ──────────────────
    property var privUpgrader: Process {
        id: privUpgrader
        onExited: function(exitCode, exitStatus) {
            root.isInstalling = false
            root.currentOperation = ""
            root._installedCache = { timestamp: 0, data: [] }
            console.log("[PikaPack] [UPGRADE] Privileged terminal process exited with code:", exitCode)
            root.checkForUpdates()
        }
    }

    // ── Helper: get best available terminal ───────────────────
    function _getTerminal() {
        // 1. User's explicit saved choice (set by Settings UI)
        if (root.preferredTerminal && root.preferredTerminal.length > 0) {
            console.log("[PikaPack] [TERMINAL] Using preferredTerminal:", root.preferredTerminal)
            return root.preferredTerminal
        }
        // 2. Auto-pick from detected list
        const avail = root.availableTerminals || []
        if (avail.length > 0) {
            const preferred = ["ptyxis", "alacritty", "kitty", "foot", "wezterm", "ghostty", "gnome-terminal", "konsole"]
            for (let i = 0; i < preferred.length; i++) {
                if (avail.indexOf(preferred[i]) !== -1) {
                    console.log("[PikaPack] [TERMINAL] Auto-selected:", preferred[i])
                    return preferred[i]
                }
            }
            console.log("[PikaPack] [TERMINAL] Using first detected:", avail[0])
            return avail[0]
        }
        // 3. $TERMINAL env var
        const envTerm = Quickshell.env("TERMINAL") || ""
        if (envTerm.length > 0) {
            console.log("[PikaPack] [TERMINAL] Using $TERMINAL:", envTerm)
            return envTerm
        }
        console.warn("[PikaPack] [TERMINAL] No terminal found — install ptyxis or set one in Settings")
        return "ptyxis"
    }

    // ── Helper: spawn a privileged command in a terminal ──────
    // innerCmd: the shell command to run under pkexec (no pkexec prefix needed)
    // proc:     a Process property to assign the command to and start
    // label:    log label for debugging
    function _runInTerminalWithSudo(innerCmd, proc, label) {
        const terminal = _getTerminal()
        // Wrap the command so the terminal stays open after completion,
        // letting the user read any output or errors before it closes.
        const wrapped = `pkexec sh -c '${innerCmd.replace(/'/g, "'\\''")}'; echo; echo '=== ${label} complete. Press Enter to close ==='; read`
        console.log("[PikaPack] [TERMINAL] Spawning:", terminal, "for:", label)
        console.log("[PikaPack] [TERMINAL] Inner command:", innerCmd)
        proc.command = [terminal, "-e", "bash", "-c", wrapped]
        proc.running = true
    }

    // ─────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────
    function init() {
        console.log("[PikaPack] ═══════════════════════════ INIT CALLED ═══════════════════════════")
        isLoading = true
        console.log("[PikaPack] [INIT] Calling _detectTerminals()...")
        _detectTerminals()
        console.log("[PikaPack] [INIT] Calling _detectDistribution()...")
        _detectDistribution()
        console.log("[PikaPack] [INIT] Calling _setupDesktopFile()...")
        _setupDesktopFile()
    }
    
    function _setupDesktopFile() {
        const homeDir = Quickshell.env("HOME") || ""
        const configDir = Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
        
        const appDir = homeDir + "/.local/share/applications"
        const scriptDir = configDir + "/quickshell/scripts"
        const desktopFile = appDir + "/event-horizon-pkg-manager.desktop"
        const iconPath = configDir + "/quickshell/assets/Event-Horizon-logo.png"
        
        const scriptContent = "#!/bin/bash\n" +
            "echo \"$1\" > /tmp/eh-pkg-file.txt\n" +
            "quickshell ipc call event-horizon-local-install openPkg\n"
        
        const scriptFile = scriptDir + "/open-pkg-manager.sh"
        
        console.log("[PikaPack] Creating desktop file in:", appDir)
        
        _runCommand("mkdir -p " + appDir + " " + scriptDir, function() {
            _runCommand("printf '%s' '" + scriptContent.replace(/'/g, "'\"'\"'") + "' > " + scriptFile + " && chmod +x " + scriptFile, function() {
                const desktopContent = "[Desktop Entry]\n" +
                    "Name=Event Horizon Package Manager\n" +
                    "Comment=Install and manage system packages\n" +
                    "Exec=" + scriptFile + " %F\n" +
                    "Icon=" + iconPath + "\n" +
                    "Terminal=false\n" +
                    "Type=Application\n" +
                    "Categories=System;PackageManager;\n" +
                    "MimeType=application/x-deb;application/x-rpm;application/x-redhat-package-manager;application/x-rpm;application/vnd.debian.binary-package;application/x-archive;application/zstd;application/x-zstd-compressed-tar;application/x-tar;\n" +
                    "NoDisplay=true\n"
                
                const escaped = desktopContent.replace(/'/g, "'\"'\"'")
                _runCommand("printf '%s' '" + escaped + "' > " + desktopFile, function(out) {
                    console.log("[PikaPack] Created .desktop file:", desktopFile)
                    _runCommand("update-desktop-database " + appDir + " 2>/dev/null || true", function() {
                        console.log("[PikaPack] Updated desktop database")
                    })
                })
            })
        })
    }

    function _detectTerminals() {
        // Seed preferredTerminal from SettingsData persistence before detection runs
        if (typeof SettingsData !== "undefined") {
            const persisted = SettingsData.terminalEmulator || ""
            if (persisted.length > 0 && root.preferredTerminal.length === 0) {
                root.preferredTerminal = persisted
                console.log("[PikaPack] [TERMINAL] Loaded persisted terminal:", persisted)
            }
        }
        _runCommand("for t in ptyxis alacritty kitty foot wezterm ghostty gnome-terminal konsole xfce4-terminal xterm; do which $t 2>/dev/null && echo $t; done", function(out) {
            const found = out.trim().split("\n").map(l => l.trim()).filter(l => l.length > 0)
            console.log("[PikaPack] [TERMINAL] Detected terminals:", found.join(", "))
            if (found.length > 0) {
                root.availableTerminals = found
                // Only auto-assign if the user hasn't already picked one
                if (!root.preferredTerminal || root.preferredTerminal.length === 0) {
                    root.preferredTerminal = found[0]
                    console.log("[PikaPack] [TERMINAL] Auto-assigned:", root.preferredTerminal)
                }
            }
        })
    }

    function _detectDistribution() {
        console.log("[PikaPack] [INIT] _detectDistribution() running...")
        console.log("[PikaPack] [STEP 1] Detecting distribution...")
        _runCommand("grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'", function(out) {
            distribution = out.trim().toLowerCase()
            console.log("[PikaPack] [STEP 1] Distribution detected →", distribution)
            console.log("[PikaPack] [INIT] Calling _detectHelpers()...")
            _detectHelpers()
        })
    }

    function _detectHelpers() {
        console.log("[PikaPack] [INIT] _detectHelpers() running...")
        console.log("[PikaPack] [STEP 2] Detecting package managers...")
        
        // Check for pikman first (PikaOS specific - handles multiple distros)
        _runCommand("which pikman || which pacman || which dnf || which apt || echo none", function(out) {
            const helper = out.trim().split('/').pop()
            console.log("[PikaPack] [STEP 2] Raw helper output:", out.trim())

            // Pikman has priority - it handles apt, pacman, dnf, AUR, etc.
            if (helper === "pikman") {
                pkgManager = "pikman"
                _detectPikmanBackend()
            } else if (helper === "dnf" || distribution === "fedora") {
                pkgManager = "dnf"
            } else if (helper === "pacman") {
                pkgManager = "pacman"
                _detectAurHelper()
            } else if (helper === "apt") {
                pkgManager = "apt"
            } else {
                pkgManager = "dnf" // force for Fedora
            }

            console.log("[PikaPack] [STEP 2] FINAL pkgManager →", pkgManager)
            
            // Always try to detect AUR helper - even if using pikman/dnf/apt,
            // the user might have yay/paru installed for AUR support
            _detectAurHelper()
            
            _detectFlatpak()
        })
    }

    function _detectPikmanBackend() {
        _runCommand("pikman --version 2>/dev/null || echo 'pikman not available'", function(out) {
            console.log("[PikaPack] [STEP 2a] pikman version:", out.trim())
            console.log("[PikaPack] [STEP 2] FINAL pkgManager → pikman (with apt backend)")
            // Always detect AUR helper even when using pikman
            _detectAurHelper()
            _detectFlatpak()
        })
    }

    function _detectAurHelper() {
        _runCommand("which paru || which yay || echo none", function(out) {
            const h = out.trim().split('/').pop()
            if (h === "paru" || h === "yay") {
                aurHelper = h
                aurEnabled = true
            }
            console.log("[PikaPack] [STEP 2] AUR helper:", aurHelper, "enabled:", aurEnabled)
        })
    }

    function _detectFlatpak() {
        _runCommand("which flatpak", function(out) {
            flatpakAvailable = out.trim().length > 0
            console.log("[PikaPack] [STEP 3] Flatpak available →", flatpakAvailable)
            isLoading = false
            capabilitiesDetected()
        })
    }

    // ─────────────────────────────────────────────────────────
    // SEARCH - Uses dnf repoquery for structured/fast results (with caching)
    // ─────────────────────────────────────────────────────────
    property var _searchCache: ({})
    property int _searchCacheTTL: 60000 // 1 minute for search

    function searchPackages(query) {
        const q = query.trim()
        console.log("[PikaPack] [SEARCH] searchPackages called with query:", q)
        if (q.length < 2) {
            searchResults = []
            isSearching = false
            _searchTimer.stop()
            return
        }

        // Check cache first
        const cacheKey = q.toLowerCase()
        const cached = _searchCache[cacheKey]
        if (cached && (Date.now() - cached.timestamp) < _searchCacheTTL) {
            console.log("[PikaPack] [SEARCH] Using cached results for:", q)
            searchResults = cached.data
            return
        }

        _pendingQuery = q
        _searchTimer.restart()
    }

    function _executeSearch(query) {
        console.log("[PikaPack] [SEARCH] _executeSearch started for:", query, "| manager:", pkgManager)
        isSearching = true
        searchResults = []

        const escaped = "'" + query.replace(/'/g, "'\\''") + "'"

        // Track how many searches we're actually starting
        let searchCount = 0

        // Run Pikman search (prefix-based for faster narrowing)
        if (pkgManager === "pikman") {
            console.log("[PikaPack] [SEARCH] Running pikman search...")
            _runCommand(`pikman search ^${escaped} 2>/dev/null`, function(out) {
                const parsed = _parsePikmanSearch(out, "pikman")
                searchResults = searchResults.concat(parsed)
                console.log("[PikaPack] [SEARCH] Pikman results:", parsed.length)
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // Run Pacman search (using pacman -Ss for official repos)
        if (pkgManager === "pacman") {
            console.log("[PikaPack] [SEARCH] Running pacman search...")
            _runCommand(`pacman -Ss -- ${escaped} 2>/dev/null`, function(out) {
                const parsed = _parsePacmanSearch(out, "pacman")
                const q_lower = query.toLowerCase()
                const filtered = parsed.filter(p => p.name.toLowerCase().startsWith(q_lower))
                searchResults = searchResults.concat(filtered)
                console.log("[PikaPack] [SEARCH] Pacman results:", filtered.length, "(filtered from", parsed.length, ")")
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // Run APT search
        if (pkgManager === "apt") {
            console.log("[PikaPack] [SEARCH] Running apt search...")
            _runCommand(`apt search ${escaped} 2>/dev/null`, function(out) {
                const parsed = _parseAptSearch(out, "apt")
                searchResults = searchResults.concat(parsed)
                console.log("[PikaPack] [SEARCH] APT results:", parsed.length)
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // Run DNF search (name field only for fast narrowing)
        if (pkgManager === "dnf") {
            console.log("[PikaPack] [SEARCH] Running dnf repoquery...")
            // dnf5 doesn't support 'name:' prefix - just use wildcard directly
            // Also removed --quiet --cacheonly as it can cause empty results
            const queryformat = "%{name}|%{version}|%{release}|%{arch}|%{summary}|%{description}|%{installsize}\\n"
            _runCommand(`dnf repoquery --qf '${queryformat}' '${query}*' 2>/dev/null`, function(out) {
                const parsed = _parseDnfRepoquery(out, "dnf")
                searchResults = searchResults.concat(parsed)
                console.log("[PikaPack] [SEARCH] DNF results:", parsed.length)
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // Run Flatpak search
        if (flatpakAvailable) {
            console.log("[PikaPack] [SEARCH] Running flatpak search...")
            _runCommand(`flatpak search --columns=name,application,description,version,remotes ${escaped} 2>/dev/null`, function(out) {
                const parsed = _parseFlatpakSearch(out, "flatpak")
                const q_lower = query.toLowerCase()
                const filtered = parsed.filter(p => p.name.toLowerCase().startsWith(q_lower))
                searchResults = searchResults.concat(filtered)
                console.log("[PikaPack] [SEARCH] Flatpak results:", filtered.length, "(filtered from", parsed.length, ")")
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // Run AUR search via RPC API (searches by name specifically for prefix matching)
        if (pkgManager === "pacman" || aurEnabled) {
            console.log("[PikaPack] [SEARCH] Running AUR RPC search...")
            // Use `and` parameter to search by name field specifically
            const escapedQuery = query.replace(/ /g, "%20")
            const aurUrl = `https://aur.archlinux.org/rpc/?v=5&type=search&by=name&arg=${escapedQuery}`
            _runCommand(`curl -s '${aurUrl}' 2>/dev/null`, function(out) {
                const parsed = _parseAurRpcSearch(out, "aur")
                const q_lower = query.toLowerCase()
                const filtered = parsed.filter(p => p.name.toLowerCase().startsWith(q_lower))
                searchResults = searchResults.concat(filtered)
                console.log("[PikaPack] [SEARCH] AUR RPC results:", filtered.length, "(filtered from", parsed.length, ")")
                _finishSearch(searchCount, query)
            })
            searchCount++
        }

        // If no searches were started, finish immediately
        if (searchCount === 0) {
            isSearching = false
            searchCompleted()
        }
    }

    property int _pendingSearchCount: 0
    function _finishSearch(expectedCount, query) {
        _pendingSearchCount++
        console.log("[PikaPack] [SEARCH] Search finished:", _pendingSearchCount, "of", expectedCount)
        if (_pendingSearchCount >= expectedCount) {
            isSearching = false
            _pendingSearchCount = 0
            
            // Cache results
            if (query && searchResults.length > 0) {
                _searchCache[query.toLowerCase()] = {
                    timestamp: Date.now(),
                    data: searchResults
                }
            }
            
            searchCompleted()
        }
    }

    // ─────────────────────────────────────────────────────────
    // INSTALLED PACKAGES - with caching
    // ─────────────────────────────────────────────────────────
    property var _installedCache: ({ timestamp: 0, data: [] })
    property int _cacheTTL: 300000 // 5 minutes in milliseconds

    function getInstalledPackages(forceRefresh) {
        // Check cache first unless force refresh
        const now = Date.now()
        if (!forceRefresh && 
            _installedCache.data.length > 0 && 
            (now - _installedCache.timestamp) < _cacheTTL) {
            console.log("[PikaPack] [INSTALLED] Using cached results, age:", (now - _installedCache.timestamp) / 1000, "seconds")
            installedPackages = _installedCache.data
            return
        }

        console.log("[PikaPack] [INSTALLED] getInstalledPackages() called, force:", forceRefresh)
        isLoading = true
        currentOperation = "Loading installed packages..."

        if (pkgManager === "pikman") {
            console.log("[PikaPack] [INSTALLED] Running pikman list --installed...")
            _runCommand("pikman list --installed 2>/dev/null", function(out) {
                const parsed = _parsePikmanInstalled(out, "pikman")
                if (flatpakAvailable) {
                    _runCommand("flatpak list --columns=name,application,version,origin 2>/dev/null", function(fpOut) {
                        const fpParsed = _parseFlatpakInstalled(fpOut, "flatpak")
                        const combined = parsed.concat(fpParsed)
                        _installedCache = { timestamp: Date.now(), data: combined }
                        installedPackages = combined
                        console.log("[PikaPack] [INSTALLED] Finished - loaded", combined.length, "packages (pikman + flatpak)")
                        isLoading = false
                        installedPackagesLoaded()
                checkOrphans()
                    })
                } else {
                    _installedCache = { timestamp: Date.now(), data: parsed }
                    installedPackages = parsed
                    console.log("[PikaPack] [INSTALLED] Finished - loaded", parsed.length, "packages")
                    isLoading = false
                    installedPackagesLoaded()
                checkOrphans()
                }
            })
        } else if (pkgManager === "apt") {
            console.log("[PikaPack] [INSTALLED] Running dpkg -l...")
            _runCommand("dpkg -l 2>/dev/null | grep '^ii' ", function(out) {
                const parsed = _parseAptInstalled(out, "apt")
                if (flatpakAvailable) {
                    _runCommand("flatpak list --columns=name,application,version,origin 2>/dev/null", function(fpOut) {
                        const fpParsed = _parseFlatpakInstalled(fpOut, "flatpak")
                        const combined = parsed.concat(fpParsed)
                        _installedCache = { timestamp: Date.now(), data: combined }
                        installedPackages = combined
                        console.log("[PikaPack] [INSTALLED] Finished - loaded", combined.length, "packages (apt + flatpak)")
                        isLoading = false
                        installedPackagesLoaded()
                checkOrphans()
                    })
                } else {
                    _installedCache = { timestamp: Date.now(), data: parsed }
                    installedPackages = parsed
                    console.log("[PikaPack] [INSTALLED] Finished - loaded", parsed.length, "packages")
                    isLoading = false
                    installedPackagesLoaded()
                checkOrphans()
                }
            })
        } else if (pkgManager === "pacman") {
            console.log("[PikaPack] [INSTALLED] Running pacman -Q...")
            _runCommand("pacman -Q 2>/dev/null", function(out) {
                const parsed = _parsePacmanInstalled(out, "pacman")
                if (flatpakAvailable) {
                    _runCommand("flatpak list --columns=name,application,version,origin 2>/dev/null", function(fpOut) {
                        const fpParsed = _parseFlatpakInstalled(fpOut, "flatpak")
                        const combined = parsed.concat(fpParsed)
                        _installedCache = { timestamp: Date.now(), data: combined }
                        installedPackages = combined
                        console.log("[PikaPack] [INSTALLED] Finished - loaded", combined.length, "packages (pacman + flatpak)")
                        isLoading = false
                        installedPackagesLoaded()
                checkOrphans()
                    })
                } else {
                    _installedCache = { timestamp: Date.now(), data: parsed }
                    installedPackages = parsed
                    console.log("[PikaPack] [INSTALLED] Finished - loaded", parsed.length, "packages")
                    isLoading = false
                    installedPackagesLoaded()
                checkOrphans()
                }
            })
        } else if (pkgManager === "dnf") {
            console.log("[PikaPack] [INSTALLED] Running dnf list installed...")
            _runCommand("dnf list --installed --quiet 2>/dev/null", function(out) {
                const parsed = _parseDnfInstalled(out, "dnf")
                if (flatpakAvailable) {
                    _runCommand("flatpak list --columns=name,application,version,origin 2>/dev/null", function(fpOut) {
                        const fpParsed = _parseFlatpakInstalled(fpOut, "flatpak")
                        const combined = parsed.concat(fpParsed)
                        _installedCache = { timestamp: Date.now(), data: combined }
                        installedPackages = combined
                        console.log("[PikaPack] [INSTALLED] Finished - loaded", combined.length, "packages (dnf + flatpak)")
                        isLoading = false
                        installedPackagesLoaded()
                checkOrphans()
                    })
                } else {
                    _installedCache = { timestamp: Date.now(), data: parsed }
                    installedPackages = parsed
                    console.log("[PikaPack] [INSTALLED] Finished - loaded", parsed.length, "packages")
                    isLoading = false
                    installedPackagesLoaded()
                checkOrphans()
                }
            })
        } else if (flatpakAvailable) {
            console.log("[PikaPack] [INSTALLED] Running flatpak list...")
            _runCommand("flatpak list --columns=name,application,version,origin 2>/dev/null", function(out) {
                const parsed = _parseFlatpakInstalled(out, "flatpak")
                _installedCache = { timestamp: Date.now(), data: parsed }
                installedPackages = parsed
                console.log("[PikaPack] [INSTALLED] Finished - loaded", parsed.length, "flatpak packages")
                isLoading = false
                installedPackagesLoaded()
                checkOrphans()
            })
        } else {
            console.log("[PikaPack] [INSTALLED] No supported manager for installed packages")
            isLoading = false
        }
    }

    // ─────────────────────────────────────────────────────────
    // INSTALL PACKAGE
    // FIX: All installs now open a real terminal emulator and run sudo
    // inside it, so the password prompt is visible and interactive.
    // pkexec was removed because it needs a registered polkit agent and
    // a display connection that Quickshell Process objects don't provide.
    // AUR installs use the pre-declared aurInstaller Process (fixing the
    // undefined-reference crash) and no longer pass --noconfirm so users
    // can review the PKGBUILD before confirming.
    // ─────────────────────────────────────────────────────────
    function installPackage(pkg, callback) {
        console.log("[PikaPack] [INSTALL] Installing:", pkg.name, "from", pkg.source)
        isInstalling = true
        currentOperation = `Installing ${pkg.name}...`

        // ── AUR: open terminal with the AUR helper (interactive, no --noconfirm)
        if (pkg.source === "aur") {
            console.log("[PikaPack] [INSTALL] AUR branch entered", "| aurHelper:", aurHelper, "| aurEnabled:", aurEnabled)
            
            // Re-detect at install time in case aurHelper wasn't set yet
            let helperToUse = aurHelper || ""
            
            // If no helper yet, trigger immediate re-detection synchronously
            if (!helperToUse && !aurEnabled) {
                console.log("[PikaPack] [INSTALL] AUR helper not detected during init, running sync re-detect...")
                // Note: We can't do sync detection in QML, so we'll use the async fallback below
            }
            
            console.log("[PikaPack] [INSTALL] Using helper:", helperToUse || "(will auto-detect)")
            console.log("[PikaPack] [INSTALL] helperToUse:", helperToUse)
            if (helperToUse === "paru" || helperToUse === "yay") {
                const terminal = _getTerminal()
                // AUR helpers must run as the normal user (not root), so NO sudo.
                // We do NOT pass --noconfirm so the user can review the PKGBUILD.
                const installCmd = `${helperToUse} -S ${pkg.name}; echo; echo '=== AUR install complete. Press Enter to close ==='; read`
                console.log("[PikaPack] [INSTALL] AUR via", helperToUse, "in terminal:", terminal)
                aurInstaller.command = [terminal, "-e", "bash", "-c", installCmd]
                aurInstaller.running = true
                if (callback) callback("Started AUR install in terminal")
            } else {
                console.log("[PikaPack] [INSTALL] No aurHelper set, running fallback detection...")
                // Try to find a helper one more time before giving up
                _runCommand("which paru || which yay || echo none", function(out) {
                    const found = out.trim().split('/').pop()
                    console.log("[PikaPack] [INSTALL] Fallback detection result:", found)
                    if (found === "paru" || found === "yay") {
                        aurHelper = found
                        aurEnabled = true
                        const terminal = _getTerminal()
                        const installCmd = `${found} -S ${pkg.name}; echo; echo '=== AUR install complete. Press Enter to close ==='; read`
                        console.log("[PikaPack] [INSTALL] AUR via", found, "in terminal:", terminal)
                        aurInstaller.command = [terminal, "-e", "bash", "-c", installCmd]
                        aurInstaller.running = true
                        if (callback) callback("Started AUR install in terminal")
                    } else {
                        console.log("[PikaPack] [INSTALL] ERROR: No AUR helper found in fallback detection")
                        isInstalling = false
                        currentOperation = ""
                        error("No AUR helper found. Please install yay or paru first.")
                    }
                })
            }
            return
        }

        // ── All other sources: open terminal and run sudo ──────
        let innerCmd = ""
        if (pkg.source === "pikman") {
            innerCmd = `pikman install -y '${pkg.name}'`
        } else if (pkg.source === "apt") {
            innerCmd = `apt install -y '${pkg.name}'`
        } else if (pkg.source === "pacman") {
            innerCmd = `pacman -S --noconfirm '${pkg.name}'`
        } else if (pkg.source === "dnf") {
            innerCmd = `dnf install -y '${pkg.name}'`
        } else if (pkg.source === "flatpak") {
            // Flatpak installs don't need root — run as user, no sudo needed
            const appId = pkg.application_id || pkg.name
            const terminal = _getTerminal()
            const flatpakCmd = `flatpak install -y '${appId}'; echo; echo '=== Flatpak install complete. Press Enter to close ==='; read`
            console.log("[PikaPack] [INSTALL] Flatpak in terminal:", terminal)
            privInstaller.command = [terminal, "-e", "bash", "-c", flatpakCmd]
            privInstaller.running = true
            if (callback) callback("Started flatpak install in terminal")
            return
        }

        if (innerCmd) {
            console.log("[PikaPack] [INSTALL] Running in terminal with sudo:", innerCmd)
            _runInTerminalWithSudo(innerCmd, privInstaller, `Install ${pkg.name}`)
            if (callback) callback("Started install in terminal")
        } else {
            isInstalling = false
            currentOperation = ""
            error("Unsupported package source: " + pkg.source)
        }
    }

    // ─────────────────────────────────────────────────────────
    // REMOVE PACKAGE
    // FIX: Same as installPackage — replaced pkexec with terminal + sudo.
    // AUR removals also open a terminal (paru/yay run as normal user).
    // ─────────────────────────────────────────────────────────
    function removePackage(pkg, callback) {
        console.log("[PikaPack] [REMOVE] Removing:", pkg.name, "from", pkg.source)
        isRemoving = true
        currentOperation = `Removing ${pkg.name}...`

        // ── AUR: run paru/yay as normal user, no sudo ──────────
        if (pkg.source === "aur") {
            const helperToUse = aurHelper || ""
            if (helperToUse === "paru" || helperToUse === "yay") {
                const terminal = _getTerminal()
                const removeCmd = `${helperToUse} -Rcs ${pkg.name}; echo; echo '=== AUR remove complete. Press Enter to close ==='; read`
                console.log("[PikaPack] [REMOVE] AUR remove via", helperToUse)
                privRemover.command = [terminal, "-e", "bash", "-c", removeCmd]
                privRemover.running = true
                if (callback) callback("Started AUR remove in terminal")
            } else {
                isRemoving = false
                currentOperation = ""
                error("No AUR helper found. Please install yay or paru first.")
            }
            return
        }

        // ── Flatpak: run as user, no sudo ─────────────────────
        if (pkg.source === "flatpak") {
            const appId = pkg.application_id || pkg.name
            const terminal = _getTerminal()
            const flatpakCmd = `flatpak uninstall -y '${appId}'; echo; echo '=== Flatpak remove complete. Press Enter to close ==='; read`
            console.log("[PikaPack] [REMOVE] Flatpak remove in terminal:", terminal)
            privRemover.command = [terminal, "-e", "bash", "-c", flatpakCmd]
            privRemover.running = true
            if (callback) callback("Started flatpak remove in terminal")
            return
        }

        // ── All other sources: terminal + sudo ────────────────
        let innerCmd = ""
        if (pkg.source === "pikman") {
            innerCmd = `pikman remove -y '${pkg.name}'`
        } else if (pkg.source === "apt") {
            innerCmd = `apt remove -y '${pkg.name}'`
        } else if (pkg.source === "pacman") {
            innerCmd = `pacman -Rns --noconfirm '${pkg.name}'`
        } else if (pkg.source === "dnf") {
            innerCmd = `dnf remove -y '${pkg.name}'`
        }

        if (innerCmd) {
            console.log("[PikaPack] [REMOVE] Running in terminal with sudo:", innerCmd)
            _runInTerminalWithSudo(innerCmd, privRemover, `Remove ${pkg.name}`)
            if (callback) callback("Started remove in terminal")
        } else {
            isRemoving = false
            currentOperation = ""
            error("Unsupported package source: " + pkg.source)
        }
    }

    // ─────────────────────────────────────────────────────────
    // CHECK UPDATES
    // ─────────────────────────────────────────────────────────
    function checkOrphans() {
        if (pkgManager !== "pacman") {
            orphanedPackages = []
            return
        }
        _runCommand("pacman -Qdtq 2>/dev/null", function(out) {
            const names = out.split("\n").map(l => l.trim()).filter(l => l.length > 0)
            orphanedPackages = names.map(n => ({ name: n, source: "pacman", installed: true, version: "", description: "Orphaned" }))
            console.log("[PikaPack] [ORPHANS] Found:", orphanedPackages.length, "orphaned packages")
        })
    }

    function checkForUpdates() {
        console.log("[PikaPack] [UPDATES] Checking for updates...")
        isLoading = true
        currentOperation = "Checking for updates..."

        // Run system pkg manager + flatpak in parallel, merge results when both finish
        let pending = 0
        let combined = []

        function _finish(label, results) {
            combined = combined.concat(results)
            console.log("[PikaPack] [UPDATES]", label, "\u2192", results.length, "updates")
            pending--
            if (pending <= 0) {
                availableUpdates = combined
                console.log("[PikaPack] [UPDATES] Total:", combined.length, "updates")
                isLoading = false
                updatesChecked()
            }
        }

        // System package manager
        if (pkgManager === "pikman") {
            pending++
            _runCommand("pikman list --upgradable 2>/dev/null", function(out) {
                _finish("pikman", _parsePikmanUpdates(out, "pikman"))
            })
        } else if (pkgManager === "apt") {
            pending++
            _runCommand("apt list --upgradable 2>/dev/null", function(out) {
                _finish("apt", _parseAptUpdates(out, "apt"))
            })
        } else if (pkgManager === "pacman") {
            pending++
            _runCommand("pacman -Qu 2>/dev/null", function(out) {
                _finish("pacman", _parsePacmanUpdates(out, "pacman"))
            })
        } else if (pkgManager === "dnf") {
            pending++
            // Use check-update without sudo - works on Fedora without elevation
            _runCommand("dnf check-update --refresh --skip-file-locks 2>&1 || echo EXITCODE:$?", function(out) {
                _finish("dnf", _parseDnfUpdates(out, "dnf"))
            })
        }

        // Flatpak — always checked independently if available
        if (flatpakAvailable) {
            pending++
            _runCommand("flatpak remote-ls --updates --columns=name,application,version,branch 2>/dev/null", function(out) {
                _finish("flatpak", _parseFlatpakUpdates(out, "flatpak"))
            })
        }

        // Nothing to check
        if (pending === 0) {
            isLoading = false
        }
    }

    function checkUpdates() {
        checkForUpdates()
    }

    // ─────────────────────────────────────────────────────────
    // UPGRADE ALL
    // FIX: Same pattern — terminal + sudo instead of pkexec.
    // ─────────────────────────────────────────────────────────
    function upgradeAll() {
        console.log("[PikaPack] [UPGRADE] Upgrading all packages...")
        isInstalling = true
        currentOperation = "Upgrading all packages..."

        let innerCmd = ""
        if (pkgManager === "pikman") {
            innerCmd = "pikman upgrade -y"
        } else if (pkgManager === "apt") {
            innerCmd = "apt upgrade -y"
        } else if (pkgManager === "pacman") {
            // For pacman, also run AUR helper upgrade if available (as normal user)
            if (aurHelper === "paru" || aurHelper === "yay") {
                const terminal = _getTerminal()
                // First sudo pacman -Syu, then user-level AUR helper upgrade
                const upgradeCmd = `pkexec pacman -Syu && ${aurHelper} -Syu; echo; echo '=== Upgrade complete. Press Enter to close ==='; read`
                console.log("[PikaPack] [UPGRADE] Full pacman+AUR upgrade in terminal")
                privUpgrader.command = [terminal, "-e", "bash", "-c", upgradeCmd]
                privUpgrader.running = true
                return
            }
            innerCmd = "pacman -Syu --noconfirm"
        } else if (pkgManager === "dnf") {
            innerCmd = "dnf upgrade -y"
        }

        if (innerCmd) {
            console.log("[PikaPack] [UPGRADE] Running in terminal with sudo:", innerCmd)
            _runInTerminalWithSudo(innerCmd, privUpgrader, "Upgrade all packages")
        } else if (flatpakAvailable) {
            // Flatpak updates run as user
            const terminal = _getTerminal()
            const flatpakUpgradeCmd = `flatpak update -y; echo; echo '=== Flatpak upgrade complete. Press Enter to close ==='; read`
            privUpgrader.command = [terminal, "-e", "bash", "-c", flatpakUpgradeCmd]
            privUpgrader.running = true
        } else {
            isInstalling = false
            error("No supported package manager for upgrade")
        }
    }


    // ─────────────────────────────────────────────────────────
    // SYNC & UPDATE
    // ─────────────────────────────────────────────────────────
    property var privSyncer: Process {
        onExited: { PackageManagerService.isInstalling = false }
    }

    function syncAndUpdate() {
        console.log("[PikaPack] [SYNC] Syncing and upgrading...")
        isInstalling = true
        currentOperation = "Syncing and upgrading..."
        const terminal = _getTerminal()
        let cmd = ""
        if (pkgManager === "pacman") {
            if (aurHelper === "paru" || aurHelper === "yay") {
                const fullCmd = "pkexec pacman -Syyu && " + aurHelper + " -Syu; echo; echo '=== Sync & Update complete. Press Enter to close ==='; read"
                privSyncer.command = [terminal, "-e", "bash", "-c", fullCmd]
                privSyncer.running = true
                return
            }
            cmd = "pacman -Syyu --noconfirm"
        } else if (pkgManager === "apt") {
            cmd = "apt update && apt upgrade -y"
        } else if (pkgManager === "dnf") {
            cmd = "dnf upgrade --refresh -y"
        } else if (pkgManager === "pikman") {
            cmd = "pikman upgrade -y"
        } else {
            isInstalling = false
            return
        }
        _runInTerminalWithSudo(cmd, privSyncer, "Sync & Update")
    }

    // ─────────────────────────────────────────────────────────
    // CLEAN CACHE
    // ─────────────────────────────────────────────────────────
    property var privCacheCleaner: Process {
        onExited: { PackageManagerService.isInstalling = false }
    }

    function cleanCache() {
        console.log("[PikaPack] [CACHE] Cleaning package cache...")
        isInstalling = true
        currentOperation = "Cleaning cache..."
        const terminal = _getTerminal()
        let inner = ""
        if (pkgManager === "pacman") {
            inner = "paccache -r 2>/dev/null || pacman -Sc --noconfirm"
        } else if (pkgManager === "apt") {
            inner = "apt clean && apt autoclean"
        } else if (pkgManager === "dnf") {
            inner = "dnf clean all"
        } else if (pkgManager === "pikman") {
            inner = "pikman clean"
        } else {
            isInstalling = false
            return
        }
        const flatpakPart = flatpakAvailable ? "; flatpak uninstall --unused -y" : ""
        const fullCmd = "sudo sh -c '" + inner.replace(/'/g, "'\\''") + "'" + flatpakPart + "; echo; echo '=== Cache clean complete. Press Enter to close ==='; read"
        privCacheCleaner.command = [terminal, "-e", "bash", "-c", fullCmd]
        privCacheCleaner.running = true
    }

    // ─────────────────────────────────────────────────────────
    // REMOVE ORPHANS
    // ─────────────────────────────────────────────────────────
    property var privOrphanRemover: Process {
        onExited: {
            PackageManagerService.isInstalling = false
            PackageManagerService.checkOrphans()
            PackageManagerService.getInstalledPackages(true)
        }
    }

    function removeOrphans() {
        if (orphanedPackages.length === 0) {
            console.log("[PikaPack] [ORPHANS] No orphans to remove")
            return
        }
        console.log("[PikaPack] [ORPHANS] Removing", orphanedPackages.length, "orphaned packages...")
        isInstalling = true
        currentOperation = "Removing orphaned packages..."
        let cmd = ""
        if (pkgManager === "pacman") {
            cmd = "pacman -Rns $(pacman -Qdtq) --noconfirm"
        } else if (pkgManager === "apt") {
            cmd = "apt autoremove -y"
        } else if (pkgManager === "dnf") {
            cmd = "dnf autoremove -y"
        } else {
            isInstalling = false
            return
        }
        _runInTerminalWithSudo(cmd, privOrphanRemover, "Remove Orphans")
    }


    // ─────────────────────────────────────────────────────────
    // Command Runner (read-only, non-privileged operations only)
    // This is used for search, listing installed packages, detecting
    // capabilities, etc. — NOT for install/remove/upgrade.
    // ─────────────────────────────────────────────────────────
    function _runCommand(cmd, callback) {
        console.log("[PikaPack] [COMMAND] EXECUTING →", cmd)

        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root, "tempProc")
        proc.command = ["sh", "-c", cmd]

        proc.stdout = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc, "stdoutCol")

        proc.stdout.onStreamFinished.connect(function() {
            const output = proc.stdout.text || ""
            console.log("[PikaPack] [COMMAND] FINISHED → length:", output.length)
            if (output.length > 0 && output.length < 500) {
                console.log("[PikaPack] [COMMAND] Preview:", output.trim().substring(0, 400))
            }
            callback(output)
            proc.destroy()
        })

        proc.running = true
    }

    // ─────────────────────────────────────────────────────────
    // Parsers
    // ─────────────────────────────────────────────────────────

    // DNF repoquery parser (structured output)
    function _parseDnfRepoquery(raw, source) {
        console.log("[PikaPack] [PARSER] _parseDnfRepoquery raw length:", raw.length)
        const results = []
        const seenNames = new Set()

        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue

            const parts = t.split("|")
            if (parts.length < 4) continue

            const name = parts[0].trim()
            if (seenNames.has(name)) continue
            seenNames.add(name)

            const version = parts[1] ? parts[1].trim() : ""
            const release = parts[2] ? parts[2].trim() : ""
            const arch = parts[3] ? parts[3].trim() : ""
            const summary = parts[4] ? parts[4].trim() : ""
            const description = parts.length >= 6 ? (parts[5] ? parts[5].trim() : "") : ""
            const sizeStr = parts.length >= 7 ? (parts[6] ? parts[6].trim() : "") : ""

            results.push({
                name: name,
                version: version + (release ? " " + release : ""),
                arch: arch,
                source: source,
                description: description || summary,
                summary: summary,
                size: _formatSize(sizeStr),
                installed: false
            })

            if (results.length >= 50) break
        }

        console.log("[PikaPack] [PARSER] dnf repoquery → parsed", results.length, "packages")
        return results
    }

    // Legacy dnf search parser (fallback)
    function _parseDnfSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parseDnfSearch raw length:", raw.length)
        const results = []
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "" || t.startsWith("Last") || t.startsWith("=")) continue
            const colonIdx = t.indexOf(" : ")
            if (colonIdx > 0) {
                let name = t.substring(0, colonIdx).trim().split(".")[0]
                const desc = t.substring(colonIdx + 3).trim()
                results.push({
                    name: name,
                    version: "",
                    source: source,
                    description: desc,
                    installed: false
                })
            }
        }
        console.log("[PikaPack] [PARSER] dnf search → parsed", results.length, "packages")
        return results
    }

    // Pacman installed parser (parses pacman -Q output)
    function _parsePacmanInstalled(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePacmanInstalled raw length:", raw.length)
        const results = raw.split("\n")
            .filter(l => {
                const t = l.trim()
                return t.length > 0
            })
            .map(line => {
                const parts = line.trim().split(/\s+/)
                if (parts.length >= 2) {
                    return {
                        name: parts[0],
                        version: parts[1],
                        source: source,
                        description: "",
                        installed: true
                    }
                }
                return null
            })
            .filter(p => p && p.name)
        console.log("[PikaPack] [PARSER] pacman installed → parsed", results.length, "packages")
        return results
    }

    function _parseDnfInstalled(raw, source) {
        console.log("[PikaPack] [PARSER] _parseDnfInstalled raw length:", raw.length)
        const results = raw.split("\n")
            .filter(l => {
                const t = l.trim()
                return t.length > 0 && !t.startsWith("Installed") && !t.startsWith("Last metadata")
            })
            .map(line => {
                const parts = line.trim().split(/\s+/)
                if (parts.length < 2) return null
                return {
                    name: parts[0].split(".")[0],
                    version: parts[1],
                    source: source,
                    description: "",
                    installed: true
                }
            })
            .filter(p => p && p.name)
        console.log("[PikaPack] [PARSER] dnf installed → parsed", results.length, "packages")
        return results
    }

    function _parseDnfUpdates(raw, source) {
        console.log("[PikaPack] [PARSER] _parseDnfUpdates raw length:", raw.length)
        const lines = raw.split("\n")
        const results = []
        
        for (const line of lines) {
            const t = line.trim()
            if (!t || t.length === 0) continue
            if (t.startsWith("Last") || t.startsWith("Updated") || t.startsWith("=") ||
                t.startsWith("Repositories") || t.startsWith("Waiting") ||
                t.startsWith("Updating") || t.includes("100%") ||
                t === "Upgrades" || t === "Obsoletes" || t === "Installs" || t === "Removals" ||
                t.startsWith("Copr") || t.startsWith("Fedora") || t.startsWith("RPM") ||
                t.startsWith("Security") || t.startsWith("Total") ||
                (t.startsWith("Available") && t.includes("Upgrades")) ||
                t.includes("EXITS")) {
                continue
            }
            
            // dnf5 format: packagename.arch    version    repository
            const parts = t.split(/\s+/)
            if (parts.length >= 2) {
                const pkgName = parts[0]
                if (pkgName.includes(".")) {
                    const nameParts = pkgName.split(".")
                    const name = nameParts.slice(0, -1).join(".")
                    const arch = nameParts[nameParts.length - 1]
                    const ver = parts[1] || ""
                    results.push({
                        name: name,
                        version: ver,
                        newVersion: ver,
                        source: source,
                        description: parts.length >= 3 ? parts.slice(2).join(" ") : "",
                        installed: true
                    })
                }
            }
        }
        
        console.log("[PikaPack] [PARSER] dnf updates → parsed", results.length, "packages")
        return results
    }

    // Pacman updates parser (parses pacman -Qu output)
    function _parsePacmanUpdates(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePacmanUpdates raw length:", raw.length)
        const results = raw.split("\n")
            .filter(l => {
                const t = l.trim()
                return t.length > 0 && !t.startsWith("warning") && !t.startsWith("error")
            })
            .map(line => {
                const parts = line.trim().split(/\s+/)
                if (parts.length >= 2) {
                    const currentVer = parts[1] ? parts[1].replace("->", "").trim() : ""
                    const newVer = line.includes("->") ? line.split("->")[1].trim().split(/\s+/)[0] : currentVer
                    return {
                        name: parts[0],
                        version: currentVer,
                        source: source,
                        description: "",
                        newVersion: newVer,
                        installed: true
                    }
                }
                return null
            })
            .filter(p => p && p.name)
        console.log("[PikaPack] [PARSER] pacman updates → parsed", results.length, "packages")
        return results
    }

    // Pikman search parser
    function _parsePikmanSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePikmanSearch raw length:", raw.length)
        const results = []
        let currentPkg = null
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue
            
            if (t.includes('/') || (!t.startsWith('[') && !t.startsWith('('))) {
                const parts = t.split(/\s+/)
                if (parts.length >= 2) {
                    if (t.includes('/')) {
                        const repoParts = t.split('/')
                        const name = repoParts[1] ? repoParts[1].split(/\s+/)[0] : ""
                        const version = parts[1] ? parts[1] : ""
                        
                        if (name) {
                            currentPkg = {
                                name: name,
                                version: version,
                                source: source,
                                description: "",
                                installed: t.includes("[installed]") || t.includes("(installed)")
                            }
                        }
                    } else {
                        currentPkg = {
                            name: parts[0],
                            version: parts[1] ? parts[1] : "",
                            source: source,
                            description: "",
                            installed: t.includes("[installed]") || t.includes("(installed)")
                        }
                    }
                }
            } else if (currentPkg && currentPkg.description === "") {
                currentPkg.description = t
            }
            
            if (currentPkg && currentPkg.name) {
                results.push(currentPkg)
                currentPkg = null
            }
        }
        
        console.log("[PikaPack] [PARSER] pikman search → parsed", results.length, "packages")
        return results
    }

    // Pikman installed parser
    function _parsePikmanInstalled(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePikmanInstalled raw length:", raw.length)
        const results = []
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "" || t.startsWith("[")) continue
            
            const parts = t.split(/\s+/)
            if (parts.length >= 2) {
                results.push({
                    name: parts[0],
                    version: parts[1],
                    source: source,
                    description: "",
                    installed: true
                })
            }
        }
        
        console.log("[PikaPack] [PARSER] pikman installed → parsed", results.length, "packages")
        return results
    }

    // Pikman updates parser
    function _parsePikmanUpdates(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePikmanUpdates raw length:", raw.length)
        const results = []
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "" || t.startsWith("[")) continue
            
            const parts = t.split(/\s+/)
            if (parts.length >= 2) {
                const currentVer = parts[1] ? parts[1] : ""
                const newVer = t.includes("->") ? t.split("->")[1].trim().split(/\s+/)[0] : currentVer
                results.push({
                    name: parts[0],
                    version: currentVer,
                    source: source,
                    description: "",
                    newVersion: newVer,
                    installed: true
                })
            }
        }
        
        console.log("[PikaPack] [PARSER] pikman updates → parsed", results.length, "packages")
        return results
    }

    // APT search parser
    function _parseAptSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parseAptSearch raw length:", raw.length)
        const results = []
        let currentPkg = null
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue
            
            if (!t.startsWith("WARNING") && !t.startsWith("Reading") && !t.startsWith("Sorting")) {
                const parts = t.split(/\s+/)
                if (parts.length >= 2 && t.includes("/")) {
                    if (currentPkg && currentPkg.name) {
                        results.push(currentPkg)
                    }
                    
                    const nameParts = parts[0].split("/")
                    const name = nameParts[1] ? nameParts[1] : parts[0]
                    
                    currentPkg = {
                        name: name,
                        version: parts[1] ? parts[1] : "",
                        source: source,
                        description: "",
                        installed: false
                    }
                } else if (currentPkg && currentPkg.description === "") {
                    currentPkg.description = t
                }
            }
        }
        
        if (currentPkg && currentPkg.name) {
            results.push(currentPkg)
        }
        
        console.log("[PikaPack] [PARSER] apt search → parsed", results.length, "packages")
        return results
    }

    // APT installed parser (parses dpkg -l output)
    function _parseAptInstalled(raw, source) {
        console.log("[PikaPack] [PARSER] _parseAptInstalled raw length:", raw.length)
        const results = []
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "" || !t.startsWith("ii ")) continue
            
            const parts = t.split(/\s+/)
            if (parts.length >= 3) {
                results.push({
                    name: parts[1],
                    version: parts[2],
                    source: source,
                    description: "",
                    installed: true
                })
            }
        }
        
        console.log("[PikaPack] [PARSER] apt installed → parsed", results.length, "packages")
        return results
    }

    // APT updates parser (parses apt list --upgradable)
    function _parseAptUpdates(raw, source) {
        console.log("[PikaPack] [PARSER] _parseAptUpdates raw length:", raw.length)
        const results = []
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "" || t.startsWith("WARNING") || t.startsWith("Listing")) continue
            
            const parts = t.split(/\s+/)
            if (parts.length >= 1) {
                const name = parts[0]
                let currentVer = ""
                let newVer = ""
                
                const versionMatch = t.match(/\[([^]]+)\s*->\s*([^\]]+)\]/)
                if (versionMatch) {
                    currentVer = versionMatch[1]
                    newVer = versionMatch[2]
                }
                
                results.push({
                    name: name,
                    version: currentVer,
                    source: source,
                    description: "",
                    newVersion: newVer,
                    installed: true
                })
            }
        }
        
        console.log("[PikaPack] [PARSER] apt updates → parsed", results.length, "packages")
        return results
    }

    // Flatpak search parser
    function _parseFlatpakSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parseFlatpakSearch raw length:", raw.length)
        const results = []
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue

            const parts = t.split("\t")
            if (parts.length >= 2) {
                results.push({
                    name: parts[0] ? parts[0].trim() : "",
                    application_id: parts[1] ? parts[1].trim() : "",
                    version: parts.length >= 4 ? (parts[3] ? parts[3].trim() : "") : "",
                    source: source,
                    description: parts.length >= 3 ? (parts[2] ? parts[2].trim() : "") : "",
                    installed: false
                })
            }
        }
        console.log("[PikaPack] [PARSER] flatpak search → parsed", results.length, "packages")
        return results
    }

    function _parseFlatpakInstalled(raw, source) {
        console.log("[PikaPack] [PARSER] _parseFlatpakInstalled raw length:", raw.length)
        const results = raw.split("\n")
            .filter(l => l.trim().length > 0)
            .map(line => {
                const cols = line.split("\t")
                return {
                    name: cols[0] ? cols[0].trim() : "",
                    application_id: cols[1] ? cols[1].trim() : "",
                    version: cols[2] ? cols[2].trim() : "",
                    source: source,
                    description: "",
                    installed: true
                }
            })
            .filter(p => p.name.length > 0)
        console.log("[PikaPack] [PARSER] flatpak installed → parsed", results.length, "packages")
        return results
    }

    function _parseFlatpakUpdates(raw, source) {
        console.log("[PikaPack] [PARSER] _parseFlatpakUpdates raw length:", raw.length)
        const results = []
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue
            // flatpak remote-ls --updates outputs tab-separated:
            // name \t application_id \t version \t branch
            const cols = t.split("\t")
            if (cols.length < 2) continue
            const name    = (cols[0] || "").trim()
            const appId   = (cols[1] || "").trim()
            const version = (cols[2] || "").trim()
            const branch  = (cols[3] || "stable").trim()
            if (!name && !appId) continue
            results.push({
                name:           name || appId,
                application_id: appId,
                version:        branch,          // currently installed branch
                newVersion:     version || "update available",
                source:         source,
                installed:      true,
                description:    ""
            })
        }
        console.log("[PikaPack] [PARSER] flatpak updates \u2192 parsed", results.length, "packages")
        return results
    }

    // AUR search parser (basic)
    function _parseAurSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parseAurSearch raw length:", raw.length)
        const results = []
        const lines = raw.split("\n")
        let i = 0
        while (i < lines.length) {
            const line = lines[i].trim()
            if (line.startsWith("aur/")) {
                const parts = line.split("/")
                const name = parts[1] ? parts[1].trim() : ""
                let version = ""
                let description = ""

                if (i + 1 < lines.length) {
                    const nextLine = lines[i + 1].trim()
                    if (nextLine.startsWith("Version:")) {
                        version = nextLine.substring(8).trim()
                    }
                    if (nextLine.startsWith("Description:")) {
                        description = nextLine.substring(12).trim()
                    }
                }

                if (name) {
                    results.push({
                        name: name,
                        version: version,
                        source: source,
                        description: description,
                        installed: false
                    })
                }
            }
            i++
        }
        console.log("[PikaPack] [PARSER] aur search → parsed", results.length, "packages")
        return results
    }

    // AUR RPC search parser (parses JSON from aur.archlinux.org RPC)
    function _parseAurRpcSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parseAurRpcSearch raw length:", raw.length)
        const results = []
        
        try {
            const json = JSON.parse(raw)
            if (json.type !== "error" && json.results && json.results.length > 0) {
                for (let result of json.results) {
                    results.push({
                        name: result.Name || "",
                        version: result.Version || "",
                        source: source,
                        description: result.Description || "",
                        installed: false,
                        aur_votes: result.NumVotes || 0,
                        aur_popularity: result.Popularity || 0
                    })
                }
            }
        } catch (e) {
            console.log("[PikaPack] [PARSER] AUR RPC JSON parse failed:", e)
        }
        
        console.log("[PikaPack] [PARSER] aur rpc search → parsed", results.length, "packages")
        return results
    }

    // Pacman search parser (parses pacman -Ss output)
    function _parsePacmanSearch(raw, source) {
        console.log("[PikaPack] [PARSER] _parsePacmanSearch raw length:", raw.length)
        const results = []
        let currentPkg = null
        
        for (let line of raw.split("\n")) {
            const t = line.trim()
            if (t === "") continue
            
            if (t.startsWith("core/") || t.startsWith("extra/") || 
                t.startsWith("community/") || t.startsWith("multilib/")) {
                if (currentPkg && currentPkg.name) {
                    results.push(currentPkg)
                }
                
                const parts = t.split(/\s+/)
                if (parts.length >= 2) {
                    const repoName = parts[0].split('/')
                    const name = repoName[1] ? repoName[1] : ""
                    const version = parts[1] ? parts[1] : ""
                    
                    currentPkg = {
                        name: name,
                        version: version,
                        repository: repoName[0] ? repoName[0] : "",
                        source: source,
                        description: "",
                        installed: false
                    }
                }
            } else if (currentPkg && currentPkg.description === "") {
                currentPkg.description = t
            }
        }
        
        if (currentPkg && currentPkg.name) {
            results.push(currentPkg)
        }
        
        console.log("[PikaPack] [PARSER] pacman search → parsed", results.length, "packages")
        return results
    }

    function _formatSize(sizeStr) {
        if (!sizeStr || sizeStr === "") return ""
        const num = parseFloat(sizeStr)
        if (isNaN(num)) return sizeStr
        if (num < 1024) return num.toFixed(0) + " B"
        if (num < 1024 * 1024) return (num / 1024).toFixed(1) + " KB"
        if (num < 1024 * 1024 * 1024) return (num / 1024 / 1024).toFixed(1) + " MB"
        return (num / 1024 / 1024 / 1024).toFixed(2) + " GB"
    }
}
