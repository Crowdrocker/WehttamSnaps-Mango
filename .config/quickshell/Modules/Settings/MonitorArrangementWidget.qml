import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var monitors: []
    property var monitorCapabilities: ({})
    property string selectedMonitor: ""
    property var hardwareCaps: ({})
    property var showDebug: ({ value: false })
    signal monitorSelected(string monitorName)
    // One emission per gesture — avoids overlapping saves when several outputs move together.
    signal positionsBatchChanged(var batch)
    signal autoDetectRequested()

    height: arrangementColumn.implicitHeight + Theme.spacingL * 2
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1
    radius: 4

    function loadHardwareCaps() {
        if (monitors.length === 0) return
        var names = monitors.map(function(m) { return m.name }).filter(function(n) { return n })
        if (names.length === 0) return
        capsProcess.monitorNames = names
        capsProcess.running = true
    }

    Process {
        id: capsProcess
        property var monitorNames: []
        running: false
        command: {
            var home = Quickshell.env("HOME") || Paths.strip(Paths.home)
            var args = [home + "/.config/quickshell/scripts/monitor-caps.py", "caps"].concat(capsProcess.monitorNames)
            return args
        }
        onExited: function(exitCode) {
            if (exitCode === 0 && stdout.text.trim()) {
                try {
                    var result = JSON.parse(stdout.text.trim())
                    if (result && typeof result === "object") {
                        hardwareCaps = result
                    }
                } catch (e) {
                    console.warn("Failed to parse hardware caps:", e)
                }
            }
        }
        stdout: StdioCollector {}
    }

    onMonitorsChanged: {
        Qt.callLater(loadHardwareCaps)
    }

    Component.onCompleted: {
        Qt.callLater(loadHardwareCaps)
    }

    // Layout footprint in the same coordinate system as monitor.position (Hyprland: scaled layout;
    // Mango monitorrule x,y with mode width/height + scale).
    function layoutSizeFromMonitor(monitorObj, capsObj) {
        var c = capsObj || monitorCapabilities[monitorObj.name] || {}
        var sc = parseFloat(monitorObj.scale || "1.0") || 1.0
        if (sc <= 0)
            sc = 1

        var pw = 0
        var ph = 0
        if (monitorObj.resolution && monitorObj.resolution.indexOf("x") > 0) {
            var parts = monitorObj.resolution.split("x")
            pw = parseInt(parts[0], 10) || 0
            ph = parseInt(parts[1], 10) || 0
        }
        var capW = Math.round(c.width || 0)
        var capH = Math.round(c.height || 0)

        // hyprctl / wlr-randr width×height already describe the on-screen layout box — do not /scale again.
        if (pw > 0 && ph > 0 && capW > 0 && capH > 0 && Math.abs(pw - capW) <= 2 && Math.abs(ph - capH) <= 2)
            return {
                w: pw,
                h: ph
            };

        // Config mode line (physical WxH) + scale → layout extent (matches position math in monitor rules).
        if (pw > 0 && ph > 0)
            return {
                w: pw / sc,
                h: ph / sc
            };

        if (capW > 0 && capH > 0)
            return {
                w: capW,
                h: capH
            };

        return {
            w: 1920,
            h: 1080
        };
    }

    // Returns {w, h} in layout coordinates; swaps for 90/270° (+ flipped) transforms.
    function getLogicalSize(monitorObj, capsObj) {
        var sz = layoutSizeFromMonitor(monitorObj, capsObj)
        var t = parseInt(monitorObj.transform) || 0
        var rotated = (t === 1 || t === 3 || t === 5 || t === 7)
        return rotated ? {
            w: sz.h,
            h: sz.w
        } : {
            w: sz.w,
            h: sz.h
        };
    }

    function parsePosition(pos) {
        if (!pos || pos === "") return {x: 0, y: 0}
        var parts = pos.split("x")
        if (parts.length >= 2)
            return {x: parseInt(parts[0]) || 0, y: parseInt(parts[1]) || 0}
        return {x: 0, y: 0}
    }

    function calculateAutoPosition(index) {
        var x = 0
        for (var i = 0; i < index; i++) {
            if (i < monitors.length && !monitors[i].disabled) {
                x += getLogicalSize(monitors[i]).w
            }
        }
        return {x: x, y: 0}
    }

    function getMonitorBounds() {
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        var hasAny = false
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            if (m.disabled) continue
            hasAny = true
            var pos = (m.position && m.position !== "") ? parsePosition(m.position) : calculateAutoPosition(i)
            var sz  = getLogicalSize(m)
            if (pos.x          < minX) minX = pos.x
            if (pos.y          < minY) minY = pos.y
            if (pos.x + sz.w   > maxX) maxX = pos.x + sz.w
            if (pos.y + sz.h   > maxY) maxY = pos.y + sz.h
        }
        if (!hasAny) return {minX: 0, minY: 0, maxX: 1920, maxY: 1080, width: 1920, height: 1080}
        return {minX: minX, minY: minY, maxX: maxX, maxY: maxY, width: maxX - minX, height: maxY - minY}
    }

    function alignMonitorsToTop() {
        var topmostY = null
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i]
            if (m.disabled) continue
            var pos = (m.position && m.position !== "") ? parsePosition(m.position) : calculateAutoPosition(i)
            if (topmostY === null || pos.y < topmostY) topmostY = pos.y
        }
        if (topmostY === null) return
        var batch = []
        for (var j = 0; j < monitors.length; j++) {
            var ma = monitors[j]
            if (ma.disabled) continue
            var cp = (ma.position && ma.position !== "") ? parsePosition(ma.position) : calculateAutoPosition(j)
            if (cp.y !== topmostY)
                batch.push({
                    "name": ma.name,
                    "position": cp.x + "x" + topmostY
                });
        }
        if (batch.length > 0)
            positionsBatchChanged(batch);
    }

    Column {
        id: arrangementColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // ── Header ───────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Math.max(headerText.implicitHeight, headerButtons.height)

            StyledText {
                id: headerText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Monitor Arrangement"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Row {
                id: headerButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                StyledRect {
                    height: 32
                    width: autoDetectBtnText.implicitWidth + Theme.spacingM * 2
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Theme.primary
                    border.width: 1
                    visible: typeof CompositorService !== "undefined" && (CompositorService.isMango || CompositorService.isNiri)
                    StyledText {
                        id: autoDetectBtnText
                        anchors.centerIn: parent
                        text: "Auto Detect"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                    StateLayer {
                        stateColor: Theme.primary
                        onClicked: root.autoDetectRequested()
                    }
                }

                StyledRect {
                    height: 32
                    width: centerBtnText.implicitWidth + Theme.spacingM * 2
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Theme.primary
                    border.width: 1
                    visible: monitors.length > 0
                    StyledText {
                        id: centerBtnText
                        anchors.centerIn: parent
                        text: "Center View"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                    StateLayer {
                        stateColor: Theme.primary
                        onClicked: canvas.doCenter()
                    }
                }

                StyledRect {
                    height: 32
                    width: alignBtnText.implicitWidth + Theme.spacingM * 2
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Theme.primary
                    border.width: 1
                    visible: monitors.length > 0
                    StyledText {
                        id: alignBtnText
                        anchors.centerIn: parent
                        text: "Align Top"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                    StateLayer {
                        stateColor: Theme.primary
                        onClicked: root.alignMonitorsToTop()
                    }
                }
            }
        }

        // ── Canvas ───────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Math.max(200, Math.min(parent.width * 0.38, 420))
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.45)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                border.width: 1
            }

            Item {
                id: canvas
                anchors.fill: parent
                anchors.margins: 1
                clip: true

                property var  bounds:      ({minX:0, minY:0, maxX:1920, maxY:1080, width:1920, height:1080})
                property real fitScale:    0.12
                property real zoomLevel:   1.0
                property real scaleFactor: fitScale * zoomLevel
                property real panX: 0
                property real panY: 0

                function toScreenX(ax) { return panX + (ax - bounds.minX) * scaleFactor }
                function toScreenY(ay) { return panY + (ay - bounds.minY) * scaleFactor }

                function recalc() {
                    var b = root.getMonitorBounds()
                    bounds = b
                    if (b.width > 0 && b.height > 0) {
                        var ws = (width  * 0.90) / b.width
                        var hs = (height * 0.90) / b.height
                        fitScale = Math.min(ws, hs)
                    }
                }

                function doCenter() {
                    recalc()
                    var cx = bounds.minX + bounds.width  / 2
                    var cy = bounds.minY + bounds.height / 2
                    panX = width  / 2 - (cx - bounds.minX) * scaleFactor
                    panY = height / 2 - (cy - bounds.minY) * scaleFactor
                }

                function refresh() { recalc(); doCenter() }

                onWidthChanged:  Qt.callLater(refresh)
                onHeightChanged: Qt.callLater(refresh)
                Component.onCompleted: Qt.callLater(refresh)

                Connections {
                    target: root
                    function onMonitorsChanged()            { canvas.refresh() }
                    function onMonitorCapabilitiesChanged() { canvas.refresh() }
                }

                // ── Pan + zoom ────────────────────────────────────────────
                MouseArea {
                    id: bgPan
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    propagateComposedEvents: true

                    property real lastX: 0
                    property real lastY: 0
                    property bool panning: false

                    onPressed: mouse => {
                        lastX = mouse.x; lastY = mouse.y
                        panning = true
                    }
                    onPositionChanged: mouse => {
                        if (panning && pressedButtons) {
                            canvas.panX += mouse.x - lastX
                            canvas.panY += mouse.y - lastY
                            lastX = mouse.x; lastY = mouse.y
                        }
                    }
                    onReleased: { panning = false }

                    onWheel: wheel => {
                        var factor   = wheel.angleDelta.y > 0 ? 1.12 : (1 / 1.12)
                        var oldScale = canvas.scaleFactor
                        canvas.zoomLevel = Math.max(0.25, Math.min(6.0, canvas.zoomLevel * factor))
                        var ratio = canvas.scaleFactor / oldScale
                        canvas.panX = wheel.x - (wheel.x - canvas.panX) * ratio
                        canvas.panY = wheel.y - (wheel.y - canvas.panY) * ratio
                        wheel.accepted = true
                    }
                }

                // ── Monitor delegates ──────────────────────────────────────
                Repeater {
                    model: root.monitors

                    delegate: Item {
                        id: del
                        property var  monitor:   modelData
                        property var  caps:      root.monitorCapabilities[monitor.name] || {}
                        property var  _lay:    root.getLogicalSize(monitor, caps)
                        property real monitorW: _lay.w
                        property real monitorH: _lay.h
                        property bool isSelected: root.selectedMonitor === monitor.name
                        visible: !monitor.disabled
                        z: isSelected ? 10 : 1

                        // actualPos is a live binding used only when NOT dragging.
                        // frozenPos is snapshotted on press and held for the whole drag
                        // so that changes to monitor.position mid-drag don't snap the card.
                        property var actualPos: (monitor.position && monitor.position !== "")
                            ? root.parsePosition(monitor.position)
                            : root.calculateAutoPosition(index)

                        property real frozenX: 0      // monitor-space X at drag start
                        property real frozenY: 0      // monitor-space Y at drag start
                        property real _pressMouseCX: 0 // canvas-space mouse X at press
                        property real _pressMouseCY: 0 // canvas-space mouse Y at press
                        property real monitorDX: 0    // monitor-space drag delta X
                        property real monitorDY: 0    // monitor-space drag delta Y
                        property bool dragging: false

                        // displayX/Y are the single source of truth for position.
                        // They are set imperatively in all three mouse handlers so
                        // the `dragging` flag never appears in a binding — eliminating
                        // the one-frame ghost caused by QML re-evaluating a ternary
                        // binding at the moment dragging changes.
                        // When not dragging, a Connections block keeps them in sync
                        // with actualPos (covers pan/zoom and external position changes).
                        property real displayX: canvas.toScreenX(actualPos.x)
                        property real displayY: canvas.toScreenY(actualPos.y)

                        x: displayX
                        y: displayY

                        // Keep displayX/Y tracking actualPos and canvas transforms
                        // whenever we are not dragging.
                        Connections {
                            target: canvas
                            enabled: !del.dragging
                            function onPanXChanged()      { del.displayX = canvas.toScreenX(del.actualPos.x) }
                            function onPanYChanged()      { del.displayY = canvas.toScreenY(del.actualPos.y) }
                            function onScaleFactorChanged() {
                                del.displayX = canvas.toScreenX(del.actualPos.x)
                                del.displayY = canvas.toScreenY(del.actualPos.y)
                            }
                        }
                        onActualPosChanged: {
                            if (!dragging) {
                                displayX = canvas.toScreenX(actualPos.x)
                                displayY = canvas.toScreenY(actualPos.y)
                            }
                        }
                        width:  monitorW * canvas.scaleFactor
                        height: monitorH * canvas.scaleFactor

                        // ── Card ───────────────────────────────────────────
                        Rectangle {
                            id: cardRect
                            anchors.fill: parent
                            radius: 6

                            color: del.dragging
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                : isSelected
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.60)
                            border.color: (del.dragging || isSelected)
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.90)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.28)
                            border.width: (del.dragging || isSelected) ? 2 : 1
                            Behavior on color        { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                width: parent.width * 0.85

                                StyledText {
                                    width: parent.width
                                    text: monitor.name
                                    font.pixelSize: Math.max(12, Math.min(del.width / 5.5, del.height / 2.5))
                                    font.weight: Font.Bold
                                    color: isSelected ? Theme.primary : Theme.surfaceText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                StyledText {
                                    width: parent.width
                                    text: {
                                        var make  = caps.make  || ""
                                        var model = caps.model || ""
                                        if (make && model) return make + " " + model
                                        if (make)  return make
                                        if (model) return model
                                        var desc = caps.description || ""
                                        return desc ? desc.split(" ").slice(0, 4).join(" ") : ""
                                    }
                                    font.pixelSize: Math.max(7, Math.min(del.width / 18, 12))
                                    color: isSelected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
                                        : Theme.surfaceVariantText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                StyledText {
                                    width: parent.width
                                    text: (caps.width && caps.height) ? caps.width + "×" + caps.height : ""
                                    font.pixelSize: Math.max(6, Math.min(del.width / 22, 10))
                                    color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.55)
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: text !== ""
                                }

                                // ── Capability badges ─────────────────────────────────
                                Row {
                                    id: capsBadges
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    property var monitorCaps: root.hardwareCaps[monitor.name] || {}

                                    Rectangle {
                                        visible: root.showDebug.value
                                        radius: 3
                                        color: "red"
                                        width: dbgText.width + 8
                                        height: dbgText.height + 4

                                        StyledText {
                                            id: dbgText
                                            anchors.centerIn: parent
                                            text: capsBadges.monitorCaps && Object.keys(capsBadges.monitorCaps).length > 0 ? "OK" : "NO"
                                            font.pixelSize: 8
                                            color: "#fff"
                                        }
                                    }

                                    Rectangle {
                                        radius: 3
                                        color: Qt.rgba(0.9, 0.6, 0.1, 0.85)
                                        width: hdrText.width + 8
                                        height: hdrText.height + 4
                                        visible: caps.hdr === true || (capsBadges.monitorCaps && capsBadges.monitorCaps.hdr === true)

                                        StyledText {
                                            id: hdrText
                                            anchors.centerIn: parent
                                            text: "HDR"
                                            font.pixelSize: Math.max(7, Math.min(del.width / 30, 9))
                                            font.weight: Font.Bold
                                            color: "#fff"
                                        }
                                    }

                                    Rectangle {
                                        radius: 3
                                        color: Qt.rgba(0.2, 0.6, 0.9, 0.85)
                                        width: tenBitText.width + 8
                                        height: tenBitText.height + 4
                                        visible: caps.ten_bit === true || (capsBadges.monitorCaps && capsBadges.monitorCaps.ten_bit === true)

                                        StyledText {
                                            id: tenBitText
                                            anchors.centerIn: parent
                                            text: "10-bit"
                                            font.pixelSize: Math.max(7, Math.min(del.width / 30, 9))
                                            font.weight: Font.Bold
                                            color: "#fff"
                                        }
                                    }

                                    Rectangle {
                                        radius: 3
                                        color: Qt.rgba(0.3, 0.8, 0.4, 0.85)
                                        width: vrrText.width + 8
                                        height: vrrText.height + 4
                                        visible: caps.vrr === true || (capsBadges.monitorCaps && capsBadges.monitorCaps.vrr === true)

                                        StyledText {
                                            id: vrrText
                                            anchors.centerIn: parent
                                            text: "VRR"
                                            font.pixelSize: Math.max(7, Math.min(del.width / 30, 9))
                                            font.weight: Font.Bold
                                            color: "#fff"
                                        }
                                    }
                                }
                            }
                        }

                        // ── Snap / collision thresholds (all in monitor-space pixels) ──────
                        // Collision push-out only fires once overlap exceeds this on both axes.
                        readonly property real _overlapTolerance: 20
                        // Edge-snap and align-snap on release: only snap if within this distance.
                        readonly property real _edgeSnapThresh:  40
                        readonly property real _alignSnapThresh: 40

                        // ── Helpers ────────────────────────────────────────

                        // Axis-aware push-out: mirrors the Python _resolve_collisions logic.
                        // Uses the drag-start position (frozenX/Y) to determine the approach
                        // axis, then center-comparison to decide push direction.
                        // Only fires once overlap exceeds _overlapTolerance on both axes.
                        function resolveCollisions(x, y) {
                            var dw = monitorW, dh = monitorH
                            var sx = del.frozenX, sy = del.frozenY
                            var tol = _overlapTolerance
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled || om.mirrorOf) continue
                                var op  = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var osz = root.getLogicalSize(om)
                                var ox = op.x, oy = op.y, ow = osz.w, oh = osz.h
                                // AABB overlap?
                                if (!(x < ox + ow && x + dw > ox && y < oy + oh && y + dh > oy)) continue
                                // Only push out once overlap is substantial enough to be intentional
                                var overlapX = Math.min(x + dw, ox + ow) - Math.max(x, ox)
                                var overlapY = Math.min(y + dh, oy + oh) - Math.max(y, oy)
                                if (overlapX <= tol && overlapY <= tol) continue
                                // Which axes were separated at drag start?
                                var hSep = (sx + dw <= ox) || (sx >= ox + ow)
                                var vSep = (sy + dh <= oy) || (sy >= oy + oh)
                                var candidates = []
                                if (hSep) {
                                    if (x + dw / 2 < ox + ow / 2)
                                        candidates.push([ox - dw, y, (x + dw) - ox])
                                    else
                                        candidates.push([ox + ow, y, (ox + ow) - x])
                                }
                                if (vSep) {
                                    if (y + dh / 2 < oy + oh / 2)
                                        candidates.push([x, oy - dh, (y + dh) - oy])
                                    else
                                        candidates.push([x, oy + oh, (oy + oh) - y])
                                }
                                if (candidates.length === 0) {
                                    // Started already overlapping — fall back to center comparison
                                    var relX = Math.abs(x + dw / 2 - ox - ow / 2)
                                    var relY = Math.abs(y + dh / 2 - oy - oh / 2)
                                    if (relX * (dh + oh) >= relY * (dw + ow)) {
                                        x = (x + dw / 2 < ox + ow / 2) ? ox - dw : ox + ow
                                    } else {
                                        y = (y + dh / 2 < oy + oh / 2) ? oy - dh : oy + oh
                                    }
                                    continue
                                }
                                // Pick the candidate that requires the smallest push
                                var best = candidates[0]
                                for (var c = 1; c < candidates.length; c++)
                                    if (candidates[c][2] < best[2]) best = candidates[c]
                                x = best[0]; y = best[1]
                            }
                            return [x, y]
                        }

                        // Mirrors Python _clamp_to_neighbors: prevent the dragged monitor
                        // from flying too far from the rest of the layout.
                        function clampToNeighbors(x, y) {
                            var dw = monitorW, dh = monitorH
                            var MAX_FACTOR = 3
                            var active = []
                            for (var i = 0; i < root.monitors.length; i++) {
                                var m = root.monitors[i]
                                if (!m.disabled && !m.mirrorOf)
                                    active.push({i: i, m: m})
                            }
                            if (active.length < 2) return [x, y]
                            var contentW = 0, contentH = 0
                            for (var a = 0; a < active.length; a++) {
                                var sz = root.getLogicalSize(active[a].m)
                                contentW += sz.w; contentH += sz.h
                            }
                            var maxW = contentW * MAX_FACTOR, maxH = contentH * MAX_FACTOR
                            var minOX = Infinity, minOY = Infinity, maxOX = -Infinity, maxOY = -Infinity
                            for (var b = 0; b < active.length; b++) {
                                if (active[b].m.name === monitor.name) continue
                                var op2 = (active[b].m.position && active[b].m.position !== "")
                                    ? root.parsePosition(active[b].m.position)
                                    : root.calculateAutoPosition(active[b].i)
                                var sz2 = root.getLogicalSize(active[b].m)
                                if (op2.x            < minOX) minOX = op2.x
                                if (op2.y            < minOY) minOY = op2.y
                                if (op2.x + sz2.w    > maxOX) maxOX = op2.x + sz2.w
                                if (op2.y + sz2.h    > maxOY) maxOY = op2.y + sz2.h
                            }
                            x = Math.max(x, Math.min(minOX, maxOX - maxW))
                            x = Math.min(x, Math.max(maxOX, minOX + maxW) - dw)
                            y = Math.max(y, Math.min(minOY, maxOY - maxH))
                            y = Math.min(y, Math.max(maxOY, minOY + maxH) - dh)
                            return [x, y]
                        }

                        // Legacy collision check kept for the small nudge grid on drag-update.
                        function checkCollision(ax, ay) {
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled) continue
                                var op = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var osz = root.getLogicalSize(om)
                                var overlapX = Math.min(ax + monitorW, op.x + osz.w) - Math.max(ax, op.x)
                                var overlapY = Math.min(ay + monitorH, op.y + osz.h) - Math.max(ay, op.y)
                                if (overlapX > Math.min(monitorW, osz.w) * 0.05 &&
                                    overlapY > Math.min(monitorH, osz.h) * 0.05) return true
                            }
                            return false
                        }

                        function snapToNearestEdgeX(ax) {
                            var thresh = _edgeSnapThresh
                            var best = ax, bestD = thresh + 1
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled) continue
                                var op = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var ow = root.getLogicalSize(om).w   // rotation-aware
                                var candidates = [op.x - monitorW, op.x + ow]
                                for (var e = 0; e < candidates.length; e++) {
                                    var d = Math.abs(ax - candidates[e])
                                    if (d < bestD) { best = candidates[e]; bestD = d }
                                }
                            }
                            return bestD <= thresh ? Math.round(best) : Math.round(ax)
                        }

                        function snapToNearestEdgeY(ay) {
                            var thresh = _edgeSnapThresh
                            var best = ay, bestD = thresh + 1
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled) continue
                                var op = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var oh = root.getLogicalSize(om).h   // rotation-aware
                                var candidates = [op.y - monitorH, op.y + oh]
                                for (var e = 0; e < candidates.length; e++) {
                                    var d = Math.abs(ay - candidates[e])
                                    if (d < bestD) { best = candidates[e]; bestD = d }
                                }
                            }
                            return bestD <= thresh ? Math.round(best) : Math.round(ay)
                        }

                        // Snap Y to align tops, bottoms, or centers of neighbours when
                        // placing monitors side-by-side horizontally.
                        function snapAlignY(ay) {
                            var thresh = _alignSnapThresh
                            var best = ay, bestD = thresh + 1
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled) continue
                                var op = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var oh = root.getLogicalSize(om).h   // rotation-aware
                                // top-align, bottom-align, center-align
                                var candidates = [op.y, op.y + oh - monitorH, op.y + (oh - monitorH) / 2]
                                for (var e = 0; e < candidates.length; e++) {
                                    var d = Math.abs(ay - candidates[e])
                                    if (d < bestD) { best = candidates[e]; bestD = d }
                                }
                            }
                            return bestD <= thresh ? Math.round(best) : ay
                        }

                        // Snap X to align left, right, or centers of neighbours when
                        // placing monitors side-by-side vertically.
                        function snapAlignX(ax) {
                            var thresh = _alignSnapThresh
                            var best = ax, bestD = thresh + 1
                            for (var i = 0; i < root.monitors.length; i++) {
                                var om = root.monitors[i]
                                if (om.name === monitor.name || om.disabled) continue
                                var op = (om.position && om.position !== "") ? root.parsePosition(om.position) : root.calculateAutoPosition(i)
                                var ow = root.getLogicalSize(om).w   // rotation-aware
                                // left-align, right-align, center-align
                                var candidates = [op.x, op.x + ow - monitorW, op.x + (ow - monitorW) / 2]
                                for (var e = 0; e < candidates.length; e++) {
                                    var d = Math.abs(ax - candidates[e])
                                    if (d < bestD) { best = candidates[e]; bestD = d }
                                }
                            }
                            return bestD <= thresh ? Math.round(best) : ax
                        }

                        // ── Drag mouse area ────────────────────────────────
                        MouseArea {
                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: del.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            onPressed: mouse => {
                                mouse.accepted = true
                                bgPan.panning = false
                                root.selectedMonitor = monitor.name
                                root.monitorSelected(monitor.name)
                                del.frozenX = del.actualPos.x
                                del.frozenY = del.actualPos.y
                                del.monitorDX = 0
                                del.monitorDY = 0
                                // Map press into canvas-space — a fixed origin that doesn't
                                // shift as the card moves.
                                var canvasPt = mapToItem(canvas, mouse.x, mouse.y)
                                del._pressMouseCX = canvasPt.x
                                del._pressMouseCY = canvasPt.y
                                del.dragging = false
                            }

                            onPositionChanged: mouse => {
                                if (pressedButtons & Qt.LeftButton) {
                                    if (!del.dragging) del.dragging = true
                                    var canvasPt = mapToItem(canvas, mouse.x, mouse.y)
                                    // Store delta in monitor-space — dividing canvas-pixel
                                    // delta by scaleFactor. This is the authoritative source
                                    // for the final position on release (no roundtrip needed).
                                    del.monitorDX = (canvasPt.x - del._pressMouseCX) / canvas.scaleFactor
                                    del.monitorDY = (canvasPt.y - del._pressMouseCY) / canvas.scaleFactor
                                    // displayX/Y follow from the same values — no separate
                                    // inversion needed on release.
                                    del.displayX = canvas.toScreenX(del.frozenX + del.monitorDX)
                                    del.displayY = canvas.toScreenY(del.frozenY + del.monitorDY)
                                }
                            }

                            onReleased: {
                                if (!del.dragging) return

                                // Use frozenX/Y + monitorDX/DY directly — no roundtrip
                                // through screen-space, so floating-point drift from
                                // panX/panY/scaleFactor can't produce values like -14.
                                var rawX = del.frozenX + del.monitorDX
                                var rawY = del.frozenY + del.monitorDY

                                // Step 1: resolve any overlaps that accumulated during free drag
                                var resolved = del.resolveCollisions(rawX, rawY)
                                rawX = resolved[0]; rawY = resolved[1]

                                // Step 2: clamp to keep everything reachable
                                var clamped = del.clampToNeighbors(rawX, rawY)
                                rawX = clamped[0]; rawY = clamped[1]

                                // Step 3: edge-snap and alignment on the primary drag axis
                                var movedX = Math.abs(rawX - del.frozenX)
                                var movedY = Math.abs(rawY - del.frozenY)

                                var ax, ay
                                if (root.monitors.length <= 1) {
                                    ax = Math.round(rawX)
                                    ay = Math.round(rawY)
                                } else if (movedX >= movedY) {
                                    // Primarily horizontal — snap X to neighbour edges,
                                    // snap Y to alignment (top/center/bottom). This corrects
                                    // pre-existing sub-pixel Y offsets like -14 on drop.
                                    ax = snapToNearestEdgeX(rawX)
                                    ay = snapAlignY(rawY)
                                    // If alignment snap didn't fire (monitor is far from
                                    // neighbours vertically), just round.
                                    if (ay === rawY) ay = Math.round(rawY)
                                } else {
                                    // Primarily vertical — snap Y to neighbour edges,
                                    // snap X to alignment (left/center/right). This corrects
                                    // pre-existing sub-pixel X offsets like -10 on drop.
                                    ay = snapToNearestEdgeY(rawY)
                                    ax = snapAlignX(rawX)
                                    if (ax === rawX) ax = Math.round(rawX)
                                }

                                // Build the full proposed layout: dragged monitor gets
                                // ax,ay; all others keep their current positions.
                                var proposed = []
                                for (var pi = 0; pi < root.monitors.length; pi++) {
                                    var pm = root.monitors[pi]
                                    if (pm.disabled) continue
                                    if (pm.name === monitor.name) {
                                        proposed.push({ name: pm.name, x: ax, y: ay })
                                    } else {
                                        var pp = (pm.position && pm.position !== "")
                                            ? root.parsePosition(pm.position)
                                            : root.calculateAutoPosition(pi)
                                        proposed.push({ name: pm.name, x: pp.x, y: pp.y })
                                    }
                                }

                                // Normalize so the top-left of the bounding box is 0,0.
                                // This eliminates any accumulated negative offsets like -15.
                                var minPX = Infinity, minPY = Infinity
                                for (var ni = 0; ni < proposed.length; ni++) {
                                    if (proposed[ni].x < minPX) minPX = proposed[ni].x
                                    if (proposed[ni].y < minPY) minPY = proposed[ni].y
                                }

                                // Move displayX/Y to the snapped+normalized position BEFORE
                                // clearing dragging so actualPos never flashes the old value.
                                del.displayX = canvas.toScreenX(ax - minPX)
                                del.displayY = canvas.toScreenY(ay - minPY)
                                del.dragging = false

                                // Apply all new positions in one save (avoids async reload between partial writes).
                                var posBatch = []
                                for (var ei = 0; ei < proposed.length; ei++) {
                                    var nx = proposed[ei].x - minPX
                                    var ny = proposed[ei].y - minPY
                                    var newPos = nx + "x" + ny
                                    var om2 = root.monitors.find(function(m) { return m.name === proposed[ei].name })
                                    if (om2 && newPos !== om2.position)
                                        posBatch.push({
                                            "name": proposed[ei].name,
                                            "position": newPos
                                        });
                                }
                                if (posBatch.length > 0)
                                    root.positionsBatchChanged(posBatch);
                            }
                        }
                    }
                }
            }
        }
    }
}
