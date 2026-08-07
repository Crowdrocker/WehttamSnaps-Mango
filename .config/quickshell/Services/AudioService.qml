pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common

Singleton {
    id: root

    // ── Devices ───────────────────────────────────────────────────────────────

    readonly property PwNode sink:   validatedSink
    readonly property PwNode source: validatedSource ?? firstAvailableSource
    readonly property bool   hasInput: !!source

    readonly property list<PwNode> sinks:   deviceNodes.sinks
    readonly property list<PwNode> sources: deviceNodes.sources
    readonly property PwNode firstAvailableSource: {
        const list = sources || []
        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (isValidSourceNode(n)) return n
        }
        return null
    }

    // FIX: maxVolume is computed in multiple places — single readonly property
    readonly property real maxVolume: SettingsData.audioVolumeOverdrive ? 1.5 : 1.0
    readonly property real epsilon:   0.005
    readonly property real stepVolume: SettingsData.audioVolumeStep / 100.0
    function nodeStillPresent(node): bool {
        const nodes = Pipewire.nodes?.values ?? []
        if (!node || nodes.length === 0) return !!node
        const nodeId = node.id
        if (nodeId === undefined || nodeId === null) return true
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n) continue
            if (n === node) return true
            if (n.id !== undefined && n.id === nodeId) return true
        }
        return false
    }
    function isValidSourceNode(node): bool {
        return !!(node
            && (node.audio !== undefined)
            && !node.isSink
            && !node.isStream
            && node.ready !== false)
    }

    // ── Output volume ─────────────────────────────────────────────────────────

    readonly property real volume: {
        if (!sink?.audio) return 0
        const vol = sink.audio.volume
        if (vol === undefined || isNaN(vol)) return 0
        return Math.max(0, Math.min(maxVolume, vol))
    }
    readonly property bool muted: sink?.audio?.muted ?? true

    // ── Input volume ──────────────────────────────────────────────────────────

    readonly property real inputVolume: {
        if (!source?.audio) return 0
        const vol = source.audio.volume
        if (vol === undefined || isNaN(vol)) return 0
        return Math.max(0, Math.min(maxVolume, vol))
    }
    readonly property bool inputMuted: source?.audio?.muted ?? true

    // ── OSD suppression ───────────────────────────────────────────────────────

    property double outputOSDSuppressedUntilMs: 0
    property double inputOSDSuppressedUntilMs:  0

    function suppressOutputOSD(durationMs = 400) {
        outputOSDSuppressedUntilMs = Math.max(outputOSDSuppressedUntilMs, Date.now() + durationMs)
    }

    function suppressInputOSD(durationMs = 400) {
        inputOSDSuppressedUntilMs = Math.max(inputOSDSuppressedUntilMs, Date.now() + durationMs)
    }

    function consumeOutputOSDSuppression(): bool { return Date.now() < outputOSDSuppressedUntilMs }
    function consumeInputOSDSuppression():  bool { return Date.now() < inputOSDSuppressedUntilMs  }

    // ── Device node lists ─────────────────────────────────────────────────────

    // FIX: deviceNodes reduce was deeply indented and hard to read — reformatted
    readonly property var deviceNodes: Pipewire.ready
        ? Pipewire.nodes.values.reduce((acc, node) => {
              if (!node.isStream) {
                  if (node.isSink)       acc.sinks.push(node)
                  else if (node.audio)   acc.sources.push(node)
              }
              return acc
          }, { "sinks": [], "sources": [] })
        : { "sinks": [], "sources": [] }

    // Validated sink — reject stale/unbound default sinks
    readonly property PwNode validatedSink: {
        if (!Pipewire.ready) return null
        const raw = Pipewire.defaultAudioSink
        if (!raw || !raw.audio || raw.isStream || raw.ready === false) return null
        if (!nodeStillPresent(raw)) return null
        return raw
    }

    // Validated source — rejects sinks masquerading as sources
    readonly property PwNode validatedSource: {
        if (!Pipewire.ready) return null
        const raw = Pipewire.defaultAudioSource
        // Be permissive for source discovery; write paths are already guarded
        // with source?.audio and source?.ready checks.
        if (!raw || raw.isSink || raw.isStream || raw.ready === false) return null
        return raw
    }

    // ── Feedback-loop guards ──────────────────────────────────────────────────

    property bool isSettingOutputVolume: false
    property bool isSettingInputVolume:  false

    //     // PwObjectTrackers ─────────────────────────────────────────────────
//
//     PwObjectTracker {
//         id: sinkTracker
//         objects: root.sink ? [root.sink] : []
//     }
//
//     PwObjectTracker {
//         id: sourceTracker
//         objects: root.source ? [root.source] : []
//     }
//
//     PwObjectTracker {
//         objects: [...root.sinks, ...root.sources]
//     }

    // ── Volume clamp watchers ─────────────────────────────────────────────────

    Connections {
        target: sink?.audio ?? null

        function onVolumeChanged() {
            if (root.isSettingOutputVolume || !root.sink?.audio) return
            const vol = root.sink.audio.volume
            if (vol === undefined || isNaN(vol) || vol <= root.maxVolume) return
            root.isSettingOutputVolume = true
            Qt.callLater(() => {
                if (root.sink?.audio && root.sink.audio.volume > root.maxVolume)
                    root.sink.audio.volume = root.maxVolume
                root.isSettingOutputVolume = false
            })
        }
    }

    Connections {
        target: source?.audio ?? null

        function onVolumeChanged() {
            if (root.isSettingInputVolume || !root.source?.audio) return
            const vol = root.source.audio.volume
            if (vol === undefined || isNaN(vol) || vol <= root.maxVolume) return
            root.isSettingInputVolume = true
            Qt.callLater(() => {
                if (root.source?.audio && root.source.audio.volume > root.maxVolume)
                    root.source.audio.volume = root.maxVolume
                root.isSettingInputVolume = false
            })
        }
    }

    // ── Output control ────────────────────────────────────────────────────────

    function increaseVolume() {
        if (!Pipewire.ready || !sink?.audio || volume >= maxVolume) return
        setVolume(Math.min(maxVolume, volume + stepVolume))
    }

    function decreaseVolume() {
        if (!Pipewire.ready || !sink?.audio || volume <= 0) return
        setVolume(Math.max(0, volume - stepVolume))
    }

    function setVolume(newVolume: real) {
        if (!Pipewire.ready || !sink?.ready || !sink?.audio) {
            Logger.w("AudioService", "No sink available or not ready")
            return
        }
        // FIX: maxVolume now comes from the shared property instead of recomputing
        const clamped = Math.max(0, Math.min(maxVolume, newVolume))
        if (Math.abs(clamped - sink.audio.volume) < epsilon) return

        isSettingOutputVolume = true
        sink.audio.muted  = false
        sink.audio.volume = clamped
        Qt.callLater(() => { isSettingOutputVolume = false })
    }

    function setOutputMuted(muted: bool) {
        if (!Pipewire.ready || !sink?.audio) {
            Logger.w("AudioService", "No sink available or Pipewire not ready")
            return
        }
        sink.audio.muted = muted
    }

    // FIX: getOutputIcon had inconsistent icon name style (mixed hyphens and underscores)
    //      and redundant clamp since `volume` is already clamped by its binding
    function getOutputIcon() {
        if (muted || volume < epsilon) return "volume_off"
        if (volume <= 0.5)             return "volume_down"
        return "volume_up"
    }

    // ── Input control ─────────────────────────────────────────────────────────

    function increaseInputVolume() {
        if (!Pipewire.ready || !source?.audio || inputVolume >= maxVolume) return
        setInputVolume(Math.min(maxVolume, inputVolume + stepVolume))
    }

    function decreaseInputVolume() {
        if (!Pipewire.ready || !source?.audio) return
        setInputVolume(Math.max(0, inputVolume - stepVolume))
    }

    function setInputVolume(newVolume: real) {
        if (!Pipewire.ready || !source?.ready || !source?.audio) {
            Logger.w("AudioService", "No source available or not ready")
            return
        }
        const clamped = Math.max(0, Math.min(maxVolume, newVolume))
        if (Math.abs(clamped - source.audio.volume) < epsilon) return

        isSettingInputVolume = true
        source.audio.muted  = false
        source.audio.volume = clamped
        Qt.callLater(() => { isSettingInputVolume = false })
    }

    function setInputMuted(muted: bool) {
        if (!Pipewire.ready || !source?.audio) {
            Logger.w("AudioService", "No source available or Pipewire not ready")
            return
        }
        source.audio.muted = muted
    }

    function getInputIcon() {
        return (inputMuted || inputVolume <= Number.EPSILON) ? "mic_off" : "mic"
    }

    // ── Device selection ──────────────────────────────────────────────────────

    function setAudioSink(newSink: PwNode): void {
        if (!Pipewire.ready) { Logger.w("AudioService", "Pipewire not ready"); return }
        Pipewire.preferredDefaultAudioSink = newSink
    }

    function setAudioSource(newSource: PwNode): void {
        if (!Pipewire.ready) { Logger.w("AudioService", "Pipewire not ready"); return }
        Pipewire.preferredDefaultAudioSource = newSource
    }

    // ── Display name helper ───────────────────────────────────────────────────

    function displayName(node) {
        if (!node) return ""
        if (node.properties?.["device.description"])          return node.properties["device.description"]
        if (node.description && node.description !== node.name) return node.description
        if (node.nickname    && node.nickname    !== node.name) return node.nickname
        // FIX: these checks were safe but node.name could be undefined — guard added
        const n = node.name || ""
        if (n.includes("analog-stereo")) return "Built-in Speakers"
        if (n.includes("bluez"))         return "Bluetooth Audio"
        if (n.includes("usb"))           return "USB Audio"
        if (n.includes("hdmi"))          return "HDMI Audio"
        return n
    }
}
