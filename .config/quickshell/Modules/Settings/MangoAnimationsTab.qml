import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Settings

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

    readonly property string animationsPath: _configBase + "/mango/hyprmango/animations.conf"

    property var deco: ({})
    property string baseFileText: ""
    property string pendingSaveContent: ""
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true
    property bool suppressBezierWrite: false
    property bool writesEnabled: false
    property string editingCurveKey: "animation_curve_open"

    readonly property var managedKeys: ["animations", "layer_animations", "animation_type_open", "animation_type_close", "layer_animation_type_open", "layer_animation_type_close", "animation_fade_in", "animation_fade_out", "tag_animation_direction", "zoom_initial_ratio", "zoom_end_ratio", "fadein_begin_opacity", "fadeout_begin_opacity", "animation_duration_move", "animation_duration_open", "animation_duration_tag", "animation_duration_close", "animation_duration_focus", "animation_curve_open", "animation_curve_move", "animation_curve_tag", "animation_curve_close", "animation_curve_focus", "animation_curve_opafadeout", "animation_curve_opafadein"]

    readonly property var defaultDeco: ({
            "animations": "1", "layer_animations": "1", "animation_type_open": "slide", "animation_type_close": "slide", "layer_animation_type_open": "slide", "layer_animation_type_close": "slide", "animation_fade_in": "1", "animation_fade_out": "1", "tag_animation_direction": "1", "zoom_initial_ratio": "0.4", "zoom_end_ratio": "0.8", "fadein_begin_opacity": "0.5", "fadeout_begin_opacity": "0.5", "animation_duration_move": "500", "animation_duration_open": "400", "animation_duration_tag": "300", "animation_duration_close": "300", "animation_duration_focus": "0", "animation_curve_open": "0.46,1.0,0.29,0.99", "animation_curve_move": "0.46,1.0,0.29,0.99", "animation_curve_tag": "0.46,1.0,0.29,0.99", "animation_curve_close": "0.46,1.0,0.29,0.99", "animation_curve_focus": "0.46,1.0,0.29,0.99", "animation_curve_opafadeout": "0.5,0.5,0.5,0.5", "animation_curve_opafadein": "0.46,1.0,0.29,0.99"
        })

    readonly property var curveTargetLabels: ["Open", "Move", "Tag", "Close", "Focus", "Opacity fade out", "Opacity fade in"]

    readonly property var windowAnimTypePresets: ["slide", "zoom", "fade", "none"]

    function windowAnimTypeOptionsForKey(key) {
        const base = windowAnimTypePresets
        const raw = String(gv(key) || "").trim()
        if (!raw)
            return base
        const lv = raw.toLowerCase()
        for (let i = 0; i < base.length; i++) {
            if (base[i] === lv)
                return base
        }
        return [raw].concat(base)
    }

    function windowAnimTypeCurrentValue(key) {
        const raw = String(gv(key) || "").trim()
        if (!raw)
            return "slide"
        const lv = raw.toLowerCase()
        const base = windowAnimTypePresets
        for (let i = 0; i < base.length; i++) {
            if (base[i] === lv)
                return lv
        }
        return raw
    }

    function curveKeyForLabel(label) {
        const m = {
            "Open": "animation_curve_open",
            "Move": "animation_curve_move",
            "Tag": "animation_curve_tag",
            "Close": "animation_curve_close",
            "Focus": "animation_curve_focus",
            "Opacity fade out": "animation_curve_opafadeout",
            "Opacity fade in": "animation_curve_opafadein"
        }
        return m[label] || "animation_curve_open"
    }

    function labelForCurveKey(key) {
        const m = {
            "animation_curve_open": "Open",
            "animation_curve_move": "Move",
            "animation_curve_tag": "Tag",
            "animation_curve_close": "Close",
            "animation_curve_focus": "Focus",
            "animation_curve_opafadeout": "Opacity fade out",
            "animation_curve_opafadein": "Opacity fade in"
        }
        return m[key] || "Open"
    }

    function escapeRe(s) {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function setKeyLine(text, key, value) {
        const lines = text.split("\n")
        const re = new RegExp("^\\s*" + escapeRe(key) + "\\s*=")
        let found = false
        for (let i = 0; i < lines.length; i++) {
            if (re.test(lines[i])) {
                lines[i] = key + " = " + value
                found = true
            }
        }
        if (!found)
            lines.push(key + " = " + value)
        return lines.join("\n")
    }

    function buildSaveText() {
        let t = baseFileText.length > 0 ? baseFileText : "# mango animations.conf\n"
        for (let i = 0; i < managedKeys.length; i++) {
            const k = managedKeys[i]
            if (deco[k] !== undefined && deco[k] !== null && String(deco[k]).length > 0)
                t = setKeyLine(t, k, String(deco[k]))
        }
        return t
    }

    function parseConf(text) {
        const out = Object.assign({}, defaultDeco)
        const lines = (text || "").split("\n")
        const keyRe = /^\s*([^#=\s]+)\s*=\s*(.*)$/
        for (let li = 0; li < lines.length; li++) {
            const line = lines[li].trim()
            if (!line || line.startsWith("#"))
                continue
            const m = line.match(keyRe)
            if (!m)
                continue
            const k = m[1]
            const v = m[2].trim()
            if (managedKeys.indexOf(k) >= 0)
                out[k] = v
        }
        return out
    }

    function setDe(k, v) {
        const c = Object.assign({}, deco)
        c[k] = String(v)
        deco = c
        schedulePersistAndReload()
    }

    function schedulePersistAndReload() {
        if (!isMango)
            return
        if (saveInFlight) {
            persistQueued = true
            return
        }
        persistDebounce.restart()
    }

    function saveNow(silent) {
        if (!isMango) {
            if (typeof ToastService !== "undefined")
                ToastService.showWarning("MangoWM not detected")
            return
        }
        persistDebounce.stop()
        if (saveInFlight) {
            persistQueued = true
            if (!silent)
                lastSaveWasSilent = false
            return
        }
        lastSaveWasSilent = !!silent
        pendingSaveContent = buildSaveText()
        const lastSlash = animationsPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? animationsPath.substring(0, lastSlash) : "."
        saveInFlight = true
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true
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

    function formatCurve(x1, y1, x2, y2) {
        return x1.toFixed(3) + "," + y1.toFixed(3) + "," + x2.toFixed(3) + "," + y2.toFixed(3)
    }

    function loadCurveIntoCanvas(key) {
        const s = gv(key)
        const p = (s || "").split(",")
        let x1 = 0.46, y1 = 1.0, x2 = 0.29, y2 = 1.0
        if (p.length >= 4) {
            const a = parseFloat(p[0]), b = parseFloat(p[1]), c = parseFloat(p[2]), d = parseFloat(p[3])
            if (!isNaN(a))
                x1 = a
            if (!isNaN(b))
                y1 = b
            if (!isNaN(c))
                x2 = c
            if (!isNaN(d))
                y2 = d
        }
        suppressBezierWrite = true
        bezierCanvas.setPoints(x1, y1, x2, y2)
        animationPreview.setPoints(x1, y1, x2, y2)
        animationPreview.start()
        suppressBezierWrite = false
    }

    function reloadFromDisk() {
        persistDebounce.stop()
        persistQueued = false
        writesEnabled = false
        animFile.reload()
    }

    Timer {
        id: persistDebounce

        interval: 400
        repeat: false

        onTriggered: {
            if (!root.isMango || root.saveInFlight) {
                if (root.isMango && root.saveInFlight)
                    root.persistQueued = true
                return
            }
            root.saveNow(true)
        }
    }

     FileView {
         id: animFile

         path: root.animationsPath
         blockWrites: true
         blockLoading: false
         atomicWrites: true
         printErrors: true

         onLoaded: {
             root.writesEnabled = false
             baseFileText = text()
             deco = parseConf(baseFileText)
             Qt.callLater(() => {
                 root.loadCurveIntoCanvas(root.editingCurveKey)
                 Qt.callLater(() => {
                     root.writesEnabled = true
                 })
             })
         }

         onLoadFailed: {
             root.writesEnabled = false
             deco = Object.assign({}, defaultDeco)
             baseFileText = ""
             if (typeof ToastService !== "undefined")
                 ToastService.showError("Could not read " + root.animationsPath)
             Qt.callLater(() => {
                 root.loadCurveIntoCanvas(root.editingCurveKey)
                 Qt.callLater(() => {
                     root.writesEnabled = true
                 })
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
                    ToastService.showError("Could not create directory for Mango animations.conf")
                return
            }
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", root.animationsPath]
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
                    ToastService.showError("Could not prepare Mango animations.conf for writing")
                return
            }
            if (pendingSaveContent !== "") {
                saveAnimFile.path = ""
                Qt.callLater(() => {
                    saveAnimFile.path = root.animationsPath
                    Qt.callLater(() => {
                        saveAnimFile.setText(pendingSaveContent)
                    })
                })
            } else {
                root.saveInFlight = false
            }
        }
    }

    FileView {
        id: saveAnimFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            baseFileText = pendingSaveContent
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango animations config")
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
            Qt.callLater(() => root.schedulePersistAndReload())
        }
    }

    Process {
        id: reloadMangoProcess

        command: ["mmsg", "dispatch", "reload_config"]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0 && typeof ToastService !== "undefined")
                ToastService.showWarning("mmsg reload_config exited " + exitCode)
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
                height: mangoHintCol.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1
                visible: !isMango

                Column {
                    id: mangoHintCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingS

                    StyledText {
                        text: "MangoWM animation settings are available when Mango is running."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            // ═══ Curve editor (Hyprland-style) ═══
            StyledRect {
                width: parent.width
                height: curveEditorSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: curveEditorSection

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "timeline"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Animation curve editor"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Curve for"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72
                        }

                        EHDropdown {
                            id: curveTargetDropdown

                            width: Math.min(280, parent.width - 72 - Theme.spacingM)
                            text: "Target"
                            options: root.curveTargetLabels
                            currentValue: root.labelForCurveKey(root.editingCurveKey)

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                root.editingCurveKey = root.curveKeyForLabel(value)
                                root.loadCurveIntoCanvas(root.editingCurveKey)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Preset"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72
                        }

                        EHDropdown {
                            id: presetDropdown

                            width: Math.min(200, parent.width - 72 - Theme.spacingM)
                            text: "Shape"
                            options: ["ease", "easeIn", "easeOut", "easeInOut", "linear", "default"]
                            currentValue: "default"

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                const presets = {
                                    "ease": [0.25, 0.1, 0.25, 1.0],
                                    "easeIn": [0.42, 0, 1.0, 1.0],
                                    "easeOut": [0, 0, 0.58, 1.0],
                                    "easeInOut": [0.42, 0, 0.58, 1.0],
                                    "linear": [0, 0, 1.0, 1.0],
                                    "default": [0.05, 0.7, 0.1, 1.0]
                                }
                                const pts = presets[value]
                                if (!pts)
                                    return
                                bezierCanvas.setPoints(pts[0], pts[1], pts[2], pts[3])
                                animationPreview.setPoints(pts[0], pts[1], pts[2], pts[3])
                                animationPreview.start()
                                root.setDe(root.editingCurveKey, root.formatCurve(pts[0], pts[1], pts[2], pts[3]))
                            }
                        }

                        StyledText {
                            text: "Drag handles or pick a preset"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    BezierCanvas {
                        id: bezierCanvas

                        x1: 0.46
                        y1: 1.0
                        x2: 0.29
                        y2: 1.0
                        width: parent.width
                        height: 280

                        onCurveChanged: function (nx1, ny1, nx2, ny2) {
                            if (root.suppressBezierWrite)
                                return
                            animationPreview.setPoints(nx1, ny1, nx2, ny2)
                            animationPreview.start()
                            root.setDe(root.editingCurveKey, root.formatCurve(nx1, ny1, nx2, ny2))
                        }

                        onDragEnd: function () {
                            animationPreview.start()
                        }
                    }

                    AnimationPreview {
                        id: animationPreview

                        x1: 0.46
                        y1: 1.0
                        x2: 0.29
                        y2: 1.0
                        width: parent.width

                        Component.onCompleted: start()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXL

                        Column {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Point 1 (X)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            EHSlider {
                                width: 80
                                value: bezierCanvas.x1
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: function(v) {
                                    bezierCanvas.x1 = v
                                    animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    root.setDe(root.editingCurveKey, root.formatCurve(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2))
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Point 1 (Y)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            EHSlider {
                                width: 80
                                value: bezierCanvas.y1
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: function(v) {
                                    bezierCanvas.y1 = v
                                    animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    root.setDe(root.editingCurveKey, root.formatCurve(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2))
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Point 2 (X)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            EHSlider {
                                width: 80
                                value: bezierCanvas.x2
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: function(v) {
                                    bezierCanvas.x2 = v
                                    animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    root.setDe(root.editingCurveKey, root.formatCurve(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2))
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Point 2 (Y)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            EHSlider {
                                width: 80
                                value: bezierCanvas.y2
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: function(v) {
                                    bezierCanvas.y2 = v
                                    animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    root.setDe(root.editingCurveKey, root.formatCurve(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2))
                                }
                            }
                        }
                    }
                }
            }

            // ═══ Animation settings (Hyprland-style rows) ═══
            StyledRect {
                width: parent.width
                height: animationSettingsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: animationSettingsSection

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "animation"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Animation settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Animations"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Enable tiled and floating window transitions"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHToggle {
                            checked: root.intToggleChecked("animations")
                            onToggled: c => root.setDe("animations", c ? "1" : "0")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Layer animations"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Panels, docks, and other layer-shell surfaces"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHToggle {
                            checked: root.intToggleChecked("layer_animations")
                            onToggled: c => root.setDe("layer_animations", c ? "1" : "0")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Fade in"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Opacity fade when surfaces appear"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        EHToggle {
                            checked: root.intToggleChecked("animation_fade_in")
                            onToggled: c => root.setDe("animation_fade_in", c ? "1" : "0")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Fade out"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Opacity fade when surfaces disappear"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        EHToggle {
                            checked: root.intToggleChecked("animation_fade_out")
                            onToggled: c => root.setDe("animation_fade_out", c ? "1" : "0")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 220 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Open animation type"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Windows and tiles appearing (Mango: slide, zoom, fade, none)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: openAnimTypeDropdown

                            width: 220
                            text: "Open type"
                            options: root.windowAnimTypeOptionsForKey("animation_type_open")
                            currentValue: root.windowAnimTypeCurrentValue("animation_type_open")

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                root.setDe("animation_type_open", value)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 220 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Close animation type"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Windows and tiles disappearing"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: closeAnimTypeDropdown

                            width: 220
                            text: "Close type"
                            options: root.windowAnimTypeOptionsForKey("animation_type_close")
                            currentValue: root.windowAnimTypeCurrentValue("animation_type_close")

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                root.setDe("animation_type_close", value)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 220 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Layer open animation type"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Panels, docks, layer-shell surfaces appearing"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: layerOpenAnimTypeDropdown

                            width: 220
                            text: "Layer open"
                            options: root.windowAnimTypeOptionsForKey("layer_animation_type_open")
                            currentValue: root.windowAnimTypeCurrentValue("layer_animation_type_open")

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                root.setDe("layer_animation_type_open", value)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 220 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Layer close animation type"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Panels, docks, layer-shell surfaces disappearing"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHDropdown {
                            id: layerCloseAnimTypeDropdown

                            width: 220
                            text: "Layer close"
                            options: root.windowAnimTypeOptionsForKey("layer_animation_type_close")
                            currentValue: root.windowAnimTypeCurrentValue("layer_animation_type_close")

                            onValueChanged: value => {
                                if (!root.writesEnabled)
                                    return
                                root.setDe("layer_animation_type_close", value)
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Tag animation direction"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("tag_animation_direction", 1)
                            minimum: 0
                            maximum: 3
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("tag_animation_direction", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXL

                        Column {
                            width: (parent.width - Theme.spacingXL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Zoom initial ratio"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: root.numKey("zoom_initial_ratio", 0.4)
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("zoom_initial_ratio", String(v))
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingXL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Zoom end ratio"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: root.numKey("zoom_end_ratio", 0.8)
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("zoom_end_ratio", String(v))
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXL

                        Column {
                            width: (parent.width - Theme.spacingXL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Fade-in begin opacity"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: root.numKey("fadein_begin_opacity", 0.5)
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("fadein_begin_opacity", String(v))
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingXL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Fade-out begin opacity"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: root.numKey("fadeout_begin_opacity", 0.8)
                                minimum: 0
                                maximum: 1
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("fadeout_begin_opacity", String(v))
                            }
                        }
                    }

                    MangoAnimDurationRow {
                        width: parent.width
                        label: "Duration move"
                        sub: "ms — moving / resizing tiled windows"
                        k: "animation_duration_move"
                    }

                    MangoAnimDurationRow {
                        width: parent.width
                        label: "Duration open"
                        sub: "ms — new windows"
                        k: "animation_duration_open"
                    }

                    MangoAnimDurationRow {
                        width: parent.width
                        label: "Duration tag"
                        sub: "ms — workspace tag changes"
                        k: "animation_duration_tag"
                    }

                    MangoAnimDurationRow {
                        width: parent.width
                        label: "Duration close"
                        sub: "ms — closing windows"
                        k: "animation_duration_close"
                    }

                    MangoAnimDurationRow {
                        width: parent.width
                        label: "Duration focus"
                        sub: "ms — focus crossfade (0 = off)"
                        k: "animation_duration_focus"
                    }
                }
            }

            // ═══ Apply & save (Hyprland-style footer) ═══
            StyledRect {
                width: parent.width
                height: actionsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: actionsSection

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "save"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Apply & save"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: "Writes " + root.animationsPath + " and runs mmsg dispatch reload_config. Edits also auto-save after a short pause."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Row {
                        width: parent.width
                        height: 48
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
                }
            }
        }
    }

    component MangoAnimDurationRow: Column {
        id: animDur

        property string label: ""
        property string sub: ""
        property string k: ""

        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS

        StyledText {
            text: animDur.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: animDur.sub
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: animDur.sub.length > 0
        }

        EHSlider {
            width: parent.width
            height: 24
            value: root.numKey(animDur.k, 400)
            minimum: 0
            maximum: 2000
            unit: "ms"
            showValue: true
            wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: v => root.setDe(animDur.k, String(Math.round(v)))
        }
    }
}
