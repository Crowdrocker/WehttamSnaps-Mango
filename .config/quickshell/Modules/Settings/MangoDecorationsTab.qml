import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    readonly property string decorationPath: _configBase + "/mango/hyprmango/decoration.conf"

    property var deco: ({})
    property string baseFileText: ""
    property bool hasUnsavedChanges: false
    property string pendingSaveContent: ""
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true

    readonly property var managedKeys: ["blur", "blur_layer", "blur_optimized", "blur_params_num_passes", "blur_params_radius", "blur_params_noise", "blur_params_brightness", "blur_params_contrast", "blur_params_saturation", "shadows", "layer_shadows", "shadow_only_floating", "shadows_size", "shadows_blur", "shadows_position_x", "shadows_position_y", "shadowscolor", "border_radius", "border_radius_location_default", "no_radius_when_single", "gappih", "gappiv", "gappoh", "gappov"]

    readonly property var defaultDeco: ({
            "blur": "1", "blur_layer": "1", "blur_optimized": "1", "blur_params_num_passes": "1", "blur_params_radius": "5", "blur_params_noise": "0.02", "blur_params_brightness": "0.9", "blur_params_contrast": "0.9", "blur_params_saturation": "1.2", "shadows": "0", "layer_shadows": "0", "shadow_only_floating": "1", "shadows_size": "10", "shadows_blur": "15", "shadows_position_x": "0", "shadows_position_y": "0", "shadowscolor": "0x000000ff", "border_radius": "0",             "border_radius_location_default": "0", "no_radius_when_single": "0", "gappih": "5", "gappiv": "5", "gappoh": "10", "gappov": "10"
        })

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
        let t = baseFileText.length > 0 ? baseFileText : "# mango decoration.conf\n"
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
        hasUnsavedChanges = true
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
        const lastSlash = decorationPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? decorationPath.substring(0, lastSlash) : "."
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

    function reloadFromDisk() {
        persistDebounce.stop()
        persistQueued = false
        decorationFile.reload()
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
        id: decorationFile

        path: isMango ? decorationPath : ""
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            baseFileText = text()
            deco = parseConf(baseFileText)
            hasUnsavedChanges = false
        }

        onLoadFailed: {
            deco = Object.assign({}, defaultDeco)
            baseFileText = ""
            hasUnsavedChanges = false
            if (typeof ToastService !== "undefined")
                ToastService.showError("Could not read " + decorationPath)
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
                    ToastService.showError("Could not create config directory for Mango decoration.conf")
                return
            }
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", decorationPath]
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
                    ToastService.showError("Could not prepare Mango decoration.conf for writing")
                return
            }
            if (pendingSaveContent !== "") {
                saveDecorationFile.path = ""
                Qt.callLater(() => {
                    saveDecorationFile.path = decorationPath
                    Qt.callLater(() => {
                        saveDecorationFile.setText(pendingSaveContent)
                    })
                })
            } else {
                root.saveInFlight = false
            }
        }
    }

    FileView {
        id: saveDecorationFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            hasUnsavedChanges = false
            baseFileText = pendingSaveContent
            pendingSaveContent = ""
            saveInFlight = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango decoration config")
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
            if (root.hasUnsavedChanges)
                Qt.callLater(() => root.schedulePersistAndReload())
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

    Process {
        id: cursorThemeDetectionProcess

        command: ["sh", "-c", "find /usr/share/icons ~/.local/share/icons ~/.icons -maxdepth 1 -type d -exec test -f {}/cursors/left_ptr \\; -print 2>/dev/null | sed 's|.*/||' | sort -u"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var detectedThemes = ["Bibata-Modern-Classic"]
                if (text && text.trim()) {
                    var themes = text.trim().split('\n')
                    for (var i = 0; i < themes.length; i++) {
                        var theme = themes[i].trim()
                        if (theme && theme !== "" && theme !== "default" && theme !== "hicolor" && theme !== "locolor" && detectedThemes.indexOf(theme) < 0)
                            detectedThemes.push(theme)
                    }
                }
                root.availableCursorThemes = detectedThemes
            }
        }
    }

    Component.onCompleted: {
        cursorThemeDetectionProcess.running = true
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
                        text: "MangoWM settings are available when you are running Mango."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    StyledText {
                        text: "Config file: " + root.decorationPath
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: pathRow.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: pathRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "description"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 4

                            StyledText {
                                text: "Mango decoration.conf"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: root.decorationPath + (root.saveInFlight ? "  ·  saving…" : (root.persistDebounce.running ? "  ·  will apply shortly…" : ""))
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            StyledText {
                                text: "Edits are written to disk and Mango reloads config automatically (short delay while dragging sliders)."
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
                }
            }

            // ── Blur ─────────────────────────────────────────────────────
            StyledRect {
                width: parent.width
                height: blurSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: blurSec

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "blur_on"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Blur"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Window blur"
                        checked: root.intToggleChecked("blur")
                        onToggled: c => root.setDe("blur", c ? "1" : "0")
                    }

                    EHToggle {
                        width: parent.width
                        text: "Layer-shell blur (panels, dock)"
                        description: "blur_layer for layer surfaces"
                        checked: root.intToggleChecked("blur_layer")
                        onToggled: c => root.setDe("blur_layer", c ? "1" : "0")
                    }

                    EHToggle {
                        width: parent.width
                        text: "Blur optimized"
                        description: "Caches wallpaper and blur background — highly recommended. Disabling significantly increases GPU usage."
                        checked: root.intToggleChecked("blur_optimized")
                        onToggled: c => root.setDe("blur_optimized", c ? "1" : "0")
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Blur passes"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_num_passes", 2)
                            minimum: 1
                            maximum: 8
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_num_passes", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Blur radius"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_radius", 5)
                            minimum: 1
                            maximum: 32
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_radius", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Noise"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_noise", 0.02)
                            minimum: 0
                            maximum: 0.5
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_noise", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Brightness"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_brightness", 0.9)
                            minimum: 0
                            maximum: 2
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_brightness", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Contrast"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_contrast", 0.9)
                            minimum: 0
                            maximum: 2
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_contrast", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Saturation"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("blur_params_saturation", 1.2)
                            minimum: 0
                            maximum: 3
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("blur_params_saturation", String(v.toFixed(2)))
                        }
                    }
                }
            }

            // ── Shadows ──────────────────────────────────────────────────
            StyledRect {
                width: parent.width
                height: shSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: shSec

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "shadow"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Shadows"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Window shadows"
                        checked: root.intToggleChecked("shadows")
                        onToggled: c => root.setDe("shadows", c ? "1" : "0")
                    }

                    EHToggle {
                        width: parent.width
                        text: "Layer shadows"
                        checked: root.intToggleChecked("layer_shadows")
                        onToggled: c => root.setDe("layer_shadows", c ? "1" : "0")
                    }

                    EHToggle {
                        width: parent.width
                        text: "Shadow only on floating"
                        checked: root.intToggleChecked("shadow_only_floating")
                        onToggled: c => root.setDe("shadow_only_floating", c ? "1" : "0")
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Shadow size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("shadows_size", 10)
                            minimum: 0
                            maximum: 64
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("shadows_size", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Shadow blur"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("shadows_blur", 15)
                            minimum: 0
                            maximum: 64
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("shadows_blur", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Shadow offset X / Y"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            EHSlider {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 24
                                value: root.numKey("shadows_position_x", 0)
                                minimum: -32
                                maximum: 32
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("shadows_position_x", String(Math.round(v)))
                            }

                            EHSlider {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 24
                                value: root.numKey("shadows_position_y", 0)
                                minimum: -32
                                maximum: 32
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: v => root.setDe("shadows_position_y", String(Math.round(v)))
                            }
                        }
                    }

                    MangoDecoTextRow {
                        width: parent.width
                        label: "Shadow color (ARGB hex)"
                        valueText: root.gv("shadowscolor")
                        onCommit: t => root.setDe("shadowscolor", t.trim())
                    }
                }
            }

            // ── Corners & opacity ────────────────────────────────────────
            StyledRect {
                width: parent.width
                height: radSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: radSec

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "rounded_corner"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Corners & opacity"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border radius"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("border_radius", 0)
                            minimum: 0
                            maximum: 32
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("border_radius", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Radius location"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHDropdown {
                            width: parent.width - 140 - Theme.spacingM
                            text: "Location"
                            options: ["0", "1", "2", "3", "4", "5"]
                            currentValue: root.gv("border_radius_location_default")
                            onValueChanged: v => root.setDe("border_radius_location_default", v)
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "No radius when single window"
                        checked: root.intToggleChecked("no_radius_when_single")
                        onToggled: c => root.setDe("no_radius_when_single", c ? "1" : "0")
                    }
                }
            }

            // ── Gaps ────────────────────────────────────────────────────────
            StyledRect {
                width: parent.width
                height: gapsSec.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isMango

                Column {
                    id: gapsSec

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "crop_landscape"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Gaps"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Inner horizontal gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("gappih", 5)
                            minimum: 0
                            maximum: 50
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("gappih", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Inner vertical gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("gappiv", 5)
                            minimum: 0
                            maximum: 50
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("gappiv", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Outer horizontal gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("gappoh", 10)
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("gappoh", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Outer vertical gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKey("gappov", 10)
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setDe("gappov", String(Math.round(v)))
                        }
                    }
                }
            }
        }
    }

    // ── Inline helpers (scoped to this file) ─────────────────────────────
    component MangoDecoFloatRow: Column {
        id: mangoFloatRow

        property string label: ""
        property string valueText: ""
        signal commit(string text)

        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS

        StyledText {
            text: mangoFloatRow.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        EHTextField {
            width: parent.width
            text: mangoFloatRow.valueText
            placeholderText: "0.0"
            onEditingFinished: mangoFloatRow.commit(text)
        }
    }

    component MangoDecoTextRow: Column {
        id: mangoTextRow

        property string label: ""
        property string valueText: ""
        signal commit(string text)

        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS

        StyledText {
            text: mangoTextRow.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        EHTextField {
            width: parent.width
            text: mangoTextRow.valueText
            onEditingFinished: mangoTextRow.commit(text)
        }
    }

    component MangoDecoDurationRow: Column {
        id: durRow

        property string label: ""
        property string k: ""

        width: parent ? parent.width : implicitWidth
        spacing: Theme.spacingS

        StyledText {
            text: durRow.label
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }

        EHSlider {
            width: parent.width
            height: 24
            value: root.numKey(durRow.k, 300)
            minimum: 0
            maximum: 2000
            unit: "ms"
            showValue: true
            wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderDragFinished: v => root.setDe(durRow.k, String(Math.round(v)))
        }
    }
}
