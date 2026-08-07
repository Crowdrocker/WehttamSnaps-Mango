pragma Singleton

pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import "StockThemes.js" as StockThemes

Singleton {
    id: root

    property string currentTheme: "dynamic"
    property string currentThemeCategory: "generic"
    property bool isLightMode: false

    readonly property string dynamic: "dynamic"
    readonly property string custom : "custom"

    readonly property string homeDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string shellDir: Paths.strip(Qt.resolvedUrl(".").toString()).replace("/Common/", "")
    readonly property string wallpaperPath: {
        if (typeof SessionData === "undefined") return ""
        
        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name)
                var wallpaperPath = firstMonitorWallpaper || SessionData.wallpaperPath

                if (wallpaperPath && wallpaperPath.startsWith("we:")) {
                    return stateDir + "/we_screenshots/" + wallpaperPath.substring(3) + ".jpg"
                }

                return wallpaperPath
            }
        }

        var wallpaperPath = SessionData.wallpaperPath
        var screens = Quickshell.screens
        if (screens.length > 0 && wallpaperPath && wallpaperPath.startsWith("we:")) {
            return stateDir + "/we_screenshots/" + wallpaperPath.substring(3) + ".jpg"
        }

        return wallpaperPath
    }
    readonly property string rawWallpaperPath: {
        if (typeof SessionData === "undefined") return ""
        
        if (SessionData.perMonitorWallpaper) {
            var screens = Quickshell.screens
            if (screens.length > 0) {
                var firstMonitorWallpaper = SessionData.getMonitorWallpaper(screens[0].name)
                return firstMonitorWallpaper || SessionData.wallpaperPath
            }
        }

        return SessionData.wallpaperPath
    }

    property bool matugenAvailable: false
    property bool gtkThemingEnabled: typeof SettingsData !== "undefined" ? SettingsData.gtkAvailable : false
    property bool qtThemingEnabled: typeof SettingsData !== "undefined" ? (SettingsData.qt5ctAvailable || SettingsData.qt6ctAvailable) : false
    property var workerRunning: false
    property var matugenColors: ({})
    property bool extractionRequested: false
    property int colorUpdateTrigger: 0
    readonly property real vibranceTrigger: typeof SettingsData !== "undefined" ? SettingsData.colorVibrance : 1.0
    property var customThemeData: null

    readonly property string stateDir: Paths.strip(`${StandardPaths.writableLocation(StandardPaths.CacheLocation)}/darkshell`)
    // Keep matugen worker state alongside QS config, so all generators share one cache/key.
    readonly property string matugenStateDir: Paths.strip(`${Quickshell.shellDir}/.state/matugen-state`)

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        matugenCheck.running = true
        if (typeof SessionData !== "undefined")
            SessionData.isLightModeChanged.connect(root.onLightModeChanged)
        
        // Initialize ColorPaletteService for wallpaper watching
        if (typeof ColorPaletteService !== "undefined") {
            ColorPaletteService.initializeIfNeeded()
        }
        
        if (typeof SettingsData !== "undefined" && SettingsData.currentThemeName) {
            switchTheme(SettingsData.currentThemeName, false)
        }
    }

    function getMatugenColor(path, fallback) {
        colorUpdateTrigger
        const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
        
        if (!matugenColors || !matugenColors.colors) {
            return fallback
        }
        
        const colorName = path
        if (matugenColors.colors[colorName] && matugenColors.colors[colorName][colorMode]) {
            const color = matugenColors.colors[colorName][colorMode]
            return color
        }
        
        // Try both dark and light modes as fallback
        if (matugenColors.colors[colorName]) {
            const keys = Object.keys(matugenColors.colors[colorName])
            if (keys.length > 0) {
                const color = matugenColors.colors[colorName][keys[0]]
                return color
            }
        }
        
        return fallback
    }

    readonly property var currentThemeData: {
        colorUpdateTrigger  // Ensure reactivity when colors change
        if (currentTheme === "custom") {
            return customThemeData || StockThemes.getThemeByName("blue", isLightMode)
        } else if (currentTheme === dynamic) {
            return {
                "primary": getMatugenColor("primary", "#42a5f5"),
                "primaryText": getMatugenColor("on_primary", "#ffffff"),
                "primaryContainer": getMatugenColor("primary_container", "#1976d2"),
                "secondary": getMatugenColor("secondary", "#8ab4f8"),
                "surface": getMatugenColor("surface", "#1a1c1e"),
                "surfaceText": getMatugenColor("on_background", "#e3e8ef"),
                "surfaceVariant": getMatugenColor("surface_variant", "#44464f"),
                "surfaceVariantText": getMatugenColor("on_surface_variant", "#c4c7c5"),
                "surfaceTint": getMatugenColor("surface_tint", "#8ab4f8"),
                "background": getMatugenColor("background", "#1a1c1e"),
                "backgroundText": getMatugenColor("on_background", "#e3e8ef"),
                "outline": getMatugenColor("outline", "#8e918f"),
                "surfaceContainer": getMatugenColor("surface_container", "#1e2023"),
                "surfaceContainerHigh": getMatugenColor("surface_container_high", "#292b2f"),
                "error": "#F2B8B5",
                "warning": "#FF9800",
                "info": "#2196F3",
                "success": "#4CAF50"
            }
        } else {
            return StockThemes.getThemeByName(currentTheme, isLightMode)
        }
    }

    property color primary: {
        vibranceTrigger; applyVibrance(currentThemeData.primary)
    }
    property color primaryText: {
        vibranceTrigger; applyVibrance(currentThemeData.primaryText)
    }
    property color primaryContainer: {
        vibranceTrigger; applyVibrance(currentThemeData.primaryContainer)
    }
    property color secondary: {
        vibranceTrigger; applyVibrance(currentThemeData.secondary)
    }
    property color surface: {
        vibranceTrigger; applyVibrance(currentThemeData.surface)
    }
    property color surfaceText: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceText)
    }
    property color surfaceVariant: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceVariant)
    }
    property color surfaceVariantText: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceVariantText)
    }
    property color surfaceTint: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceTint)
    }
    property color background: {
        vibranceTrigger; applyVibrance(currentThemeData.background)
    }
    property color backgroundText: {
        vibranceTrigger; applyVibrance(currentThemeData.backgroundText)
    }
    property color outline: {
        vibranceTrigger; applyVibrance(currentThemeData.outline)
    }
    property color outlineVariant: currentThemeData.outlineVariant ? (function() { vibranceTrigger; return applyVibrance(currentThemeData.outlineVariant) })() : Qt.rgba(outline.r, outline.g, outline.b, 0.6)
    property color surfaceContainer: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceContainer)
    }
    property color surfaceContainerHigh: {
        vibranceTrigger; applyVibrance(currentThemeData.surfaceContainerHigh)
    }

    property color onSurface: surfaceText
    property color onSurfaceVariant: surfaceVariantText
    property color onPrimary: primaryText
    property color onSurface_12: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.12)
    property color onSurface_38: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.38)
    property color onSurfaceVariant_30: Qt.rgba(onSurfaceVariant.r, onSurfaceVariant.g, onSurfaceVariant.b, 0.30)

    property color error: {
        vibranceTrigger; applyVibrance(currentThemeData.error || "#F2B8B5")
    }
    property color warning: {
        vibranceTrigger; applyVibrance(currentThemeData.warning || "#FF9800")
    }
    property color info: {
        vibranceTrigger; applyVibrance(currentThemeData.info || "#2196F3")
    }
    property color tempWarning: {
        vibranceTrigger; applyVibrance("#ff9933")
    }
    property color tempDanger: {
        vibranceTrigger; applyVibrance("#ff5555")
    }
    property color success: {
        vibranceTrigger; applyVibrance(currentThemeData.success || "#4CAF50")
    }

    property color primaryHover: Qt.rgba(primary.r, primary.g, primary.b, 0.12)
    property color primaryHoverLight: Qt.rgba(primary.r, primary.g, primary.b, 0.08)
    property color primaryPressed: Qt.rgba(primary.r, primary.g, primary.b, 0.16)
    property color primarySelected: Qt.rgba(primary.r, primary.g, primary.b, 0.3)
    property color primaryBackground: Qt.rgba(primary.r, primary.g, primary.b, 0.04)

    property color secondaryHover: Qt.rgba(secondary.r, secondary.g, secondary.b, 0.08)

    property color surfaceHover: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.08)
    property color surfacePressed: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.12)
    property color surfaceSelected: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.15)
    property color surfaceLight: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.1)
    property color surfaceVariantAlpha: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.2)
    property color surfaceTextHover: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.08)
    property color surfaceTextAlpha: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.3)
    property color surfaceTextLight: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.06)
    property color surfaceTextMedium: Qt.rgba(surfaceText.r, surfaceText.g, surfaceText.b, 0.7)

    property color outlineButton: Qt.rgba(outline.r, outline.g, outline.b, 0.5)
    property color outlineLight: Qt.rgba(outline.r, outline.g, outline.b, 0.05)
    property color outlineMedium: Qt.rgba(outline.r, outline.g, outline.b, 0.08)
    property color outlineStrong: Qt.rgba(outline.r, outline.g, outline.b, 0.12)

    property color errorHover: Qt.rgba(error.r, error.g, error.b, 0.12)
    property color errorPressed: Qt.rgba(error.r, error.g, error.b, 0.16)

    property color shadowNone: Qt.rgba(0, 0, 0, 0)
    property color shadowLight: Qt.rgba(0, 0, 0, 0.04)
    property color shadowMedium: Qt.rgba(0, 0, 0, 0.08)
    property color shadowStrong: Qt.rgba(0, 0, 0, 0.12)

    property int shorterDuration: 100
    property int shortDuration: 150
    property int mediumDuration: 300
    property int longDuration: 500
    property int extraLongDuration: 1000
    property int standardEasing: Easing.OutCubic
    property int emphasizedEasing: Easing.OutQuart

    property real cornerRadius: typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12
    property real widgetRadius: typeof SettingsData !== "undefined" ? SettingsData.widgetRadius : 12
    // Back-compat helpers (older configs reference these)
    readonly property real cornerRadiusSmall: Math.max(2, cornerRadius * 0.5)

    readonly property real _baseSpacingXXS: 2
    readonly property real _baseSpacingXS: 4
    readonly property real _baseSpacingS: 6
    readonly property real _baseSpacingM: 10
    readonly property real _baseSpacingL: 16
    readonly property real _baseSpacingXL: 26
    readonly property real _baseSpacingXXL: 42

    property real spacingXXS: _baseSpacingXXS * getControlScaleFactor()
    property real spacingXS: _baseSpacingXS * getControlScaleFactor()
    property real spacingS: _baseSpacingS * getControlScaleFactor()
    property real spacingM: _baseSpacingM * getControlScaleFactor()
    property real spacingL: _baseSpacingL * getControlScaleFactor()
    property real spacingXL: _baseSpacingXL * getControlScaleFactor()
    property real spacingXXL: _baseSpacingXXL * getControlScaleFactor()
    property real fontScale: (typeof SettingsData !== "undefined" ? SettingsData.fontScale : 1.0)
    
    property real fontSizeXXS: Math.max(1, Math.round((fontScale || 1.0) * 8))
    // Clamp minimums so common patterns like `fontSizeSmall - 1` never hit 0.
    property real fontSizeXS: Math.max(2, Math.round((fontScale || 1.0) * 10))
    // Back-compat alias: many UIs use fontSizeXSmall
    readonly property real fontSizeXSmall: fontSizeXS
    property real fontSizeSmall: Math.max(2, Math.round((fontScale || 1.0) * 12))
    property real fontSizeMedium: Math.max(1, Math.round((fontScale || 1.0) * 14))
    property real fontSizeLarge: Math.max(1, Math.round((fontScale || 1.0) * 16))
    property real fontSizeXLarge: Math.max(1, Math.round((fontScale || 1.0) * 20))
    property real fontSizeXXL: Math.max(1, Math.round((fontScale || 1.0) * 24))
    property real fontSizeXXXL: Math.max(1, Math.round((fontScale || 1.0) * 32))

    readonly property real _baseBarHeight: 48
    readonly property real _baseIconSize: 24
    readonly property real _baseIconSizeSmall: 16
    readonly property real _baseIconSizeLarge: 32

    property real barHeight: _baseBarHeight * getWindowScaleFactor()
    property real iconSize: _baseIconSize * getIconScaleFactor()
    property real iconSizeSmall: _baseIconSizeSmall * getIconScaleFactor()
    property real iconSizeLarge: _baseIconSizeLarge * getIconScaleFactor()

    readonly property real _baseButtonHeightSmall: 32
    readonly property real _baseButtonHeightMedium: 40
    readonly property real _baseButtonHeightLarge: 48

    property real buttonHeightSmall: _baseButtonHeightSmall * getControlScaleFactor()
    property real buttonHeightMedium: _baseButtonHeightMedium * getControlScaleFactor()
    property real buttonHeightLarge: _baseButtonHeightLarge * getControlScaleFactor()
    property real buttonHeight: buttonHeightMedium

    readonly property real _baseInputHeightSmall: 36
    readonly property real _baseInputHeightMedium: 44
    readonly property real _baseInputHeightLarge: 52

    property real inputHeightSmall: _baseInputHeightSmall * getControlScaleFactor()
    property real inputHeightMedium: _baseInputHeightMedium * getControlScaleFactor()
    property real inputHeightLarge: _baseInputHeightLarge * getControlScaleFactor()
    property real inputHeight: inputHeightMedium

    function getScaleFactor() {
        var base = 1.0
        if (typeof Screen !== 'undefined') {
            const screenHeight = Screen.height
            // 1440p and below: no automatic scaling (scale = 1.0)
            // Only 4K+ gets automatic upscaling
            if (screenHeight >= 2160) base = 1.2
            else base = 1.0
        }

        return base
    }

    function getSettingsUiScale() {
        var uiScale = 1.0
        if (typeof SettingsData !== "undefined" && SettingsData.settingsUiScale !== undefined) {
            uiScale = SettingsData.settingsUiScale
        }
        return Math.max(0.7, Math.min(1.5, uiScale))
    }

    function getControlScaleFactor() {
        var scale = getScaleFactor() * getSettingsUiScale()
        if (typeof SettingsData !== "undefined" && SettingsData.settingsUiAdvancedScaling && SettingsData.settingsUiControlScale !== undefined) {
            scale *= SettingsData.settingsUiControlScale
        }
        return scale
    }

    function getIconScaleFactor() {
        var scale = getScaleFactor() * getSettingsUiScale()
        if (typeof SettingsData !== "undefined" && SettingsData.settingsUiAdvancedScaling && SettingsData.settingsUiIconScale !== undefined) {
            scale *= SettingsData.settingsUiIconScale
        }
        return scale
    }

    function getWindowScaleFactor() {
        var scale = getScaleFactor() * getSettingsUiScale()
        if (typeof SettingsData !== "undefined" && SettingsData.settingsUiAdvancedScaling && SettingsData.settingsUiWindowScale !== undefined) {
            scale *= SettingsData.settingsUiWindowScale
        }
        return scale
    }
    
    function scaledSize(baseSize) {
        return baseSize * getScaleFactor()
    }
    
    function scaledHeight(baseHeight) {
        return Math.max(Math.round(baseHeight * getScaleFactor()), 1)
    }
    
    function scaledWidth(baseWidth) {
        return Math.max(Math.round(baseWidth * getScaleFactor()), 1)
    }

    property real panelTransparency: 0.85
    property real widgetTransparency: typeof SettingsData !== "undefined" && SettingsData.topBarWidgetTransparency !== undefined ? SettingsData.topBarWidgetTransparency : 1.0
    property real popupTransparency: typeof SettingsData !== "undefined" && SettingsData.popupTransparency !== undefined ? SettingsData.popupTransparency : 0.92

    function screenTransition() {
        CompositorService.isNiri && NiriService.doScreenTransition()
    }

    function switchTheme(themeName, savePrefs = true, enableTransition = true) {
        if (enableTransition) {
            screenTransition()
        }
        if (themeName === dynamic) {
            currentTheme = dynamic
            currentThemeCategory = dynamic
            extractColors()
        } else if (themeName === custom) {
            currentTheme = custom
            currentThemeCategory = custom
            if (typeof SettingsData !== "undefined" && SettingsData.customThemeFile) {
                loadCustomThemeFromFile(SettingsData.customThemeFile)
            }
        } else {
            currentTheme = themeName
            if (StockThemes.isCatppuccinVariant(themeName)) {
                currentThemeCategory = "catppuccin"
            } else {
                currentThemeCategory = "generic"
            }
        }
        if (savePrefs && typeof SettingsData !== "undefined")
            SettingsData.setTheme(currentTheme)

        generateSystemThemesFromCurrentTheme()
    }

    function setLightMode(light, savePrefs = true) {
        screenTransition()
        isLightMode = light
        if (savePrefs && typeof SessionData !== "undefined")
            SessionData.setLightMode(isLightMode)
        PortalService.setLightMode(isLightMode)
        generateSystemThemesFromCurrentTheme()
    }

    function toggleLightMode(savePrefs = true) {
        setLightMode(!isLightMode, savePrefs)
    }

    function forceGenerateSystemThemes() {
        screenTransition()
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showWarning("matugen not available - cannot generate system themes")
            }
            return
        }
        generateSystemThemesFromCurrentTheme()
    }

    function getAvailableThemes() {
        return StockThemes.getAllThemeNames()
    }

    function getThemeDisplayName(themeName) {
        const themeData = StockThemes.getThemeByName(themeName, isLightMode)
        return themeData.name
    }

    function getThemeColors(themeName) {
        if (themeName === "custom" && customThemeData) {
            return customThemeData
        }
        return StockThemes.getThemeByName(themeName, isLightMode)
    }

    function switchThemeCategory(category, defaultTheme) {
        currentThemeCategory = category
        switchTheme(defaultTheme, true, false)
    }

    function getCatppuccinColor(variantName) {
        const catColors = {
            "cat-rosewater": "#f5e0dc", "cat-flamingo": "#f2cdcd", "cat-pink": "#f5c2e7", "cat-mauve": "#cba6f7",
            "cat-red": "#f38ba8", "cat-maroon": "#eba0ac", "cat-peach": "#fab387", "cat-yellow": "#f9e2af",
            "cat-green": "#a6e3a1", "cat-teal": "#94e2d5", "cat-sky": "#89dceb", "cat-sapphire": "#74c7ec",
            "cat-blue": "#89b4fa", "cat-lavender": "#b4befe"
        }
        return catColors[variantName] || "#cba6f7"
    }

    function getCatppuccinVariantName(variantName) {
        const catNames = {
            "cat-rosewater": "Rosewater", "cat-flamingo": "Flamingo", "cat-pink": "Pink", "cat-mauve": "Mauve",
            "cat-red": "Red", "cat-maroon": "Maroon", "cat-peach": "Peach", "cat-yellow": "Yellow",
            "cat-green": "Green", "cat-teal": "Teal", "cat-sky": "Sky", "cat-sapphire": "Sapphire",
            "cat-blue": "Blue", "cat-lavender": "Lavender"
        }
        return catNames[variantName] || "Unknown"
    }

    function loadCustomTheme(themeData) {
        screenTransition()
        if (themeData.dark || themeData.light) {
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const selectedTheme = themeData[colorMode] || themeData.dark || themeData.light
            customThemeData = selectedTheme
        } else {
            customThemeData = themeData
        }

        generateSystemThemesFromCurrentTheme()
    }

    function loadCustomThemeFromFile(filePath) {
        customThemeFileView.path = filePath
    }

    property alias availableThemeNames: root._availableThemeNames
    readonly property var _availableThemeNames: StockThemes.getAllThemeNames()
    property string currentThemeName: currentTheme

    function popupBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency)
    }

    function contentBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, popupTransparency)
    }

    function panelBackground() {
        return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, panelTransparency)
    }

    property real notepadTransparency: SettingsData.notepadTransparencyOverride >= 0 ? SettingsData.notepadTransparencyOverride : popupTransparency

    property var widgetBaseBackgroundColor: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sc"
        switch (colorMode) {
            case "s":
                return surface
            case "sc":
            case "sth":
            default:
                return surfaceContainer
            case "sch":
                return surfaceContainerHigh
        }
    }

    property var widgetBaseHoverColor: {
        const baseColor = widgetBaseBackgroundColor
        const factor = 1.2
        return isLightMode ? Qt.darker(baseColor, factor) : Qt.lighter(baseColor, factor)
    }

    property var widgetBackground: {
        const colorMode = typeof SettingsData !== "undefined" ? SettingsData.widgetBackgroundColor : "sc"
        switch (colorMode) {
            case "s":
                return Qt.rgba(surface.r, surface.g, surface.b, widgetTransparency)
            case "sc":
            case "sth":
            default:
                return Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, widgetTransparency)
            case "sch":
                return Qt.rgba(surfaceContainerHigh.r, surfaceContainerHigh.g, surfaceContainerHigh.b, widgetTransparency)
        }
    }

    function getPopupBackgroundAlpha() {
        return popupTransparency
    }

    function getContentBackgroundAlpha() {
        return popupTransparency
    }

    function isColorDark(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5
    }

    function _parseColor(color) {
        if (typeof color !== "string") {
            return color
        }

        const value = color.trim()
        if (value.length === 0) return color

        const lower = value.toLowerCase()
        if (lower === "transparent") {
            return Qt.rgba(0, 0, 0, 0)
        }

        const hexMatch = lower.match(/^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/)
        if (hexMatch) {
            const hex = hexMatch[1]
            let r, g, b, a
            if (hex.length === 3) {
                r = parseInt(hex[0] + hex[0], 16)
                g = parseInt(hex[1] + hex[1], 16)
                b = parseInt(hex[2] + hex[2], 16)
                a = 255
            } else if (hex.length === 4) {
                r = parseInt(hex[0] + hex[0], 16)
                g = parseInt(hex[1] + hex[1], 16)
                b = parseInt(hex[2] + hex[2], 16)
                a = parseInt(hex[3] + hex[3], 16)
            } else if (hex.length === 6) {
                r = parseInt(hex.substring(0, 2), 16)
                g = parseInt(hex.substring(2, 4), 16)
                b = parseInt(hex.substring(4, 6), 16)
                a = 255
            } else {
                r = parseInt(hex.substring(0, 2), 16)
                g = parseInt(hex.substring(2, 4), 16)
                b = parseInt(hex.substring(4, 6), 16)
                a = parseInt(hex.substring(6, 8), 16)
            }

            return Qt.rgba(r / 255, g / 255, b / 255, a / 255)
        }

        const rgbMatch = lower.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)$/)
        if (rgbMatch) {
            const r = Math.max(0, Math.min(255, parseFloat(rgbMatch[1])))
            const g = Math.max(0, Math.min(255, parseFloat(rgbMatch[2])))
            const b = Math.max(0, Math.min(255, parseFloat(rgbMatch[3])))
            const a = rgbMatch[4] !== undefined ? Math.max(0, Math.min(1, parseFloat(rgbMatch[4]))) : 1
            return Qt.rgba(r / 255, g / 255, b / 255, a)
        }

        return color
    }

    function applyVibrance(color) {
        const parsedColor = _parseColor(color)
        
        if (typeof parsedColor === 'string') {
            return parsedColor
        }
        
        const vibrance = typeof SettingsData !== "undefined" ? SettingsData.colorVibrance : 1.0
        
        if (vibrance >= 0.999) {
            return parsedColor
        }
        
        const gray = 0.299 * parsedColor.r + 0.587 * parsedColor.g + 0.114 * parsedColor.b
        
        return Qt.rgba(
            gray + (parsedColor.r - gray) * vibrance,
            gray + (parsedColor.g - gray) * vibrance,
            gray + (parsedColor.b - gray) * vibrance,
            parsedColor.a
        )
    }

    function getBatteryIcon(level, isCharging, batteryAvailable) {
        if (!batteryAvailable)
            return _getBatteryPowerProfileIcon()

        if (isCharging) {
            if (level >= 90)
                return "battery_charging_full"
            if (level >= 80)
                return "battery_charging_90"
            if (level >= 60)
                return "battery_charging_80"
            if (level >= 50)
                return "battery_charging_60"
            if (level >= 30)
                return "battery_charging_50"
            if (level >= 20)
                return "battery_charging_30"
            return "battery_charging_20"
        } else {
            if (level >= 95)
                return "battery_full"
            if (level >= 85)
                return "battery_6_bar"
            if (level >= 70)
                return "battery_5_bar"
            if (level >= 55)
                return "battery_4_bar"
            if (level >= 40)
                return "battery_3_bar"
            if (level >= 25)
                return "battery_2_bar"
            if (level >= 10)
                return "battery_1_bar"
            return "battery_alert"
        }
    }

    function _getBatteryPowerProfileIcon() {
        if (typeof PowerProfiles === "undefined")
            return "balance"

        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "energy_savings_leaf"
        case PowerProfile.Performance:
            return "rocket_launch"
        default:
            return "balance"
        }
    }

    function getPowerProfileIcon(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "battery_saver"
        case PowerProfile.Balanced:
            return "battery_std"
        case PowerProfile.Performance:
            return "flash_on"
        default:
            return "settings"
        }
    }

    function getPowerProfileLabel(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Power Saver"
        case PowerProfile.Balanced:
            return "Balanced"
        case PowerProfile.Performance:
            return "Performance"
        default:
            return profile.charAt(0).toUpperCase() + profile.slice(1)
        }
    }

    function getPowerProfileDescription(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver:
            return "Extend battery life"
        case PowerProfile.Balanced:
            return "Balance power and performance"
        case PowerProfile.Performance:
            return "Prioritize performance"
        default:
            return "Custom power profile"
        }
    }

    readonly property var availableMatugenSchemes: [{
            "value": "scheme-tonal-spot",
            "label": "Tonal Spot",
            "description": "Balanced palette with focused accents (default)."
        }, {
            "value": "scheme-vibrant",
            "label": "Vibrant",
            "description": "Lively palette with saturated accents."
        }, {
            "value": "scheme-content",
            "label": "Content",
            "description": "Derives colors that closely match the underlying image."
        }, {
            "value": "scheme-expressive",
            "label": "Expressive",
            "description": "Vibrant palette with playful saturation."
        }, {
            "value": "scheme-fidelity",
            "label": "Fidelity",
            "description": "High-fidelity palette that preserves source hues."
        }, {
            "value": "scheme-fruit-salad",
            "label": "Fruit Salad",
            "description": "Colorful mix of bright contrasting accents."
        }, {
            "value": "scheme-monochrome",
            "label": "Monochrome",
            "description": "Minimal palette built around a single hue."
        }, {
            "value": "scheme-neutral",
            "label": "Neutral",
            "description": "Muted palette with subdued, calming tones."
        }, {
            "value": "scheme-rainbow",
            "label": "Rainbow",
            "description": "Diverse palette spanning the full spectrum."
        }]

    function getMatugenScheme(value) {
        const schemes = availableMatugenSchemes
        for (var i = 0; i < schemes.length; i++) {
            if (schemes[i].value === value)
                return schemes[i]
        }
        return schemes[0]
    }

    function extractColors() {
        extractionRequested = true
        
        // Check if wallpaper path is available before attempting to extract colors
        if (!wallpaperPath) {
            if (typeof ToastService !== "undefined") {
                ToastService.wallpaperErrorStatus = "error"
                ToastService.showError("No wallpaper set - please set a wallpaper first for dynamic theming")
            }
            return
        }
        
        if (matugenAvailable)
            if (rawWallpaperPath.startsWith("we:")) {
                fileCheckerTimer.start()
            } else {
                fileChecker.running = true
            }
        else
            matugenCheck.running = true
    }

    function onLightModeChanged() {
        if (matugenColors && Object.keys(matugenColors).length > 0) {
            colorUpdateTrigger++
        }

        if (currentTheme === "custom" && customThemeFileView.path) {
            customThemeFileView.reload()
        }
    }

    function setDesiredTheme(kind, value, isLight, iconTheme, matugenType) {
        if (!matugenAvailable) {
            return
        }

        if (typeof NiriService !== "undefined" && CompositorService.isNiri) {
            NiriService.suppressNextToast()
        }

        const desired = {
            "kind": kind,
            "value": value,
            "mode": isLight ? "light" : "dark",
            "iconTheme": iconTheme || "System Default",
            "matugenType": matugenType || "scheme-tonal-spot"
        }

        const json = JSON.stringify(desired)
        const desiredPath = matugenStateDir + "/matugen.desired.json"

        Quickshell.execDetached(["sh", "-c", `mkdir -p '${matugenStateDir}' && cat > '${desiredPath}' << 'EOF'\n${json}\nEOF`])
        workerRunning = true
        if (rawWallpaperPath.startsWith("we:")) {
            systemThemeGenerator.command = [
                "sh", "-c",
                `sleep 1 && ${shellDir}/scripts/matugen-worker.sh '${matugenStateDir}' '${shellDir}' --run`
            ]
        } else {
            systemThemeGenerator.command = [shellDir + "/scripts/matugen-worker.sh", matugenStateDir, shellDir, "--run"]
        }
        systemThemeGenerator.running = true
    }

    function generateSystemThemesFromCurrentTheme() {
        if (!matugenAvailable)
            return

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
        const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"

        const matugenScheme = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"

        if (currentTheme === dynamic) {
            if (!wallpaperPath) {
                return
            }
            if (wallpaperPath.startsWith("#")) {
                setDesiredTheme("hex", wallpaperPath, isLight, iconTheme, matugenScheme)
            } else {
                setDesiredTheme("image", wallpaperPath, isLight, iconTheme, matugenScheme)
            }
        } else {
            let primaryColor
            let matugenType
            if (currentTheme === "custom") {
                if (!customThemeData || !customThemeData.primary) {
                    return
                }
                primaryColor = customThemeData.primary
                matugenType = customThemeData.matugen_type
            } else {
                primaryColor = currentThemeData.primary
                matugenType = currentThemeData.matugen_type
            }

            if (!primaryColor) {
                return
            }
            setDesiredTheme("hex", primaryColor, isLight, iconTheme, matugenType)
        }
    }

    function applyGtkColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available - cannot apply GTK colors")
            }
            return
        }

        const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "true" : "false"
        gtkApplier.command = [shellDir + "/scripts/gtk.sh", configDir, isLight, shellDir]
        gtkApplier.running = true
    }

    function applyQtColors() {
        if (!matugenAvailable) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("matugen not available - cannot apply Qt colors")
            }
            return
        }

        qtApplier.command = [shellDir + "/scripts/qt.sh", configDir]
        qtApplier.running = true
    }

    // Normalize matugen 4 colors format to simpler format
    // matugen 4 returns: { colors: { primary: { dark: { color: "#hex" }, light: { color: "#hex" } } } }
    // We convert to: { colors: { primary: { dark: "#hex", light: "#hex" } } }
    function normalizeMatugenColors(colors) {
        if (!colors || !colors.colors) {
            return colors
        }
        
        // Create a shallow copy of the colors object
        const normalized = { colors: {} }
        const colorKeys = Object.keys(colors.colors)
        
        colorKeys.forEach(colorName => {
            const colorData = colors.colors[colorName]
            if (colorData && typeof colorData === 'object') {
                // Check if this is matugen 4 format (has dark/light/default with .color property)
                const modes = ['dark', 'light', 'default']
                let hasNestedFormat = false
                
                modes.forEach(mode => {
                    if (colorData[mode] && colorData[mode].color) {
                        hasNestedFormat = true
                    }
                })
                
                if (hasNestedFormat) {
                    // Convert from nested format to direct hex strings
                    const converted = {}
                    modes.forEach(mode => {
                        if (colorData[mode] && colorData[mode].color) {
                            converted[mode] = colorData[mode].color
                        }
                    })
                    normalized.colors[colorName] = converted
                } else {
                    normalized.colors[colorName] = colorData
                }
            } else {
                normalized.colors[colorName] = colorData
            }
        })
        
        return normalized
    }

    // Apply saturation boost and lightness offset to matugen colors
    function applyColorAdjustments(colors) {
        // First normalize matugen 4 format to simpler format
        colors = normalizeMatugenColors(colors)
        
        const saturationBoost = (typeof SettingsData !== "undefined" && SettingsData.matugenSaturationBoost) ? SettingsData.matugenSaturationBoost : 1.0
        const lightnessOffset = (typeof SettingsData !== "undefined" && SettingsData.matugenLightnessOffset) ? SettingsData.matugenLightnessOffset : 0.0
        
        // If no adjustments needed, return normalized colors
        if (saturationBoost === 1.0 && lightnessOffset === 0.0) {
            return colors
        }
        
        // Helper function to convert hex to HSL
        function hexToHsl(hex) {
            if (!hex || typeof hex !== 'string') return null
            hex = hex.replace('#', '')
            if (hex.length !== 6) return null
            
            const r = parseInt(hex.substr(0, 2), 16) / 255
            const g = parseInt(hex.substr(2, 2), 16) / 255
            const b = parseInt(hex.substr(4, 2), 16) / 255
            
            const max = Math.max(r, g, b)
            const min = Math.min(r, g, b)
            let h, s, l = (max + min) / 2
            
            if (max === min) {
                h = s = 0
            } else {
                const d = max - min
                s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                switch (max) {
                    case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break
                    case g: h = ((b - r) / d + 2) / 6; break
                    case b: h = ((r - g) / d + 4) / 6; break
                }
            }
            return { h: h * 360, s: s * 100, l: l * 100 }
        }
        
        // Helper function to convert HSL to hex
        function hslToHex(h, s, l) {
            h = h / 360
            s = s / 100
            l = l / 100
            
            let r, g, b
            if (s === 0) {
                r = g = b = l
            } else {
                const hue2rgb = (p, q, t) => {
                    if (t < 0) t += 1
                    if (t > 1) t -= 1
                    if (t < 1/6) return p + (q - p) * 6 * t
                    if (t < 1/2) return q
                    if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
                    return p
                }
                const q = l < 0.5 ? l * (1 + s) : l + s - l * s
                const p = 2 * l - q
                r = hue2rgb(p, q, h + 1/3)
                g = hue2rgb(p, q, h)
                b = hue2rgb(p, q, h - 1/3)
            }
            
            const toHex = x => {
                const hex = Math.round(x * 255).toString(16)
                return hex.length === 1 ? '0' + hex : hex
            }
            return '#' + toHex(r) + toHex(g) + toHex(b)
        }
        
        // Process colors if they exist
        if (colors.colors) {
            const modes = ['light', 'dark']
            modes.forEach(mode => {
                if (colors.colors[mode]) {
                    Object.keys(colors.colors[mode]).forEach(colorName => {
                        const hex = colors.colors[mode][colorName]
                        const hsl = hexToHsl(hex)
                        if (hsl) {
                            // Apply saturation boost
                            hsl.s = Math.min(100, Math.max(0, hsl.s * saturationBoost))
                            // Apply lightness offset
                            hsl.l = Math.min(100, Math.max(0, hsl.l + lightnessOffset * 50))
                            colors.colors[mode][colorName] = hslToHex(hsl.h, hsl.s, hsl.l)
                        }
                    })
                }
            })
        }
        
        return colors
    }

    // Re-apply color adjustments to existing matugen colors (for slider changes)
    function reapplyColorAdjustments() {
        if (matugenColors && Object.keys(matugenColors).length > 0) {
            // Deep clone the colors to trigger reactivity
            var colors = JSON.parse(JSON.stringify(matugenColors))
            colors = applyColorAdjustments(colors)
            matugenColors = colors
            colorUpdateTrigger++
            
            // Also update Hyprland border colors if enabled (delayed to allow theme to update first)
            if (typeof SettingsData !== 'undefined' && SettingsData.hyprlandThemingEnabled && 
                typeof CompositorService !== 'undefined' && CompositorService.isHyprland) {
                borderUpdateTimer.start()
            }
            
            // Also update Niri border colors if enabled (delayed to allow theme to update first)
            if (typeof SettingsData !== 'undefined' && SettingsData.niriThemingEnabled && 
                typeof CompositorService !== 'undefined' && CompositorService.isNiri) {
                niriBorderUpdateTimer.start()
            }
        }
    }

    // Timer to delay border update until after theme colors have updated
    Timer {
        id: borderUpdateTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (typeof SettingsData !== 'undefined' && SettingsData.hyprlandThemingEnabled && 
                typeof CompositorService !== 'undefined' && CompositorService.isHyprland) {
                CompositorService.applyBorderColors(SettingsData.hyprlandBorderHue, SettingsData.hyprlandBorderAlpha)
            }
        }
    }

    // Timer to delay Niri border update until after theme colors have updated
    Timer {
        id: niriBorderUpdateTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (typeof SettingsData !== 'undefined' && SettingsData.niriThemingEnabled && 
                typeof CompositorService !== 'undefined' && CompositorService.isNiri) {
                CompositorService.applyNiriBorderColors(SettingsData.niriBorderHue, SettingsData.niriBorderAlpha)
            }
        }
    }

    function extractJsonFromText(text) {
        if (!text)
            return null

        const start = text.search(/[{\[]/)
        if (start === -1)
            return null

        const open = text[start]
        const pairs = {
            "{": '}',
            "[": ']'
        }
        const close = pairs[open]
        if (!close)
            return null

        let inString = false
        let escape = false
        const stack = [open]

        for (var i = start + 1; i < text.length; i++) {
            const ch = text[i]

            if (inString) {
                if (escape) {
                    escape = false
                } else if (ch === '\\') {
                    escape = true
                } else if (ch === '"') {
                    inString = false
                }
                continue
            }

            if (ch === '"') {
                inString = true
                continue
            }
            if (ch === '{' || ch === '[') {
                stack.push(ch)
                continue
            }
            if (ch === '}' || ch === ']') {
                const last = stack.pop()
                if (!last || pairs[last] !== ch) {
                    return null
                }
                if (stack.length === 0) {
                    return text.slice(start, i + 1)
                }
            }
        }
        return null
    }

    Process {
        id: matugenCheck
        command: ["which", "matugen"]
        onExited: code => {
            matugenAvailable = (code === 0)
            if (!matugenAvailable) {
                if (typeof ToastService !== "undefined") {
                    ToastService.wallpaperErrorStatus = "matugen_missing"
                    ToastService.showWarning("matugen not found - dynamic theming disabled")
                }
                return
            }
            if (extractionRequested) {
                if (rawWallpaperPath.startsWith("we:")) {
                    fileCheckerTimer.start()
                } else {
                    fileChecker.running = true
                }
            }

            const isLight = (typeof SessionData !== "undefined" && SessionData.isLightMode)
            const iconTheme = (typeof SettingsData !== "undefined" && SettingsData.iconTheme) ? SettingsData.iconTheme : "System Default"
            const matugenScheme = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"

            if (currentTheme === dynamic) {
                if (wallpaperPath) {
                    Quickshell.execDetached(["rm", "-f", matugenStateDir + "/matugen.key"])
                    if (wallpaperPath.startsWith("#")) {
                        setDesiredTheme("hex", wallpaperPath, isLight, iconTheme, matugenScheme)
                    } else {
                        setDesiredTheme("image", wallpaperPath, isLight, iconTheme, matugenScheme)
                    }
                }
            } else {
                let primaryColor
                let matugenType
                if (currentTheme === "custom") {
                    if (customThemeData && customThemeData.primary) {
                        primaryColor = customThemeData.primary
                        matugenType = customThemeData.matugen_type
                    }
                } else {
                    primaryColor = currentThemeData.primary
                    matugenType = currentThemeData.matugen_type
                }

                if (primaryColor) {
                    Quickshell.execDetached(["rm", "-f", matugenStateDir + "/matugen.key"])
                    setDesiredTheme("hex", primaryColor, isLight, iconTheme, matugenType)
                }
            }
        }
    }

    Process {
        id: fileChecker
        command: ["test", "-r", wallpaperPath]
        onExited: code => {
            if (code === 0) {
                matugenProcess.running = true
            } else if (wallpaperPath.startsWith("#")) {
                colorMatugenProcess.running = true
            }
            // Don't show error here - ColorPaletteService handles color extraction
        }
    }

    Timer {
        id: fileCheckerTimer
        interval: 1000
        repeat: false
        onTriggered: {
            fileChecker.running = true
        }
    }

    Process {
        id: matugenProcess
        command: {
            const scheme = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
            const contrast = (typeof SettingsData !== "undefined" && SettingsData.matugenContrast !== undefined) ? SettingsData.matugenContrast : 0.0
            const resizeFilter = (typeof SettingsData !== "undefined" && SettingsData.matugenResizeFilter) ? SettingsData.matugenResizeFilter : "lanczos3"
            const fallbackColor = (typeof SettingsData !== "undefined" && SettingsData.matugenFallbackColor) ? SettingsData.matugenFallbackColor : ""
            
            var cmd = ["matugen", "--json", "hex", "--type", scheme]
            
            // Add contrast if not default (0.0)
            if (contrast !== 0.0) {
                cmd.push("--contrast", contrast.toString())
            }
            
            // Add resize filter if not default
            if (resizeFilter !== "lanczos3") {
                cmd.push("--resize-filter", resizeFilter)
            }
            
            // Add fallback color if set
            if (fallbackColor !== "") {
                cmd.push("--fallback-color", fallbackColor)
            }
            
            cmd.push("image", wallpaperPath)
            return cmd
        }

        stdout: StdioCollector {
            id: matugenCollector
            onStreamFinished: {
                if (!matugenCollector.text) {
                    // ColorPaletteService handles color extraction - don't show duplicate error
                    return
                }
                const extractedJson = extractJsonFromText(matugenCollector.text)
                if (!extractedJson) {
                    // ColorPaletteService handles color extraction - don't show duplicate error
                    return
                }
                try {
                    var colors = JSON.parse(extractedJson)
                    // Apply saturation boost and lightness offset
                    colors = applyColorAdjustments(colors)
                    root.matugenColors = colors
                    root.colorUpdateTrigger++
                    
                    // Generate system themes for Hyprland, GTK, Qt, etc.
                    generateSystemThemesFromCurrentTheme()
                    
                    // Update Niri border colors if enabled
                    if (typeof SettingsData !== 'undefined' && SettingsData.niriThemingEnabled && 
                        typeof CompositorService !== 'undefined' && CompositorService.isNiri) {
                        niriBorderUpdateTimer.start()
                    }
                    
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError()
                    }
                } catch (e) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Wallpaper processing failed (JSON parse error after extraction)")
                    }
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                // Only show error if ColorPaletteService hasn't already handled it
                // ColorPaletteService handles color extraction for the UI
                // Don't show duplicate errors here
            }
        }
    }

    Process {
        id: colorMatugenProcess
        command: {
            const scheme = (typeof SettingsData !== "undefined" && SettingsData.matugenScheme) ? SettingsData.matugenScheme : "scheme-tonal-spot"
            const contrast = (typeof SettingsData !== "undefined" && SettingsData.matugenContrast !== undefined) ? SettingsData.matugenContrast : 0.0
            const resizeFilter = (typeof SettingsData !== "undefined" && SettingsData.matugenResizeFilter) ? SettingsData.matugenResizeFilter : "lanczos3"
            const fallbackColor = (typeof SettingsData !== "undefined" && SettingsData.matugenFallbackColor) ? SettingsData.matugenFallbackColor : ""
            
            var cmd = ["matugen", "--json", "hex", "--type", scheme]
            
            // Add contrast if not default (0.0)
            if (contrast !== 0.0) {
                cmd.push("--contrast", contrast.toString())
            }
            
            // Add resize filter if not default
            if (resizeFilter !== "lanczos3") {
                cmd.push("--resize-filter", resizeFilter)
            }
            
            // Add fallback color if set
            if (fallbackColor !== "") {
                cmd.push("--fallback-color", fallbackColor)
            }
            
            cmd.push("color", "hex", wallpaperPath)
            return cmd
        }

        stdout: StdioCollector {
            id: colorMatugenCollector
            onStreamFinished: {
                if (!colorMatugenCollector.text) {
                    // ColorPaletteService handles color extraction - don't show duplicate error
                    return
                }
                const extractedJson = extractJsonFromText(colorMatugenCollector.text)
                if (!extractedJson) {
                    // ColorPaletteService handles color extraction - don't show duplicate error
                    return
                }
                try {
                    var colors = JSON.parse(extractedJson)
                    // Apply saturation boost and lightness offset
                    colors = applyColorAdjustments(colors)
                    root.matugenColors = colors
                    root.colorUpdateTrigger++
                    
                    // Generate system themes for Hyprland, GTK, Qt, etc.
                    generateSystemThemesFromCurrentTheme()
                    
                    // Update Niri border colors if enabled
                    if (typeof SettingsData !== 'undefined' && SettingsData.niriThemingEnabled && 
                        typeof CompositorService !== 'undefined' && CompositorService.isNiri) {
                        niriBorderUpdateTimer.start()
                    }
                    
                    if (typeof ToastService !== "undefined") {
                        ToastService.clearWallpaperError()
                    }
                } catch (e) {
                    if (typeof ToastService !== "undefined") {
                        ToastService.wallpaperErrorStatus = "error"
                        ToastService.showError("Color processing failed (JSON parse error after extraction)")
                    }
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                // Only show error if ColorPaletteService hasn't already handled it
                // Don't show duplicate errors
            }
        }
    }

    Process {
        id: ensureStateDir
    }

    Process {
        id: systemThemeGenerator
        running: false

        onExited: exitCode => {
            workerRunning = false

            if (exitCode === 2) {
                // Wallpaper not found - this might be handled by ColorPaletteService
                // Don't show error if ColorPaletteService is working
            } else if (exitCode !== 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Theme worker failed (" + exitCode + ")")
                }
            }
        }
    }

    Process {
        id: gtkApplier
        running: false

        stdout: StdioCollector {
            id: gtkStdout
        }

        stderr: StdioCollector {
            id: gtkStderr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined" && typeof NiriService !== "undefined" && !NiriService.matugenSuppression) {
                    ToastService.showInfo("GTK colors applied successfully")
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply GTK colors: " + gtkStderr.text)
                }
            }
        }
    }

    Process {
        id: qtApplier
        running: false

        stdout: StdioCollector {
            id: qtStdout
        }

        stderr: StdioCollector {
            id: qtStderr
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showInfo("Qt colors applied successfully")
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to apply Qt colors: " + qtStderr.text)
                }
            }
        }
    }

    FileView {
        id: customThemeFileView
        watchChanges: currentTheme === "custom"

        function parseAndLoadTheme() {
            try {
                var themeData = JSON.parse(customThemeFileView.text())
                loadCustomTheme(themeData)
            } catch (e) {
                ToastService.showError("Invalid JSON format: " + e.message)
            }
        }

        onLoaded: {
            parseAndLoadTheme()
        }

        onFileChanged: {
            customThemeFileView.reload()
        }

        onLoadFailed: function (error) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to read theme file: " + error)
            }
        }
    }

    IpcHandler {
        target: "theme"

        function toggle(): string {
            root.toggleLightMode()
            return root.isLightMode ? "light" : "dark"
        }

        function light(): string {
            root.setLightMode(true)
            return "light"
        }

        function dark(): string {
            root.setLightMode(false)
            return "dark"
        }

        function getMode(): string {
            return root.isLightMode ? "light" : "dark"
        }
    }

    function snap(value, dpr) {
        const s = dpr || 1;
        return Math.round(value * s) / s;
    }

    function px(value, dpr) {
        const s = dpr || 1;
        return Math.round(value * s) / s;
    }

    function hairline(dpr) {
        return 1 / (dpr || 1);
    }

    function withAlpha(color, alpha) {
        if (!color) return Qt.rgba(0, 0, 0, alpha);
        if (typeof color === "string") {
            // Try to parse string colors
            const parsed = _parseColor(color);
            if (typeof parsed === "string") {
                return Qt.rgba(0, 0, 0, alpha); // fallback
            }
            return Qt.rgba(parsed.r, parsed.g, parsed.b, alpha);
        }
        // Assume it's a color object with r,g,b properties
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }
}
