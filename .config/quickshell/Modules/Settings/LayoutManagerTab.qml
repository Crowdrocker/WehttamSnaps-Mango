import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Qt.labs.platform 1.1
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.FileBrowser

Item {
    id: layoutManagerTab

    property var parentModal: null
    property string importSelectedFilePath: ""

    // ── Directory the scanner watches ─────────────────────────────────────────
    readonly property string layoutsDir: {
        var cfg = StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                      .toString().replace("file://", "")
        return cfg + "/EventHorizon/Layouts/"
    }

    // ── FolderListModel – replaces the fragile hardcoded filename loop ────────
    FolderListModel {
        id: layoutDirModel
        folder:          layoutsDir ? "file://" + layoutsDir : ""
        nameFilters:     ["*.json"]
        showDirs:        false
        showDotAndDotDot: false
        showHidden:      false
        sortField:       FolderListModel.Time
        sortReversed:    true
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                Qt.callLater(rebuildModel)
        }
    }

    ListModel { id: savedLayoutsModel }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function showMessage(msg) { if (typeof ToastService !== "undefined") ToastService.showInfo(msg) }
    function showSuccess(msg) { if (typeof ToastService !== "undefined") ToastService.showSuccess(msg) }
    function showError(msg)   { if (typeof ToastService !== "undefined") ToastService.showError(msg) }

    function rebuildModel() {
        savedLayoutsModel.clear()
        for (var i = 0; i < layoutDirModel.count; i++) {
            var fp = layoutDirModel.get(i, "filePath").toString().replace("file://", "")
            var fv = Qt.createQmlObject(
                'import QtQuick; import Quickshell.Io; FileView { blockLoading: true; printErrors: false }',
                layoutManagerTab)
            if (!fv) continue
            fv.path = fp
            var txt = fv.text()
            fv.destroy()
            if (!txt || !txt.trim()) continue
            try {
                var obj = JSON.parse(txt.trim())
                obj.filePath = fp
                savedLayoutsModel.append(obj)
            } catch (e) { /* silently skip malformed files */ }
        }
    }

    // Trigger initial load after a short delay so Quickshell is ready
    Timer {
        interval: 120; repeat: false; running: true
        onTriggered: {
            Paths.mkdir(layoutsDir)
            rebuildModel()
        }
    }

    // ── Preset definitions ────────────────────────────────────────────────────
    readonly property var defaultLayouts: [
        { name: "Windows 11",    icon: "grid_view",      description: "Centered taskbar, top bar hidden." },
        { name: "macOS",         icon: "dock",           description: "Top menu bar with a bottom app dock." },
        { name: "GNOME",         icon: "view_sidebar",   description: "Top bar + left-side dock." },
        { name: "GNOME Floating",icon: "view_sidebar",   description: "Floating top bar, left dock." },
        { name: "Mini Panel",    icon: "vertical_split", description: "Compact side panel only." },
        { name: "Super Dock",    icon: "dashboard",      description: "Full-featured bottom dock." },
        { name: "ZorinOS",       icon: "tv",             description: "Zorin OS look and feel." },
        { name: "KDE",           icon: "apps",           description: "Classic desktop with bottom taskbar." }
    ]

    // ── Preset apply logic ────────────────────────────────────────────────────
    function applyPreset(name) {
        // First try loading from file
        var fileName = name.toLowerCase().replace(/\s+/g, "_") + ".json"
        if (name === "Mini Panel") fileName = "minipanel.json"
        var fv = Qt.createQmlObject(
            'import QtQuick; import Quickshell.Io; FileView { blockLoading: true }',
            layoutManagerTab)
        if (fv) {
            var cfgDir = StandardPaths.writableLocation(StandardPaths.ConfigLocation)
                             .toString().replace("file://", "")
            fv.path = cfgDir + "/quickshell/Layouts/" + fileName
            var txt = fv.text()
            fv.destroy()
            if (txt && txt.trim()) {
                try {
                    var layout = JSON.parse(txt.trim())
                    if (applyLayout(layout)) { showSuccess("Applied " + name + " layout!"); return }
                } catch (e) {}
            }
        }

        // Fall back to built-in presets
        var builtIn = builtInPreset(name)
        if (builtIn && applyLayout(builtIn)) {
            showSuccess("Applied " + name + " layout!")
        } else {
            showError("Failed to apply " + name + " layout")
        }
    }

    function builtInPreset(name) {
        switch (name) {
            case "Windows 11": return {
                topBar: { visible: false, position: "top",    widgets: { left: ["launcherButton"], center: ["workspaceSwitcher"], right: ["systemTray","clock","notificationButton","controlCenterButton"] } },
                dock:   { visible: false, widgetsEnabled: false, position: "bottom", widgets: { left:[], center:[], right:[] } },
                taskBar:{ visible: true,  widgets: { left:[{id:"launcherButton",enabled:true}], center:[{id:"pinnedApps",enabled:true}], right:[{id:"systemTray",enabled:true},{id:"controlCenterButton",enabled:true},{id:"clock",enabled:true},{id:"systemUpdate",enabled:true}] } }
            }
            case "macOS": return {
                topBar: { visible: true,  position: "top",    widgets: { left: ["launcherButton"], center: ["workspaceSwitcher"], right: ["systemTray","weather","clock","notificationButton","controlCenterButton","systemUpdate"] } },
                dock:   { visible: true,  widgetsEnabled: true, position: "bottom", widgets: { left:[], center:[{id:"launchpad",enabled:true},{id:"pinnedApps",enabled:true},{id:"trash",enabled:true}], right:[] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } }
            }
            case "GNOME": return {
                topBar: { visible: true,  position: "top",    widgets: { left: [{id:"workspaceSwitcher",enabled:true}], center: [{id:"clock",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"notificationButton",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: true,  widgetsEnabled: true, position: "bottom", widgets: { left:[], center:[{id:"launchpad",enabled:true},{id:"pinnedApps",enabled:true},{id:"trash",enabled:true}], right:[] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } }
            }
            case "GNOME Floating": return {
                topBar: { visible: true,  position: "top", float: true, roundedCorners: true, cornerRadius: 50, height: 29, leftMargin: 1, rightMargin: 1, topMargin: 2, transparency: 0.49, widgets: { left: [{id:"workspaceSwitcher",enabled:true}], center: [{id:"clock",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"notificationButton",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: true,  widgetsEnabled: true, position: "bottom", widgets: { left:[], center:[{id:"launchpad",enabled:true},{id:"pinnedApps",enabled:true},{id:"trash",enabled:true}], right:[] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } },
                miniPanel:{ visible: true, position: "top", height: 48, scale: 0.85, opacity: 0.47, widgets: { left: ["launcherButton"], center: [{id:"spacer",enabled:true},{id:"workspaceSwitcher",enabled:true},{id:"spacer",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"clock",enabled:true},{id:"notificationButton",enabled:true},{id:"controlCenterButton",enabled:true}] } }
            }
            case "Mini Panel": return {
                topBar: { visible: false, position: "top", widgets: { left: ["launcherButton",{id:"mediaDisplay",enabled:true}], center: [{id:"workspaceSwitcher",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: false, widgetsEnabled: true, position: "bottom", widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true},{id:"music",enabled:true}], center:[{id:"launchpad",enabled:true},{id:"pinnedApps",enabled:true},{id:"trash",enabled:true}], right:[{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true},{id:"settingsButton",enabled:true},{id:"volumeMixerButton",enabled:true}] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true},{id:"mediaDisplay",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } },
                miniPanel:{ visible: true, position: "top", height: 48, widgets: { left: ["launcherButton","workspaceSwitcher","windowPreview"], center: ["music"], right: ["systemTray","clock","notificationButton","controlCenterButton"] } }
            }
            case "Super Dock": return {
                topBar: { visible: false, position: "top", widgets: { left: ["launcherButton",{id:"mediaDisplay",enabled:true}], center: [{id:"workspaceSwitcher",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: true,  widgetsEnabled: true, position: "bottom", widgets: { left:[{id:"launcherButton",enabled:true},{id:"music",enabled:true},{id:"workspaceSwitcher",enabled:true}], center:[{id:"launchpad",enabled:true},{id:"pinnedApps",enabled:true},{id:"trash",enabled:true}], right:[{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true},{id:"settingsButton",enabled:true}] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true},{id:"mediaDisplay",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } }
            }
            case "ZorinOS": return {
                topBar: { visible: false, position: "top", widgets: { left: ["launcherButton",{id:"mediaDisplay",enabled:true}], center: [{id:"workspaceSwitcher",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: true,  widgetsEnabled: true, position: "bottom", expandToScreen: true, widgets: { left:[{id:"launcherButton",enabled:true},{id:"pinnedApps",enabled:true}], center:[], right:[{id:"workspaceSwitcher",enabled:true},{id:"systemTray",enabled:true},{id:"controlCenterButton",enabled:true},{id:"clock",enabled:true}] } },
                taskBar:{ visible: false, widgets: { left:[{id:"launcherButton",enabled:true},{id:"workspaceSwitcher",enabled:true},{id:"mediaDisplay",enabled:true}], center:[{id:"pinnedApps",enabled:true},{id:"separator",enabled:true}], right:["systemTray","weather","clock","controlCenterButton","systemUpdate"] } }
            }
            case "KDE": return {
                topBar: { visible: false, position: "top", widgets: { left: ["launcherButton",{id:"mediaDisplay",enabled:true}], center: [{id:"workspaceSwitcher",enabled:true}], right: [{id:"systemTray",enabled:true},{id:"weather",enabled:true},{id:"clock",enabled:true},{id:"controlCenterButton",enabled:true}] } },
                dock:   { visible: false, widgetsEnabled: true, position: "bottom", widgets: { left:[{id:"launcherButton",enabled:true},{id:"pinnedApps",enabled:true}], center:[], right:[{id:"workspaceSwitcher",enabled:true},{id:"systemTray",enabled:true},{id:"controlCenterButton",enabled:true},{id:"clock",enabled:true}] } },
                taskBar:{ visible: true,  widgets: { left:[{id:"launcherButton",enabled:true},{id:"pinnedApps",enabled:true}], center:[], right:[{id:"systemTray",enabled:true},{id:"notificationButton",enabled:true},{id:"clipboard",enabled:true},{id:"controlCenterButton",enabled:true},{id:"clock",enabled:true}] } }
            }
            default: return null
        }
    }

    // ── Layout snapshot / apply / delete / export / import ───────────────────
    function createCurrentLayoutSnapshot() {
        function s(v, def) { return v !== undefined ? v : def }
        return {
            version: "1.0",
            name: "Current Layout",
            description: "Layout snapshot",
            timestamp: new Date().toISOString(),
            topBar: {
                visible: s(SettingsData.topBarVisible, false),
                position: SettingsData.topBarPosition || "top",
                float: s(SettingsData.topBarFloat, false),
                roundedCorners: s(SettingsData.topBarRoundedCorners, false),
                cornerRadius: s(SettingsData.topBarCornerRadius, 12),
                height: s(SettingsData.topBarHeight, 40),
                leftMargin: s(SettingsData.topBarLeftMargin, 0),
                rightMargin: s(SettingsData.topBarRightMargin, 0),
                topMargin: s(SettingsData.topBarTopMargin, 0),
                transparency: s(SettingsData.topBarTransparency, 0.75),
                widgetTransparency: s(SettingsData.topBarWidgetTransparency, 0.85),
                iconSize: s(SettingsData.topbarIconSize, 24),
                iconSpacing: s(SettingsData.topbarIconSpacing, 2),
                spacing: s(SettingsData.topBarSpacing, 4),
                innerPadding: s(SettingsData.topBarInnerPadding, 8),
                bottomGap: s(SettingsData.topBarBottomGap, 0),
                autoHide: s(SettingsData.topBarAutoHide, false),
                autoFit: s(SettingsData.topBarAutoFit, false),
                noBackground: s(SettingsData.topBarNoBackground, true),
                squareCorners: s(SettingsData.topBarSquareCorners, false),
                borderEnabled: s(SettingsData.topBarBorderEnabled, false),
                borderWidth: s(SettingsData.topBarBorderWidth, 2),
                widgets: {
                    left:   SettingsData.topBarLeftWidgets   || [],
                    center: SettingsData.topBarCenterWidgets || [],
                    right:  SettingsData.topBarRightWidgets  || []
                }
            },
            dock: {
                visible: s(SettingsData.showDock, false),
                widgetsEnabled: s(SettingsData.dockWidgetsEnabled, false),
                position: SettingsData.dockPosition || "bottom",
                expandToScreen: s(SettingsData.dockExpandToScreen, false),
                scale: s(SettingsData.dockScale, 1.0),
                iconSize: s(SettingsData.dockIconSize, 40),
                iconSpacing: s(SettingsData.dockIconSpacing, 2),
                pinnedAppsPillEnabled: s(SettingsData.dockPinnedAppsPillEnabled, false),
                borderEnabled: s(SettingsData.dockBorderEnabled, false),
                widgets: {
                    left:   SettingsData.dockLeftWidgets   || [],
                    center: SettingsData.dockCenterWidgets || [],
                    right:  SettingsData.dockRightWidgets  || []
                }
            },
            taskBar: {
                visible: s(SettingsData.taskBarVisible, true),
                float: s(SettingsData.taskBarFloat, false),
                roundedCorners: s(SettingsData.taskBarRoundedCorners, false),
                cornerRadius: s(SettingsData.taskBarCornerRadius, 32),
                groupApps: s(SettingsData.taskBarGroupApps, true),
                height: s(SettingsData.taskBarHeight, 54),
                bottomMargin: s(SettingsData.taskBarBottomMargin, 3),
                transparency: s(SettingsData.taskBarTransparency, 0.5),
                iconSize: s(SettingsData.taskbarIconSize, 30),
                iconSpacing: s(SettingsData.taskbarIconSpacing, 2),
                autoHide: s(SettingsData.taskBarAutoHide, true),
                borderEnabled: s(SettingsData.taskBarBorderEnabled, false),
                widgets: {
                    left:   SettingsData.taskBarLeftWidgets   || [],
                    center: SettingsData.taskBarCenterWidgets || [],
                    right:  SettingsData.taskBarRightWidgets  || []
                }
            },
            miniPanel: {
                visible: s(SettingsData.showMiniPanel, false),
                position: s(SettingsData.minipanelPosition, "top"),
                autohide: s(SettingsData.miniPanelAutohide, false),
                height: s(SettingsData.miniPanelHeight, 48),
                scale: s(SettingsData.miniPanelScale, 1.0),
                opacity: s(SettingsData.miniPanelOpacity, 1.0),
                widgets: {
                    left:   SettingsData.miniPanelLeftWidgets   || [],
                    center: SettingsData.miniPanelCenterWidgets || [],
                    right:  SettingsData.miniPanelRightWidgets  || []
                }
            },
            global: { cornerRadius: s(SettingsData.cornerRadius, 32) }
        }
    }

    function applyLayout(layout) {
        if (!layout) return false
        try {
            if (layout.topBar) {
                var tb = layout.topBar
                if (tb.visible      !== undefined) SettingsData.topBarVisible      = tb.visible
                if (tb.position)                   SettingsData.topBarPosition     = tb.position
                if (tb.float        !== undefined) SettingsData.topBarFloat        = tb.float
                if (tb.roundedCorners !== undefined) SettingsData.topBarRoundedCorners = tb.roundedCorners
                if (tb.cornerRadius !== undefined) SettingsData.topBarCornerRadius = tb.cornerRadius
                if (tb.height       !== undefined) SettingsData.topBarHeight       = tb.height
                if (tb.leftMargin   !== undefined) SettingsData.topBarLeftMargin   = tb.leftMargin
                if (tb.rightMargin  !== undefined) SettingsData.topBarRightMargin  = tb.rightMargin
                if (tb.topMargin    !== undefined) SettingsData.topBarTopMargin    = tb.topMargin
                if (tb.transparency !== undefined) SettingsData.topBarTransparency = tb.transparency
                if (tb.widgetTransparency !== undefined) SettingsData.topBarWidgetTransparency = tb.widgetTransparency
                if (tb.iconSize     !== undefined) SettingsData.topbarIconSize     = tb.iconSize
                if (tb.iconSpacing  !== undefined) SettingsData.topbarIconSpacing  = tb.iconSpacing
                if (tb.spacing      !== undefined) SettingsData.topBarSpacing      = tb.spacing
                if (tb.innerPadding !== undefined) SettingsData.topBarInnerPadding = tb.innerPadding
                if (tb.bottomGap    !== undefined) SettingsData.topBarBottomGap    = tb.bottomGap
                if (tb.autoHide     !== undefined) SettingsData.topBarAutoHide     = tb.autoHide
                if (tb.autoFit      !== undefined) SettingsData.topBarAutoFit      = tb.autoFit
                if (tb.noBackground !== undefined) SettingsData.topBarNoBackground = tb.noBackground
                if (tb.squareCorners !== undefined) SettingsData.topBarSquareCorners = tb.squareCorners
                if (tb.gothCornersEnabled !== undefined) SettingsData.topBarGothCornersEnabled = tb.gothCornersEnabled
                if (tb.borderEnabled !== undefined) SettingsData.topBarBorderEnabled = tb.borderEnabled
                if (tb.borderWidth  !== undefined) SettingsData.topBarBorderWidth  = tb.borderWidth
                if (tb.borderRed    !== undefined) SettingsData.topBarBorderRed    = tb.borderRed
                if (tb.borderGreen  !== undefined) SettingsData.topBarBorderGreen  = tb.borderGreen
                if (tb.borderBlue   !== undefined) SettingsData.topBarBorderBlue   = tb.borderBlue
                if (tb.borderAlpha  !== undefined) SettingsData.topBarBorderAlpha  = tb.borderAlpha
                if (tb.dynamicBorderColors !== undefined) SettingsData.topBarDynamicBorderColors = tb.dynamicBorderColors
                if (tb.widgets) {
                    if (tb.widgets.left)   SettingsData.setTopBarLeftWidgets(tb.widgets.left)
                    if (tb.widgets.center) SettingsData.setTopBarCenterWidgets(tb.widgets.center)
                    if (tb.widgets.right)  SettingsData.setTopBarRightWidgets(tb.widgets.right)
                }
            }
            if (layout.dock) {
                var dk = layout.dock
                if (dk.visible         !== undefined) SettingsData.showDock            = dk.visible
                if (dk.widgetsEnabled  !== undefined) SettingsData.dockWidgetsEnabled  = dk.widgetsEnabled
                if (dk.position)                      SettingsData.dockPosition        = dk.position
                if (dk.expandToScreen  !== undefined) SettingsData.dockExpandToScreen  = dk.expandToScreen
                if (dk.scale           !== undefined) SettingsData.dockScale           = dk.scale
                if (dk.iconSize        !== undefined) SettingsData.dockIconSize        = dk.iconSize
                if (dk.iconSpacing     !== undefined) SettingsData.dockIconSpacing     = dk.iconSpacing
                if (dk.pinnedAppsPillEnabled !== undefined) SettingsData.dockPinnedAppsPillEnabled = dk.pinnedAppsPillEnabled
                if (dk.borderEnabled   !== undefined) SettingsData.dockBorderEnabled   = dk.borderEnabled
                if (dk.borderWidth     !== undefined) SettingsData.dockBorderWidth     = dk.borderWidth
                if (dk.borderRed       !== undefined) SettingsData.dockBorderRed       = dk.borderRed
                if (dk.borderGreen     !== undefined) SettingsData.dockBorderGreen     = dk.borderGreen
                if (dk.borderBlue      !== undefined) SettingsData.dockBorderBlue      = dk.borderBlue
                if (dk.borderAlpha     !== undefined) SettingsData.dockBorderAlpha     = dk.borderAlpha
                if (dk.dynamicBorderColors !== undefined) SettingsData.dockDynamicBorderColors = dk.dynamicBorderColors
                if (dk.widgets) {
                    if (dk.widgets.left)   SettingsData.setDockLeftWidgets(dk.widgets.left)
                    if (dk.widgets.center) SettingsData.setDockCenterWidgets(dk.widgets.center)
                    if (dk.widgets.right)  SettingsData.setDockRightWidgets(dk.widgets.right)
                }
            }
            if (layout.taskBar) {
                var ts = layout.taskBar
                if (ts.visible         !== undefined) SettingsData.taskBarVisible      = ts.visible
                if (ts.float           !== undefined) SettingsData.taskBarFloat        = ts.float
                if (ts.roundedCorners  !== undefined) SettingsData.taskBarRoundedCorners = ts.roundedCorners
                if (ts.cornerRadius    !== undefined) SettingsData.taskBarCornerRadius  = ts.cornerRadius
                if (ts.groupApps       !== undefined) SettingsData.taskBarGroupApps    = ts.groupApps
                if (ts.height          !== undefined) SettingsData.taskBarHeight       = ts.height
                if (ts.bottomMargin    !== undefined) SettingsData.taskBarBottomMargin = ts.bottomMargin
                if (ts.exclusiveZone   !== undefined) SettingsData.taskBarExclusiveZone = ts.exclusiveZone
                if (ts.transparency    !== undefined) SettingsData.taskBarTransparency = ts.transparency
                if (ts.iconSize        !== undefined) SettingsData.taskbarIconSize     = ts.iconSize
                if (ts.iconSpacing     !== undefined) SettingsData.taskbarIconSpacing  = ts.iconSpacing
                if (ts.autoHide        !== undefined) SettingsData.taskBarAutoHide     = ts.autoHide
                if (ts.pinnedAppsPosition)            SettingsData.taskBarPinnedAppsPosition = ts.pinnedAppsPosition
                if (ts.borderEnabled   !== undefined) SettingsData.taskBarBorderEnabled = ts.borderEnabled
                if (ts.borderWidth     !== undefined) SettingsData.taskBarBorderWidth  = ts.borderWidth
                if (ts.borderRed       !== undefined) SettingsData.taskBarBorderRed    = ts.borderRed
                if (ts.borderGreen     !== undefined) SettingsData.taskBarBorderGreen  = ts.borderGreen
                if (ts.borderBlue      !== undefined) SettingsData.taskBarBorderBlue   = ts.borderBlue
                if (ts.borderAlpha     !== undefined) SettingsData.taskBarBorderAlpha  = ts.borderAlpha
                if (ts.dynamicBorderColors !== undefined) SettingsData.taskBarDynamicBorderColors = ts.dynamicBorderColors
                if (ts.widgets) {
                    if (ts.widgets.left)   SettingsData.setTaskBarLeftWidgets(ts.widgets.left)
                    if (ts.widgets.center) SettingsData.setTaskBarCenterWidgets(ts.widgets.center)
                    if (ts.widgets.right)  SettingsData.setTaskBarRightWidgets(ts.widgets.right)
                }
            }
            if (layout.miniPanel) {
                var mp = layout.miniPanel
                if (mp.visible   !== undefined) SettingsData.showMiniPanel      = mp.visible
                if (mp.position  !== undefined) SettingsData.minipanelPosition  = mp.position
                if (mp.autohide  !== undefined) SettingsData.miniPanelAutohide  = mp.autohide
                if (mp.height    !== undefined) SettingsData.miniPanelHeight    = mp.height
                if (mp.scale     !== undefined) SettingsData.miniPanelScale     = mp.scale
                if (mp.opacity   !== undefined) SettingsData.miniPanelOpacity   = mp.opacity
                if (mp.widgets) {
                    if (mp.widgets.left)   SettingsData.miniPanelLeftWidgets   = mp.widgets.left
                    if (mp.widgets.center) SettingsData.miniPanelCenterWidgets = mp.widgets.center
                    if (mp.widgets.right)  SettingsData.miniPanelRightWidgets  = mp.widgets.right
                }
            }
            if (layout.global && layout.global.cornerRadius !== undefined)
                SettingsData.cornerRadius = layout.global.cornerRadius
            return true
        } catch (e) {
            console.error("Failed to apply layout:", e)
            return false
        }
    }

    function deleteLayout(layout, index) {
        if (!layout || !layout.filePath) { showError("Cannot delete: no file path"); return }
        Quickshell.execDetached(["rm", "-f", layout.filePath])
        savedLayoutsModel.remove(index)
        showSuccess("Deleted '" + (layout.name || "layout") + "'")
    }

    function exportLayoutToFile(layoutName, description, filePath) {
        try {
            Paths.mkdir(filePath.substring(0, filePath.lastIndexOf('/')))
            var layout = createCurrentLayoutSnapshot()
            layout.name = layoutName
            layout.description = description || ""
            var fv = Qt.createQmlObject(
                'import QtQuick; import Quickshell.Io; FileView { blockLoading: true; atomicWrites: true }',
                layoutManagerTab)
            if (!fv) { showError("Failed to save layout file"); return }
            fv.path = filePath
            fv.setText(JSON.stringify(layout, null, 2))
            fv.destroy()
            Qt.callLater(rebuildModel)
            showSuccess("Exported '" + layoutName + "'!")
        } catch (e) {
            showError("Failed to export layout")
        }
    }

    function importLayout(filePath) {
        try {
            var fv = Qt.createQmlObject(
                'import QtQuick; import Quickshell.Io; FileView { blockLoading: true }',
                layoutManagerTab)
            if (!fv) { showError("Failed to read layout file"); return }
            fv.path = filePath
            var txt = fv.text()
            fv.destroy()
            if (!txt || !txt.trim()) { showError("Layout file is empty"); return }
            var layout = JSON.parse(txt.trim())
            if (!applyLayout(layout)) { showError("Failed to apply imported layout"); return }
            var layoutName = layout.name || "Imported Layout"
            var saveName = layoutName.replace(/[^a-zA-Z0-9]/g, "_").toLowerCase() + ".json"
            exportLayoutToFile(layoutName, layout.description || "Imported layout",
                               layoutsDir + saveName)
        } catch (e) {
            showError("Invalid layout file format")
        }
    }

    // =========================================================================
    // UI
    // =========================================================================

    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: rootColumn.implicitHeight + Theme.spacingXL * 2
        contentWidth: width

        Column {
            id: rootColumn
            width: parent.width
            spacing: 0
            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingXL

            // ── Header ───────────────────────────────────────────────────────
            Item {
                width: parent.width
                height: headerRow.implicitHeight
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL

                RowLayout {
                    id: headerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "dashboard"
                        size: 28
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Layout Manager"
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: 500
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Switch, save and manage desktop layouts"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    // Import button
                    StyledRect {
                        Layout.preferredWidth: importBtnRow.implicitWidth + Theme.spacingM * 2
                        Layout.preferredHeight: 34
                        radius: Theme.cornerRadius
                        color: importBtnArea.containsMouse
                               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                               : "transparent"
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                        Row {
                            id: importBtnRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS
                            EHIcon { name: "file_download"; size: 15; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "Import"; font.pixelSize: Theme.fontSizeSmall; font.weight: 500; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: importBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: importFileBrowser.open()
                        }
                    }

                    // Export button
                    StyledRect {
                        Layout.preferredWidth: exportBtnRow.implicitWidth + Theme.spacingM * 2
                        Layout.preferredHeight: 34
                        radius: Theme.cornerRadius
                        color: exportBtnArea.containsMouse ? Theme.primary
                               : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                        Row {
                            id: exportBtnRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS
                            EHIcon { name: "file_upload"; size: 15; color: Theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "Export"; font.pixelSize: Theme.fontSizeSmall; font.weight: 500; color: Theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: exportBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: exportDialog.visible = true
                        }
                    }
                }
            }

            Item { width: parent.width; height: Theme.spacingXL }

            // ── Current Layout Status bar ─────────────────────────────────────
            Item {
                width: parent.width
                height: statusCard.implicitHeight + Theme.spacingS * 2

                StyledRect {
                    id: statusCard
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL; anchors.rightMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: statusInner.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                    border.width: 1

                    Row {
                        id: statusInner
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingL; anchors.rightMargin: Theme.spacingL
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXL

                        // Status chip helper component
                        Repeater {
                            model: [
                                { label: "Top Bar",  on: SettingsData.topBarVisible,  icon: "horizontal_distribute" },
                                { label: "Dock",     on: SettingsData.showDock,        icon: "dock" },
                                { label: "Task Bar", on: SettingsData.taskBarVisible,  icon: "view_column" },
                                { label: "Panel",    on: SettingsData.showMiniPanel,   icon: "vertical_split" }
                            ]

                            Row {
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                property bool on: modelData.on

                                Rectangle {
                                    width: 7; height: 7; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: on ? Theme.primary : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.4)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: 500
                                    color: on ? Theme.surfaceText : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: parent.width; height: Theme.spacingXL }

            // ── Section: Preset Layouts ───────────────────────────────────────
            Item {
                width: parent.width
                height: presetSection.implicitHeight

                Column {
                    id: presetSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL; anchors.rightMargin: Theme.spacingL
                    spacing: Theme.spacingM

                    // Section header
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        EHIcon { name: "auto_awesome"; size: Theme.iconSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }

                        StyledText {
                            text: "Preset Layouts"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: 500
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: "One-click layouts inspired by popular desktop environments"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    // Grid of preset cards
                    Flow {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            model: layoutManagerTab.defaultLayouts

                            StyledRect {
                                width: {
                                    var cols = Math.max(1, Math.floor(parent.width / 220))
                                    return Math.floor((parent.width - Theme.spacingM * (cols - 1)) / cols)
                                }
                                height: 160
                                radius: Theme.cornerRadius
                                color: presetHover.containsMouse
                                       ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                                       : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.35)
                                border.color: presetHover.containsMouse
                                              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                              : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                                Column {
                                    id: presetCardCol
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: presetApplyBtn.top
                                    anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                    anchors.topMargin: Theme.spacingM; anchors.bottomMargin: Theme.spacingS
                                    spacing: Theme.spacingS
                                    clip: true

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        EHIcon {
                                            name: modelData.icon
                                            size: Theme.iconSize
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - Theme.iconSize - Theme.spacingS
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.1
                                        }
                                    }

                                    StyledText {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.3
                                    }
                                }

                                // Apply button — always pinned to card bottom
                                StyledRect {
                                    id: presetApplyBtn
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                    anchors.bottomMargin: Theme.spacingM
                                    height: 30
                                    radius: Theme.cornerRadius
                                    color: applyPresetArea.containsMouse
                                           ? Theme.primary
                                           : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        EHIcon {
                                            name: "check_circle"; size: 13
                                            color: applyPresetArea.containsMouse ? Theme.primaryText : Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: "Apply"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: 500
                                            color: applyPresetArea.containsMouse ? Theme.primaryText : Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: applyPresetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: layoutManagerTab.applyPreset(modelData.name)
                                    }
                                }

                                MouseArea {
                                    id: presetHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }

            Item { width: parent.width; height: Theme.spacingXL }

            // ── Section: Saved Layouts ────────────────────────────────────────
            Item {
                width: parent.width
                height: savedSection.implicitHeight

                Column {
                    id: savedSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingL; anchors.rightMargin: Theme.spacingL
                    spacing: Theme.spacingM

                    // Section header with refresh button
                    RowLayout {
                        width: parent.width

                        Row {
                            spacing: Theme.spacingS
                            Layout.fillWidth: true

                            EHIcon { name: "bookmarks"; size: Theme.iconSizeSmall; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }

                            StyledText {
                                text: "Saved Layouts"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: 500
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Count chip
                            StyledRect {
                                visible: savedLayoutsModel.count > 0
                                width: countChipText.implicitWidth + 10
                                height: 20
                                radius: 10
                                color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    id: countChipText
                                    anchors.centerIn: parent
                                    text: savedLayoutsModel.count
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.secondary
                                }
                            }
                        }

                        // Refresh button
                        StyledRect {
                            Layout.preferredWidth: refreshBtnRow.implicitWidth + Theme.spacingM * 2
                            Layout.preferredHeight: 30
                            radius: Theme.cornerRadius
                            color: refreshBtnArea.containsMouse
                                   ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12)
                                   : "transparent"
                            border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.6)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                            Row {
                                id: refreshBtnRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                EHIcon {
                                    id: refreshIcon
                                    name: "refresh"; size: 14; color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter

                                    RotationAnimation on rotation {
                                        id: refreshSpin
                                        running: false
                                        from: 0; to: 360; duration: 500
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                                StyledText {
                                    text: "Refresh"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: 500
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: refreshBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    refreshSpin.restart()
                                    rebuildModel()
                                    showMessage("Refreshed — " + savedLayoutsModel.count + " layout" +
                                                (savedLayoutsModel.count !== 1 ? "s" : "") + " found")
                                }
                            }
                        }
                    }

                    StyledText {
                        text: savedLayoutsModel.count > 0
                              ? "Layouts found in " + layoutsDir
                              : "No layouts found — export one or drop a .json into " + layoutsDir
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        elide: Text.ElideMiddle
                    }

                    // Empty state
                    StyledRect {
                        width: parent.width
                        height: 110
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                        border.width: 1
                        visible: savedLayoutsModel.count === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            EHIcon { name: "folder_open"; size: 32; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }

                            StyledText {
                                text: "No saved layouts yet"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: 500
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "Use Export to save your current configuration"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.7)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Saved layout cards grid
                    Flow {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: savedLayoutsModel.count > 0

                        Repeater {
                            model: savedLayoutsModel

                            StyledRect {
                                width: {
                                    var cols = Math.max(1, Math.floor(parent.width / 240))
                                    return Math.floor((parent.width - Theme.spacingM * (cols - 1)) / cols)
                                }
                                height: 160
                                radius: Theme.cornerRadius
                                color: savedCardHover.containsMouse
                                       ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                                       : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.35)
                                border.color: savedCardHover.containsMouse
                                              ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.4)
                                              : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                                Column {
                                    id: savedCardCol
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: savedApplyBtn.top
                                    anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                    anchors.topMargin: Theme.spacingM; anchors.bottomMargin: Theme.spacingS
                                    spacing: Theme.spacingS
                                    clip: true

                                    // Title row with delete
                                    Item {
                                        width: parent.width
                                        height: Math.max(Theme.iconSize, savedNameText.implicitHeight)

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: deleteBtn.left
                                            anchors.rightMargin: Theme.spacingS
                                            spacing: Theme.spacingS
                                            height: parent.height

                                            EHIcon { name: "save"; size: Theme.iconSize; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }

                                            StyledText {
                                                id: savedNameText
                                                text: model.name || "Custom Layout"
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: 500
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - Theme.iconSize - Theme.spacingS
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Delete icon
                                        Item {
                                            id: deleteBtn
                                            width: 28; height: 28
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter

                                            EHIcon {
                                                name: "delete"; size: 17
                                                color: deleteBtnArea.containsMouse ? Theme.error : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.5)
                                                anchors.centerIn: parent
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                id: deleteBtnArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    deleteConfirmDialog.layoutToDelete = model
                                                    deleteConfirmDialog.layoutIndex    = index
                                                    deleteConfirmDialog.layoutName     = model.name || "Custom Layout"
                                                    deleteConfirmDialog.visible        = true
                                                }
                                            }
                                        }
                                    }

                                    // Description
                                    StyledText {
                                        text: model.description || "Custom saved layout"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    // Bar summary chips
                                    Row {
                                        spacing: Theme.spacingXS

                                        Repeater {
                                            model: [
                                                { lbl: "Top",  on: savedCardCol.parent && savedLayoutsModel.get && (savedLayoutsModel.get(index) || {}).topBar && (savedLayoutsModel.get(index).topBar || {}).visible },
                                                { lbl: "Dock", on: savedCardCol.parent && savedLayoutsModel.get && (savedLayoutsModel.get(index) || {}).dock  && (savedLayoutsModel.get(index).dock  || {}).visible },
                                                { lbl: "Task", on: savedCardCol.parent && savedLayoutsModel.get && (savedLayoutsModel.get(index) || {}).taskBar && (savedLayoutsModel.get(index).taskBar || {}).visible }
                                            ]

                                            StyledRect {
                                                visible: modelData.on !== undefined
                                                width:  chipLbl.implicitWidth + 10
                                                height: 18
                                                radius: 9
                                                color: modelData.on
                                                       ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                                       : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.1)

                                                StyledText {
                                                    id: chipLbl
                                                    anchors.centerIn: parent
                                                    text: modelData.lbl
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: modelData.on ? Theme.secondary : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.6)
                                                }
                                            }
                                        }

                                        // Timestamp
                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: model.timestamp ? Qt.formatDate(new Date(model.timestamp), "MMM d") : ""
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.5)
                                        }
                                    }
                                }

                                // Apply button — always pinned to card bottom
                                StyledRect {
                                    id: savedApplyBtn
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                                    anchors.bottomMargin: Theme.spacingM
                                    height: 30
                                    radius: Theme.cornerRadius
                                    color: applySavedArea.containsMouse
                                           ? Theme.secondary
                                           : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.1)
                                    border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.5)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        EHIcon {
                                            name: "check_circle"; size: 13
                                            color: applySavedArea.containsMouse ? Theme.primaryText : Theme.secondary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: "Apply"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: 500
                                            color: applySavedArea.containsMouse ? Theme.primaryText : Theme.secondary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: applySavedArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (applyLayout(model)) {
                                                showSuccess("Applied '" + (model.name || "layout") + "'!")
                                            } else {
                                                showError("Failed to apply layout")
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: savedCardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }

            Item { width: parent.width; height: Theme.spacingXL }
        }
    }

    // =========================================================================
    // Dialogs / modals
    // =========================================================================

    FileBrowserModal {
        id: importFileBrowser
        browserTitle: "Select Layout File"
        browserIcon: "file_download"
        browserType: "import"
        fileExtensions: ["*.json"]
        selectFolderMode: false
        onFileSelected: path => {
            layoutManagerTab.importSelectedFilePath = path
            layoutManagerTab.importLayout(path)
            close()
        }
    }

    // ── Export Dialog ─────────────────────────────────────────────────────────
    FloatingWindow {
        id: exportDialog
        title: "Export Current Layout"
        minimumSize: Qt.size(480, 460)
        implicitWidth: 520
        implicitHeight: 500
        visible: false

        onVisibleChanged: {
            if (visible) {
                var now = new Date()
                exportNameField.text = "My Layout " + Qt.formatDate(now, "yyyy-MM-dd")
                exportDescField.text = ""
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            // Header
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                StyledText {
                    text: "Export Layout"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: 600
                    color: Theme.surfaceText
                }

                StyledText {
                    text: "Save your current desktop configuration as a reusable preset"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Live preview of active bars
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: previewCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: previewCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Repeater {
                        model: [
                            { label: "Top Bar",  on: SettingsData.topBarVisible,  icon: "horizontal_distribute",
                              detail: (SettingsData.topBarPosition || "top") + " • " +
                                      ((SettingsData.topBarLeftWidgets||[]).length +
                                       (SettingsData.topBarCenterWidgets||[]).length +
                                       (SettingsData.topBarRightWidgets||[]).length) + " widgets" },
                            { label: "Dock",     on: SettingsData.showDock,        icon: "dock",
                              detail: (SettingsData.dockPosition || "bottom") + " • " +
                                      ((SettingsData.dockLeftWidgets||[]).length +
                                       (SettingsData.dockCenterWidgets||[]).length +
                                       (SettingsData.dockRightWidgets||[]).length) + " widgets" },
                            { label: "Task Bar", on: SettingsData.taskBarVisible,  icon: "view_column",
                              detail: ((SettingsData.taskBarLeftWidgets||[]).length +
                                       (SettingsData.taskBarCenterWidgets||[]).length +
                                       (SettingsData.taskBarRightWidgets||[]).length) + " widgets" }
                        ]

                        RowLayout {
                            width: previewCol.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 28; height: 28; radius: 6
                                color: modelData.on
                                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                       : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.08)

                                EHIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon; size: 16
                                    color: modelData.on ? Theme.primary : Theme.surfaceVariantText
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: 500
                                    color: modelData.on ? Theme.surfaceText : Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: (modelData.on ? "Visible • " : "Hidden • ") + modelData.detail
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                }
                            }

                            Rectangle {
                                width: 7; height: 7; radius: 4
                                color: modelData.on ? Theme.primary
                                       : Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.3)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }
            }

            // Name field
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                StyledText { text: "Layout Name"; font.pixelSize: Theme.fontSizeSmall; font.weight: 500; color: Theme.surfaceText }

                TextField {
                    id: exportNameField
                    width: parent.width
                    height: 42
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    placeholderText: "Enter a name for your layout"
                    selectByMouse: true
                    background: Rectangle {
                        color: Theme.surfaceContainer
                        border.color: exportNameField.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                        border.width: exportNameField.activeFocus ? 2 : 1
                        radius: Theme.cornerRadius
                    }
                    leftPadding: Theme.spacingM; rightPadding: Theme.spacingM
                }
            }

            // Description field (optional)
            Column {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                StyledText { text: "Description (optional)"; font.pixelSize: Theme.fontSizeSmall; font.weight: 500; color: Theme.surfaceText }

                TextArea {
                    id: exportDescField
                    width: parent.width
                    height: 72
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    placeholderText: "Describe this layout..."
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    background: Rectangle {
                        color: Theme.surfaceContainer
                        border.color: exportDescField.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                        border.width: exportDescField.activeFocus ? 2 : 1
                        radius: Theme.cornerRadius
                    }
                    leftPadding: Theme.spacingM; rightPadding: Theme.spacingM
                    topPadding: Theme.spacingS;  bottomPadding: Theme.spacingS
                }
            }

            Item { Layout.fillHeight: true }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Item { Layout.fillWidth: true }

                StyledRect {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: cancelExportArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06) : "transparent"
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4); border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                    StyledText { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }

                    MouseArea {
                        id: cancelExportArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: exportDialog.hide()
                    }
                }

                StyledRect {
                    Layout.preferredWidth: 140; Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    enabled: exportNameField.text.trim() !== ""
                    opacity: enabled ? 1.0 : 0.5
                    color: doExportArea.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                    Row {
                        anchors.centerIn: parent; spacing: Theme.spacingXS
                        EHIcon { name: "save"; size: 15; color: Theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Export Layout"; font.pixelSize: Theme.fontSizeMedium; font.weight: 500; color: Theme.primaryText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: doExportArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: exportNameField.text.trim() !== ""
                        onClicked: {
                            var safeName = exportNameField.text.trim().replace(/[^a-zA-Z0-9]/g, "_").toLowerCase()
                            var fp = layoutsDir + safeName + ".json"
                            exportLayoutToFile(exportNameField.text.trim(), exportDescField.text.trim(), fp)
                            exportDialog.hide()
                        }
                    }
                }
            }
        }

        FloatingWindowControls { targetWindow: exportDialog }
    }

    // ── Delete Confirmation Dialog ────────────────────────────────────────────
    FloatingWindow {
        id: deleteConfirmDialog
        title: "Delete Layout"
        minimumSize: Qt.size(340, 180)
        implicitWidth: 380
        implicitHeight: 200
        visible: false

        property var    layoutToDelete: null
        property int    layoutIndex:    -1
        property string layoutName:     ""

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL

            Row {
                spacing: Theme.spacingM
                width: parent.width

                EHIcon { name: "warning"; size: 28; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }

                Column {
                    spacing: Theme.spacingXS
                    width: parent.width - 28 - Theme.spacingM

                    StyledText {
                        text: "Delete \"" + deleteConfirmDialog.layoutName + "\"?"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: 500
                        color: Theme.surfaceText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "This will permanently delete the layout file."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Item { Layout.fillWidth: true }

                StyledRect {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 36
                    radius: Theme.cornerRadius
                    color: cancelDelArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06) : "transparent"
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4); border.width: 1
                    StyledText { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                    MouseArea { id: cancelDelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteConfirmDialog.visible = false }
                }

                StyledRect {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 36
                    radius: Theme.cornerRadius
                    color: confirmDelArea.containsMouse ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.8)
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                    Row {
                        anchors.centerIn: parent; spacing: Theme.spacingXS
                        EHIcon { name: "delete"; size: 14; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Delete"; font.pixelSize: Theme.fontSizeSmall; font.weight: 500; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: confirmDelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (deleteConfirmDialog.layoutToDelete && deleteConfirmDialog.layoutIndex >= 0)
                                deleteLayout(deleteConfirmDialog.layoutToDelete, deleteConfirmDialog.layoutIndex)
                            deleteConfirmDialog.visible = false
                        }
                    }
                }
            }
        }

        FloatingWindowControls { targetWindow: deleteConfirmDialog }
    }
}
