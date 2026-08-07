pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property var outputTags: ({})
    property string lastFocusedOutput: ""
    property int refreshToken: 0

    Timer {
        id: pollTimer
        interval: 400
        repeat: true
        running: typeof CompositorService !== "undefined" && CompositorService.isMango
        onTriggered: tagRefreshProcess.running = true
    }

    Connections {
        target: CompositorService

        function onIsMangoChanged() {
            if (CompositorService.isMango)
                tagRefreshProcess.running = true
        }
    }

    Process {
        id: tagRefreshProcess
        command: ["mmsg", "get", "all-tags"]

        stdout: StdioCollector {
            id: tagStdout

            onStreamFinished: {
                root.parseTagOutput(tagStdout.text || "")
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && typeof LoggingService !== "undefined") {
                LoggingService.warn("MangoService", "mmsg get all-tags failed", {
                    "exitCode": exitCode
                })
            }
        }
    }

    function parseTagOutput(text) {
        const byOut = {}
        try {
            const data = JSON.parse(text || "")
            const entries = data.all_tags || []
            for (const entry of entries) {
                const name = entry.monitor || ""
                if (!name) continue
                byOut[name] = { "selected": 0, "occupied": 0, "urgent": 0, "tags": {} }
                const tags = entry.tags || []
                for (const tag of tags) {
                    const idx = tag.index
                    if (idx < 1 || idx > 32) continue
                    byOut[name].tags[idx] = {
                        "state": tag.is_active ? 1 : (tag.is_urgent ? 2 : 0),
                        "clients": tag.client_count || 0,
                        "focused": 0
                    }
                    if (tag.is_active)
                        byOut[name].selected |= 1 << (idx - 1)
                    if ((tag.client_count || 0) > 0)
                        byOut[name].occupied |= 1 << (idx - 1)
                    if (tag.is_urgent)
                        byOut[name].urgent |= 1 << (idx - 1)
                }
            }
        } catch (e) {
            if (typeof LoggingService !== "undefined")
                LoggingService.warn("MangoService", "Failed to parse all-tags JSON", { "error": String(e) })
        }

        root.outputTags = byOut
        root.refreshToken++
        const keys = Object.keys(byOut)
        for (const name of keys) {
            if ((byOut[name].selected || 0) !== 0) {
                root.lastFocusedOutput = name
                return
            }
        }
        if (keys.length > 0)
            root.lastFocusedOutput = keys[0]
    }

    function resolveOutput(screenName) {
        if (screenName && root.outputTags[screenName])
            return screenName
        if (root.lastFocusedOutput && root.outputTags[root.lastFocusedOutput])
            return root.lastFocusedOutput
        const keys = Object.keys(root.outputTags)
        return keys.length > 0 ? keys[0] : ""
    }

    function outputForDisplay(screenName, perMonitor) {
        if (perMonitor && screenName && root.outputTags[screenName])
            return screenName
        if (!perMonitor && root.lastFocusedOutput && root.outputTags[root.lastFocusedOutput])
            return root.lastFocusedOutput
        return root.resolveOutput(screenName)
    }

    function primaryTagFromMask(mask) {
        if (!mask)
            return 1
        for (let i = 1; i <= 32; i++) {
            if (mask & (1 << (i - 1)))
                return i
        }
        return 1
    }

    function activeTagForScreen(screenName, perMonitor) {
        const out = root.outputForDisplay(screenName, perMonitor)
        if (!out)
            return 1
        const st = root.outputTags[out]
        if (!st)
            return 1
        return root.primaryTagFromMask(st.selected || 0)
    }

    function isTagActiveOnOutput(screenName, tagId, perMonitor) {
        const out = root.outputForDisplay(screenName, perMonitor)
        if (!out || !tagId)
            return false
        const st = root.outputTags[out]
        if (!st)
            return false
        const mask = st.selected || 0
        return (mask & (1 << (tagId - 1))) !== 0
    }

    function switchToTag(tagId, screenName, perMonitor) {
        Quickshell.execDetached(["mmsg", "dispatch", "view," + String(tagId)])
    }

    function cycleTag(screenName, perMonitor, direction) {
        const n = Math.max(1, typeof CompositorService !== "undefined" ? CompositorService.mangoTagCount : 9)
        const cur = root.activeTagForScreen(screenName, perMonitor)
        const idx = cur - 1
        const next = direction > 0 ? ((idx + 1) % n + 1) : ((idx - 1 + n) % n + 1)
        root.switchToTag(next, screenName, perMonitor)
    }

    function toplevelScreensNamed(w, outputName) {
        if (!w || !outputName)
            return false
        const scrs = w.screens || []
        for (let i = 0; i < scrs.length; i++) {
            const s = scrs[i]
            if (s && s.name === outputName)
                return true
        }
        return false
    }

    function toplevelMayAppearOnOutputForIcons(w, outputName) {
        if (!w || !outputName)
            return false
        const scrs = w.screens || []
        const keys = Object.keys(root.outputTags)
        const nOut = keys.length

        if (root.toplevelScreensNamed(w, outputName))
            return true

        if (nOut <= 1) {
            if (scrs.length === 0)
                return true
            return false
        }

        if (scrs.length === 0)
            return true

        if (scrs.length === 1)
            return true

        return false
    }

    function workspaceIconsForTag(screenName, tagId, perMonitor) {
        if (typeof CompositorService === "undefined" || !CompositorService.isMango)
            return []
        const out = root.outputForDisplay(screenName, perMonitor)
        if (!out)
            return []
        const st = root.outputTags[out]
        if (!st)
            return []
        const sel = st.selected || 0
        const occ = st.occupied || 0
        const bit = 1 << (tagId - 1)
        if (!((sel & bit) || (occ & bit)))
            return []

        const tmeta = st.tags[tagId] || st.tags[String(tagId)]
        const ipcClients = tmeta && tmeta.clients > 0 ? tmeta.clients : 0
        const tagSelectedHere = (sel & bit) !== 0

        const all = CompositorService.sortedToplevels || []
        let onScreen = all.filter(w => {
            if (!w || w.minimized)
                return false
            if (tagSelectedHere)
                return root.toplevelMayAppearOnOutputForIcons(w, out)
            return root.toplevelScreensNamed(w, out)
        })
        onScreen.sort((a, b) => (b.activated ? 1 : 0) - (a.activated ? 1 : 0))

        let cap = ipcClients
        if (cap <= 0 && (occ & bit))
            cap = Math.min(onScreen.length, 16)
        if (cap > 0)
            onScreen = onScreen.slice(0, Math.min(cap, 32))

        // MangoWM doesn't expose windows on non-visible tags via toplevel protocol.
        // Show count badge whenever we know clients exist (ipcClients) OR the
        // occupied bit is set but we found no windows (background tag).
        if (onScreen.length === 0) {
            const knownCount = ipcClients > 0 ? ipcClients : ((occ & bit) ? 1 : 0)
            if (knownCount > 0) {
                return [{
                    "type": "count",
                    "count": knownCount,
                    "icon": "",
                    "isSteamApp": false,
                    "active": false,
                    "windowId": null,
                    "fallbackText": knownCount + " windows"
                }]
            }
            return []
        }

        const byApp = {}

        onScreen.forEach((w, i) => {
                             const keyBase = (w.appId || w.app_id || w.class || w.windowClass || "unknown").toLowerCase()
                             const titlePart = (w.title || "").slice(0, 48).replace(/\s+/g, " ")
                             const key = `${keyBase}#${i}#${titlePart}`

                             const moddedId = Paths.moddedAppId(keyBase)
                             const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                             const icon = isSteamApp ? "" : Quickshell.iconPath(DesktopEntries.heuristicLookup(moddedId)?.icon, true)
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "isSteamApp": isSteamApp,
                                 "active": !!w.activated,
                                 "count": 1,
                                 "windowId": w,
                                 "fallbackText": w.appId || w.title || ""
                             }
                         })

        return Object.values(byApp)
    }
}
