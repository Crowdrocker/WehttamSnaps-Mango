import QtQuick
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null

    readonly property bool isMango: typeof CompositorService !== "undefined" && CompositorService.isMango

    readonly property string _configBase: {
        const cfg = Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.ConfigLocation))
        if (cfg && cfg.length > 0)
            return cfg.replace(/^file:\/\//, "")
        const h = Paths.stringify(Paths.home).replace(/^file:\/\//, "")
        return h ? h + "/.config" : ""
    }

    readonly property string miscPath: _configBase + "/mango/hyprmango/misc.conf"

    property var miscSegments: []
    property var deco: ({})
    property string pendingSaveContent: ""
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true
    property bool writesEnabled: false

    readonly property var managedMiscKeys: ["focus_on_activate", "sloppyfocus", "warpcursor", "focus_cross_monitor", "focus_cross_tag", "no_border_when_single", "idleinhibit_ignore_visible", "drag_tile_to_tile", "enable_floating_snap", "snap_distance", "cursor_size", "axis_bind_apply_timeout", "hotarea_size", "enable_hotarea", "ov_tab_mode", "ov_no_resize", "overviewgappi", "overviewgappo", "xwayland_persistence", "cursor_hide_timeout", "cursor_hide_on_keypress", "drag_tile_small", "drag_corner", "drag_warp_cursor", "allow_lock_transparent", "allow_shortcuts_inhibit", "syncobj_enable", "exchange_cross_monitor", "view_current_to_back", "scratchpad_cross_monitor", "single_scratchpad", "tag_carousel", "drag_tile_refresh_interval", "drag_floating_refresh_interval", "hdr_depth"]

    readonly property var defaultDeco: ({
            "focus_on_activate": "1", "sloppyfocus": "1", "warpcursor": "1", "focus_cross_monitor": "0", "focus_cross_tag": "0", "no_border_when_single": "0", "idleinhibit_ignore_visible": "0", "drag_tile_to_tile": "0", "enable_floating_snap": "0", "snap_distance": "30", "cursor_size": "24", "axis_bind_apply_timeout": "100", "hotarea_size": "10", "enable_hotarea": "0", "ov_tab_mode": "1", "ov_no_resize": "1", "overviewgappi": "5", "overviewgappo": "30", "xwayland_persistence": "1", "cursor_hide_timeout": "0", "cursor_hide_on_keypress": "0", "drag_tile_small": "1", "drag_corner": "3", "drag_warp_cursor": "1", "allow_lock_transparent": "0", "allow_shortcuts_inhibit": "1", "syncobj_enable": "1", "exchange_cross_monitor": "0", "view_current_to_back": "0", "scratchpad_cross_monitor": "0", "single_scratchpad": "1", "tag_carousel": "0",             "drag_tile_refresh_interval": "8.0", "drag_floating_refresh_interval": "8.0", "hdr_depth": "2"
        })

    function makeDefaultMiscSegments() {
        const s = [
            { type: "line", raw: "# Miscellaneous settings" },
            { type: "line", raw: "" },
            { type: "line", raw: "# Focus behavior" },
            { type: "line", raw: "" }
        ]
        const focusKeys = ["focus_on_activate", "sloppyfocus", "warpcursor", "focus_cross_monitor", "focus_cross_tag", "exchange_cross_monitor"]
        for (let i = 0; i < focusKeys.length; i++)
            s.push({ type: "kv", key: focusKeys[i] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Window behavior" })
        s.push({ type: "line", raw: "" })
        const windowKeys = ["no_border_when_single", "idleinhibit_ignore_visible", "drag_tile_to_tile", "drag_tile_small", "drag_corner", "drag_warp_cursor", "enable_floating_snap", "snap_distance", "view_current_to_back", "tag_carousel"]
        for (let j = 0; j < windowKeys.length; j++)
            s.push({ type: "kv", key: windowKeys[j] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Drag refresh intervals" })
        s.push({ type: "line", raw: "" })
        const dragKeys = ["drag_tile_refresh_interval", "drag_floating_refresh_interval"]
        for (let d = 0; d < dragKeys.length; d++)
            s.push({ type: "kv", key: dragKeys[d] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Cursor" })
        s.push({ type: "line", raw: "" })
        const cursorKeys = ["cursor_size", "cursor_hide_timeout", "cursor_hide_on_keypress", "axis_bind_apply_timeout"]
        for (let k = 0; k < cursorKeys.length; k++)
            s.push({ type: "kv", key: cursorKeys[k] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Scratchpad" })
        s.push({ type: "line", raw: "" })
        const scratchpadKeys = ["scratchpad_cross_monitor", "single_scratchpad"]
        for (let sc = 0; sc < scratchpadKeys.length; sc++)
            s.push({ type: "kv", key: scratchpadKeys[sc] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Overview" })
        s.push({ type: "line", raw: "" })
        const overviewKeys = ["hotarea_size", "enable_hotarea", "ov_tab_mode", "ov_no_resize", "overviewgappi", "overviewgappo"]
        for (let l = 0; l < overviewKeys.length; l++)
            s.push({ type: "kv", key: overviewKeys[l] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Security & system" })
        s.push({ type: "line", raw: "" })
        const securityKeys = ["allow_lock_transparent", "allow_shortcuts_inhibit", "syncobj_enable"]
        for (let sec = 0; sec < securityKeys.length; sec++)
            s.push({ type: "kv", key: securityKeys[sec] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# XWayland persistence (0/1; relogin to apply)" })
        s.push({ type: "line", raw: "" })
        s.push({ type: "kv", key: "xwayland_persistence" })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# HDR" })
        s.push({ type: "line", raw: "" })
        s.push({ type: "kv", key: "hdr_depth" })
        return s
    }

    function parseMiscFile(text) {
        if (!text || !String(text).trim()) {
            miscSegments = makeDefaultMiscSegments()
            deco = Object.assign({}, defaultDeco)
            return
        }
        const lines = String(text).split("\n")
        const segs = []
        const d = Object.assign({}, defaultDeco)
        const kvRe = /^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$/
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            const t = raw.trim()
            if (!t) {
                segs.push({ type: "line", raw: raw })
                continue
            }
            if (t.startsWith("#")) {
                segs.push({ type: "line", raw: raw })
                continue
            }
            const km = t.match(kvRe)
            if (km) {
                const key = km[1]
                const val = km[2].trim()
                if (managedMiscKeys.indexOf(key) >= 0) {
                    segs.push({ type: "kv", key: key })
                    d[key] = val
                    continue
                }
            }
            segs.push({ type: "line", raw: raw })
        }
        miscSegments = segs
        deco = d
    }

    function serializeMiscFile() {
        const d = deco
        return miscSegments.map(seg => {
            if (seg.type === "line")
                return seg.raw
            if (seg.type === "kv") {
                const k = seg.key
                const v = d[k] !== undefined && d[k] !== null ? String(d[k]) : (defaultDeco[k] !== undefined ? defaultDeco[k] : "")
                return k + " = " + v
            }
            return ""
        }).join("\n")
    }

    function gv(k) {
        if (deco[k] !== undefined && deco[k] !== null)
            return String(deco[k])
        return defaultDeco[k] !== undefined ? defaultDeco[k] : ""
    }

    function numKey(k, defN) {
        const v = parseFloat(gv(k))
        return isNaN(v) ? defN : v
    }

    function intToggleChecked(k) {
        return parseInt(gv(k), 10) !== 0
    }

    function setDe(k, v) {
        const c = Object.assign({}, deco)
        c[k] = String(v)
        deco = c
        schedulePersistAndReload()
    }

    function schedulePersistAndReload() {
        if (saveInFlight) {
            persistQueued = true
            return
        }
        persistDebounce.restart()
    }

    function saveNow(silent) {
        persistDebounce.stop()
        if (saveInFlight) {
            persistQueued = true
            if (!silent)
                lastSaveWasSilent = false
            return
        }
        lastSaveWasSilent = !!silent
        pendingSaveContent = serializeMiscFile()
        const lastSlash = miscPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? miscPath.substring(0, lastSlash) : "."
        saveInFlight = true
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true
    }

    function reloadFromDisk() {
        writesEnabled = false
        persistDebounce.stop()
        persistQueued = false
        miscFile.reload()
    }

    Timer {
        id: persistDebounce

        interval: 400
        repeat: false

        onTriggered: {
            if (root.saveInFlight) {
                root.persistQueued = true
                return
            }
            root.saveNow(true)
        }
    }

    FileView {
        id: miscFile

        path: root.miscPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            root.writesEnabled = false
            root.parseMiscFile(text())
            Qt.callLater(() => {
                root.writesEnabled = true
            })
        }

        onLoadFailed: {
            root.writesEnabled = false
            root.parseMiscFile("")
            if (typeof ToastService !== "undefined")
                ToastService.showError("Could not read " + root.miscPath + " — using defaults")
            Qt.callLater(() => {
                root.writesEnabled = true
            })
        }
    }

    Process {
        id: ensureDirProcess

        command: ["mkdir", "-p"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.saveInFlight = false
                root.pendingSaveContent = ""
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Could not create config directory for misc.conf")
                return
            }
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", root.miscPath]
                touchFileProcess.running = true
            } else {
                root.saveInFlight = false
            }
        }
    }

    Process {
        id: touchFileProcess

        command: ["touch"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.saveInFlight = false
                root.pendingSaveContent = ""
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Could not prepare misc.conf for writing")
                return
            }
            if (pendingSaveContent !== "") {
                saveMiscFile.path = ""
                Qt.callLater(() => {
                    saveMiscFile.path = root.miscPath
                    Qt.callLater(() => {
                        saveMiscFile.setText(pendingSaveContent)
                    })
                })
            } else {
                root.saveInFlight = false
            }
        }
    }

    FileView {
        id: saveMiscFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango misc config")
            if (root.isMango)
                reloadMangoProcess.running = true
            if (persistQueued) {
                persistQueued = false
                Qt.callLater(() => root.schedulePersistAndReload())
            }
        }

        onSaveFailed: error => {
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined")
                ToastService.showError("Save failed: " + (error || "unknown"))
        }
    }

    Process {
        id: reloadMangoProcess

        command: ["mmsg", "dispatch", "reload_config"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0 && typeof ToastService !== "undefined")
                ToastService.showWarning("mmsg reload_config exited " + exitCode + " — restart Mango if settings did not apply")
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainCol.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainCol
            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: hintCol.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1
                visible: !isMango

                Column {
                    id: hintCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingS
                    StyledText {
                        text: "Edit $XDG_CONFIG_HOME/mango/hyprmango/misc.conf. XWayland persistence requires relogin. See https://github.com/mangowm/mango/wiki/Miscellaneous-Settings"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: headCol.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: headCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon {
                            name: "settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 4
                            StyledText {
                                text: "Miscellaneous"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: root.miscPath
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        StyledRect {
                            height: 32
                            radius: 8
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 1
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                EHIcon {
                                    name: "refresh"
                                    size: 16
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "Reload file"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            StateLayer {
                                stateColor: Theme.primary
                                cornerRadius: 8
                                onClicked: root.reloadFromDisk()
                            }
                        }
                        StyledRect {
                            height: 32
                            radius: 8
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 1
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                EHIcon {
                                    name: "save"
                                    size: 16
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: "Save now"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            StateLayer {
                                stateColor: Theme.primary
                                cornerRadius: 8
                                onClicked: root.saveNow(false)
                            }
                        }
                    }
                    StyledText {
                        text: "Auto-saves after edits; comments and unknown lines are kept."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: focusSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: focusSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "radar"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Focus behavior"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    EHToggle { width: parent.width; text: "Focus on activate"; checked: root.intToggleChecked("focus_on_activate"); onToggled: c => root.setDe("focus_on_activate", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Sloppy focus"; checked: root.intToggleChecked("sloppyfocus"); onToggled: c => root.setDe("sloppyfocus", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Warp cursor"; description: "Move cursor to focused window"; checked: root.intToggleChecked("warpcursor"); onToggled: c => root.setDe("warpcursor", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Focus cross monitor"; checked: root.intToggleChecked("focus_cross_monitor"); onToggled: c => root.setDe("focus_cross_monitor", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Focus cross tag"; checked: root.intToggleChecked("focus_cross_tag"); onToggled: c => root.setDe("focus_cross_tag", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Exchange cross monitor"; description: "Allow swapping windows across monitors"; checked: root.intToggleChecked("exchange_cross_monitor"); onToggled: c => root.setDe("exchange_cross_monitor", c ? "1" : "0") }
                }
            }

            StyledRect {
                width: parent.width
                height: windowSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: windowSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "window"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Window behavior"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    EHToggle { width: parent.width; text: "No border when single"; description: "Hide border on single window"; checked: root.intToggleChecked("no_border_when_single"); onToggled: c => root.setDe("no_border_when_single", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Idle inhibit ignore visible"; checked: root.intToggleChecked("idleinhibit_ignore_visible"); onToggled: c => root.setDe("idleinhibit_ignore_visible", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Drag tile to tile"; checked: root.intToggleChecked("drag_tile_to_tile"); onToggled: c => root.setDe("drag_tile_to_tile", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Drag tile small"; description: "Allow dragging tiled window to small size"; checked: root.intToggleChecked("drag_tile_small"); onToggled: c => root.setDe("drag_tile_small", c ? "1" : "0") }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Drag corner"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - root.labelWidth - Theme.spacingM; text: "Drag corner"; options: ["0", "1", "2", "3", "4"]; currentValue: root.gv("drag_corner"); onValueChanged: v => root.setDe("drag_corner", v) } }
                    EHToggle { width: parent.width; text: "Drag warp cursor"; description: "Warp cursor when dragging windows"; checked: root.intToggleChecked("drag_warp_cursor"); onToggled: c => root.setDe("drag_warp_cursor", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Enable floating snap"; checked: root.intToggleChecked("enable_floating_snap"); onToggled: c => root.setDe("enable_floating_snap", c ? "1" : "0") }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Snap distance"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("snap_distance", 30); minimum: 5; maximum: 100; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("snap_distance", String(Math.round(v))) } }
                    EHToggle { width: parent.width; text: "View current to back"; description: "Toggling current tag switches to previous"; checked: root.intToggleChecked("view_current_to_back"); onToggled: c => root.setDe("view_current_to_back", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Tag carousel"; description: "Enable tag carousel cycling"; checked: root.intToggleChecked("tag_carousel"); onToggled: c => root.setDe("tag_carousel", c ? "1" : "0") }
                }
            }

            StyledRect {
                width: parent.width
                height: dragSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: dragSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "swap_hor"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Drag refresh"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Tile drag refresh interval"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("drag_tile_refresh_interval", 8.0); minimum: 1; maximum: 16; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("drag_tile_refresh_interval", String(Math.round(v))) } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Floating drag refresh interval"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("drag_floating_refresh_interval", 8.0); minimum: 1; maximum: 16; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("drag_floating_refresh_interval", String(Math.round(v))) } }
                }
            }

            StyledRect {
                width: parent.width
                height: cursorSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: cursorSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "mouse"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Cursor"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Axis bind timeout"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("axis_bind_apply_timeout", 100); minimum: 10; maximum: 500; unit: "ms"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("axis_bind_apply_timeout", String(Math.round(v))) } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Cursor hide timeout (s)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("cursor_hide_timeout", 0); minimum: 0; maximum: 30; unit: "s"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("cursor_hide_timeout", String(Math.round(v))) } }
                    EHToggle { width: parent.width; text: "Cursor hide on keypress"; checked: root.intToggleChecked("cursor_hide_on_keypress"); onToggled: c => root.setDe("cursor_hide_on_keypress", c ? "1" : "0") }
                }
            }

            StyledRect {
                width: parent.width
                height: overviewSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: overviewSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "space_dashboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Overview"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Hotarea size"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("hotarea_size", 10); minimum: 1; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("hotarea_size", String(Math.round(v))) } }
                    EHToggle { width: parent.width; text: "Enable hotarea"; description: "Show overview when cursor at screen edge"; checked: root.intToggleChecked("enable_hotarea"); onToggled: c => root.setDe("enable_hotarea", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Overview tab mode"; checked: root.intToggleChecked("ov_tab_mode"); onToggled: c => root.setDe("ov_tab_mode", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Disable resize in overview"; description: "ov_no_resize — use snap to display instead"; checked: root.intToggleChecked("ov_no_resize"); onToggled: c => root.setDe("ov_no_resize", c ? "1" : "0") }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Overview gap inner"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("overviewgappi", 5); minimum: 0; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("overviewgappi", String(Math.round(v))) } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Overview gap outer"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("overviewgappo", 30); minimum: 0; maximum: 100; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("overviewgappo", String(Math.round(v))) } }
                }
            }

            StyledRect {
                width: parent.width
                height: scratchpadSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: scratchpadSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "flip_to_back"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Scratchpad"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    EHToggle { width: parent.width; text: "Scratchpad cross monitor"; description: "Share scratchpad pool across all monitors"; checked: root.intToggleChecked("scratchpad_cross_monitor"); onToggled: c => root.setDe("scratchpad_cross_monitor", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Single scratchpad"; description: "Only allow one scratchpad visible at a time"; checked: root.intToggleChecked("single_scratchpad"); onToggled: c => root.setDe("single_scratchpad", c ? "1" : "0") }
                }
            }

            StyledRect {
                width: parent.width
                height: securitySec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: securitySec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "security"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Security & system"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    EHToggle { width: parent.width; text: "Allow lock transparent"; description: "Allow the lock screen to be transparent"; checked: root.intToggleChecked("allow_lock_transparent"); onToggled: c => root.setDe("allow_lock_transparent", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Allow shortcuts inhibit"; description: "Allow shortcuts to be inhibited by clients"; checked: root.intToggleChecked("allow_shortcuts_inhibit"); onToggled: c => root.setDe("allow_shortcuts_inhibit", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Syncobj enable"; description: "Enable drm_syncobj timeline support (requires restart)"; checked: root.intToggleChecked("syncobj_enable"); onToggled: c => root.setDe("syncobj_enable", c ? "1" : "0") }
                }
            }

            StyledRect {
                width: parent.width
                height: xwaylandSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: xwaylandSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "desktop_windows"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "XWayland"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    StyledText { text: "XWayland persistence requires relogin to apply."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    EHToggle { width: parent.width; text: "XWayland persistence"; description: "Persist XWayland windows across sessions"; checked: root.intToggleChecked("xwayland_persistence"); onToggled: c => root.setDe("xwayland_persistence", c ? "1" : "0") }
                }
            }
        }
    }
}