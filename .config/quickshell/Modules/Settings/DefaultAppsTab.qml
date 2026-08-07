import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

Item {
    id: root

    // ── Query queue ──────────────────────────────────────────────────────────
    property var queryQueue: []
    property bool queryInProgress: false
    property var activeQueryCallback: null

    Process {
        id: queryProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.activeQueryCallback) {
                    root.activeQueryCallback((text || "").trim())
                    root.activeQueryCallback = null
                }
                root.queryInProgress = false
                root.processNextQuery()
            }
        }
    }

    function processNextQuery() {
        if (root.queryInProgress || root.queryQueue.length === 0) return
        root.queryInProgress = true
        var item = root.queryQueue.shift()
        root.activeQueryCallback = item.callback
        queryProcess.command = ["xdg-mime", "query", "default", item.mime]
        queryProcess.running = true
    }

    function queryDefault(mime, cb) {
        if (!mime || !cb) return
        root.queryQueue.push({mime: mime, callback: cb})
        root.processNextQuery()
    }

    // ── App helpers ──────────────────────────────────────────────────────────
    function normalizeDesktopId(id) {
        if (!id || typeof id !== 'string') return ""
        var n = id.toLowerCase().trim()
        return n.endsWith('.desktop') ? n.slice(0, -8) : n
    }

    function desktopIdsMatch(id1, id2) {
        return normalizeDesktopId(id1) === normalizeDesktopId(id2)
    }

    function ensureDesktopExtension(id) {
        if (!id) return ""
        var n = id.trim()
        return n.endsWith('.desktop') ? n : n + '.desktop'
    }

    function setDefault(mime, desktopId) {
        if (!mime || !desktopId) return
        var finalId = ensureDesktopExtension(desktopId)
        Quickshell.execDetached(["gio", "mime", mime, finalId])
        Quickshell.execDetached(["xdg-mime", "default", finalId, mime])
    }

    readonly property var allApps: (
        (typeof DesktopEntries !== "undefined" && DesktopEntries.applications)
            ? (function() {
                  var raw = DesktopEntries.applications
                  var list = Array.isArray(raw) ? raw : (raw && raw.values ? raw.values : [])
                  return list.filter(a => !(a && (a.noDisplay || a.runInTerminal)))
              })()
            : []
    )

    function appsByCategory(cat) { return allApps.filter(a => (a.categories || []).includes(cat)) }
    function appsByMime(mime)     { return allApps.filter(a => (a.mimeTypes || []).includes(mime)) }

    function uniqueApps(list) {
        const seen = new Set(), out = []
        for (const a of list) {
            if (!a) continue
            const id = normalizeDesktopId(getAppId(a))
            if (!seen.has(id)) { seen.add(id); out.push(a) }
        }
        return out
    }

    function getAppId(app) {
        if (!app) return ""
        return app.id || app.desktopId || app.filename || app.appId || ((app.name || "Unknown") + ".desktop")
    }

    function getAppsForMimeTypes(mimeTypes) {
        if (!mimeTypes || mimeTypes.length === 0) return []
        var apps = root.allApps || [], out = [], seen = new Set()
        for (var i = 0; i < mimeTypes.length; i++) {
            var mime = mimeTypes[i]
            for (var j = 0; j < apps.length; j++) {
                var app = apps[j]
                if ((app.mimeTypes || []).includes(mime)) {
                    var nid = normalizeDesktopId(getAppId(app))
                    if (!seen.has(nid)) { seen.add(nid); out.push(app) }
                }
            }
        }
        for (var k = 0; k < mimeTypes.length; k++) {
            var mime = mimeTypes[k]
            if (mime.startsWith('x-scheme-handler/')) {
                var handler = mime.split('/')[1]
                var catApps = handler === 'http' || handler === 'https'
                    ? appsByCategory('WebBrowser')
                    : handler === 'mailto' ? appsByCategory('Email') : []
                for (var l = 0; l < catApps.length; l++) {
                    var nid = normalizeDesktopId(getAppId(catApps[l]))
                    if (!seen.has(nid)) { seen.add(nid); out.push(catApps[l]) }
                }
            }
        }
        return out
    }

    function displayName(app) {
        if (!app) return "Unknown"
        return app.name || app.displayName || app.genericName || app.comment || app.title || app.id || app.filename || "Unknown"
    }

    // ── App categories model ─────────────────────────────────────────────────
    readonly property var defaultsModel: [
        { key: "browser",   title: "Web Browser",       icon: "web",
          mimes: ["x-scheme-handler/http", "x-scheme-handler/https"],
          candidates: () => uniqueApps(appsByCategory("WebBrowser")) },
        { key: "mailer",    title: "Mail Client",       icon: "mail",
          mimes: ["x-scheme-handler/mailto"],
          candidates: () => uniqueApps(appsByCategory("Email")) },
        { key: "pdf",       title: "PDF Viewer",        icon: "picture_as_pdf",
          mimes: ["application/pdf"],
          candidates: () => uniqueApps(appsByMime("application/pdf").concat(appsByCategory("Office"))) },
        { key: "images",    title: "Image Viewer",      icon: "photo",
          mimes: ["image/jpeg", "image/png"],
          candidates: () => uniqueApps(appsByCategory("Graphics").concat(appsByCategory("Photography"))) },
        { key: "video",     title: "Video Player",      icon: "movie",
          mimes: ["video/mp4", "video/x-matroska"],
          candidates: () => uniqueApps(appsByCategory("Video").concat(appsByCategory("AudioVideo"))) },
        { key: "text",      title: "Text Editor",       icon: "edit",
          mimes: ["text/plain"],
          candidates: () => uniqueApps(appsByCategory("TextEditor").concat(appsByCategory("Development"))) },
        { key: "files",     title: "File Manager",      icon: "folder",
          mimes: ["inode/directory"],
          candidates: () => uniqueApps(appsByCategory("FileManager").concat(appsByCategory("Utilities"))) },
        { key: "terminal",  title: "Terminal Emulator", icon: "terminal",
          mimes: [], isTerminal: true,  candidates: () => [] },
        { key: "aurhelper", title: "AUR Helper",        icon: "package",
          mimes: [], isAurHelper: true, candidates: () => [] }
    ]

    // ── UI ───────────────────────────────────────────────────────────────────
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

            // ── Header ────────────────────────────────────────────────────
            StyledRect {
                width: parent.width
                height: headerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: headerSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "apps"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            StyledText {
                                text: "Default Applications"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Configure default applications for file types and actions. Changes apply immediately."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }

            // ── App rows — single card ─────────────────────────────────────
            StyledRect {
                width: parent.width
                height: appsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: appsSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: 0

                    Repeater {
                        model: root.defaultsModel

                        delegate: Item {
                            id: appRow
                            width: parent.width
                            height: 72

                            // ── Per-row state & logic ──────────────────────
                            property var candidates: []
                            property string currentDesktopId: ""

                            function initCandidates() {
                                if (modelData.isTerminal) {
                                    candidates = (SettingsData.availableTerminals || []).map(t => ({ name: t, id: t }))
                                } else if (modelData.isAurHelper) {
                                    candidates = (SettingsData.availableAurHelpers || []).map(h => ({ name: h, id: h }))
                                } else {
                                    var detected = root.getAppsForMimeTypes(modelData.mimes || [])
                                    if (detected.length === 0 && modelData.candidates) detected = modelData.candidates() || []
                                    candidates = root.uniqueApps(detected)
                                }
                            }

                            function findAppById(desktopId) {
                                if (!desktopId) return null
                                var check = function(list) {
                                    for (var i = 0; i < list.length; i++) {
                                        var app = list[i]
                                        if (!app) continue
                                        var ids = [app.id, app.desktopId, app.filename, app.appId, root.getAppId(app)]
                                        for (var f = 0; f < ids.length; f++)
                                            if (ids[f] && root.desktopIdsMatch(ids[f], desktopId)) return app
                                    }
                                    return null
                                }
                                var found = check(candidates) || check(root.allApps)
                                if (found) return found
                                if (typeof DesktopEntries !== "undefined") {
                                    var entry = DesktopEntries.heuristicLookup(desktopId)
                                    if (entry) return { id: entry.id || desktopId, name: entry.name, icon: entry.icon, mimeTypes: entry.mimeTypes || [] }
                                }
                                return null
                            }

                            function ensureCurrentInCandidates() {
                                if (modelData.isTerminal || modelData.isAurHelper || !currentDesktopId) return
                                var found = candidates.some(a => root.desktopIdsMatch(root.getAppId(a), currentDesktopId))
                                if (!found) {
                                    var app = findAppById(currentDesktopId)
                                    if (app) candidates = [app].concat(candidates)
                                }
                            }

                            function refreshDefault() {
                                if (modelData.isTerminal) { currentDesktopId = SettingsData.terminalEmulator || ""; return }
                                if (modelData.isAurHelper) { currentDesktopId = SettingsData.aurHelper || ""; return }
                                var mime = (modelData.mimes || [])[0]
                                if (!mime) { currentDesktopId = ""; return }
                                root.queryDefault(mime, function(id) {
                                    currentDesktopId = id || ""
                                    ensureCurrentInCandidates()
                                })
                            }

                            Connections {
                                target: SettingsData
                                function onAvailableTerminalsChanged() {
                                    if (modelData.isTerminal) appRow.initCandidates()
                                }
                                function onAvailableAurHelpersChanged() {
                                    if (modelData.isAurHelper) appRow.initCandidates()
                                }
                            }

                            Component.onCompleted: { initCandidates(); refreshDefault() }

                            property var optionNames: (candidates || []).map(a =>
                                (modelData.isTerminal || modelData.isAurHelper) ? a.name : root.displayName(a))
                            property var optionIcons: (candidates || []).map(a =>
                                modelData.isTerminal ? "terminal" : modelData.isAurHelper ? "" : (a.icon || "application-x-executable"))
                            property var nameToId: {
                                var _ = candidates.length; var m = {}
                                for (var i = 0; i < (candidates || []).length; i++) {
                                    var a = candidates[i]
                                    m[(modelData.isTerminal || modelData.isAurHelper) ? a.name : root.displayName(a)] =
                                        (modelData.isTerminal || modelData.isAurHelper) ? a.id : root.getAppId(a)
                                }
                                return m
                            }

                            property string currentName: {
                                if (modelData.isTerminal) return SettingsData.terminalEmulator || ""
                                if (modelData.isAurHelper) return SettingsData.aurHelper || ""
                                var app = findAppById(currentDesktopId)
                                if (app) return root.displayName(app)
                                if (currentDesktopId && typeof DesktopEntries !== "undefined") {
                                    var e = DesktopEntries.heuristicLookup(currentDesktopId)
                                    if (e && e.name) return e.name
                                }
                                if (currentDesktopId) {
                                    var base = root.normalizeDesktopId(currentDesktopId)
                                    var parts = base.split('.')
                                    var skip = ["org", "com", "io", "net", "dev"]
                                    var meaningful = parts.filter(p => p && !skip.includes(p.toLowerCase()))
                                    if (meaningful.length > 0) {
                                        var n = meaningful[meaningful.length - 1]
                                        return n.charAt(0).toUpperCase() + n.slice(1)
                                    }
                                    return parts[parts.length - 1] || base
                                }
                                return ""
                            }

                            property string currentIcon: {
                                if (modelData.isTerminal) return "terminal"
                                if (modelData.isAurHelper) return ""
                                var app = findAppById(currentDesktopId)
                                if (app && app.icon) return app.icon
                                if (currentDesktopId && typeof DesktopEntries !== "undefined") {
                                    var e = DesktopEntries.heuristicLookup(currentDesktopId)
                                    if (e && e.icon) return e.icon
                                }
                                return "application-x-executable"
                            }

                            // ── Row UI ─────────────────────────────────────
                            // Hover tint
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: rowHover.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.04)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                            // Left: icon + label (fixed width so all rows align)
                            Row {
                                id: labelCol
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                width: 200

                                EHIcon {
                                    name: modelData.icon || "application-x-executable"
                                    size: Theme.iconSize - 2
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.title
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: 200 - Theme.iconSize - Theme.spacingM * 2
                                }
                            }

                            // Dropdown — all start at the same X (right half), right-edge padded
                            EHDropdown {
                                anchors.left: parent.left
                                anchors.leftMargin: parent.width * 0.5
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height
                                text: ""
                                options: appRow.optionNames || []
                                optionIcons: appRow.optionIcons || []
                                currentValue: appRow.currentName || ""
                                onValueChanged: value => {
                                    var id = appRow.nameToId[value] || ""
                                    if (!id) return
                                    if (modelData.isTerminal) {
                                        SettingsData.terminalEmulator = id
                                        appRow.currentDesktopId = id
                                    } else if (modelData.isAurHelper) {
                                        SettingsData.aurHelper = id
                                        appRow.currentDesktopId = id
                                    } else {
                                        for (var i = 0; i < (modelData.mimes || []).length; i++)
                                            root.setDefault(modelData.mimes[i], id)
                                        appRow.currentDesktopId = id
                                        appRow.ensureCurrentInCandidates()
                                        Qt.callLater(() => Qt.callLater(() => Qt.callLater(() => appRow.refreshDefault())))
                                    }
                                }
                            }

                            // Row divider
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.outline
                                opacity: 0.12
                                visible: index < root.defaultsModel.length - 1
                            }
                        }
                    }
                }
            }
        }
    }
}