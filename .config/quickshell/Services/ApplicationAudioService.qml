pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property int totalNodeCount: (Pipewire.nodes?.values || []).length

    signal applicationVolumeChanged
    signal applicationMuteChanged
    signal streamsChanged

    Component.onCompleted: {
        Pipewire.nodes?.valuesChanged.connect(function() { streamsChanged() })
    }

    // ── Node validation ───────────────────────────────────────────────────────

    function isValidNode(node) {
        if (!node || !node.audio) return false
        try { return node.isStream ? true : node.ready !== false } catch (e) { return false }
    }

    function isValidStreamNode(node) {
        if (!node || !node.audio) return false
        try { return node.isStream !== undefined } catch (e) { return false }
    }

    function isNodeReadyForVolumeControl(node) {
        return !!(node && node.audio && node.ready !== false)
    }

    function isNodeBound(node) { return isNodeReadyForVolumeControl(node) }

    // ── Filtered node lists ───────────────────────────────────────────────────

    readonly property var applicationStreams: (Pipewire.nodes?.values || []).filter(function(node) {
        if (!isValidStreamNode(node)) return false
        try { return node.isStream && node.isSink } catch (e) { return false }
    })

    readonly property var applicationInputStreams: (Pipewire.nodes?.values || []).filter(function(node) {
        if (!isValidStreamNode(node)) return false
        try { return node.isStream && !node.isSink } catch (e) { return false }
    })

    readonly property var outputDevices: !Pipewire.ready ? [] : (Pipewire.nodes?.values || []).filter(function(node) {
        if (!node) return false
        try { return !node.isStream && node.isSink } catch (e) { return false }
    })

    readonly property var inputDevices: !Pipewire.ready ? [] : (Pipewire.nodes?.values || []).filter(function(node) {
        if (!node) return false
        try { return !node.isStream && !node.isSink && !!node.audio } catch (e) { return false }
    })

    // ── Application name/icon resolution ─────────────────────────────────────

    readonly property var _genericRuntimeStrings: new Set([
        "chromium", "chromium-browser", "chrome", "google-chrome",
        "electron", "electron32", "electron31", "electron30",
        "node", "python", "python3", "java", "wine", "wineserver"
    ])

    function _isGeneric(s) { return root._genericRuntimeStrings.has(s.toLowerCase()) }

    function _buildCandidates(node) {
        var props      = node.properties || {}
        var binaryName = props["application.process.binary"] || ""
        var appId      = props["application.id"]             || ""
        var appName    = props["application.name"]           || ""
        var bin        = binaryName ? binaryName.split("/").pop().toLowerCase() : ""
        var nodeName   = (node.name || "").split(/[-_.]/)[0].toLowerCase()
        var nodeDesc   = (node.description || "").toLowerCase()

        var c = []
        function add(s) { if (s && !_isGeneric(s) && c.indexOf(s) < 0) c.push(s) }
        add(bin)
        if (appId) { add(appId.toLowerCase()); add(appId.split(".")[0].toLowerCase()) }
        add(appName.toLowerCase())
        add(nodeName)
        add(nodeDesc)
        return c
    }

    function getApplicationName(node) {
        if (!node) return "Unknown Application"
        var c = _buildCandidates(node)
        for (var i = 0; i < c.length; i++) {
            try { var e = DesktopEntries.heuristicLookup(c[i]); if (e && e.name) return e.name } catch (ex) {}
        }
        var props   = node.properties || {}
        var appName = props["application.name"] || ""
        if (node.description && !_isGeneric(node.description)) return node.description
        if (appName && !_isGeneric(appName)) return appName
        if (c[0]) return c[0].charAt(0).toUpperCase() + c[0].slice(1)
        return "Unknown Application"
    }

    function getApplicationIconName(node) {
        if (!node) return ""
        var c = _buildCandidates(node)
        for (var i = 0; i < c.length; i++) {
            try { var e = DesktopEntries.heuristicLookup(c[i]); if (e && e.icon) return e.icon } catch (ex) {}
        }
        var iconName = (node.properties || {})["application.icon-name"] || ""
        return iconName || c[0] || ""
    }

    function getApplicationIcon(node) {
        var iconName = getApplicationIconName(node)
        if (!iconName) return ""
        try { return Quickshell.iconPath(iconName, "application-x-executable") } catch (e) { return "" }
    }

    // ── Volume / mute control ─────────────────────────────────────────────────

    function setApplicationVolume(node, percentage) {
        if (!node || !node.audio) return "No audio stream available"
        if (node.ready === false) return "Node not ready"
        try {
            var clamped = Math.max(0, Math.min(100, percentage))
            node.audio.volume = clamped / 100
            root.applicationVolumeChanged()
            return "Volume set to " + clamped + "%"
        } catch (e) { return "Failed to set volume" }
    }

    function toggleApplicationMute(node) {
        if (!node || !node.audio) return "No audio stream available"
        if (!isNodeBound(node))   return "Node not ready"
        try {
            node.audio.muted = !node.audio.muted
            root.applicationMuteChanged()
            return node.audio.muted ? "Application muted" : "Application unmuted"
        } catch (e) { return "Failed to toggle mute" }
    }

    function setApplicationInputVolume(node, pct) { return setApplicationVolume(node, pct) }
    function toggleApplicationInputMute(node)      { return toggleApplicationMute(node) }

    // ── Stream routing ────────────────────────────────────────────────────────
    //
    // THE FIX: The old code called `pw-link <nodeId> <nodeId>` which is WRONG.
    // pw-link operates on PORT ids/names, not node ids.
    //
    // The correct way to move a stream to a specific device is:
    //   pw-metadata <streamNodeId> target.node <sinkNodeId>
    //
    // WirePlumber watches this metadata key and automatically re-links all the
    // stream's ports to the target device's ports.

    function routeStreamToOutput(streamNode, targetSinkNode) {
        if (!streamNode || !targetSinkNode)                    return "Invalid stream or target device"
        if (!streamNode.isStream || !streamNode.isSink)        return "Not an output stream"
        if (targetSinkNode.isStream || !targetSinkNode.isSink) return "Not a valid output device"
        var sid = streamNode.id
        var tid = targetSinkNode.id
        if (sid === undefined || tid === undefined)            return "Invalid node IDs"
        _routeComponent.createObject(root, { streamId: sid, targetId: tid,
            cb: function() { root.applicationVolumeChanged() } })
        return "Routing stream..."
    }

    function routeStreamToInput(streamNode, targetSourceNode) {
        if (!streamNode || !targetSourceNode)                      return "Invalid stream or target device"
        if (!streamNode.isStream || streamNode.isSink)             return "Not an input stream"
        if (targetSourceNode.isStream || targetSourceNode.isSink)  return "Not a valid input device"
        var sid = streamNode.id
        var tid = targetSourceNode.id
        if (sid === undefined || tid === undefined)                return "Invalid node IDs"
        _routeComponent.createObject(root, { streamId: sid, targetId: tid,
            cb: function() { root.applicationVolumeChanged() } })
        return "Routing input stream..."
    }

    Component {
        id: _routeComponent
        Process {
            property int streamId
            property int targetId
            property var cb
            property int _attempt: 0

            // Attempt 0: pw-metadata target.node  (WirePlumber modern key)
            // Attempt 1: pw-metadata node.target   (WirePlumber legacy key)
            // Attempt 2: give up
            function _cmd() {
                var key = _attempt === 0 ? "target.node" : "node.target"
                return ["pw-metadata", streamId.toString(), key, targetId.toString()]
            }

            command: _cmd()
            Component.onCompleted: running = true

            onExited: function(exitCode) {
                if (exitCode === 0) {
                    if (cb) cb()
                    destroy()
                    return
                }
                _attempt++
                if (_attempt < 2) {
                    command = _cmd()
                    running = true
                } else {
                    if (typeof LoggingService !== 'undefined')
                        LoggingService.warn("ApplicationAudioService",
                            "Failed to route stream after all attempts",
                            { streamId: streamId, targetId: targetId })
                    destroy()
                }
            }
        }
    }

    // ── Current device helpers ────────────────────────────────────────────────

    function getCurrentOutputDevice(streamNode) {
        if (!streamNode || !streamNode.isStream || !streamNode.isSink) return null
        return AudioService.sink
    }

    function getCurrentInputDevice(streamNode) {
        if (!streamNode || !streamNode.isStream || streamNode.isSink) return null
        return AudioService.source
    }


    // ── Per-stream EQ via pipewire-filter-chain ───────────────────────────────
    //
    // Spawns `pipewire-filter-chain` with a bq_peaking IIR filter graph written
    // to /tmp. One process per stream; killed when EQ disabled or bands go flat.
    // Requires: pipewire-filter-chain (ships with pipewire >= 0.3.40)

    property var _eqProcesses: ({})
    readonly property var _eqFreqs: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    function applyEq(streamNode, bands, enabled) {
        if (!streamNode) return
        var sid = streamNode.id
        if (sid === undefined) return
        _killEq(sid)
        if (!enabled) return

        var flat = true
        for (var i = 0; i < bands.length; i++) { if (bands[i] !== 0) { flat = false; break } }
        if (flat) return

        var activeFreqs = [], activeGains = []
        for (var b = 0; b < 10; b++) {
            if (bands[b] === 0) continue
            activeFreqs.push(_eqFreqs[b])
            activeGains.push(bands[b])
        }
        if (activeFreqs.length === 0) return

        var nodeObjs = []
        var linkObjs = []
        for (var n = 0; n < activeFreqs.length; n++) {
            nodeObjs.push("{ type = builtin name = eq" + n + " label = bq_peaking control = { \"Freq\" = " + activeFreqs[n] + " \"Q\" = 1.0 \"Gain\" = " + activeGains[n] + " } }")
            if (n > 0) linkObjs.push("{ output = \"eq" + (n-1) + ":Out\" input = \"eq" + n + ":In\" }")
        }

        var targetName = streamNode.name || ("node-" + sid)
        var filterNodes = nodeObjs.join(",")
        var filterLinks = linkObjs.length > 0 ? ("," + linkObjs.join(",")) : ""
        var cfg = "context.modules = [{ name = libpipewire-module-filter-chain args = {"
            + " node.description = \"qs-eq-" + sid + "\""
            + " filter.graph = { nodes = [" + filterNodes + "]" + filterLinks + " }"
            + " capture.props = { node.name = \"qs-eq-cap-" + sid + "\" media.class = Audio/Sink node.passive = true }"
            + " playback.props = { node.name = \"qs-eq-play-" + sid + "\" node.target = \"" + targetName + "\" node.passive = true }"
            + " } }]"

        _eqWriteComp.createObject(root, { _sid: sid, _path: "/tmp/qs-eq-" + sid + ".json", _cfg: cfg })
    }
    function _killEq(nodeId) {
        var p = _eqProcesses[nodeId]
        if (p) { try { p.running = false } catch(e) {} try { p.destroy() } catch(e) {} delete _eqProcesses[nodeId] }
    }

    Component {
        id: _eqWriteComp
        FileView {
            property int _sid; property string _path; property string _cfg
            path: _path
            Component.onCompleted: {
                setText(_cfg)
                _eqSpawnComp.createObject(root, { _sid: _sid, _path: _path })
                destroy()
            }
        }
    }

    Component {
        id: _eqSpawnComp
        Process {
            property int _sid; property string _path
            command: ["pipewire", "-c", _path]
            Component.onCompleted: { root._eqProcesses[_sid] = this; running = true }
            onExited: function() { if (root._eqProcesses[_sid] === this) delete root._eqProcesses[_sid]; destroy() }
        }
    }

    // ── PwObjectTracker ───────────────────────────────────────────────────────

    function getTrackableNodes() {
        if (!Pipewire.nodes?.values) return []
        return Pipewire.nodes.values.filter(function(node) {
            return node && node.ready && node.audio &&
                   node.properties !== undefined && node.name !== undefined
        })
    }

    PwObjectTracker { objects: root.getTrackableNodes() }
}
