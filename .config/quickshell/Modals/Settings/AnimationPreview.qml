import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property real x1: 0.25
    property real y1: 0.1
    property real x2: 0.25
    property real y2: 1.0
    
    implicitHeight: 40

    property real _progress: 0.0
    
    onX1Changed: requestPaint()
    onY1Changed: requestPaint()
    onX2Changed: requestPaint()
    onY2Changed: requestPaint()
    on_ProgressChanged: requestPaint()

    function requestPaint() {
        canvas.requestPaint()
    }

    function start() {
        _progress = 0.0
        anim.restart()
    }
    
    function stop() {
        anim.stop()
    }
    
    function setPoints(nx1, ny1, nx2, ny2) {
        x1 = nx1
        y1 = ny1
        x2 = nx2
        y2 = ny2
        _progress = 0.0
    }

    function ease(t, x1Val, y1Val, x2Val, y2Val) {
        let tt = t
        for (let i = 0; i < 10; i++) {
            const cx = (1-tt)*(1-tt)*(1-tt)*0 + 3*(1-tt)*(1-tt)*tt*x1Val + 3*(1-tt)*tt*tt*x2Val + tt*tt*tt*1
            const error = cx - t
            if (Math.abs(error) < 0.001) break
            
            const dX = 3*(1-tt)*(1-tt)*x1Val + 6*(1-tt)*tt*(x2Val - x1Val) + 3*tt*tt*(1 - x2Val)
            
            if (Math.abs(dX) < 0.001) break
            tt = tt - error / dX
            tt = Math.max(0, Math.min(1, tt))
        }
        
        return (1-tt)*(1-tt)*(1-tt)*0 + 3*(1-tt)*(1-tt)*tt*y1Val + 3*(1-tt)*tt*tt*y2Val + tt*tt*tt*1
    }

    SequentialAnimation {
        id: anim
        running: false
        NumberAnimation {
            target: root
            property: "_progress"
            from: 0
            to: 1
            duration: 2000
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 500 }
        ScriptAction { script: function() { _progress = 0; anim.restart() } }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        
        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            
            const w = width
            const h = height
            const dotR = 6
            const pad = dotR + 2
            
            ctx.clearRect(0, 0, w, h)
            
            const surfaceColor = Theme.surfaceContainer
            const gridColor = Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.15)
            const accentColor = Theme.primary
            
            let minY = 0, maxY = 1
            for (let i = 0; i <= 100; i++) {
                const t = i / 100
                const val = ease(t, x1, y1, x2, y2)
                minY = Math.min(minY, val)
                maxY = Math.max(maxY, val)
            }
            
            const span = maxY - minY
            const usable = w - 2 * pad
            
            const valToX = function(v) {
                return pad + (v - minY) / span * usable
            }
            
            ctx.strokeStyle = gridColor
            ctx.lineWidth = 2
            
            ctx.beginPath()
            ctx.moveTo(valToX(0), h/2)
            ctx.lineTo(valToX(1), h/2)
            ctx.stroke()
            
            const easedVal = ease(_progress, x1, y1, x2, y2)
            const dotX = valToX(easedVal)
            
            ctx.fillStyle = accentColor
            ctx.beginPath()
            ctx.arc(dotX, h/2, dotR, 0, Math.PI * 2)
            ctx.fill()
        }
    }
}