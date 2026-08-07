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

    readonly property string layoutPath: _configBase + "/mango/hyprmango/layout.conf"

    property var layoutSegments: []
    property var deco: ({})
    property string pendingSaveContent: ""
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true
    property bool writesEnabled: false

    readonly property var managedLayoutKeys: ["scroller_structs", "scroller_default_proportion", "scroller_focus_center", "scroller_prefer_center", "scroller_prefer_overspread", "edge_scroller_pointer_focus", "edge_scroller_focus_allow_speed", "scroller_default_proportion_single", "scroller_ignore_proportion_single", "scroller_proportion_preset", "new_is_master", "default_mfact", "default_nmaster", "smartgaps", "center_master_overspread", "center_when_single_stack", "dwindle_split_ratio", "dwindle_smart_split", "dwindle_hsplit", "dwindle_vsplit", "dwindle_preserve_split", "dwindle_smart_resize", "dwindle_drop_simple_split", "dwindle_manual_split", "circle_layout"]

    readonly property var defaultDeco: ({
            "scroller_structs": "20", "scroller_default_proportion": "0.9", "scroller_focus_center": "0", "scroller_prefer_center": "0", "scroller_prefer_overspread": "1", "edge_scroller_pointer_focus": "1", "edge_scroller_focus_allow_speed": "0.0", "scroller_default_proportion_single": "1.0", "scroller_ignore_proportion_single": "1", "scroller_proportion_preset": "0.5,0.8,1.0", "new_is_master": "1", "default_mfact": "0.55", "default_nmaster": "1", "smartgaps": "0", "center_master_overspread": "0", "center_when_single_stack": "1", "dwindle_split_ratio": "0.5", "dwindle_smart_split": "0", "dwindle_hsplit": "1", "dwindle_vsplit": "1", "dwindle_preserve_split": "0", "dwindle_smart_resize": "0", "dwindle_drop_simple_split": "1", "dwindle_manual_split": "0", "circle_layout": ""
        })

    readonly property var layoutNameOptions: ["tile", "scroller", "monocle", "grid", "deck", "center_tile", "vertical_tile", "right_tile", "vertical_scroller", "vertical_grid", "vertical_deck", "dwindle", "fair", "vertical_fair", "tgmix"]

    function makeDefaultLayoutSegments() {
        const s = [
            { type: "line", raw: "# Layout configuration" },
            { type: "line", raw: "" },
            { type: "line", raw: "# Scrolling / tiling" },
            { type: "line", raw: "" }
        ]
        for (let i = 0; i < managedLayoutKeys.length; i++) {
            const k = managedLayoutKeys[i]
            s.push({ type: "kv", key: k })
        }
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Tag rules — default layout per tag" })
        s.push({ type: "line", raw: "" })
        for (let t = 1; t <= 9; t++)
            s.push({ type: "tagrule", id: t, layoutName: "tile" })
        return s
    }

    function parseLayoutFile(text) {
        if (!text || !String(text).trim()) {
            layoutSegments = makeDefaultLayoutSegments()
            deco = Object.assign({}, defaultDeco)
            return
        }
        const lines = String(text).split("\n")
        const segs = []
        const d = Object.assign({}, defaultDeco)
        const tr = /^tagrule=id:(\d+),layout_name:(.+)$/
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
            const tm = t.match(tr)
            if (tm) {
                segs.push({ type: "tagrule", id: parseInt(tm[1], 10), layoutName: tm[2].trim() })
                continue
            }
            const km = t.match(kvRe)
            if (km) {
                const key = km[1]
                const val = km[2].trim()
                if (managedLayoutKeys.indexOf(key) >= 0) {
                    segs.push({ type: "kv", key: key })
                    d[key] = val
                    continue
                }
            }
            segs.push({ type: "line", raw: raw })
        }
        layoutSegments = segs
        deco = d
    }

    function serializeLayoutFile() {
        const d = deco
        return layoutSegments.map(seg => {
            if (seg.type === "line")
                return seg.raw
            if (seg.type === "kv") {
                const k = seg.key
                const v = d[k] !== undefined && d[k] !== null ? String(d[k]) : (defaultDeco[k] || "")
                return k + " = " + v
            }
            if (seg.type === "tagrule")
                return "tagrule=id:" + seg.id + ",layout_name:" + seg.layoutName
            return ""
        }).join("\n")
    }

    function gv(k) {
        if (deco[k] !== undefined && deco[k] !== null && String(deco[k]).length > 0)
            return deco[k]
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

    function setTagLayout(tagId, layoutName) {
        const name = String(layoutName || "tile").trim()
        const copy = layoutSegments.slice()
        let found = false
        for (let i = 0; i < copy.length; i++) {
            if (copy[i].type === "tagrule" && copy[i].id === tagId) {
                copy[i] = Object.assign({}, copy[i], { layoutName: name })
                found = true
                break
            }
        }
        if (!found)
            copy.push({ type: "tagrule", id: tagId, layoutName: name })
        layoutSegments = copy
        schedulePersistAndReload()
    }

    function tagLayoutName(tagId) {
        for (let i = 0; i < layoutSegments.length; i++) {
            const s = layoutSegments[i]
            if (s.type === "tagrule" && s.id === tagId)
                return s.layoutName || "tile"
        }
        return "tile"
    }

    function layoutNameOptionsForTag(tagId) {
        const cur = String(tagLayoutName(tagId) || "tile")
        if (layoutNameOptions.indexOf(cur) >= 0)
            return layoutNameOptions
        return [cur].concat(layoutNameOptions)
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
        pendingSaveContent = serializeLayoutFile()
        const lastSlash = layoutPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? layoutPath.substring(0, lastSlash) : "."
        saveInFlight = true
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true
    }

    function reloadFromDisk() {
        writesEnabled = false
        persistDebounce.stop()
        persistQueued = false
        layoutFile.reload()
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
        id: layoutFile

        path: root.layoutPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            root.writesEnabled = false
            root.parseLayoutFile(text())
            Qt.callLater(() => {
                root.writesEnabled = true
            })
        }

        onLoadFailed: {
            root.writesEnabled = false
            root.parseLayoutFile("")
            if (typeof ToastService !== "undefined")
                ToastService.showError("Could not read " + root.layoutPath + " — using defaults")
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
                    ToastService.showError("Could not create config directory for layout.conf")
                return
            }
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", root.layoutPath]
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
                    ToastService.showError("Could not prepare layout.conf for writing")
                return
            }
            if (pendingSaveContent !== "") {
                saveLayoutFile.path = ""
                Qt.callLater(() => {
                    saveLayoutFile.path = root.layoutPath
                    Qt.callLater(() => {
                        saveLayoutFile.setText(pendingSaveContent)
                    })
                })
            } else {
                root.saveInFlight = false
            }
        }
    }

    FileView {
        id: saveLayoutFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango layout config")
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
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn

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
                        text: "Edit layouts for $XDG_CONFIG_HOME/mango/hyprmango/layout.conf. Save writes the file; reload_config runs when Mango is active."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // Header row: path + actions
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
                            name: "grid_view"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 4
                            StyledText {
                                text: "Layout"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: root.layoutPath
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
                                EHIcon { name: "refresh"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Reload file"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
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
                                EHIcon { name: "save"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Save now"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            StateLayer {
                                stateColor: Theme.primary
                                cornerRadius: 8
                                onClicked: root.saveNow(false)
                            }
                        }
                    }

                    StyledText {
                        text: "Changes auto-save after a short pause. Comments and unknown lines in layout.conf are preserved."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // ━━━ Scroller ━━━
            StyledRect {
                width: parent.width
                height: scrollSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: scrollSec
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "view_week"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Scroller layout"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        StyledText { text: "Scroller structs"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: root.numKey("scroller_structs", 20)
                            minimum: 1; maximum: 64; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("scroller_structs", String(Math.round(v)))
                        }
                    }

                    MLayoutFloat {
                        width: parent.width; label: "Default proportion (width ratio)"
                        valueText: root.gv("scroller_default_proportion")
                        onCommit: t => root.setDe("scroller_default_proportion", t)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Focus center"
                        description: "Keep the focused window centered in the scroller"
                        checked: root.intToggleChecked("scroller_focus_center")
                        onToggled: c => root.setDe("scroller_focus_center", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Prefer center"
                        description: "Center when the focused window was off-screen"
                        checked: root.intToggleChecked("scroller_prefer_center")
                        onToggled: c => root.setDe("scroller_prefer_center", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Edge pointer focus"
                        description: "Focus windows under the pointer at screen edges"
                        checked: root.intToggleChecked("edge_scroller_pointer_focus")
                        onToggled: c => root.setDe("edge_scroller_pointer_focus", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Prefer overspread"
                        description: "Allow windows to overspread with extra space (priority > focus_center)"
                        checked: root.intToggleChecked("scroller_prefer_overspread")
                        onToggled: c => root.setDe("scroller_prefer_overspread", c ? "1" : "0")
                    }
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Edge pointer focus speed threshold"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: root.numKey("edge_scroller_focus_allow_speed", 0.0)
                            minimum: 0; maximum: 1; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("edge_scroller_focus_allow_speed", String(v.toFixed(1)))
                        }
                    }
                    EHToggle {
                        width: parent.width
                        text: "Ignore proportion for single window"
                        checked: root.intToggleChecked("scroller_ignore_proportion_single")
                        onToggled: c => root.setDe("scroller_ignore_proportion_single", c ? "1" : "0")
                    }
                    MLayoutFloat {
                        width: parent.width; label: "Single-window proportion"
                        valueText: root.gv("scroller_default_proportion_single")
                        onCommit: t => root.setDe("scroller_default_proportion_single", t)
                    }
                    MLayoutText {
                        width: parent.width; label: "Proportion presets (comma-separated)"
                        valueText: root.gv("scroller_proportion_preset")
                        onCommit: t => root.setDe("scroller_proportion_preset", t.trim())
                    }
                }
            }

            // ━━━ Master / tile ━━━
            StyledRect {
                width: parent.width
                height: masterSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: masterSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "splitscreen"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Master stack (tile and similar)"
                            font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "New window is master"
                        checked: root.intToggleChecked("new_is_master")
                        onToggled: c => root.setDe("new_is_master", c ? "1" : "0")
                    }
                    MLayoutFloat {
                        width: parent.width; label: "Master factor (mfact)"
                        valueText: root.gv("default_mfact")
                        onCommit: t => root.setDe("default_mfact", t)
                    }
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Nmaster"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: root.numKey("default_nmaster", 1)
                            minimum: 1; maximum: 8; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("default_nmaster", String(Math.round(v)))
                        }
                    }
                    EHToggle {
                        width: parent.width
                        text: "Smart gaps"
                        checked: root.intToggleChecked("smartgaps")
                        onToggled: c => root.setDe("smartgaps", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Center master overspread"
                        description: "Center tile: master spreads if no stack exists"
                        checked: root.intToggleChecked("center_master_overspread")
                        onToggled: c => root.setDe("center_master_overspread", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Center when single stack"
                        description: "Center tile: center master when only one stack window"
                        checked: root.intToggleChecked("center_when_single_stack")
                        onToggled: c => root.setDe("center_when_single_stack", c ? "1" : "0")
                    }
                }
            }

            // ━━━ Dwindle ━━━
            StyledRect {
                width: parent.width
                height: dwindleSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dwindleSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "pivot_table_chart"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Dwindle layout"
                            font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Split ratio (0.05–0.95)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: root.numKey("dwindle_split_ratio", 0.5)
                            minimum: 0.05; maximum: 0.95; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("dwindle_split_ratio", String(v.toFixed(2)))
                        }
                    }
                    EHToggle {
                        width: parent.width
                        text: "Smart split"
                        description: "Pick split axis from cursor position"
                        checked: root.intToggleChecked("dwindle_smart_split")
                        onToggled: c => root.setDe("dwindle_smart_split", c ? "1" : "0")
                    }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Horizontal split"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "hsplit"; options: ["0", "1", "2"]; currentValue: root.gv("dwindle_hsplit"); onValueChanged: v => root.setDe("dwindle_hsplit", v) } }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Vertical split"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "vsplit"; options: ["0", "1", "2"]; currentValue: root.gv("dwindle_vsplit"); onValueChanged: v => root.setDe("dwindle_vsplit", v) } }
                    EHToggle {
                        width: parent.width
                        text: "Preserve split"
                        description: "Keep sibling split orientation on close"
                        checked: root.intToggleChecked("dwindle_preserve_split")
                        onToggled: c => root.setDe("dwindle_preserve_split", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Smart resize"
                        description: "Drag-to-tile resize toward cursor"
                        checked: root.intToggleChecked("dwindle_smart_resize")
                        onToggled: c => root.setDe("dwindle_smart_resize", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Drop simple split"
                        description: "Drag-to-tile: 2-zone vs 4-quadrant preview"
                        checked: root.intToggleChecked("dwindle_drop_simple_split")
                        onToggled: c => root.setDe("dwindle_drop_simple_split", c ? "1" : "0")
                    }
                    EHToggle {
                        width: parent.width
                        text: "Manual split"
                        checked: root.intToggleChecked("dwindle_manual_split")
                        onToggled: c => root.setDe("dwindle_manual_split", c ? "1" : "0")
                    }
                }
            }

            // ━━━ Layout cycling ━━━
            StyledRect {
                width: parent.width
                height: cycleSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: cycleSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "repeat"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "Layout cycling"
                            font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MLayoutText {
                        width: parent.width; label: "circle_layout (comma-separated, e.g. tile,scroller,grid)"
                        valueText: root.gv("circle_layout")
                        onCommit: t => root.setDe("circle_layout", t.trim())
                    }
                }
            }

            // ━━━ Tag default layouts ━━━
            StyledRect {
                width: parent.width
                height: tagSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: tagSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "view_carousel"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 4
                            StyledText { text: "Tag default layouts"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "tagrule=id:N,layout_name:… — per-tag layout when you switch to that tag."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }

                    Repeater {
                        model: 9
                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            required property int index
                            property int tagNum: index + 1
                            height: 52

                            StyledText {
                                text: "Tag " + parent.tagNum
                                width: 64
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            EHDropdown {
                                id: tagLayoutDd
                                width: Math.min(280, parent.width - 64 - Theme.spacingM)
                                text: "Layout"
                                options: root.layoutNameOptionsForTag(parent.tagNum)
                                currentValue: root.tagLayoutName(parent.tagNum)

                                onValueChanged: v => {
                                    if (!root.writesEnabled)
                                        return
                                    if (v && v.length)
                                        root.setTagLayout(parent.tagNum, v)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MLayoutFloat: Column {
        id: mlf
        property string label: ""
        property string valueText: ""
        signal commit(string t)
        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS
        StyledText { text: mlf.label; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHTextField { width: parent.width; text: mlf.valueText; onEditingFinished: mlf.commit(text) }
    }

    component MLayoutText: Column {
        id: mlt
        property string label: ""
        property string valueText: ""
        signal commit(string t)
        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS
        StyledText { text: mlt.label; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHTextField { width: parent.width; text: mlt.valueText; onEditingFinished: mlt.commit(text) }
    }
}
