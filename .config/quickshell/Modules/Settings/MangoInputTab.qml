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

    readonly property string inputPath: _configBase + "/mango/hyprmango/input.conf"

    property var inputSegments: []
    property var deco: ({})
    property string pendingSaveContent: ""
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true
    property bool writesEnabled: false

    // https://github.com/mangowm/mango/wiki/input
    readonly property var managedInputKeys: ["repeat_rate", "repeat_delay", "numlockon", "xkb_rules_rules", "xkb_rules_model", "xkb_rules_layout", "xkb_rules_variant", "xkb_rules_options", "disable_trackpad", "tap_to_click", "tap_and_drag", "trackpad_natural_scrolling", "trackpad_accel_profile", "trackpad_accel_speed", "trackpad_scroll_factor", "scroll_button", "scroll_method", "click_method", "drag_lock", "disable_while_typing", "left_handed", "middle_button_emulation", "swipe_min_threshold", "button_map", "send_events_mode", "mouse_natural_scrolling", "mouse_accel_profile", "mouse_accel_speed", "axis_scroll_factor"]

    readonly property var defaultDeco: ({
            "repeat_rate": "25", "repeat_delay": "600", "numlockon": "0", "xkb_rules_rules": "", "xkb_rules_model": "", "xkb_rules_layout": "us", "xkb_rules_variant": "", "xkb_rules_options": "", "disable_trackpad": "0", "tap_to_click": "1", "tap_and_drag": "1", "trackpad_natural_scrolling": "0", "trackpad_accel_profile": "2", "trackpad_accel_speed": "0.0", "trackpad_scroll_factor": "1.0", "scroll_button": "274", "scroll_method": "1", "click_method": "1", "drag_lock": "1", "disable_while_typing": "1", "left_handed": "0", "middle_button_emulation": "0", "swipe_min_threshold": "1", "button_map": "0", "send_events_mode": "0", "mouse_natural_scrolling": "0", "mouse_accel_profile": "2", "mouse_accel_speed": "0.0", "axis_scroll_factor": "1.0"
        })

    function makeDefaultInputSegments() {
        const s = [
            { type: "line", raw: "# Input — https://github.com/mangowm/mango/wiki/input" },
            { type: "line", raw: "" },
            { type: "line", raw: "# Keyboard" },
            { type: "line", raw: "" }
        ]
        const order = ["repeat_rate", "repeat_delay", "numlockon", "xkb_rules_rules", "xkb_rules_model", "xkb_rules_layout", "xkb_rules_variant", "xkb_rules_options"]
        for (let i = 0; i < order.length; i++)
            s.push({ type: "kv", key: order[i] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Trackpad" })
        s.push({ type: "line", raw: "" })
        const track = ["disable_trackpad", "tap_to_click", "tap_and_drag", "trackpad_natural_scrolling", "trackpad_accel_profile", "trackpad_accel_speed", "trackpad_scroll_factor", "scroll_button", "scroll_method", "click_method", "drag_lock", "disable_while_typing", "left_handed", "middle_button_emulation", "swipe_min_threshold", "button_map"]
        for (let j = 0; j < track.length; j++)
            s.push({ type: "kv", key: track[j] })
        s.push({ type: "line", raw: "" })
        s.push({ type: "line", raw: "# Mouse" })
        s.push({ type: "line", raw: "" })
        const mouse = ["mouse_natural_scrolling", "mouse_accel_profile", "mouse_accel_speed", "axis_scroll_factor", "send_events_mode"]
        for (let k = 0; k < mouse.length; k++)
            s.push({ type: "kv", key: mouse[k] })
        return s
    }

    function parseInputFile(text) {
        if (!text || !String(text).trim()) {
            inputSegments = makeDefaultInputSegments()
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
                if (managedInputKeys.indexOf(key) >= 0) {
                    segs.push({ type: "kv", key: key })
                    d[key] = val
                    continue
                }
            }
            segs.push({ type: "line", raw: raw })
        }
        inputSegments = segs
        deco = d
    }

    function serializeInputFile() {
        const d = deco
        return inputSegments.map(seg => {
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
        pendingSaveContent = serializeInputFile()
        const lastSlash = inputPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? inputPath.substring(0, lastSlash) : "."
        saveInFlight = true
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true
    }

    function reloadFromDisk() {
        writesEnabled = false
        persistDebounce.stop()
        persistQueued = false
        inputFile.reload()
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
        id: inputFile

        path: root.inputPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            root.writesEnabled = false
            root.parseInputFile(text())
            Qt.callLater(() => {
                root.writesEnabled = true
            })
        }

        onLoadFailed: {
            root.writesEnabled = false
            root.parseInputFile("")
            if (typeof ToastService !== "undefined")
                ToastService.showError("Could not read " + root.inputPath + " — using defaults")
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
                    ToastService.showError("Could not create config directory for input.conf")
                return
            }
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", root.inputPath]
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
                    ToastService.showError("Could not prepare input.conf for writing")
                return
            }
            if (pendingSaveContent !== "") {
                saveInputFile.path = ""
                Qt.callLater(() => {
                    saveInputFile.path = root.inputPath
                    Qt.callLater(() => {
                        saveInputFile.setText(pendingSaveContent)
                    })
                })
            } else {
                root.saveInFlight = false
            }
        }
    }

    FileView {
        id: saveInputFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango input config")
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
                        text: "Edit $XDG_CONFIG_HOME/mango/hyprmango/input.conf. Some trackpad changes may need a relogin. IME (Fcitx/IBus) belongs in env.conf."
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
                            name: "mouse"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 4
                            StyledText {
                                text: "Input"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: root.inputPath
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

            // ── Keyboard ──
            StyledRect {
                width: parent.width
                height: kbSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: kbSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "keyboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Keyboard"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS; StyledText { text: "Repeat rate (keys/sec)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("repeat_rate", 25); minimum: 1; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("repeat_rate", String(Math.round(v))) } }
                        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS; StyledText { text: "Repeat delay (ms)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("repeat_delay", 600); minimum: 100; maximum: 2000; unit: "ms"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("repeat_delay", String(Math.round(v))) } }
                    }
                    EHToggle { width: parent.width; text: "Numlock on at startup"; checked: root.intToggleChecked("numlockon"); onToggled: c => root.setDe("numlockon", c ? "1" : "0") }
                    MInpText { width: parent.width; label: "XKB rules file"; valueText: root.gv("xkb_rules_rules"); placeholderText: "e.g. evdev"; onCommit: t => root.setDe("xkb_rules_rules", t.trim()) }
                    MInpText { width: parent.width; label: "XKB model"; valueText: root.gv("xkb_rules_model"); placeholderText: "e.g. pc104"; onCommit: t => root.setDe("xkb_rules_model", t.trim()) }
                    MInpText { width: parent.width; label: "XKB layout"; valueText: root.gv("xkb_rules_layout"); placeholderText: "e.g. us,de"; onCommit: t => root.setDe("xkb_rules_layout", t.trim()) }
                    MInpText { width: parent.width; label: "XKB variant"; valueText: root.gv("xkb_rules_variant"); placeholderText: "e.g. ,dvorak"; onCommit: t => root.setDe("xkb_rules_variant", t.trim()) }
                    MInpText { width: parent.width; label: "XKB options"; valueText: root.gv("xkb_rules_options"); placeholderText: "e.g. grp:alt_shift_toggle"; onCommit: t => root.setDe("xkb_rules_options", t.trim()) }
                }
            }

            // ── Trackpad ──
            StyledRect {
                width: parent.width
                height: tpSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: tpSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "touch_app"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Trackpad"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    StyledText { text: "May require relogin to apply."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    EHToggle { width: parent.width; text: "Disable trackpad"; checked: root.intToggleChecked("disable_trackpad"); onToggled: c => root.setDe("disable_trackpad", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Tap to click"; checked: root.intToggleChecked("tap_to_click"); onToggled: c => root.setDe("tap_to_click", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Tap and drag"; checked: root.intToggleChecked("tap_and_drag"); onToggled: c => root.setDe("tap_and_drag", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Natural scrolling (trackpad)"; checked: root.intToggleChecked("trackpad_natural_scrolling"); onToggled: c => root.setDe("trackpad_natural_scrolling", c ? "1" : "0") }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Trackpad accel profile"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "Profile"; options: ["0", "1", "2"]; currentValue: root.gv("trackpad_accel_profile"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("trackpad_accel_profile", v) } } }
                    MInpText { width: parent.width; label: "Trackpad accel speed (-1.0 .. 1.0)"; valueText: root.gv("trackpad_accel_speed"); placeholderText: "0.0"; onCommit: t => root.setDe("trackpad_accel_speed", t.trim()) }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Trackpad scroll factor"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("trackpad_scroll_factor", 1.0); minimum: 0.1; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("trackpad_scroll_factor", String(v.toFixed(1))) } }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Scroll button (272–279)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("scroll_button", 274); minimum: 272; maximum: 279; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("scroll_button", String(Math.round(v))) } }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Scroll method"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 120; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 120 - Theme.spacingM; text: "Method"; options: ["0", "1", "2", "4"]; currentValue: root.gv("scroll_method"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("scroll_method", v) } } }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Click method"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 120; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 120 - Theme.spacingM; text: "Click"; options: ["0", "1", "2"]; currentValue: root.gv("click_method"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("click_method", v) } } }
                    EHToggle { width: parent.width; text: "Drag lock"; description: "Keep dragging after tap"; checked: root.intToggleChecked("drag_lock"); onToggled: c => root.setDe("drag_lock", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Disable while typing"; checked: root.intToggleChecked("disable_while_typing"); onToggled: c => root.setDe("disable_while_typing", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Left handed (buttons)"; description: "Swap left/right; shared with pointer devices"; checked: root.intToggleChecked("left_handed"); onToggled: c => root.setDe("left_handed", c ? "1" : "0") }
                    EHToggle { width: parent.width; text: "Middle button emulation"; checked: root.intToggleChecked("middle_button_emulation"); onToggled: c => root.setDe("middle_button_emulation", c ? "1" : "0") }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Swipe minimum threshold"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("swipe_min_threshold", 1); minimum: 1; maximum: 200; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("swipe_min_threshold", String(Math.round(v))) } }
                }
            }

            // ── Mouse ──
            StyledRect {
                width: parent.width
                height: moSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                Column {
                    id: moSec
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    Row { width: parent.width; spacing: Theme.spacingM; EHIcon { name: "sensors"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter } StyledText { text: "Mouse"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter } }
                    EHToggle { width: parent.width; text: "Natural scrolling (mouse)"; checked: root.intToggleChecked("mouse_natural_scrolling"); onToggled: c => root.setDe("mouse_natural_scrolling", c ? "1" : "0") }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Mouse accel profile"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "Profile"; options: ["0", "1", "2"]; currentValue: root.gv("mouse_accel_profile"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("mouse_accel_profile", v) } } }
                    MInpText { width: parent.width; label: "Mouse accel speed (-1.0 .. 1.0)"; valueText: root.gv("mouse_accel_speed"); placeholderText: "0.0"; onCommit: t => root.setDe("mouse_accel_speed", t.trim()) }
                    Column { width: parent.width; spacing: Theme.spacingS; StyledText { text: "Axis scroll factor"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText } EHSlider { width: parent.width; height: 24; value: root.numKey("axis_scroll_factor", 1.0); minimum: 0.1; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => root.setDe("axis_scroll_factor", String(v.toFixed(1))) } }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Send events mode"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "Mode"; options: ["0", "1", "2"]; currentValue: root.gv("send_events_mode"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("send_events_mode", v) } } }
                    Row { width: parent.width; spacing: Theme.spacingM; StyledText { text: "Button map (tap)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; width: 140; anchors.verticalCenter: parent.verticalCenter } EHDropdown { width: parent.width - 140 - Theme.spacingM; text: "Map"; options: ["0", "1"]; currentValue: root.gv("button_map"); onValueChanged: v => { if (root.writesEnabled && v) root.setDe("button_map", v) } } }
                }
            }
        }
    }

    component MInpText: Column {
        id: mIt
        property string label: ""
        property string valueText: ""
        property string placeholderText: ""
        signal commit(string t)
        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS
        StyledText { text: mIt.label; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHTextField { width: parent.width; text: mIt.valueText; placeholderText: mIt.placeholderText; onEditingFinished: mIt.commit(text) }
    }
}
