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
import qs.Services

Item {
    id: keybindsMangoTab

    property var parentModal: null

    readonly property bool isMango: typeof CompositorService !== "undefined" && CompositorService.isMango

    readonly property string _configBasePath: {
        const cfg = _stripFileUrl(Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.ConfigLocation)))
        if (cfg && cfg.length > 0) return cfg
        const home = _stripFileUrl(Quickshell.env("HOME") || Paths.stringify(Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation)))
        return home ? home + "/.config" : ""
    }

    readonly property string resolvedKeybindsPath: _configBasePath + "/mango/hyprmango/keybinds.conf"

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

    readonly property var builtInKeybinds: [
        { "name": "Reload Mango config", "bindPrefix": "bind", "modifiers": "CTRL+SUPER", "key": "r", "command": "reload_config" },
        { "name": "Quit compositor", "bindPrefix": "bind", "modifiers": "SUPER", "key": "m", "command": "quit" },
        { "name": "Close window", "bindPrefix": "bind", "modifiers": "ALT", "key": "q", "command": "killclient" },
        { "name": "Rofi launcher", "bindPrefix": "bind", "modifiers": "ALT", "key": "space", "command": "spawn,rofi -show drun" },
        { "name": "Terminal (foot)", "bindPrefix": "bind", "modifiers": "ALT", "key": "Return", "command": "spawn,foot" },
        { "name": "Focus — left", "bindPrefix": "bind", "modifiers": "ALT", "key": "Left", "command": "focusdir,left" },
        { "name": "Focus — right", "bindPrefix": "bind", "modifiers": "ALT", "key": "Right", "command": "focusdir,right" },
        { "name": "Toggle floating", "bindPrefix": "bind", "modifiers": "ALT", "key": "backslash", "command": "togglefloating" },
        { "name": "Toggle fullscreen", "bindPrefix": "bind", "modifiers": "ALT", "key": "f", "command": "togglefullscreen" },
        { "name": "Tag workspace 1", "bindPrefix": "bind", "modifiers": "ALT", "key": "1", "command": "tag,1,0" },
        { "name": "View tag 1", "bindPrefix": "bind", "modifiers": "CTRL", "key": "1", "command": "view,1,0" },
        { "name": "Layout — switch", "bindPrefix": "bind", "modifiers": "SUPER", "key": "n", "command": "switch_layout" },
        { "name": "QS cheatsheet (example)", "bindPrefix": "bind", "modifiers": "SUPER", "key": "slash", "command": "spawn,quickshell ipc call cheatsheet toggle" },
        { "name": "QS overview (example)", "bindPrefix": "bind", "modifiers": "SUPER", "key": "Tab", "command": "spawn_shell,qs ipc call workspaceoverview toggle" }
    ]

    Component.onCompleted: {
        checkConfigFileExists()
        loadKeybinds()
    }

    function _stripFileUrl(p) {
        if (!p) return ""
        return p.replace(/^file:\/\//, "")
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

    function parseKeybinds(content) {
        var lines = content.split('\n')
        var parsed = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.length === 0 || line.startsWith('#')) {
                parsed.push({
                    type: 'comment',
                    original: lines[i],
                    text: line
                })
                continue
            }

            var mPrefix = line.match(/^(bind[a-z]*)\s*=\s*(.+)$/i)
            if (mPrefix) {
                var bindPrefix = mPrefix[1]
                var afterEq = mPrefix[2]
                var c1 = afterEq.indexOf(",")
                if (c1 < 0) {
                    parsed.push({ type: 'raw', original: lines[i], text: line })
                } else {
                    var modifiers = afterEq.slice(0, c1).trim()
                    var afterMod = afterEq.slice(c1 + 1)
                    var c2 = afterMod.indexOf(",")
                    if (c2 < 0) {
                        parsed.push({
                            type: 'keybind',
                            original: lines[i],
                            bindPrefix: bindPrefix,
                            modifiers: modifiers,
                            key: afterMod.trim(),
                            command: "",
                            isRelease: bindPrefix === "bindr" || bindPrefix === "bindrl"
                        })
                    } else {
                        var key = afterMod.slice(0, c2).trim()
                        var command = afterMod.slice(c2 + 1).trim()
                        parsed.push({
                            type: 'keybind',
                            original: lines[i],
                            bindPrefix: bindPrefix,
                            modifiers: modifiers,
                            key: key,
                            command: command,
                            isRelease: bindPrefix === "bindr" || bindPrefix === "bindrl"
                        })
                    }
                }
            } else {
                parsed.push({
                    type: 'raw',
                    original: lines[i],
                    text: line
                })
            }
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
        if (cmd.startsWith("tag,") || cmd.startsWith("view,") || cmd.indexOf("viewto") === 0 || cmd.indexOf("tagto") === 0) return "Tags / workspaces"
        if (cmd.indexOf("focus") === 0 || cmd.indexOf("focusdir") === 0 || cmd.indexOf("focusstack") === 0) return "Focus"
        if (cmd.indexOf("movewin") === 0 || cmd.indexOf("resizewin") === 0 || cmd.indexOf("exchange_") === 0) return "Move & resize"
        if (cmd.indexOf("spawn") === 0 || cmd.indexOf("spawn_shell") === 0) return "Launch"
        if (cmd.indexOf("toggle") === 0 || cmd.indexOf("minimized") === 0) return "Window toggles"
        if (cmd.indexOf("mon") > 0 || cmd.startsWith("focusmon") || cmd.startsWith("tagmon")) return "Monitors"
        if (cmd.includes("quickshell") || cmd.includes(" qs ") || cmd.startsWith("qs ")) return "Quickshell"
        if (cmd === "quit" || cmd === "reload_config" || cmd === "killclient") return "System"
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

    function bindSignature(b) {
        if (!b || b.type !== "keybind")
            return ""
        return (b.bindPrefix || "bind") + ":" + (b.modifiers || "") + "," + (b.key || "") + "," + (b.command || "")
    }

    function _sameKeybindForEdit(bind, modelData) {
        if (!bind || bind.type !== "keybind" || !modelData)
            return false
        const bp1 = bind.bindPrefix || "bind"
        const bp2 = modelData.bindPrefix || "bind"
        return bp1 === bp2 && bind.modifiers === modelData.modifiers && bind.key === modelData.key && bind.command === modelData.command
    }

    function toggleExpanded(bind) {
        const key = bindSignature(bind)
        expandedKey = expandedKey === key ? "" : key
    }

    function isExpanded(bind) {
        return expandedKey === bindSignature(bind)
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
                var pfx = item.bindPrefix || (item.isRelease ? "bindr" : "bind")
                var partsK = [item.modifiers, item.key]
                if (item.command)
                    partsK.push(item.command)
                line = pfx + "=" + partsK.join(",")
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
            original: "bind=,,",
            bindPrefix: "bind",
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
        var pfx = builtIn.bindPrefix || "bind"
        var newKeybind = {
            type: 'keybind',
            original: pfx + '=' + builtIn.modifiers + ',' + builtIn.key + ',' + builtIn.command,
            bindPrefix: pfx,
            modifiers: builtIn.modifiers,
            key: builtIn.key,
            command: builtIn.command,
            isRelease: pfx === "bindr" || pfx === "bindrl"
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
        onTriggered: keybindsMangoTab._updateFiltered()
    }

    FileView {
        id: keybindsFile
        path: keybindsMangoTab.resolvedKeybindsPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true

        onLoaded: {
            var fileContent = text()
            const savedY = keybindsMangoTab._savedScrollY
            const wasPreserving = keybindsMangoTab._preserveScroll
            keybindsMangoTab._preserveScroll = false
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
                ToastService.showInfo("Keybinds saved: " + keybindsMangoTab.resolvedKeybindsPath)
            }
            const savedY = keybindsMangoTab._savedScrollY
            const wasPreserving = keybindsMangoTab._preserveScroll
            keybindsMangoTab._preserveScroll = false
            Qt.callLater(() => {
                keybindsFile.reload()
                if (wasPreserving) {
                    Qt.callLater(() => {
                        flickable.contentY = savedY
                    })
                }
            })
            reloadMangoKeybindsProcess.running = true
            pendingSaveContent = ""
        }

        onSaveFailed: (error) => {
            if (typeof ToastService !== "undefined") {
                ToastService.showError("Failed to save keybinds file (" + keybindsMangoTab.resolvedKeybindsPath + "): " + (error || "Unknown error"))
            }
            pendingSaveContent = ""
        }
    }

    Process {
        id: reloadMangoKeybindsProcess

        command: ["mmsg", "dispatch", "reload_config"]
        running: false

        onExited: exitCode => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Mango keybinds config reloaded")
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("mmsg reload_config failed; restart Mango if binds did not apply")
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
                            StyledText { text: "Mango keybinds"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Edit " + keybindsMangoTab.resolvedKeybindsPath + " — format bind=MODIFIERS,KEY,command (see Mango docs)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHTextField {
                            id: searchField
                            width: parent.width - addButton.width - presetTemplatesButton.width - Theme.spacingM * 2
                            height: 44
                            placeholderText: "Search keybinds..."
                            leftIconName: "search"
                            autoExpandWidth: false
                            autoExpandHeight: false
                            onTextChanged: {
                                keybindsMangoTab.searchQuery = text
                                searchDebounce.restart()
                            }
                        }

                        EHActionButton {
                            id: presetTemplatesButton
                            width: 44
                            height: 44
                            circular: false
                            iconName: "library_books"
                            iconSize: Theme.iconSize
                            iconColor: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: !keybindsMangoTab.showingNewBind
                            opacity: enabled ? 1 : 0.5
                            onClicked: builtInKeybindsPopup.open()
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
                            enabled: !keybindsMangoTab.showingNewBind
                            opacity: enabled ? 1 : 0.5
                            onClicked: keybindsMangoTab.addNewKeybind()
                        }
                    }

                }
            }

            StyledRect {
                width: parent.width
                height: mangoKeybindsHintCol.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1
                visible: !keybindsMangoTab.isMango

                Column {
                    id: mangoKeybindsHintCol
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
                            color: !keybindsMangoTab.selectedCategory ? Theme.primary : Theme.surfaceContainer

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
                                color: !keybindsMangoTab.selectedCategory ? Theme.primaryText : Theme.surfaceVariantText
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keybindsMangoTab.selectedCategory = ""
                                    keybindsMangoTab._updateFiltered()
                                }
                            }
                        }

                        Repeater {
                            model: keybindsMangoTab._cachedCategories

                            delegate: Rectangle {
                                required property string modelData
                                required property int index

                                width: catText.implicitWidth + Theme.spacingL
                                height: 32
                                radius: Theme.cornerRadius
                                color: keybindsMangoTab.selectedCategory === modelData ? Theme.primary : Theme.surfaceContainer

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
                                    color: keybindsMangoTab.selectedCategory === modelData ? Theme.primaryText : Theme.surfaceVariantText
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        keybindsMangoTab.selectedCategory = modelData
                                        keybindsMangoTab._updateFiltered()
                                    }
                                }
                            }
                        }
            }

            Column {
                id: newBindSection
                width: parent.width
                spacing: Theme.spacingM
                visible: keybindsMangoTab.showingNewBind
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
                    model: keybindsMangoTab._filteredBinds

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

                            property bool isExpanded: keybindsMangoTab.isExpanded(modelData)

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
                                                for (var i = 0; i < keybindsMangoTab.keybinds.length; i++) {
                                                    var bind = keybindsMangoTab.keybinds[i]
                                                    if (keybindsMangoTab._sameKeybindForEdit(bind, modelData)) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsMangoTab.keybinds[bindIndex].modifiers = text
                                                }
                                                modelData.modifiers = text
                                                keybindsMangoTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsMangoTab.toggleExpanded(modelData)
                                        Keys.onTabPressed: {
                                            keyField.forceActiveFocus()
                                            keyField.selectAll()
                                        }
                                        Keys.onEnterPressed: keybindsMangoTab._saveChanges()
                                        Keys.onReturnPressed: keybindsMangoTab._saveChanges()
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
                                                for (var i = 0; i < keybindsMangoTab.keybinds.length; i++) {
                                                    var bind = keybindsMangoTab.keybinds[i]
                                                    if (keybindsMangoTab._sameKeybindForEdit(bind, modelData)) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsMangoTab.keybinds[bindIndex].key = text
                                                }
                                                modelData.key = text
                                                keybindsMangoTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsMangoTab.toggleExpanded(modelData)
                                        Keys.onTabPressed: {
                                            commandField.forceActiveFocus()
                                            commandField.selectAll()
                                        }
                                        Keys.onEnterPressed: keybindsMangoTab._saveChanges()
                                        Keys.onReturnPressed: keybindsMangoTab._saveChanges()
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
                                                for (var i = 0; i < keybindsMangoTab.keybinds.length; i++) {
                                                    var bind = keybindsMangoTab.keybinds[i]
                                                    if (keybindsMangoTab._sameKeybindForEdit(bind, modelData)) {
                                                        bindIndex = i
                                                        break
                                                    }
                                                }
                                                if (bindIndex >= 0) {
                                                    keybindsMangoTab.keybinds[bindIndex].command = text
                                                }
                                                modelData.command = text
                                                keybindsMangoTab.hasUnsavedChanges = true
                                            }
                                        }
                                        Keys.onEscapePressed: keybindsMangoTab.toggleExpanded(modelData)
                                        Keys.onEnterPressed: keybindsMangoTab._saveChanges()
                                        Keys.onReturnPressed: keybindsMangoTab._saveChanges()
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
                                            for (var i = 0; i < keybindsMangoTab.keybinds.length; i++) {
                                                var bind = keybindsMangoTab.keybinds[i]
                                                if (keybindsMangoTab._sameKeybindForEdit(bind, modelData)) {
                                                    bindIndex = i
                                                    break
                                                }
                                            }
                                            if (bindIndex >= 0) {
                                                keybindsMangoTab._savedScrollY = flickable.contentY
                                                keybindsMangoTab._preserveScroll = true
                                                keybindsMangoTab.hasUnsavedChanges = true
                                                keybindsMangoTab.keybinds.splice(bindIndex, 1)
                                                keybindsMangoTab._updateFiltered()
                                                Qt.callLater(() => {
                                                    if (keybindsMangoTab._preserveScroll) {
                                                        flickable.contentY = keybindsMangoTab._savedScrollY
                                                        keybindsMangoTab._preserveScroll = false
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
                                onClicked: keybindsMangoTab.toggleExpanded(modelData)

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
                                        keybindsMangoTab.toggleExpanded(modelData)
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
        height: keybindsMangoTab.hasUnsavedChanges ? 60 : 0
        visible: keybindsMangoTab.hasUnsavedChanges || height > 0
        opacity: keybindsMangoTab.hasUnsavedChanges ? 1 : 0
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
                enabled: keybindsMangoTab.hasUnsavedChanges && keybindsMangoTab._isNewBindComplete()
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
                        keybindsMangoTab._saveChanges()
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
                        text: "Mango template binds (adjust modifiers to taste)"
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
                        model: keybindsMangoTab.builtInKeybinds

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
                                    onClicked: keybindsMangoTab.addBuiltInKeybind(modelData)
                                }
                            }

                            MouseArea {
                                id: builtInMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: keybindsMangoTab.addBuiltInKeybind(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

}
