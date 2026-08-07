import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modals
import qs.Modals.FileBrowser

Item {
    id: keybindsTab

    property var parentModal: null

    readonly property string _configBasePath: {
        const cfg = _stripFileUrl(Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.ConfigLocation)))
        if (cfg && cfg.length > 0) return cfg
        const home = _stripFileUrl(Quickshell.env("HOME") || Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation)))
        return home ? home + "/.config" : ""
    }

    readonly property string defaultKeybindsPath: _configBasePath + "/hypr/hyprland/keybinds.lua"

    property string keybindsPath: (SettingsData.keybindsPath && SettingsData.keybindsPath !== "") ? SettingsData.keybindsPath : defaultKeybindsPath

    readonly property string resolvedKeybindsPath: _resolveKeybindsPath(keybindsPath)

    property var keybinds: []
    property bool isLoading: false
    property bool hasUnsavedChanges: false
    property int editingIndex: -1
    property string searchQuery: ""
    property string selectedCategory: ""
    property bool showingNewBind: false
    property string expandedKey: ""

    property var _filteredBinds: []
    property var _cachedCategories: []
    property real _savedScrollY: 0
    property bool _preserveScroll: false
    property bool _configFileExists: true
    property bool _checkingFileExists: false



    Component.onCompleted: {
        checkConfigFileExists()
        loadKeybinds()
    }

    function _stripFileUrl(p) {
        if (!p) return ""
        return p.replace(/^file:\/\//, "")
    }

    function _resolveKeybindsPath(path) {
        const baseConfig = _configBasePath || ""
        const homeEnv = _stripFileUrl(Quickshell.env("HOME") || Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation)) || "")

        var cleaned = (path || "").trim()
        if (cleaned.length === 0) {
            return defaultKeybindsPath
        }

        cleaned = _stripFileUrl(cleaned)

        if (cleaned.startsWith("~/")) {
            cleaned = homeEnv + cleaned.substring(1)
        } else {
            cleaned = cleaned.replace(/^\$HOME/, homeEnv)
            cleaned = cleaned.replace(/^\${HOME}/, homeEnv)
        }

        const looksAbsolute = cleaned.startsWith("/") || cleaned.match(/^[A-Za-z]:[\\/]/)
        if (!looksAbsolute) {
            cleaned = (baseConfig ? baseConfig : homeEnv) + "/" + cleaned
        }

        return cleaned
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(scrollToTop)
            checkConfigFileExists()
        }
    }

    function checkConfigFileExists() {
        if (_checkingFileExists) return
        _checkingFileExists = true
        checkFileProcess.command = ["test", "-f", resolvedKeybindsPath]
        checkFileProcess.running = true
    }

    function loadKeybinds() {
        isLoading = true
        keybindsFile.path = ""
        keybindsFile.path = resolvedKeybindsPath
    }

    function _isLuaFile() {
        return resolvedKeybindsPath.toLowerCase().endsWith('.lua')
    }

    function parseKeybinds(content) {
        var lines = content.split('\n')
        var parsed = []

        for (var i = 0; i < lines.length; i++) {
            var rawLine = lines[i]
            var line = rawLine.trim()

            if (line.length === 0) {
                parsed.push({
                    type: 'comment',
                    original: rawLine,
                    text: ''
                })
                continue
            }

            if (line.startsWith('#') || line.startsWith('--')) {
                parsed.push({
                    type: 'comment',
                    original: rawLine,
                    text: line
                })
                continue
            }

            var isLuaBind = false
            var dqMatch = line.match(/^hl\.bind\(\s*"([^"]*)"\s*,\s*(.+)$/)
            var sqMatch = !dqMatch ? line.match(/^hl\.bind\(\s*'([^']*)'\s*,\s*(.+)$/) : null
            if (dqMatch || sqMatch) {
                var m = dqMatch || sqMatch
                var keyCombo = m[1]
                var rest = m[2]
                var depth = 0
                var closeParen = -1
                for (var j = 0; j < rest.length; j++) {
                    if (rest[j] === '(') depth++
                    else if (rest[j] === ')') {
                        if (depth === 0) { closeParen = j; break }
                        depth--
                    }
                }
                if (closeParen > 0) {
                    var dispatcher = rest.substring(0, closeParen).trim()
                    var opts = rest.substring(closeParen + 1).trim()
                    var lastPlus = keyCombo.lastIndexOf(' + ')
                    var mods = lastPlus >= 0 ? keyCombo.substring(0, lastPlus).trim() : ''
                    var k = lastPlus >= 0 ? keyCombo.substring(lastPlus + 3).trim() : keyCombo.trim()
                    parsed.push({
                        type: 'keybind',
                        original: rawLine,
                        modifiers: mods,
                        key: k,
                        command: dispatcher,
                        isRelease: opts.indexOf('release = true') >= 0
                    })
                    isLuaBind = true
                }
            }
            if (isLuaBind) continue

            var bindMatch = line.match(/^bind[rs]?\s*=\s*(.+)$/)
            if (bindMatch) {
                var parts = bindMatch[1].split(',').map(function(p) { return p.trim() })
                if (parts.length >= 2) {
                    parsed.push({
                        type: 'keybind',
                        original: rawLine,
                        modifiers: parts[0],
                        key: parts[1],
                        command: parts.slice(2).join(',').trim(),
                        isRelease: line.startsWith('bindr')
                    })
                    continue
                }
            }

            parsed.push({
                type: 'raw',
                original: rawLine,
                text: line
            })
        }

        keybinds = parsed
        isLoading = false
        hasUnsavedChanges = false
        _updateCategories()
        _updateFiltered()
    }

    function _updateFiltered() {
        const allBinds = keybinds.filter(k => k.type === 'keybind')
        if (!searchQuery && !selectedCategory) {
            _filteredBinds = allBinds
            return
        }

        const q = searchQuery.toLowerCase()
        const result = []

        for (let i = 0; i < allBinds.length; i++) {
            const bind = allBinds[i]

            if (q) {
                const keyStr = (bind.modifiers || "") + " " + (bind.key || "") + " " + (bind.command || "")
                if (keyStr.toLowerCase().indexOf(q) === -1) {
                    continue
                }
            }

            if (selectedCategory) {
                const category = _getCategoryForBind(bind)
                if (category !== selectedCategory) {
                    continue
                }
            }

            result.push(bind)
        }
        _filteredBinds = result
    }

    function _getCategoryForBind(bind) {
        if (!bind.command) return ""
        const cmd = bind.command.toLowerCase()
        if (cmd.includes("workspace")) return "Workspaces"
        if (cmd.includes("move") || cmd.includes("resize")) return "Window Management"
        if (cmd.includes("exec") || cmd.includes("$")) return "Applications"
        if (cmd.includes("toggle") || cmd.includes("fullscreen") || cmd.includes("floating")) return "Window Actions"
        if (cmd.includes("focus")) return "Focus"
        if (cmd.includes("ipc") || cmd.includes("quickshell")) return "Quickshell"
        return "Other"
    }

    function _updateCategories() {
        const allBinds = keybinds.filter(k => k.type === 'keybind')
        const categories = new Set()
        for (let i = 0; i < allBinds.length; i++) {
            const cat = _getCategoryForBind(allBinds[i])
            if (cat) categories.add(cat)
        }
        _cachedCategories = Array.from(categories).sort()
    }

    function toggleExpanded(bind) {
        const key = (bind.modifiers || "") + "+" + (bind.key || "")
        expandedKey = expandedKey === key ? "" : key
    }

    function isExpanded(bind) {
        const key = (bind.modifiers || "") + "+" + (bind.key || "")
        return expandedKey === key
    }

    function saveKeybinds() {
        _savedScrollY = flickable.contentY
        _preserveScroll = true

        var lines = []
        var lastWasEmpty = false

        for (var i = 0; i < keybinds.length; i++) {
            var item = keybinds[i]
            var line = ""

            if (item.type === 'comment' || item.type === 'raw') {
                line = item.original
            } else if (item.type === 'keybind') {
                if (_isLuaFile()) {
                    var keyCombo = item.modifiers ? item.modifiers + ' + ' + item.key : item.key
                    var suffix = item.isRelease ? ', {release = true}' : ''
                    line = 'hl.bind("' + keyCombo + '", ' + item.command + suffix + ')'
                } else {
                    var bindType = item.isRelease ? 'bindr' : 'bind'
                    var parts = [item.modifiers, item.key]
                    if (item.command) {
                        parts.push(item.command)
                    }
                    line = bindType + ' = ' + parts.join(', ')
                }
            } else {
                line = item.original
            }

            line = line.replace(/\s+$/, '')

            var isEmpty = line.length === 0 || line.trim().length === 0
            if (isEmpty && lastWasEmpty) {
                continue
            }
            lastWasEmpty = isEmpty

            lines.push(line)
        }

        while (lines.length > 0 && lines[lines.length - 1].trim().length === 0) {
            lines.pop()
        }

        var content = lines.join('\n')

        var targetPath = resolvedKeybindsPath
        var lastSlash = targetPath.lastIndexOf('/')
        var dirPath = lastSlash >= 0 ? targetPath.substring(0, lastSlash) : "."
        if (!dirPath || dirPath.length === 0) {
            dirPath = "."
        }

        if (!targetPath || targetPath.trim().length === 0) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Keybinds path is empty; set a valid path in Settings")
            }
            return
        }

        pendingSaveContent = content
        ensureDirProcess.command = ["mkdir", "-p", dirPath]
        ensureDirProcess.running = true

        if (typeof ToastService !== "undefined") {
            ToastService.showInfo("Saving keybinds to " + targetPath)
        }
    }

    Process {
        id: ensureDirProcess
        command: ["mkdir", "-p"]
        running: false

        onExited: exitCode => {
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", resolvedKeybindsPath]
                touchFileProcess.running = true
            }
        }
    }

    Process {
        id: touchFileProcess
        command: ["touch"]
        running: false

        onExited: exitCode => {
            if (pendingSaveContent !== "") {
                saveKeybindsFile.path = ""
                Qt.callLater(() => {
                    saveKeybindsFile.path = resolvedKeybindsPath
                    Qt.callLater(() => {
                        saveKeybindsFile.setText(pendingSaveContent)
                    })
                })
            }
        }
    }

    property string pendingSaveContent: ""

    function addNewKeybind() {
        var newKeybind = {
            type: 'keybind',
            original: _isLuaFile() ? 'hl.bind(" + ", hl.dsp.exec_cmd(""))' : 'bind = , , ',
            modifiers: '',
            key: '',
            command: '',
            isRelease: false
        }
        keybinds.push(newKeybind)
        editingIndex = keybinds.length - 1
        hasUnsavedChanges = true
        showingNewBind = true
        _updateFiltered()
        Qt.callLater(() => {
            if (newModifiersField) {
                newModifiersField.forceActiveFocus()
            }
        })
    }

    function cancelNewBind() {
        if (editingIndex >= 0 && editingIndex < keybinds.length) {
            keybinds.splice(editingIndex, 1)
        }
        editingIndex = -1
        showingNewBind = false
        hasUnsavedChanges = false
        _updateFiltered()
    }

    function saveNewBind() {
        if (editingIndex >= 0 && editingIndex < keybinds.length) {
            var bind = keybinds[editingIndex]
            if (bind.modifiers && bind.key && bind.command) {
                hasUnsavedChanges = true
                showingNewBind = false
                editingIndex = -1
                _updateFiltered()
            } else {
                cancelNewBind()
            }
        }
    }

    function addBuiltInKeybind(builtIn) {
        var newKeybind = {
            type: 'keybind',
            original: _isLuaFile() ? 'hl.bind("' + builtIn.modifiers + ' + ' + builtIn.key + '", ' + builtIn.command + ')' : 'bind = ' + builtIn.modifiers + ', ' + builtIn.key + ', ' + builtIn.command,
            modifiers: builtIn.modifiers,
            key: builtIn.key,
            command: builtIn.command,
            isRelease: false
        }
        keybinds.push(newKeybind)
        editingIndex = keybinds.length - 1
        hasUnsavedChanges = true
        builtInKeybindsPopup.close()
        _updateFiltered()
    }

    function _isNewBindComplete() {
        if (!showingNewBind) return true
        if (editingIndex < 0 || editingIndex >= keybinds.length) return false
        const bind = keybinds[editingIndex]
        return !!(bind.modifiers && bind.modifiers.trim() && bind.key && bind.key.trim() && bind.command && bind.command.trim())
    }

    function _saveChanges() {
        if (showingNewBind && !_isNewBindComplete()) {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Fill out modifier, key, and command before saving")
            }
            return
        }

        if (showingNewBind) {
            saveNewBind()
        }
        saveKeybinds()
    }

    function startEditing(index) {
        editingIndex = index
    }

    function stopEditing() {
        editingIndex = -1
    }

    function scrollToTop() {
        flickable.contentY = 0
    }

    Timer {
        id: searchDebounce
        interval: 150
        onTriggered: keybindsTab._updateFiltered()
    }

    FileView {
        id: keybindsFile
        path: keybindsTab.resolvedKeybindsPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            var fileContent = text()
            const savedY = keybindsTab._savedScrollY
            const wasPreserving = keybindsTab._preserveScroll
            keybindsTab._preserveScroll = false
            parseKeybinds(fileContent)
            if (wasPreserving) {
                Qt.callLater(() => {
                    flickable.contentY = savedY
                })
            }
        }

        onLoadFailed: {
            isLoading = false
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to load keybinds file")
            }
        }
    }

    Process {
        id: checkFileProcess
        command: ["test", "-f"]
        running: false

        onExited: exitCode => {
            _configFileExists = (exitCode === 0)
            _checkingFileExists = false
        }
    }

    FileView {
        id: saveKeybindsFile
        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onSaved: {
            hasUnsavedChanges = false
            if (typeof ToastService !== "undefined") {
                ToastService.showInfo("Keybinds saved: " + keybindsTab.resolvedKeybindsPath)
            }
            const savedY = keybindsTab._savedScrollY
            const wasPreserving = keybindsTab._preserveScroll
            keybindsTab._preserveScroll = false
            Qt.callLater(() => {
                keybindsFile.reload()
                if (wasPreserving) {
                    Qt.callLater(() => {
                        flickable.contentY = savedY
                    })
                }
            })
            reloadHyprlandProcess.running = true
            pendingSaveContent = ""
        }

        onSaveFailed: (error) => {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to save keybinds file (" + keybindsTab.resolvedKeybindsPath + "): " + (error || "Unknown error"))
            }
            pendingSaveContent = ""
        }
    }

    Process {
        id: reloadHyprlandProcess
        command: ["hyprctl", "reload"]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined") {
                    ToastService.showInfo("Hyprland configuration reloaded")
                }
            } else {
                if (typeof ToastService !== "undefined") {
                    ToastService.showError("Failed to reload Hyprland configuration")
                }
            }
        }
    }

    EHFlickable {
        id: flickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + Theme.spacingL

        Column {
            id: contentColumn
            width: flickable.width
            spacing: Theme.spacingL
            topPadding: Theme.spacingL
            bottomPadding: Theme.spacingL

            StyledRect {
                width: parent.width
                height: headerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: headerSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "keyboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Keybinds"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Manage keyboard shortcuts for Hyprland"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHTextField {
                            id: searchField
                            width: parent.width - addButton.width - Theme.spacingM
                            height: 44
                            placeholderText: "Search keybinds..."
                            leftIconName: "search"
                            autoExpandWidth: false
                            autoExpandHeight: false
                            onTextChanged: {
                                keybindsTab.searchQuery = text
                                searchDebounce.restart()
                            }
                        }

                        EHActionButton {
                            id: addButton
                            width: 44
                            height: 44
                            circular: false
                            iconName: "add"
                            iconSize: Theme.iconSize
                            iconColor: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !keybindsTab.showingNewBind
                            opacity: enabled ? 1 : 0.5
                            onClicked: keybindsTab.addNewKeybind()
                        }
                    }

                }
            }

            StyledRect {
                id: warningBox
                width: parent.width
                height: warningSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                readonly property bool showWarning: !_configFileExists && !isLoading
                color: showWarning ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                border.color: showWarning ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                border.width: 1
                visible: showWarning

                Column {
                    id: warningSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "warning"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Config File Missing"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.primary
                            }

                            StyledText {
                                text: "The keybinds config file does not exist. It will be created when you save your first keybind."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                visible: _cachedCategories.length > 0

                        Rectangle {
                            width: allChipText.implicitWidth + Theme.spacingL
                            height: 32
                            radius: Theme.cornerRadius
                            color: !keybindsTab.selectedCategory ? Theme.primary : Theme.surfaceContainer

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            StyledText {
                                id: allChipText
                                text: "All"
                                font.pixelSize: Theme.fontSizeSmall
                                color: !keybindsTab.selectedCategory ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keybindsTab.selectedCategory = ""
                                    keybindsTab._updateFiltered()
                                }
                            }
                        }

                        Repeater {
                            model: keybindsTab._cachedCategories

                            delegate: Rectangle {
                                required property string modelData
                                required property int index

                                width: catText.implicitWidth + Theme.spacingL
                                height: 32
                                radius: Theme.cornerRadius
                                color: keybindsTab.selectedCategory === modelData ? Theme.primary : Theme.surfaceContainer

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                StyledText {
                                    id: catText
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: keybindsTab.selectedCategory === modelData ? Theme.primaryText : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        keybindsTab.selectedCategory = modelData
                                        keybindsTab._updateFiltered()
                                    }
                                }
                            }
                        }
            }

            Column {
                id: newBindSection
                width: parent.width
                spacing: Theme.spacingM
                visible: keybindsTab.showingNewBind
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                StyledText {
                    text: "New Keybind"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Row {
                    id: keybindEditRow
                    width: parent.width
                    spacing: Theme.spacingM

                            EHTextField {
                                id: newModifiersField
                                width: 140
                                height: 40
                                placeholderText: "MODIFIER"
                                autoExpandWidth: false
                                autoExpandHeight: false
                                text: editingIndex >= 0 && editingIndex < keybinds.length ? keybinds[editingIndex].modifiers || "" : ""
                                onTextChanged: {
                                    if (editingIndex >= 0 && editingIndex < keybinds.length) {
                                        keybinds[editingIndex].modifiers = text
                                        hasUnsavedChanges = true
                                    }
                                }
                                Keys.onEscapePressed: cancelNewBind()
                                Keys.onTabPressed: newKeyField.forceActiveFocus()
                                Keys.onEnterPressed: {
                                    if (newKeyField.text && newCommandField.text) {
                                        saveNewBind()
                                    } else {
                                        newKeyField.forceActiveFocus()
                                    }
                                }
                                Keys.onReturnPressed: {
                                    if (newKeyField.text && newCommandField.text) {
                                        saveNewBind()
                                    } else {
                                        newKeyField.forceActiveFocus()
                                    }
                                }
                            }

                            EHTextField {
                                id: newKeyField
                                width: 120
                                height: 40
                                placeholderText: "KEY"
                                autoExpandWidth: false
                                autoExpandHeight: false
                                text: editingIndex >= 0 && editingIndex < keybinds.length ? keybinds[editingIndex].key || "" : ""
                                onTextChanged: {
                                    if (editingIndex >= 0 && editingIndex < keybinds.length) {
                                        keybinds[editingIndex].key = text
                                        hasUnsavedChanges = true
                                    }
                                }
                                Keys.onEscapePressed: cancelNewBind()
                                Keys.onTabPressed: newCommandField.forceActiveFocus()
                                Keys.onEnterPressed: {
                                    if (newModifiersField.text && newCommandField.text) {
                                        saveNewBind()
                                    } else {
                                        newCommandField.forceActiveFocus()
                                    }
                                }
                                Keys.onReturnPressed: {
                                    if (newModifiersField.text && newCommandField.text) {
                                        saveNewBind()
                                    } else {
                                        newCommandField.forceActiveFocus()
                                    }
                                }
                            }

                            EHTextField {
                                id: newCommandField
                                width: parent.width - 140 - 120 - Theme.spacingM * 2 - 80
                                height: 40
                                placeholderText: "COMMAND"
                                autoExpandWidth: false
                                autoExpandHeight: false
                                text: editingIndex >= 0 && editingIndex < keybinds.length ? keybinds[editingIndex].command || "" : ""
                                onTextChanged: {
                                    if (editingIndex >= 0 && editingIndex < keybinds.length) {
                                        keybinds[editingIndex].command = text
                                        hasUnsavedChanges = true
                                    }
                                }
                                Keys.onEscapePressed: cancelNewBind()
                                Keys.onEnterPressed: {
                                    if (newModifiersField.text && newKeyField.text) {
                                        saveNewBind()
                                    }
                                }
                                Keys.onReturnPressed: {
                                    if (newModifiersField.text && newKeyField.text) {
                                        saveNewBind()
                                    }
                                }
                            }

                            EHActionButton {
                                width: 36
                                height: 36
                                circular: true
                                iconName: "close"
                                iconSize: 18
                                iconColor: Theme.error
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: cancelNewBind()
                            }
                }
            }

            Item {
                width: parent.width
                height: isLoading ? 40 : 0
                visible: isLoading

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "sync"
                        size: 20
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: isLoading
                        }
                    }

                    StyledText {
                        text: "Loading keybinds..."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StyledText {
                text: "No keybinds found"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: !isLoading && _filteredBinds.length === 0
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                Repeater {
                    model: keybindsTab._filteredBinds

                    Item {
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: bindItem.height

                        StyledRect {
                            id: bindItem
                            width: contentColumn.width
                            height: collapsedContent.height + (isExpanded ? expandedContent.height + Theme.spacingM : 0) + Theme.spacingL * 2
                            radius: Theme.cornerRadius
                            color: itemMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, Theme.popupTransparency)
                            border.color: Theme.outlineVariant
                            border.width: 1

                            property bool isExpanded: keybindsTab.isExpanded(modelData)

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Column {
                                id: collapsedContent
                                anchors.left: parent.left
                                anchors.right: expandButton.left
                                anchors.top: parent.top
                                anchors.leftMargin: Theme.spacingL
                                anchors.rightMargin: Theme.spacingM
                                anchors.topMargin: Theme.spacingL
                                spacing: Theme.spacingXS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    StyledText {
                                        width: 140
                                        text: modelData.modifiers || "MOD"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: modelData.modifiers ? Theme.surfaceText : Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                    }

                                    StyledText {
                                        width: 120
                                        text: modelData.key || "key"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: modelData.key ? Theme.surfaceText : Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                    }

                                    StyledText {
                                        width: parent.width - 140 - 120 - Theme.spacingM * 2
                                        text: modelData.command || "command"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: modelData.command ? Theme.surfaceText : Theme.surfaceVariantText
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Column {
                                id: expandedContent
                                anchors.left: parent.left
                                anchors.right: expandButton.left
                                anchors.top: collapsedContent.bottom
                                anchors.leftMargin: Theme.spacingL
                                anchors.rightMargin: Theme.spacingM
                                anchors.topMargin: Theme.spacingM
                                spacing: Theme.spacingM
                                visible: bindItem.isExpanded
                                height: visible ? implicitHeight : 0

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                opacity: visible ? 1 : 0

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    EHTextField {
                                        id: modifiersField
                                        width: 140
                                        height: 40
                                        placeholderText: "MODIFIER"
                                        autoExpandWidth: false
                                        autoExpandHeight: false
                                        text: modelData.modifiers || ""
                                        onTextChanged: {
                                            if (modelData.modifiers !== text) {
                                                // Find the bind in the keybinds array by matching properties
                                                var bindIndex = -1
                                                for (var i = 0; i < keybindsTab.keybinds.length; i++) {
                                                    var bind = keybindsTab.keybinds[i]
                                                    if (bind.type === 'keybind' &&
                                                        bind.modifiers === modelData.modifiers &&
                                                        bind.key === modelData.key &&
                                                        bind.command === modelData.command) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsTab.keybinds[bindIndex].modifiers = text
                                                }
                                                modelData.modifiers = text
                                                keybindsTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsTab.toggleExpanded(modelData)
                                        Keys.onTabPressed: {
                                            keyField.forceActiveFocus()
                                            keyField.selectAll()
                                        }
                                        Keys.onEnterPressed: keybindsTab._saveChanges()
                                        Keys.onReturnPressed: keybindsTab._saveChanges()
                                    }

                                    EHTextField {
                                        id: keyField
                                        width: 120
                                        height: 40
                                        placeholderText: "KEY"
                                        autoExpandWidth: false
                                        autoExpandHeight: false
                                        text: modelData.key || ""
                                        onTextChanged: {
                                            if (modelData.key !== text) {
                                                // Find the bind in the keybinds array by matching properties
                                                var bindIndex = -1
                                                for (var i = 0; i < keybindsTab.keybinds.length; i++) {
                                                    var bind = keybindsTab.keybinds[i]
                                                    if (bind.type === 'keybind' &&
                                                        bind.modifiers === modelData.modifiers &&
                                                        bind.key === modelData.key &&
                                                        bind.command === modelData.command) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsTab.keybinds[bindIndex].key = text
                                                }
                                                modelData.key = text
                                                keybindsTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsTab.toggleExpanded(modelData)
                                        Keys.onTabPressed: {
                                            commandField.forceActiveFocus()
                                            commandField.selectAll()
                                        }
                                        Keys.onEnterPressed: keybindsTab._saveChanges()
                                        Keys.onReturnPressed: keybindsTab._saveChanges()
                                    }

                                    EHTextField {
                                        id: commandField
                                        width: parent.width - 140 - 120 - Theme.spacingM * 2
                                        height: 40
                                        placeholderText: "COMMAND"
                                        autoExpandWidth: false
                                        autoExpandHeight: false
                                        text: modelData.command || ""
                                        onTextChanged: {
                                            if (modelData.command !== text) {
                                                // Find the bind in the keybinds array by matching properties
                                                var bindIndex = -1
                                                for (var i = 0; i < keybindsTab.keybinds.length; i++) {
                                                    var bind = keybindsTab.keybinds[i]
                                                    if (bind.type === 'keybind' &&
                                                        bind.modifiers === modelData.modifiers &&
                                                        bind.key === modelData.key &&
                                                        bind.command === modelData.command) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsTab.keybinds[bindIndex].command = text
                                                }
                                                modelData.command = text
                                                keybindsTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsTab.toggleExpanded(modelData)
                                        Keys.onEnterPressed: keybindsTab._saveChanges()
                                        Keys.onReturnPressed: keybindsTab._saveChanges()
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    layoutDirection: Qt.RightToLeft

                                    EHActionButton {
                                        buttonSize: 36
                                        circular: false
                                        iconName: "delete"
                                        iconSize: 18
                                        iconColor: Theme.error
                                        onClicked: {
                                            var bindIndex = -1
                                            for (var i = 0; i < keybindsTab.keybinds.length; i++) {
                                                var bind = keybindsTab.keybinds[i]
                                                if (bind.type === 'keybind' &&
                                                    bind.modifiers === modelData.modifiers &&
                                                    bind.key === modelData.key &&
                                                    bind.command === modelData.command) {
                                                    bindIndex = i
                                                    break
                                                }
                                            }
                                            if (bindIndex >= 0) {
                                                keybindsTab._savedScrollY = flickable.contentY
                                                keybindsTab._preserveScroll = true
                                                keybindsTab.hasUnsavedChanges = true
                                                keybindsTab.keybinds.splice(bindIndex, 1)
                                                keybindsTab._updateFiltered()
                                                Qt.callLater(() => {
                                                    if (keybindsTab._preserveScroll) {
                                                        flickable.contentY = keybindsTab._savedScrollY
                                                        keybindsTab._preserveScroll = false
                                                    }
                                                })
                                            }
                                        }
                            }
                                }
                            }

                            EHActionButton {
                                id: expandButton
                                buttonSize: 32
                                circular: true
                                iconName: bindItem.isExpanded ? "expand_less" : "expand_more"
                                iconSize: 18
                                iconColor: Theme.surfaceVariantText
                                anchors.top: parent.top
                                anchors.topMargin: Theme.spacingL
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                onClicked: keybindsTab.toggleExpanded(modelData)

                                Behavior on iconColor {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: bindItem.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor
                                propagateComposedEvents: true
                                acceptedButtons: bindItem.isExpanded ? Qt.NoButton : Qt.AllButtons
                                onClicked: {
                                    if (!bindItem.isExpanded) {
                                        keybindsTab.toggleExpanded(modelData)
                                        Qt.callLater(() => {
                                            if (modifiersField) {
                                                modifiersField.forceActiveFocus()
                                                modifiersField.selectAll()
                                            }
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    StyledRect {
        id: saveBanner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingXL
        width: Math.min(parent.width - Theme.spacingL * 2, 420)
        height: keybindsTab.hasUnsavedChanges ? 60 : 0
        visible: keybindsTab.hasUnsavedChanges || height > 0
        opacity: keybindsTab.hasUnsavedChanges ? 1 : 0
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, Theme.popupTransparency)
        border.color: Theme.outlineVariant
        border.width: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.25)
            shadowBlur: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                text: "Unsaved changes"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width - saveChangesButton.width - parent.spacing
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            StyledRect {
                id: saveChangesButton
                width: 132
                height: 40
                radius: Theme.cornerRadius
                enabled: keybindsTab.hasUnsavedChanges && keybindsTab._isNewBindComplete()
                color: enabled ? (saveButtonMouseArea.containsMouse ? Theme.primary : Theme.primary) : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.4)
                border.color: enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                opacity: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    EHIcon {
                        name: "save"
                        size: 18
                        color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Save"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: saveButtonMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!enabled) return
                        keybindsTab._saveChanges()
                    }
                }
            }
        }
    }

    Popup {
        id: builtInKeybindsPopup

        parent: Overlay.overlay
        width: 500
        height: Math.min(600, builtInList.height + Theme.spacingL * 2)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: StyledRect {
            color: Theme.surfaceContainer
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            border.width: 1
            radius: Theme.cornerRadius

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.3)
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 4
            }
        }

        Column {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                EHIcon {
                    name: "list"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - Theme.iconSize - Theme.spacingM
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: "Built-in Keybinds"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "Select a keybind to add to your configuration"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            EHFlickable {
                width: parent.width
                height: parent.height - 100
                clip: true
                contentHeight: builtInList.height
                contentWidth: width

                Column {
                    id: builtInList
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: keybindsTab.builtInKeybinds

                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: builtInMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Column {
                                    width: parent.width - 100
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: modelData.modifiers + " + " + modelData.key + " → " + modelData.command
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        font.family: SettingsData.monoFontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                EHActionButton {
                                    buttonSize: 32
                                    circular: true
                                    iconName: "add"
                                    iconSize: 18
                                    iconColor: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: keybindsTab.addBuiltInKeybind(modelData)
                                }
                            }

                            MouseArea {
                                id: builtInMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: keybindsTab.addBuiltInKeybind(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: keybindsFileBrowser

        browserTitle: "Select Keybinds Config File"
        browserIcon: "keyboard"
        browserType: "generic"
        fileExtensions: ["*.conf", "*.lua"]
        saveMode: false
        showHiddenFiles: true

        onFileSelected: path => {
            var cleanPath = path.replace(/^file:\/\//, '')
            SettingsData.keybindsPath = cleanPath
            SettingsData.saveSettings()
            keybindsTab.keybindsPath = cleanPath
            checkConfigFileExists()
            loadKeybinds()
            close()
        }
    }
}
