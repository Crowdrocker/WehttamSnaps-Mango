import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property real x1: 0.25
    property real y1: 0.1
    property real x2: 0.25
    property real y2: 1.0
    
    property var onCurveChanged: function(x1, y1, x2, y2) {}
    property var onDragEnd: function() {}

    property real dragging: 0
    
    readonly property real handleRadius: 8
    readonly property real gridPadding: 16

    implicitWidth: 300
    implicitHeight: 300

    onX1Changed: canvas.requestPaint()
    onY1Changed: canvas.requestPaint()
    onX2Changed: canvas.requestPaint()
    onY2Changed: canvas.requestPaint()

    function setPoints(nx1, ny1, nx2, ny2) {
        x1 = nx1
        y1 = ny1
        x2 = nx2
        y2 = ny2
    }

    function getPoints() {
        return [x1, y1, x2, y2]
    }

    Canvas {
        id: canvas
        width: 300
        height: 300
        anchors.fill: parent
        
        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            
            const w = width
            const h = height
            const pad = gridPadding + handleRadius
            
            const scaleX = (w - 2 * pad) / 1.0
            const scaleY = (h - 2 * pad) / 1.0
            const scale = Math.min(scaleX, scaleY)
            
            const gridW = 1.0 * scale
            const gridH = 1.0 * scale
            const xOff = (w - gridW) / 2
            const yOff = (h - gridH) / 2
            
            const toCanvasX = function(bx) { return xOff + bx * scale }
            const toCanvasY = function(by) { return yOff + (1.0 - by) * scale }
            
            ctx.clearRect(0, 0, w, h)
            
            const surfaceColor = Theme.surfaceContainer
            const gridColor = Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.08)
            const borderColor = Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.25)
            const lineColor = Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.15)
            const handleLineColor = Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.35)
            const accentColor = Theme.primary
            
            ctx.strokeStyle = gridColor
            ctx.lineWidth = 0.5
            for (let i = 0; i <= 10; i++) {
                const frac = i / 10
                const x = toCanvasX(frac)
                const y = toCanvasY(frac)
                ctx.beginPath()
                ctx.moveTo(x, toCanvasY(0))
                ctx.lineTo(x, toCanvasY(1))
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(toCanvasX(0), y)
                ctx.lineTo(toCanvasX(1), y)
                ctx.stroke()
            }
            
            ctx.strokeStyle = borderColor
            ctx.lineWidth = 1
            ctx.strokeRect(toCanvasX(0), toCanvasY(1), gridW, gridH)
            
            ctx.strokeStyle = lineColor
            ctx.setLineDash([4, 4])
            ctx.beginPath()
            ctx.moveTo(toCanvasX(0), toCanvasY(0))
            ctx.lineTo(toCanvasX(1), toCanvasY(1))
            ctx.stroke()
            ctx.setLineDash([])
            
            const p1x = toCanvasX(x1)
            const p1y = toCanvasY(y1)
            const p2x = toCanvasX(x2)
            const p2y = toCanvasY(y2)
            const p0x = toCanvasX(0)
            const p0y = toCanvasY(0)
            const p3x = toCanvasX(1)
            const p3y = toCanvasY(1)
            
            ctx.strokeStyle = handleLineColor
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(p0x, p0y)
            ctx.lineTo(p1x, p1y)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(p3x, p3y)
            ctx.lineTo(p2x, p2y)
            ctx.stroke()
            
            ctx.strokeStyle = accentColor
            ctx.lineWidth = 2.5
            ctx.beginPath()
            ctx.moveTo(p0x, p0y)
            const steps = 80
            for (let i = 1; i <= steps; i++) {
                const t = i / steps
                const bx = cubicBezierX(t, x1, x2)
                const by = cubicBezierY(t, y1, y2)
                ctx.lineTo(toCanvasX(bx), toCanvasY(by))
            }
            ctx.stroke()
            
            const drawHandle = function(px, py, isActive) {
                const color = isActive ? Theme.secondary : accentColor
                ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 1)
                ctx.beginPath()
                ctx.arc(px, py, handleRadius, 0, Math.PI * 2)
                ctx.fill()
                
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.9)
                ctx.beginPath()
                ctx.arc(px, py, handleRadius - 2, 0, Math.PI * 2)
                ctx.fill()
                
                ctx.fillStyle = color
                ctx.beginPath()
                ctx.arc(px, py, handleRadius - 4, 0, Math.PI * 2)
                ctx.fill()
            }
            
            drawHandle(p1x, p1y, dragging === 1)
            drawHandle(p2x, p2y, dragging === 2)
        }
    }

    function cubicBezierX(t, x1, x2) {
        return 3 * (1-t) * (1-t) * t * x1 + 3 * (1-t) * t * t * x2 + t * t * t
    }

    function cubicBezierY(t, y1, y2) {
        return 3 * (1-t) * (1-t) * t * y1 + 3 * (1-t) * t * t * y2 + t * t * t
    }

    MouseArea {
        anchors.fill: parent
        
        function hitTest(mx, my) {
            const pad = gridPadding + handleRadius
            const w = parent.width
            const h = parent.height
            
            const scaleX = (w - 2 * pad) / 1.0
            const scaleY = (h - 2 * pad) / 1.0
            const scale = Math.min(scaleX, scaleY)
            const gridW = 1.0 * scale
            const gridH = 1.0 * scale
            const xOff = (w - gridW) / 2
            const yOff = (h - gridH) / 2
            
            const toCanvasX = function(bx) { return xOff + bx * scale }
            const toCanvasY = function(by) { return yOff + (1.0 - by) * scale }
            
            const p1x = toCanvasX(x1)
            const p1y = toCanvasY(y1)
            const p2x = toCanvasX(x2)
            const p2y = toCanvasY(y2)
            
            const hitRadius = handleRadius + 4
            
            if ((mx - p1x) * (mx - p1x) + (my - p1y) * (my - p1y) <= hitRadius * hitRadius)
                return 1
            if ((mx - p2x) * (mx - p2x) + (my - p2y) * (my - p2y) <= hitRadius * hitRadius)
                return 2
            return 0
        }
        
        onPressed: dragging = hitTest(mouseX, mouseY)
        onPositionChanged: {
            if (dragging === 0) return
            
            const pad = gridPadding + handleRadius
            const w = parent.width
            const h = parent.height
            
            const scaleX = (w - 2 * pad) / 1.0
            const scaleY = (h - 2 * pad) / 1.0
            const scale = Math.min(scaleX, scaleY)
            const gridW = 1.0 * scale
            const xOff = (w - gridW) / 2
            const yOff = (h - gridW) / 2
            
            const fromCanvasX = function(cx) { return Math.max(0, Math.min(1, (cx - xOff) / scale)) }
            const fromCanvasY = function(cy) { return 1.0 - (cy - yOff) / scale }
            
            const bx = fromCanvasX(mouseX)
            const by = fromCanvasY(mouseY)
            
            if (dragging === 1) {
                x1 = parseFloat(bx.toFixed(3))
                y1 = parseFloat(by.toFixed(3))
            } else {
                x2 = parseFloat(bx.toFixed(3))
                y2 = parseFloat(by.toFixed(3))
            }
            
            canvas.requestPaint()
            onCurveChanged(x1, y1, x2, y2)
        }
        onReleased: {
            if (dragging !== 0) {
                onDragEnd()
                dragging = 0
            }
        }
    }
}