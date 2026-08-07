import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    anchors.fill: parent

    property var parentModal: null

    readonly property bool isMango: typeof CompositorService !== "undefined" && CompositorService.isMango

    readonly property string _configBase: {
        const cfg = Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.ConfigLocation))
        if (cfg && cfg.length > 0)
            return cfg.replace(/^file:\/\//, "")
        const h = Paths.stringify(Paths.home).replace(/^file:\/\//, "")
        return h ? h + "/.config" : ""
    }

    readonly property string colorsPath: _configBase + "/mango/hyprmango/colors.conf"

     // Managed keys based on Mango "Appearance" docs (colors.conf)
     readonly property var managed: ({
         "colors": ["rootcolor", "bordercolor", "focuscolor", "maximizescreencolor", "urgentcolor", "scratchpadcolor", "globalcolor", "overlaycolor", "dropcolor", "splitcolor"],
         "dimensions": ["borderpx"],
         "opacity": ["focused_opacity", "unfocused_opacity"],
         "overview": ["overviewgappi", "overviewgappo", "ov_tab_mode", "hotarea_size", "enable_hotarea"],
         "scratchpad": ["scratchpad_width_ratio", "scratchpad_height_ratio"],
         "cursor": ["cursor_size", "cursor_theme"],
         "jumpLabel": ["jump_label_decorate_fg_color", "jump_label_decorate_bg_color", "jump_label_decorate_focus_fg_color", "jump_label_decorate_focus_bg_color", "jump_label_decorate_border_color", "jump_label_decorate_border_width", "jump_label_decorate_corner_radius", "jump_label_decorate_padding_x", "jump_label_decorate_padding_y", "jump_label_decorate_font_desc"],
         "tabBar": ["group_bar_height", "group_bar_decorate_fg_color", "group_bar_decorate_bg_color", "group_bar_decorate_focus_fg_color", "group_bar_decorate_focus_bg_color", "group_bar_decorate_border_color", "group_bar_decorate_border_width", "group_bar_decorate_corner_radius", "group_bar_decorate_padding_x", "group_bar_decorate_padding_y", "group_bar_decorate_font_desc"]
     })

     readonly property var managedKeys: [
         // colors
         "rootcolor", "bordercolor", "focuscolor", "maximizescreencolor",
         "urgentcolor", "scratchpadcolor", "globalcolor", "overlaycolor",
         "dropcolor", "splitcolor",
         // dimensions
         "borderpx",
         // opacity
         "focused_opacity", "unfocused_opacity",
         // overview
         "overviewgappi", "overviewgappo", "ov_tab_mode", "hotarea_size", "enable_hotarea",
         // scratchpad
         "scratchpad_width_ratio", "scratchpad_height_ratio",
         // cursor
         "cursor_size", "cursor_theme",
         // overview jump label
         "jump_label_decorate_fg_color", "jump_label_decorate_bg_color",
         "jump_label_decorate_focus_fg_color", "jump_label_decorate_focus_bg_color",
         "jump_label_decorate_border_color", "jump_label_decorate_border_width",
         "jump_label_decorate_corner_radius", "jump_label_decorate_padding_x",
         "jump_label_decorate_padding_y", "jump_label_decorate_font_desc",
         // monocle tab bar
         "group_bar_height", "group_bar_decorate_fg_color", "group_bar_decorate_bg_color",
         "group_bar_decorate_focus_fg_color", "group_bar_decorate_focus_bg_color",
         "group_bar_decorate_border_color", "group_bar_decorate_border_width",
         "group_bar_decorate_corner_radius", "group_bar_decorate_padding_x",
         "group_bar_decorate_padding_y", "group_bar_decorate_font_desc"
     ]

     // Defaults from Mango docs (fallbacks; file may override)
     readonly property var defaults: ({
         "rootcolor": "0x201b14ff",
         "bordercolor": "0x444444ff",
         "focuscolor": "0xc9b890ff",
         "maximizescreencolor": "0x89aa61ff",
         "urgentcolor": "0xad401fff",
         "scratchpadcolor": "0x516c93ff",
         "globalcolor": "0xb153a7ff",
         "overlaycolor": "0x14a57cff",
         "dropcolor": "0x444444ff",
         "splitcolor": "0x444444ff",

         "focused_opacity": "1.0",
         "unfocused_opacity": "1.0",

         "overviewgappi": "5",
         "overviewgappo": "30",
         "ov_tab_mode": "0",
         "hotarea_size": "10",
         "enable_hotarea": "1",

         "scratchpad_width_ratio": "0.8",
         "scratchpad_height_ratio": "0.9",

         "cursor_size": "24",
         "cursor_theme": "",

         "jump_label_decorate_fg_color": "0xffffffff",
         "jump_label_decorate_bg_color": "0x333333ff",
         "jump_label_decorate_focus_fg_color": "0xffffffff",
         "jump_label_decorate_focus_bg_color": "0x333333ff",
         "jump_label_decorate_border_color": "0x444444ff",
         "jump_label_decorate_border_width": "1",
         "jump_label_decorate_corner_radius": "0",
         "jump_label_decorate_padding_x": "8",
         "jump_label_decorate_padding_y": "8",
         "jump_label_decorate_font_desc": "",

         "group_bar_height": "32",
         "group_bar_decorate_fg_color": "0xffffffff",
         "group_bar_decorate_bg_color": "0x333333ff",
         "group_bar_decorate_focus_fg_color": "0xffffffff",
         "group_bar_decorate_focus_bg_color": "0x555555ff",
         "group_bar_decorate_border_color": "0x444444ff",
         "group_bar_decorate_border_width": "1",
         "group_bar_decorate_corner_radius": "0",
         "group_bar_decorate_padding_x": "8",
         "group_bar_decorate_padding_y": "4",
         "group_bar_decorate_font_desc": ""
     })

    property string baseFileText: ""
    property var cfg: ({})
    property bool hasUnsavedChanges: false
    property bool saveInFlight: false
    property bool persistQueued: false
    property bool lastSaveWasSilent: true
    property string pendingSaveContent: ""
    property bool writesEnabled: false
    property string inlineStatus: ""
    property bool inlineStatusIsError: false

    function escapeRe(s) {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function setKeyLine(text, key, value) {
        const lines = (text || "").split("\n")
        const re = new RegExp("^\\s*" + escapeRe(key) + "\\s*=")
        let found = false
        for (let i = 0; i < lines.length; i++) {
            if (re.test(lines[i])) {
                lines[i] = key + "=" + value
                found = true
            }
        }
        if (!found)
            lines.push(key + "=" + value)
        return lines.join("\n")
    }

    function parseConf(text) {
        const out = Object.assign({}, defaults)
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
            const v = (m[2] || "").trim()
            out[k] = v
        }
        return out
    }

    function buildSaveText() {
        let t = baseFileText && baseFileText.length > 0 ? baseFileText : "# Mango colors.conf (appearance)\n"

        // Always persist managed keys
        for (let i = 0; i < managedKeys.length; i++) {
            const k = managedKeys[i]
            const v = cfg && cfg[k] !== undefined && cfg[k] !== null ? String(cfg[k]).trim() : ""
            if (v.length > 0)
                t = setKeyLine(t, k, v)
        }

        // Also persist unknown keys present in cfg (keeps "handles everything")
        const keys = Object.keys(cfg || {})
        for (let j = 0; j < keys.length; j++) {
            const k2 = keys[j]
            if (managedKeys.indexOf(k2) >= 0) continue
            const v2 = cfg[k2]
            if (v2 !== undefined && v2 !== null && String(v2).trim().length > 0)
                t = setKeyLine(t, k2, String(v2).trim())
        }
        return t
    }

    function gv(k) {
        const v = cfg && cfg[k] !== undefined && cfg[k] !== null ? String(cfg[k]).trim() : ""
        if (v.length > 0)
            return v
        return defaults[k] !== undefined ? String(defaults[k]) : ""
    }

    function numKeyDirect(k, defN) {
        const v = parseFloat(gv(k))
        return isNaN(v) ? defN : v
    }

    function setCfgValue(k, v) {
        const c = Object.assign({}, cfg)
        c[k] = String(v).trim()
        cfg = c
        hasUnsavedChanges = true
        schedulePersistAndReload()
    }

    function intToggleChecked(k) {
        const v = parseInt(gv(k), 10)
        return !isNaN(v) && v !== 0
    }

    function managedSet() {
        const s = {}
        for (let i = 0; i < managedKeys.length; i++)
            s[managedKeys[i]] = true
        return s
    }

    function otherKeysSorted() {
        const c = cfg || {}
        const ms = managedSet()
        const keys = Object.keys(c)
        const out = []
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (!k || ms[k]) continue
            const v = c[k]
            if (v === undefined || v === null) continue
            if (String(v).trim().length === 0) continue
            out.push(k)
        }
        out.sort()
        return out
    }

    function schedulePersistAndReload() {
        if (!writesEnabled)
            return
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
            if (!silent) lastSaveWasSilent = false
            return
        }
        lastSaveWasSilent = !!silent
        pendingSaveContent = buildSaveText()
        const lastSlash = colorsPath.lastIndexOf("/")
        const dirPath = lastSlash >= 0 ? colorsPath.substring(0, lastSlash) : "."
        saveInFlight = true
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true
    }

    Timer {
        id: persistDebounce
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.writesEnabled || root.saveInFlight) {
                if (root.writesEnabled && root.saveInFlight)
                    root.persistQueued = true
                return
            }
            root.saveNow(true)
        }
    }

    FileView {
        id: colorsFile
        path: colorsPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true
        watchChanges: true

        onLoaded: {
            baseFileText = text()
            cfg = parseConf(baseFileText)
            hasUnsavedChanges = false
            inlineStatus = ""
            inlineStatusIsError = false
        }

        onLoadFailed: {
            cfg = Object.assign({}, defaults)
            baseFileText = ""
            hasUnsavedChanges = false
            inlineStatus = "Could not read " + colorsPath
            inlineStatusIsError = true
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
                    ToastService.showError("Could not create config directory for Mango colors.conf")
                return
            }
            touchFileProcess.command = ["touch", colorsPath]
            touchFileProcess.running = true
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
                    ToastService.showError("Could not prepare Mango colors.conf for writing")
                return
            }
            saveColorsFile.path = ""
            Qt.callLater(() => {
                saveColorsFile.path = colorsPath
                Qt.callLater(() => saveColorsFile.setText(pendingSaveContent))
            })
        }
    }

    FileView {
        id: saveColorsFile
        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            hasUnsavedChanges = false
            baseFileText = pendingSaveContent
            pendingSaveContent = ""
            saveInFlight = false
            inlineStatus = "Saved"
            inlineStatusIsError = false
            if (typeof ToastService !== "undefined" && !lastSaveWasSilent)
                ToastService.showInfo("Saved Mango colors config")
            reloadMangoProcess.running = true
            if (persistQueued) {
                persistQueued = false
                Qt.callLater(() => root.schedulePersistAndReload())
            }
        }

        onSaveFailed: error => {
            pendingSaveContent = ""
            saveInFlight = false
            inlineStatus = "Save failed: " + (error || "unknown")
            inlineStatusIsError = true
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
                ToastService.showWarning("mmsg reload_config exited " + exitCode + " — restart Mango if colors did not apply")
        }
    }

    // Same behavior as other Mango tabs: allow editing always, but only auto-save/reload when Mango is active.
    Component.onCompleted: {
        writesEnabled = true
        colorsFile.reload()
    }

    function sectionCard(title, subtitle, keysModel) {
        // helper for mental model only; QML doesn't allow returning objects here
        return null
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
                        text: "MangoWM is not the active compositor. You can still edit this file; reload applies when you run Mango."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                EHToggle {
                    width: parent.width
                    text: "Dynamic borders"
                    description: "When enabled, Matugen updates Mango border colors on wallpaper change."
                    checked: typeof SettingsData !== "undefined" ? SettingsData.mangoDynamicBorders : true
                    onToggled: toggled => {
                        if (typeof SettingsData !== "undefined" && SettingsData.setMangoDynamicBorders)
                            SettingsData.setMangoDynamicBorders(toggled)
                    }
                }

                StyledRect {
                    width: parent.width
                    height: statusText.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    visible: root.inlineStatus !== ""
                    color: root.inlineStatusIsError
                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    border.color: root.inlineStatusIsError
                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25)
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                    border.width: 1

                    StyledText {
                        id: statusText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.spacingM
                        text: root.inlineStatus
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.inlineStatusIsError ? Theme.error : Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Column {
                        width: parent.width - Theme.iconSize * 2 - Theme.spacingM * 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "MangoWM Colors"
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Edits " + colorsPath + " (Mango RGBA hex: 0xRRGGBBAA)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    EHActionButton {
                        width: 44
                        height: 44
                        circular: false
                        iconName: "refresh"
                        iconSize: Theme.iconSize
                        iconColor: Theme.primary
                        enabled: !saveInFlight
                        opacity: enabled ? 1 : 0.5
                        onClicked: colorsFile.reload()
                    }

                    EHActionButton {
                        width: 44
                        height: 44
                        circular: false
                        iconName: "save"
                        iconSize: Theme.iconSize
                        iconColor: Theme.primary
                        enabled: !saveInFlight
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.saveNow(false)
                    }
                }
            }

            // Colors
            StyledRect {
                width: parent.width
                implicitHeight: colorsCol.implicitHeight + Theme.spacingL * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: colorsCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Colors"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Repeater {
                        model: root.managed.colors

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledText {
                                width: 220
                                text: modelData
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            EHTextField {
                                width: parent.width - 220 - Theme.spacingM
                                text: root.gv(modelData)
                                placeholderText: "0xRRGGBBAA"
                                onEditingFinished: root.setCfgValue(modelData, text.trim())
                            }
                        }
                    }
                }
            }



            // Opacity + overview + scratchpad + cursor
            StyledRect {
                width: parent.width
                implicitHeight: miscCol.implicitHeight + Theme.spacingL * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: miscCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Opacity, overview, scratchpad & cursor"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border width"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("borderpx", 1)
                            minimum: 0
                            maximum: 10
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("borderpx", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Focused opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("focused_opacity", 1.0)
                            minimum: 0
                            maximum: 1
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("focused_opacity", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Unfocused opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("unfocused_opacity", 1.0)
                            minimum: 0
                            maximum: 1
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("unfocused_opacity", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Overview gap inner"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("overviewgappi", 5)
                            minimum: 0
                            maximum: 50
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("overviewgappi", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Overview gap outer"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("overviewgappo", 30)
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("overviewgappo", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Hotarea size"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("hotarea_size", 10)
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("hotarea_size", String(Math.round(v)))
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable hotarea"
                        checked: root.intToggleChecked("enable_hotarea")
                        onToggled: c => root.setCfgValue("enable_hotarea", c ? "1" : "0")
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Overview tab mode"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHDropdown {
                            width: parent.width - 140 - Theme.spacingM
                            text: "Mode"
                            options: ["0", "1", "2"]
                            currentValue: root.gv("ov_tab_mode")
                            onValueChanged: v => root.setCfgValue("ov_tab_mode", v)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Scratchpad width ratio"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("scratchpad_width_ratio", 0.8)
                            minimum: 0
                            maximum: 1
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("scratchpad_width_ratio", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Scratchpad height ratio"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("scratchpad_height_ratio", 0.9)
                            minimum: 0
                            maximum: 1
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("scratchpad_height_ratio", String(v.toFixed(2)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Cursor size"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("cursor_size", 24)
                            minimum: 8
                            maximum: 64
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("cursor_size", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Cursor theme"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("cursor_theme")
                            placeholderText: "(system default)"
                            onEditingFinished: root.setCfgValue("cursor_theme", text.trim())
                        }
                    }

            }
            }

            // Overview jump label theming
            StyledRect {
                width: parent.width
                implicitHeight: jumpLabelCol.implicitHeight + Theme.spacingL * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: jumpLabelCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Overview jump label theming"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Foreground color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_fg_color")
                            placeholderText: "0xffffffff"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_fg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Background color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_bg_color")
                            placeholderText: "0x333333ff"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_bg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Focus foreground"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_focus_fg_color")
                            placeholderText: "0xffffffff"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_focus_fg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Focus background"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_focus_bg_color")
                            placeholderText: "0x333333ff"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_focus_bg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Border color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_border_color")
                            placeholderText: "0x444444ff"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_border_color", text.trim())
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border width"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("jump_label_decorate_border_width", 1)
                            minimum: 0
                            maximum: 10
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("jump_label_decorate_border_width", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Corner radius"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("jump_label_decorate_corner_radius", 0)
                            minimum: 0
                            maximum: 20
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("jump_label_decorate_corner_radius", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Padding X"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("jump_label_decorate_padding_x", 8)
                            minimum: 0
                            maximum: 30
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("jump_label_decorate_padding_x", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Padding Y"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("jump_label_decorate_padding_y", 8)
                            minimum: 0
                            maximum: 30
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("jump_label_decorate_padding_y", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Font"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("jump_label_decorate_font_desc")
                            placeholderText: "(default)"
                            onEditingFinished: root.setCfgValue("jump_label_decorate_font_desc", text.trim())
                        }
                    }
                }
            }

            // Monocle tab bar theming
            StyledRect {
                width: parent.width
                implicitHeight: tabBarCol.implicitHeight + Theme.spacingL * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: tabBarCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Monocle tab bar theming"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Tab bar height"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("group_bar_height", 32)
                            minimum: 16
                            maximum: 80
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("group_bar_height", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Foreground color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_fg_color")
                            placeholderText: "0xffffffff"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_fg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Background color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_bg_color")
                            placeholderText: "0x333333ff"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_bg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Focus foreground"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_focus_fg_color")
                            placeholderText: "0xffffffff"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_focus_fg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Focus background"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_focus_bg_color")
                            placeholderText: "0x555555ff"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_focus_bg_color", text.trim())
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Border color"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_border_color")
                            placeholderText: "0x444444ff"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_border_color", text.trim())
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border width"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("group_bar_decorate_border_width", 1)
                            minimum: 0
                            maximum: 10
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("group_bar_decorate_border_width", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Corner radius"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("group_bar_decorate_corner_radius", 0)
                            minimum: 0
                            maximum: 20
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("group_bar_decorate_corner_radius", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Padding X"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("group_bar_decorate_padding_x", 8)
                            minimum: 0
                            maximum: 30
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("group_bar_decorate_padding_x", String(Math.round(v)))
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Padding Y"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: root.numKeyDirect("group_bar_decorate_padding_y", 4)
                            minimum: 0
                            maximum: 20
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => root.setCfgValue("group_bar_decorate_padding_y", String(Math.round(v)))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Font"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        EHTextField {
                            width: parent.width - 140 - Theme.spacingM
                            text: root.gv("group_bar_decorate_font_desc")
                            placeholderText: "(default)"
                            onEditingFinished: root.setCfgValue("group_bar_decorate_font_desc", text.trim())
                        }
                    }
                }
            }

            // Other keys in the file
            StyledRect {
                width: parent.width
                implicitHeight: otherKeysCol.implicitHeight + Theme.spacingL * 2
                height: implicitHeight
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1
                visible: root.otherKeysSorted().length > 0

                Column {
                    id: otherKeysCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Other keys (from your file)"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Repeater {
                        model: root.otherKeysSorted()

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledText {
                                width: 220
                                text: modelData
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            EHTextField {
                                width: parent.width - 220 - Theme.spacingM
                                text: root.gv(modelData)
                                onEditingFinished: root.setCfgValue(modelData, text.trim())
                            }
                        }
                    }
                }
            }
        }
    }
}

