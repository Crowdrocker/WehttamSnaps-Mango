pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

Singleton {
    id: root

    readonly property string screenshotsDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.PicturesLocation)) + "/Screenshots"

    // Must be set by the root UI (shell.qml) so screencopy can render.
    // Map: screenName -> ScreencopyFileCapture
    property var screencopyCaptures: ({})

    signal areaRequested(string path, string backgroundPath)

    // ── Portal (wlr impl) screenshot support ────────────────────────────────
    // We call the wlroots implementation directly to avoid needing a GTK portal.
    // This provides correct compositor-composed pixels (opacity, wallpaper, etc.).
    property string _portalPendingOutPath: ""
    property bool _portalPendingInteractive: false
    property string _portalPendingFallbackScreenName: ""

    function _uriToLocalPath(uri) {
        if (!uri || !uri.length)
            return ""
        if (!uri.startsWith("file://"))
            return ""
        // file:///tmp/out.png -> /tmp/out.png
        const raw = uri.slice("file://".length)
        try {
            return decodeURIComponent(raw)
        } catch (_) {
            return raw
        }
    }

    function _extractFileUri(text) {
        if (!text || !text.length)
            return ""
        const i = text.indexOf("file://")
        if (i < 0)
            return ""
        let j = i
        while (j < text.length) {
            const ch = text[j]
            if (ch === "'" || ch === ">" || ch === " " || ch === "\n" || ch === "\t" || ch === "\r")
                break
            j++
        }
        return text.slice(i, j)
    }

    function _portalWlrScreenshotToFile(outPath, interactive) {
        _portalPendingOutPath = outPath
        _portalPendingInteractive = !!interactive
        _portalPendingFallbackScreenName = ""
        portalShotProcess.command = [
            "gdbus", "call", "--session",
            "--dest", "org.freedesktop.impl.portal.desktop.wlr",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.impl.portal.Screenshot.Screenshot",
            "/org/freedesktop/portal/desktop",
            "qs",
            "",
            interactive ? "{'interactive': <true>}" : "{}"
        ]
        portalShotProcess.running = true
        return true
    }

    function _screenByName(screenName) {
        const screens = Quickshell.screens || []
        if (screenName && screenName.length) {
            const s = screens.find(sc => sc.name === screenName)
            if (s)
                return s
        }
        return screens.length ? screens[0] : null
    }

    function _ensureDir() {
        Quickshell.execDetached(["sh", "-c", `mkdir -p "${screenshotsDir}"`])
    }

    function _timestampPath() {
        const ts = Date.now()
        return `${screenshotsDir}/screenshot-${ts}.png`
    }

    function _runEditor(path) {
        const editor = Quickshell.env("SCREENSHOT_EDITOR") || Quickshell.env("EH_SCREENSHOT_EDITOR") || ""
        if (editor && editor.length) {
            Quickshell.execDetached(["sh", "-c", editor.replaceAll("%path%", path)])
            return
        }
        Quickshell.execDetached(["sh", "-c",
            `command -v satty >/dev/null 2>&1 && exec satty -f "${path}"; ` +
            `command -v swappy >/dev/null 2>&1 && exec swappy -f "${path}"; ` +
            `exit 0`
        ])
    }

    function postProcess(path) {
        // Copy to clipboard (best-effort).
        Quickshell.execDetached(["sh", "-c",
            `command -v wl-copy >/dev/null 2>&1 || exit 0; ` +
            `wl-copy --type image/png < "${path}" || true; ` +
            `exit 0`
        ])
        _runEditor(path)
        if (typeof ToastService !== "undefined")
            ToastService.showInfo("Screenshot saved", path)
    }

    function _captureScreenToFile(screen, path) {
        const cap = screencopyCaptures && screen && screen.name ? screencopyCaptures[screen.name] : null
        if (!cap) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "Screencopy capture not initialized")
            return false
        }
        return cap.captureToFile(screen, path, function (ok, p) {
            if (ok) {
                _runEditor(p)
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Screenshot saved", p)
            } else if (typeof ToastService !== "undefined") {
                ToastService.showError("Screenshot failed", "Capture failed")
            }
        })
    }

    function areaOn(screenName) {
        _ensureDir()
        const path = _timestampPath()

        if (CompositorService.isNiri) {
            const ok = (typeof NiriService !== "undefined") ? NiriService.screenshot(path) : false
            if (!ok && typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "niri is not available")
            return ok
        }

        // Hyprland (wlroots): prefer portal impl interactive selection for best composition.
        if (CompositorService.isHyprland) {
            _portalPendingFallbackScreenName = screenName || ""
            return _portalWlrScreenshotToFile(path, true)
        }

        const screen = _screenByName(screenName)
        if (!screen) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "No screens available")
            return false
        }

        const bgPath = `${screenshotsDir}/.screenshot-bg-${Date.now()}.png`
        const cap = screencopyCaptures && screen.name ? screencopyCaptures[screen.name] : null
        if (!cap) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "Screencopy capture not initialized")
            return false
        }
        return cap.captureToFile(screen, bgPath, function (ok, p) {
            if (!ok) {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Screenshot failed", "Capture failed")
                return
            }
            areaRequested(path, p)
        })
    }

    function area() { return areaOn("") }

    function screenOn(screenName) {
        _ensureDir()
        const path = _timestampPath()

        if (CompositorService.isNiri) {
            const ok = (typeof NiriService !== "undefined") ? NiriService.screenshotScreen(path) : false
            if (!ok && typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "niri is not available")
            return ok
        }

        if (CompositorService.isHyprland) {
            return _portalWlrScreenshotToFile(path, false)
        }

        const screen = _screenByName(screenName)
        if (!screen) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "No screens available")
            return false
        }
        return _captureScreenToFile(screen, path)
    }

    function screen() { return screenOn("") }

    function fullscreen() {
        _ensureDir()
        if (!Quickshell.screens || Quickshell.screens.length === 0) {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "No screens available")
            return false
        }
        // Capture each screen to its own file.
        let okAny = false
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i]
            const path = `${screenshotsDir}/screenshot-${Date.now()}-${screen.name}.png`
            okAny = _captureScreenToFile(screen, path) || okAny
        }
        return okAny
    }

    function window() {
        _ensureDir()
        const path = _timestampPath()

        if (CompositorService.isNiri) {
            const ok = (typeof NiriService !== "undefined") ? NiriService.screenshotWindow(path) : false
            if (!ok && typeof ToastService !== "undefined")
                ToastService.showError("Screenshot failed", "niri is not available")
            return ok
        }

        if (typeof ToastService !== "undefined")
            ToastService.showWarning("Screenshot window", "Window capture not implemented yet")
        return false
    }

    Process {
        id: portalShotProcess
        running: false
        stdout: StdioCollector { id: portalShotStdout }
        stderr: StdioCollector { id: portalShotStderr }

        onExited: function (code) {
            const out = (portalShotStdout && portalShotStdout.text) ? portalShotStdout.text : ""
            const outPath = _portalPendingOutPath
            const wasInteractive = _portalPendingInteractive
            const fallbackScreenName = _portalPendingFallbackScreenName
            _portalPendingOutPath = ""
            _portalPendingInteractive = false
            _portalPendingFallbackScreenName = ""

            if (code !== 0) {
                // If user cancelled interactive selection, fall back to our QML area picker.
                if (wasInteractive) {
                    const screen = _screenByName(fallbackScreenName)
                    if (!screen) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showError("Screenshot failed", "No screens available")
                        return
                    }
                    const bgPath = `${screenshotsDir}/.screenshot-bg-${Date.now()}.png`
                    const cap = screencopyCaptures && screen.name ? screencopyCaptures[screen.name] : null
                    if (!cap) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showError("Screenshot failed", "Screencopy capture not initialized")
                        return
                    }
                    cap.captureToFile(screen, bgPath, function (ok, p) {
                        if (!ok) {
                            if (typeof ToastService !== "undefined")
                                ToastService.showError("Screenshot failed", "Capture failed")
                            return
                        }
                        areaRequested(outPath, p)
                    })
                    return
                }
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Screenshot failed", "Portal capture failed")
                return
            }

            const uri = _extractFileUri(out)
            const tmpPath = _uriToLocalPath(uri)
            if (!tmpPath.length || !outPath.length) {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Screenshot failed", "Portal returned no path")
                return
            }

            // Move into our screenshots dir.
            Quickshell.execDetached(["sh", "-c", `cp -f "${tmpPath}" "${outPath}" && rm -f "${tmpPath}"`])
            postProcess(outPath)
        }
    }
}

