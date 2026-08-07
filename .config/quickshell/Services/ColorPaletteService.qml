pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // ── Public state ──────────────────────────────────────────────────────────

    property var    extractedColors:    []
    property var    selectedColors:     []
    property real   hueShiftDegrees:    0       // -180..180
    property real   saturationScale:    1.0     // 0.5..1.5
    property real   lightnessScale:     1.0     // 0.5..1.5
    property bool   isExtracting:       false
    property string currentWallpaper:   ""
    property var    customThemeData:    null
    property string customThemeFilePath: ""
    property bool   customThemeReady:   false
    property var    matugenJsonData:    null    // raw matugen JSON for dynamic theme
    property var    availableThemes:    []

    property string currentThemeName: {
        if (typeof SettingsData !== "undefined")
            return SettingsData.currentColorTheme || ""
        return ""
    }

    // ── Private state ─────────────────────────────────────────────────────────

    property bool   _initialized:        false
    property string _lastWallpaperPath:  ""

    // ── Signals ───────────────────────────────────────────────────────────────

    signal colorsExtracted()
    signal colorsChanged()
    signal customThemeCreated(var themeData)
    signal themesUpdated()
    signal textColorAdjustmentChanged()

    // ── Initialization ────────────────────────────────────────────────────────

    function initializeIfNeeded() {
        if (_initialized) return
        _initialized = true

        Qt.callLater(function () {
            if (typeof SettingsData !== "undefined" && SettingsData.savedColorThemes !== undefined) {
                loadCustomThemeFromSettings()
                updateAvailableThemes()
            }
        })
    }

    // ── Wallpaper watcher timer ───────────────────────────────────────────────
    // Use a plain declarative Timer — not Qt.createQmlObject.

    Timer {
        id: wallpaperWatchTimer
        interval: 500
        repeat:   true
        running:  false     // started explicitly once settings are ready

        onTriggered: {
            if (typeof SessionData === "undefined") return

            var currentPath = SessionData.wallpaperPath || ""
            if (currentPath === root._lastWallpaperPath || currentPath === "") return

            root._lastWallpaperPath = currentPath

            if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic)
                root.extractColorsFromWallpaper(currentPath)
        }
    }

    function startWallpaperWatcher() {
        if (typeof SessionData !== "undefined")
            root._lastWallpaperPath = SessionData.wallpaperPath || ""
        wallpaperWatchTimer.running = true
    }

    // ── Color extraction ──────────────────────────────────────────────────────

    function extractColorsFromWallpaper(wallpaperPath, force) {
        // Use SessionData as the canonical id so "we:…" and resolved file paths
        // do not trigger duplicate runs; path passed in may be Theme-resolved.
        const raw = (typeof SessionData !== "undefined" && SessionData.wallpaperPath)
                      ? SessionData.wallpaperPath
                      : wallpaperPath
        const doForce = (force === true)
        if (!raw || (!doForce && raw === currentWallpaper)) return

        currentWallpaper = raw
        isExtracting     = true

        const isLightMode = typeof SessionData !== "undefined" ? SessionData.isLightMode : false
        const mode        = isLightMode ? "light" : "dark"
        const schemeType  = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme)
                            ? SettingsData.matugenScheme
                            : "scheme-tonal-spot"
        const contrast = (typeof SettingsData !== "undefined" && SettingsData.matugenContrast !== undefined)
                            ? SettingsData.matugenContrast
                            : 0.0
        const resizeFilter = (typeof SettingsData !== "undefined" && SettingsData.matugenResizeFilter)
                            ? SettingsData.matugenResizeFilter
                            : "lanczos3"
        const fallbackColor = (typeof SettingsData !== "undefined" && SettingsData.matugenFallbackColor)
                            ? SettingsData.matugenFallbackColor
                            : ""

        var cmd = ["matugen", "--json", "hex", "-m", mode, "--type", schemeType]

        if (contrast !== 0.0)
            cmd.push("--contrast", contrast.toString())
        if (resizeFilter !== "lanczos3")
            cmd.push("--resize-filter", resizeFilter)
        if (fallbackColor !== "")
            cmd.push("--fallback-color", fallbackColor)

        if (raw.startsWith("#")) {
            cmd.push("color", "hex", raw)
        } else {
            // Theme.qml resolves "we:…" to a real image under cache; matugen must read a file.
            const imagePath = (typeof Theme !== "undefined" && Theme.wallpaperPath) ? Theme.wallpaperPath : raw
            cmd.push("image", imagePath, "--source-color-index", "0")
        }

        matugenProcess.command = cmd
        matugenProcess.running = true
    }

    function onWallpaperChanged(newWallpaperPath) {
        if (!newWallpaperPath) return
        root._lastWallpaperPath = newWallpaperPath
        if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic)
            extractColorsFromWallpaper(newWallpaperPath)
    }

    // ── matugen process ───────────────────────────────────────────────────────
    // Collect stdout via SplitParser (line-by-line) so we can assemble the
    // full JSON string before parsing, which is the correct Quickshell pattern.

    property string _matugenBuffer: ""

    Process {
        id: matugenProcess

        stdout: SplitParser {
            // SplitParser emits onRead for each line; we accumulate then parse
            // when the process finishes (onExited below).
            onRead: data => {
                root._matugenBuffer += data + "\n"
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.isExtracting = false
            const raw = root._matugenBuffer.trim()
            root._matugenBuffer = ""

            if (exitCode !== 0 || !raw) {
                console.error("ColorPaletteService: matugen exited with code", exitCode)
                root.extractedColors = []
                return
            }

            try {
                const jsonData = JSON.parse(raw)
                root.matugenJsonData = jsonData

                const colors = root.extractColorsFromMatugen(jsonData)
                root.extractedColors = colors
                root.colorsExtracted()

                if (colors.length > 0) {
                    root.selectedColors = [colors[0]]
                    root.colorsChanged()
                    Qt.callLater(function () { root.applySelectedColors() })
                    Qt.callLater(function () { root.applyMatugenTemplates() })
                }
            } catch (e) {
                console.error("ColorPaletteService: Failed to parse matugen output:", e.message)
                console.error("ColorPaletteService: Raw output (first 500):", raw.substring(0, 500))
                root.extractedColors = []
            }
        }
    }

    // ── Template application process ──────────────────────────────────────────

    Process {
        id: templateProcess
        // stderr passthrough so errors surface in the Quickshell log
        onExited: (exitCode, _) => {
            if (exitCode !== 0)
                console.error("ColorPaletteService: matugen-worker.sh exited with code", exitCode)
        }
    }

    function applyMatugenTemplates() {
        const runEhTemplates = typeof SettingsData !== "undefined"
                               ? (SettingsData.runEHMatugenTemplates !== false)
                               : true
        if (!runEhTemplates) return

        // Quickshell.shellDir is the canonical path to the QS config directory.
        const shellDir = Quickshell.shellDir
        // Use .state subdirectory within the config directory for persistent state.
        const stateDir = shellDir + "/.state/matugen-state"

        const wallpaperPath = root.currentWallpaper
        if (!wallpaperPath) {
            console.warn("ColorPaletteService: applyMatugenTemplates — no wallpaper path")
            return
        }

        const isLightMode = typeof SessionData !== "undefined" ? SessionData.isLightMode : false
        const mode        = isLightMode ? "light" : "dark"
        const schemeType  = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme)
                            ? SettingsData.matugenScheme
                            : "scheme-tonal-spot"
        const iconTheme   = (typeof SettingsData !== "undefined" && SettingsData.iconTheme)
                            ? SettingsData.iconTheme
                            : "System Default"

        const raw         = root.currentWallpaper
        const kind        = raw.startsWith("#") ? "hex" : "image"
        const value       = (kind === "hex")
                            ? raw
                            : ((typeof Theme !== "undefined" && Theme.wallpaperPath) ? Theme.wallpaperPath : raw)

        const desiredJson = JSON.stringify({
            kind:        kind,
            value:       value,
            mode:        mode,
            iconTheme:   iconTheme,
            matugenType: schemeType
        })

        const desiredPath  = stateDir + "/matugen.desired.json"
        const workerScript = shellDir + "/scripts/matugen-worker.sh"

        // Write desired.json then invoke the worker.
        // Using single-quotes around the JSON in the shell command would break if
        // any path contains a single-quote; use printf + a heredoc-style approach.
        const cmd = `mkdir -p ${JSON.stringify(stateDir)} && `
                  + `printf '%s' ${JSON.stringify(desiredJson)} > ${JSON.stringify(desiredPath)} && `
                  + `${JSON.stringify(workerScript)} ${JSON.stringify(stateDir)} ${JSON.stringify(shellDir)} --run`

        templateProcess.command = ["bash", "-c", cmd]
        templateProcess.running = true
    }

    // ── Color selection helpers ───────────────────────────────────────────────

    function selectColor(color, selected) {
        if (selected) {
            if (!selectedColors.includes(color))
                selectedColors.push(color)
        } else {
            const index = selectedColors.indexOf(color)
            if (index > -1)
                selectedColors.splice(index, 1)
        }
        colorsChanged()
    }

    function clearSelection() {
        selectedColors = []
        colorsChanged()
    }

    // ── Color math utilities ──────────────────────────────────────────────────

    function getBrightness(color) {
        let r, g, b
        if (typeof color === "string" && color.startsWith("#")) {
            r = parseInt(color.slice(1, 3), 16) / 255
            g = parseInt(color.slice(3, 5), 16) / 255
            b = parseInt(color.slice(5, 7), 16) / 255
        } else {
            r = color.r || 0
            g = color.g || 0
            b = color.b || 0
        }
        return (r * 0.299 + g * 0.587 + b * 0.114)
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function hexToHsl(hex) {
        if (typeof hex !== "string" || !hex.startsWith("#") || (hex.length !== 7 && hex.length !== 9))
            return { h: 0, s: 0, l: 0 }

        const r = parseInt(hex.substr(1, 2), 16) / 255
        const g = parseInt(hex.substr(3, 2), 16) / 255
        const b = parseInt(hex.substr(5, 2), 16) / 255

        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        let h = 0, s = 0
        const l = (max + min) / 2

        if (max !== min) {
            const d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break
                case g: h = (b - r) / d + 2;                break
                case b: h = (r - g) / d + 4;                break
            }
            h /= 6
        }
        return { h, s, l }
    }

    function hslToHex(h, s, l) {
        const hue2rgb = (p, q, t) => {
            if (t < 0) t += 1
            if (t > 1) t -= 1
            if (t < 1 / 6) return p + (q - p) * 6 * t
            if (t < 1 / 2) return q
            if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
            return p
        }

        let r, g, b
        if (s === 0) {
            r = g = b = l
        } else {
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s
            const p = 2 * l - q
            r = hue2rgb(p, q, h + 1 / 3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1 / 3)
        }

        const toHex = x => Math.round(x * 255).toString(16).padStart(2, "0")
        return "#" + toHex(r) + toHex(g) + toHex(b)
    }

    function applyHueAdjustments(color) {
        if (!color) return color

        let hex = color
        if (typeof color === "object" && color.r !== undefined) {
            const r = Math.max(0, Math.min(1, color.r))
            const g = Math.max(0, Math.min(1, color.g))
            const b = Math.max(0, Math.min(1, color.b))
            hex = "#" + [r, g, b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("")
        }

        if (typeof hex !== "string" || !hex.startsWith("#")) return hex

        const hsl = hexToHsl(hex)
        let h = (hsl.h * 360 + hueShiftDegrees) % 360
        if (h < 0) h += 360
        h /= 360
        const s = clamp01(hsl.s * saturationScale)
        const l = clamp01(hsl.l * lightnessScale)
        return hslToHex(h, s, l)
    }

    // ── Theme utilities ───────────────────────────────────────────────────────

    function normalizeThemeData(themeData) {
        if (!themeData) return null
        if (themeData.dark || themeData.light) {
            return {
                dark:  themeData.dark  || themeData.light,
                light: themeData.light || themeData.dark
            }
        }
        return { dark: themeData, light: themeData }
    }

    function getPrimaryColorFromTheme(themeData) {
        if (!themeData)                              return "#42a5f5"
        if (themeData.primary)                       return themeData.primary
        if (themeData.dark  && themeData.dark.primary)  return themeData.dark.primary
        if (themeData.light && themeData.light.primary) return themeData.light.primary
        return "#42a5f5"
    }

    function seedSelectionFromCurrentTheme() {
        if (selectedColors.length > 0) return
        const activeTheme = root.customThemeData
                         || (typeof Theme !== "undefined" ? Theme.customThemeData : null)
        const primary = getPrimaryColorFromTheme(activeTheme)
        if (primary) {
            selectedColors = [primary]
            colorsChanged()
        }
    }

    function getTextColorForBackground(backgroundColor) {
        if (typeof SettingsData !== "undefined" && SettingsData.extractedColorTextOverrideEnabled) {
            const hexR = Math.max(0, Math.min(255, SettingsData.extractedColorTextR)).toString(16).padStart(2, "0")
            const hexG = Math.max(0, Math.min(255, SettingsData.extractedColorTextG)).toString(16).padStart(2, "0")
            const hexB = Math.max(0, Math.min(255, SettingsData.extractedColorTextB)).toString(16).padStart(2, "0")
            return "#" + hexR + hexG + hexB
        }
        return getBrightness(backgroundColor) > 0.5 ? "#000000" : "#ffffff"
    }

    // ── Full theme generation from a single primary color ─────────────────────

    function generateThemeFromPrimaryColor(primaryColor, matugenType, isLightMode) {
        if (matugenType === undefined) matugenType  = "scheme-tonal-spot"
        if (isLightMode === undefined) isLightMode  = false

        const colorToHex = color => {
            if (typeof color === "string") return color
            const r = Math.round((color.r || 0) * 255)
            const g = Math.round((color.g || 0) * 255)
            const b = Math.round((color.b || 0) * 255)
            return "#" + [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("")
        }

        const brightness = c => {
            let r, g, b
            if (typeof c === "string" && c.startsWith("#")) {
                r = parseInt(c.slice(1, 3), 16) / 255
                g = parseInt(c.slice(3, 5), 16) / 255
                b = parseInt(c.slice(5, 7), 16) / 255
            } else { r = c.r || 0; g = c.g || 0; b = c.b || 0 }
            return r * 0.299 + g * 0.587 + b * 0.114
        }

        const textFor = (bg, light) => {
            if (typeof SettingsData !== "undefined" && SettingsData.extractedColorTextOverrideEnabled) {
                const hexR = Math.max(0, Math.min(255, SettingsData.extractedColorTextR)).toString(16).padStart(2, "0")
                const hexG = Math.max(0, Math.min(255, SettingsData.extractedColorTextG)).toString(16).padStart(2, "0")
                const hexB = Math.max(0, Math.min(255, SettingsData.extractedColorTextB)).toString(16).padStart(2, "0")
                return "#" + hexR + hexG + hexB
            }
            return brightness(bg) > 0.5 ? "#000000" : "#ffffff"
        }

        const dk = (c, f) => colorToHex(isLightMode ? Qt.darker(c, f)  : Qt.lighter(c, f))
        const lk = (c, f) => colorToHex(isLightMode ? Qt.lighter(c, f) : Qt.darker(c, f))

        return {
            name:                       "Custom Palette",
            primary:                    primaryColor,
            primaryText:                textFor(primaryColor, isLightMode),
            primaryContainer:           dk(primaryColor, 1.2),
            primaryContainerText:       textFor(dk(primaryColor, 1.2), isLightMode),
            secondary:                  dk(primaryColor, 1.4),
            secondaryText:              textFor(dk(primaryColor, 1.4), isLightMode),
            secondaryContainer:         dk(primaryColor, 1.6),
            secondaryContainerText:     textFor(dk(primaryColor, 1.6), isLightMode),
            tertiary:                   dk(primaryColor, 1.8),
            tertiaryText:               textFor(dk(primaryColor, 1.8), isLightMode),
            tertiaryContainer:          dk(primaryColor, 2.0),
            tertiaryContainerText:      textFor(dk(primaryColor, 2.0), isLightMode),
            surface:                    lk(primaryColor, 3.0),
            surfaceText:                textFor(lk(primaryColor, 3.0), isLightMode),
            surfaceVariant:             lk(primaryColor, 2.5),
            surfaceVariantText:         textFor(lk(primaryColor, 2.5), isLightMode),
            surfaceTint:                primaryColor,
            surfaceContainer:           lk(primaryColor, 2.8),
            surfaceContainerText:       textFor(lk(primaryColor, 2.8), isLightMode),
            surfaceContainerHigh:       lk(primaryColor, 2.6),
            surfaceContainerHighText:   textFor(lk(primaryColor, 2.6), isLightMode),
            surfaceContainerHighest:    lk(primaryColor, 2.4),
            surfaceContainerHighestText: textFor(lk(primaryColor, 2.4), isLightMode),
            background:                 lk(primaryColor, 3.2),
            backgroundText:             textFor(lk(primaryColor, 3.2), isLightMode),
            outline:                    dk(primaryColor, 1.5),
            outlineVariant:             dk(primaryColor, 2.2),
            error:                      isLightMode ? "#B3261E" : "#F2B8B5",
            errorText:                  isLightMode ? "#ffffff"  : "#000000",
            errorContainer:             isLightMode ? "#FDEAEA"  : "#8C1D18",
            errorContainerText:         textFor(isLightMode ? "#FDEAEA" : "#8C1D18", isLightMode),
            warning:                    isLightMode ? "#F57C00"  : "#FFB74D",
            warningText:                isLightMode ? "#ffffff"  : "#000000",
            warningContainer:           isLightMode ? "#FFF3E0"  : "#E65100",
            warningContainerText:       textFor(isLightMode ? "#FFF3E0" : "#E65100", isLightMode),
            info:                       isLightMode ? "#1976D2"  : "#64B5F6",
            infoText:                   isLightMode ? "#ffffff"  : "#000000",
            infoContainer:              isLightMode ? "#E3F2FD"  : "#0D47A1",
            infoContainerText:          textFor(isLightMode ? "#E3F2FD" : "#0D47A1", isLightMode),
            success:                    isLightMode ? "#2E7D32"  : "#81C784",
            successText:                isLightMode ? "#ffffff"  : "#000000",
            successContainer:           isLightMode ? "#E8F5E8"  : "#1B5E20",
            successContainerText:       textFor(isLightMode ? "#E8F5E8" : "#1B5E20", isLightMode),
            matugen_type:               matugenType,
            onSurface:                  textFor(lk(primaryColor, 3.0), isLightMode),
            onSurfaceVariant:           textFor(lk(primaryColor, 2.5), isLightMode),
            onPrimary:                  textFor(primaryColor, isLightMode),
            onSurface_12:               "rgba(255,255,255,0.12)",
            onSurface_38:               "rgba(255,255,255,0.38)",
            onSurfaceVariant_30:        "rgba(255,255,255,0.30)",
            primaryHover:               dk(primaryColor, 1.1),
            primaryHoverLight:          dk(primaryColor, 1.05),
            primaryPressed:             dk(primaryColor, 1.3),
            primarySelected:            dk(primaryColor, 1.4),
            primaryBackground:          dk(primaryColor, 1.8),
            secondaryHover:             dk(primaryColor, 1.3),
            surfaceHover:               dk(primaryColor, 1.1),
            surfacePressed:             dk(primaryColor, 1.2),
            surfaceSelected:            dk(primaryColor, 1.3),
            surfaceLight:               dk(primaryColor, 1.05),
            surfaceVariantAlpha:        dk(primaryColor, 1.2),
            surfaceTextHover:           isLightMode ? "rgba(0,0,0,0.08)"  : "rgba(255,255,255,0.08)",
            surfaceTextAlpha:           isLightMode ? "rgba(0,0,0,0.3)"   : "rgba(255,255,255,0.3)",
            surfaceTextLight:           isLightMode ? "rgba(0,0,0,0.06)"  : "rgba(255,255,255,0.06)",
            surfaceTextMedium:          isLightMode ? "rgba(0,0,0,0.7)"   : "rgba(255,255,255,0.7)",
            outlineButton:              dk(primaryColor, 1.2),
            outlineLight:               dk(primaryColor, 1.1),
            outlineMedium:              dk(primaryColor, 1.15),
            outlineStrong:              dk(primaryColor, 1.3),
            errorHover:                 colorToHex(isLightMode ? Qt.darker("#B3261E", 1.1) : Qt.lighter("#F2B8B5", 1.1)),
            errorPressed:               colorToHex(isLightMode ? Qt.darker("#B3261E", 1.3) : Qt.lighter("#F2B8B5", 1.3)),
            shadowMedium:               "rgba(0,0,0,0.08)",
            shadowStrong:               "rgba(0,0,0,0.3)"
        }
    }

    // ── Apply selected palette colors to the live theme ───────────────────────

    function applySelectedColors() {
        if (selectedColors.length === 0) {
            seedSelectionFromCurrentTheme()
            if (selectedColors.length === 0) return
        }

        const adjustedSelection = selectedColors.map(c => applyHueAdjustments(c))
        const primaryColor      = adjustedSelection[0] || applyHueAdjustments("#42a5f5")
        const isLightMode       = typeof SessionData !== "undefined" ? SessionData.isLightMode : false
        const customTheme       = generateThemeFromPrimaryColor(primaryColor, "scheme-custom", isLightMode)

        // Persist logo color
        if (typeof SettingsData !== "undefined") {
            const hex = primaryColor.replace("#", "")
            SettingsData.launcherLogoRed   = parseInt(hex.substr(0, 2), 16) / 255
            SettingsData.launcherLogoGreen = parseInt(hex.substr(2, 2), 16) / 255
            SettingsData.launcherLogoBlue  = parseInt(hex.substr(4, 2), 16) / 255
            if (SettingsData.osLogoAutoSync) {
                SettingsData.osLogoColorOverride = primaryColor
            }
            SettingsData.saveSettings()
        }

        const normalizedCustomTheme = normalizeThemeData(customTheme)
        root.customThemeData  = normalizedCustomTheme
        root.customThemeReady = true

        if (typeof Theme !== "undefined") {
            if (Theme.currentTheme === Theme.dynamic && root.matugenJsonData?.colors) {
                // Re-normalise raw matugen colors into { colors: { name: { dark, light } } }
                const rawColors            = root.matugenJsonData.colors
                const normalizedMatugenColors = { colors: {} }
                const modes = ["dark", "light", "default"]

                Object.keys(rawColors).forEach(colorName => {
                    const colorData = rawColors[colorName]
                    if (colorData && typeof colorData === "object") {
                        const converted = {}
                        modes.forEach(m => {
                            if (colorData[m]?.color)
                                converted[m] = colorData[m].color
                        })
                        if (Object.keys(converted).length > 0)
                            normalizedMatugenColors.colors[colorName] = converted
                    }
                })
                Theme.matugenColors = normalizedMatugenColors
            }

            if (Theme.currentTheme !== Theme.dynamic) {
                Theme.switchTheme("custom", true, false)
                Theme.loadCustomTheme(normalizedCustomTheme)
            }

            Theme.generateSystemThemesFromCurrentTheme()
            Theme.colorUpdateTrigger++

            if (typeof CompositorService !== "undefined")
                CompositorService.applyBorderColors(0, 1.0)
        }

        customThemeCreated(customTheme)
    }

    // ── Extract palette colors from matugen JSON ──────────────────────────────

    function extractColorsFromMatugen(jsonData) {
        const colors   = []
        const toHex    = c => {
            if (typeof c === "string") return c
            const r = Math.round((c.r || 0) * 255)
            const g = Math.round((c.g || 0) * 255)
            const b = Math.round((c.b || 0) * 255)
            return "#" + [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("")
        }
        const addColor = c => {
            const hex = toHex(c)
            if (hex && typeof hex === "string" && hex.startsWith("#"))
                colors.push(hex)
        }

        const isLightMode   = typeof SessionData !== "undefined" ? SessionData.isLightMode : false
        const currentMode   = isLightMode ? "light" : "dark"

        if (!jsonData.colors) {
            console.error("ColorPaletteService: No 'colors' key in matugen JSON")
            return []
        }

        const schemeData = jsonData.colors

        const colorKeys = [
            "primary", "secondary", "tertiary", "surface", "surface_variant",
            "outline", "surface_container", "surface_container_high",
            "surface_container_low", "surface_container_lowest",
            "surface_container_highest", "primary_container",
            "secondary_container", "tertiary_container",
            "primary_fixed", "primary_fixed_dim",
            "secondary_fixed", "secondary_fixed_dim",
            "tertiary_fixed", "tertiary_fixed_dim",
            "inverse_primary", "inverse_surface", "inverse_on_surface",
            "surface_dim", "surface_bright", "surface_tint"
        ]

        colorKeys.forEach(key => {
            const entry = schemeData[key]
            if (!entry) return
            // matugen 4: entry[mode].color, fallback to entry.default.color
            const colorValue = entry[currentMode]?.color ?? entry.default?.color ?? entry
            addColor(colorValue)
        })

        let unique = [...new Set(colors)]

        // Pad to 16 if we got fewer colors
        if (unique.length < 16) {
            const base        = unique[0] || "#42a5f5"
            const multipliers = [1.05, 1.1, 1.15, 1.2, 1.25, 1.3, 1.35, 1.4]
            for (const m of multipliers) {
                if (unique.length >= 16) break
                addColor(toHex(Qt.lighter(base, m)))
                addColor(toHex(Qt.darker(base, m)))
                unique = [...new Set(colors)]
            }
        }

        return unique.slice(0, 16)
    }

    // ── Persist / load themes ─────────────────────────────────────────────────

    function saveCustomThemeToFile(themeData, customName, customDisplayName) {
        try {
            const normalizedThemeData = normalizeThemeData(themeData)
            if (!normalizedThemeData) return false

            const primaryCandidate = getPrimaryColorFromTheme(normalizedThemeData)

            const baseName = (customName && typeof customName === "string" && customName.trim().length > 0)
                             ? customName.trim()
                             : primaryCandidate.replace("#", "").toLowerCase()

            const safeName = baseName
                             .replace(/[^a-zA-Z0-9_-]/g, "-")
                             .replace(/-+/g, "-")
                             .replace(/^-+|-+$/g, "")
                             .toLowerCase() || "custom-theme"

            const displayName = (customDisplayName && typeof customDisplayName === "string" && customDisplayName.trim().length > 0)
                                ? customDisplayName.trim()
                                : "#" + primaryCandidate.replace("#", "").toUpperCase()

            const essentialThemeData = {
                primary:      primaryCandidate,
                matugen_type: normalizedThemeData.dark?.matugen_type
                           || normalizedThemeData.light?.matugen_type
                           || "scheme-tonal-spot"
            }

            const themeInfo = {
                name:         safeName,
                displayName:  displayName,
                primaryColor: primaryCandidate,
                themeData:    essentialThemeData,
                version:      2
            }

            if (typeof SettingsData !== "undefined") {
                let themes = (SettingsData.savedColorThemes || []).filter(t => t.name !== safeName)
                themes.push(themeInfo)
                SettingsData.setSavedColorThemes(themes)
                SettingsData.setCurrentColorTheme(safeName)
                SettingsData.saveTextColorPreset(safeName)
                updateAvailableThemes()
                root.customThemeData = normalizedThemeData
                return true
            } else {
                Qt.callLater(function () {
                    if (typeof SettingsData !== "undefined")
                        saveCustomThemeToFile(themeData, customName, customDisplayName)
                })
            }
        } catch (e) {
            console.error("ColorPaletteService: saveCustomThemeToFile error:", e)
        }
        return false
    }

    function saveThemeWithName(themeName) {
        const data       = root.customThemeData || (typeof Theme !== "undefined" ? Theme.customThemeData : null)
        const normalized = normalizeThemeData(data)
        if (!normalized) return false
        return saveCustomThemeToFile(normalized, themeName, themeName)
    }

    function loadCustomThemeFromSettings() {
        try {
            if (typeof SettingsData === "undefined") return null

            const currentThemeName = SettingsData.currentColorTheme
            if (!currentThemeName) return null

            const themes = SettingsData.savedColorThemes || []
            const theme  = themes.find(t => t.name === currentThemeName)
            if (!theme) return null

            const normalized = normalizeThemeData(theme.themeData)
            if (!normalized) return null

            if (typeof Theme !== "undefined") {
                root.customThemeData  = normalized
                Theme.customThemeData = normalized

                if (Theme.currentTheme === Theme.dynamic && root.matugenJsonData?.colors) {
                    Theme.matugenColors = { colors: root.matugenJsonData.colors }
                }

                if (Theme.currentTheme !== Theme.dynamic) {
                    Theme.switchTheme("custom", true, false)
                    Theme.loadCustomTheme(normalized)
                }

                Theme.generateSystemThemesFromCurrentTheme()

                if (typeof SettingsData !== "undefined") {
                    const primaryColor = getPrimaryColorFromTheme(normalized)
                    const hex = primaryColor.replace("#", "")
                    SettingsData.launcherLogoRed     = parseInt(hex.substr(0, 2), 16) / 255
                    SettingsData.launcherLogoGreen   = parseInt(hex.substr(2, 2), 16) / 255
                    SettingsData.launcherLogoBlue    = parseInt(hex.substr(4, 2), 16) / 255
                    if (SettingsData.osLogoAutoSync) {
                        SettingsData.osLogoColorOverride = primaryColor
                    }
                    SettingsData.loadTextColorFromTheme(currentThemeName)
                }
            }

            return normalized
        } catch (e) {
            console.error("ColorPaletteService: loadCustomThemeFromSettings error:", e)
        }
        return null
    }

    function updateCurrentThemeTextColors() {
        if (typeof SettingsData === "undefined") return

        const hexR = Math.max(0, Math.min(255, SettingsData.extractedColorTextR)).toString(16).padStart(2, "0")
        const hexG = Math.max(0, Math.min(255, SettingsData.extractedColorTextG)).toString(16).padStart(2, "0")
        const hexB = Math.max(0, Math.min(255, SettingsData.extractedColorTextB)).toString(16).padStart(2, "0")
        const overrideTextColor = "#" + hexR + hexG + hexB

        const textColorProperties = [
            "primaryText", "primaryContainerText", "secondaryText", "secondaryContainerText",
            "tertiaryText", "tertiaryContainerText", "surfaceText", "surfaceVariantText",
            "surfaceContainerText", "surfaceContainerHighText", "surfaceContainerHighestText",
            "backgroundText", "errorContainerText", "warningContainerText", "infoContainerText",
            "successContainerText", "onSurface", "onSurfaceVariant", "onPrimary"
        ]

        const applyOverride = obj => {
            if (!obj) return
            textColorProperties.forEach(p => { if (obj[p] !== undefined) obj[p] = overrideTextColor })
        }

        // Update saved theme data
        if (SettingsData.currentColorTheme) {
            const themes = SettingsData.savedColorThemes || []
            const theme  = themes.find(t => t.name === SettingsData.currentColorTheme)
            if (theme?.themeData) {
                if (theme.themeData.dark || theme.themeData.light) {
                    applyOverride(theme.themeData.dark)
                    applyOverride(theme.themeData.light)
                } else {
                    applyOverride(theme.themeData)
                }
                SettingsData.setSavedColorThemes(themes)
            }
        }

        // Update live Theme
        if (typeof Theme !== "undefined" && Theme.currentTheme === "custom" && Theme.customThemeData) {
            applyOverride(Theme.customThemeData)
            Theme.customThemeData = Theme.customThemeData
            Theme.generateSystemThemesFromCurrentTheme()
            if (Theme.colorUpdateTrigger !== undefined) Theme.colorUpdateTrigger++
        }
    }

    function updateAvailableThemes() {
        try {
            availableThemes = (typeof SettingsData !== "undefined")
                              ? (SettingsData.savedColorThemes || [])
                              : []
        } catch (e) {
            availableThemes = []
        }
        themesUpdated()
    }

    function loadThemeByName(themeName) {
        const theme = availableThemes.find(t => t.name === themeName)
        if (!theme) return false

        const isLightMode = typeof SessionData !== "undefined" ? SessionData.isLightMode : false
        let normalized

        if (theme.version === 2) {
            normalized = normalizeThemeData(
                generateThemeFromPrimaryColor(theme.themeData.primary, theme.themeData.matugen_type, isLightMode)
            )
        } else {
            normalized = normalizeThemeData(theme.themeData)
        }
        if (!normalized) return false

        if (typeof SettingsData !== "undefined") {
            SettingsData.setCurrentColorTheme(themeName)
            SettingsData.loadTextColorFromTheme(themeName)
        }

        if (typeof Theme !== "undefined") {
            root.customThemeData  = normalized
            Theme.customThemeData = normalized

            if (Theme.currentTheme === Theme.dynamic && root.matugenJsonData?.colors)
                Theme.matugenColors = { colors: root.matugenJsonData.colors }

            if (Theme.currentTheme !== Theme.dynamic) {
                Theme.switchTheme("custom", true, false)
                Theme.loadCustomTheme(normalized)
            }

            Theme.generateSystemThemesFromCurrentTheme()
        }

        if (typeof SettingsData !== "undefined") {
            const primaryColor = theme.themeData.primary
            const hex = primaryColor.replace("#", "")
            SettingsData.launcherLogoRed     = parseInt(hex.substr(0, 2), 16) / 255
            SettingsData.launcherLogoGreen   = parseInt(hex.substr(2, 2), 16) / 255
            SettingsData.launcherLogoBlue    = parseInt(hex.substr(4, 2), 16) / 255
            if (SettingsData.osLogoAutoSync) {
                SettingsData.osLogoColorOverride = primaryColor
            }
            SettingsData.saveSettings()
        }

        return true
    }

    function deleteTheme(themeName) {
        if (typeof SettingsData === "undefined") return false
        try {
            let themes = (SettingsData.savedColorThemes || []).filter(t => t.name !== themeName)
            SettingsData.setSavedColorThemes(themes)
            if (SettingsData.currentColorTheme === themeName)
                SettingsData.setCurrentColorTheme("")
            updateAvailableThemes()
            return true
        } catch (e) {
            console.error("ColorPaletteService: deleteTheme error:", e)
        }
        return false
    }

    // ── Startup timer: wait for SettingsData before loading themes ────────────

    Timer {
        id: initTimer
        interval: 200
        repeat:   true
        running:  true
        onTriggered: {
            if (typeof SettingsData !== "undefined" && SettingsData.savedColorThemes !== undefined) {
                running = false
                root.loadCustomThemeFromSettings()
                root.updateAvailableThemes()
            }
        }
    }

    // ── Component lifecycle ───────────────────────────────────────────────────

    Component.onCompleted: {
        if (typeof SettingsData !== "undefined" && SettingsData.savedColorThemes !== undefined) {
            loadCustomThemeFromSettings()
            updateAvailableThemes()
        }

        startWallpaperWatcher()

        Qt.callLater(function () {
            if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic && Theme.wallpaperPath)
                extractColorsFromWallpaper(Theme.wallpaperPath)
        })

        if (typeof Theme !== "undefined" && Theme.onCurrentThemeChanged) {
            Theme.onCurrentThemeChanged.connect(function () {
                if (Theme.currentTheme === Theme.dynamic && Theme.wallpaperPath)
                    extractColorsFromWallpaper(Theme.wallpaperPath)
            })
        }

        if (typeof SessionData !== "undefined" && typeof SessionData.lightModeChanged !== "undefined") {
            SessionData.lightModeChanged.connect(function () {
                if (typeof Theme !== "undefined" && Theme.wallpaperPath)
                    extractColorsFromWallpaper(Theme.wallpaperPath)
            })
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────────
    // IpcHandler function signatures must NOT use TypeScript-style type
    // annotations — plain JS parameter names only.

    IpcHandler {
        target: "colorpalette"

        function extract(wallpaperPath: string) {
            root.extractColorsFromWallpaper(wallpaperPath)
            return "SUCCESS: Color extraction started"
        }

        function getcolors() {
            return JSON.stringify(root.extractedColors)
        }

        function select(color: string, selected: bool) {
            root.selectColor(color, selected)
            return "SUCCESS: Color selection updated"
        }

        function apply() {
            root.applySelectedColors()
            return "SUCCESS: Selected colors applied to theme"
        }
    }
}