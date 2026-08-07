import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActiveMedia: activePlayer !== null
    readonly property bool isPlaying: hasActiveMedia && activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    property bool alwaysOn: true

    // Reads from SettingsData so the slider in dock settings persists across
    // sessions. CavaService provides values in 0-100 range.
    // The slider exposes 0-100% which maps to 0.0-1.0 here.
    property real visualizerIntensity: (typeof SettingsData !== "undefined" && SettingsData.dockCavaIntensity !== undefined)
                                        ? SettingsData.dockCavaIntensity
                                        : 1.0

    property int barCount: 40
    property bool showShadow: true
    property bool useWallpaperColors: false
    property real widgetOpacity: 0.8
    property bool fillWidth: false

    // Default gradient colors
    property color gradientStart: "#4158D0"
    property color gradientMid1: "#C850C0"
    property color gradientMid2: "#FFCC70"
    property color gradientEnd: "#ffe53b"

    readonly property var matugenColorNames: [
        "primary", "secondary", "tertiary", "surface_tint",
        "primary_container", "secondary_container", "tertiary_container",
        "primary_fixed", "secondary_fixed", "tertiary_fixed"
    ]

    // In background mode report implicitWidth 0 so the Row in DockWidgets
    // does not allocate a fixed slot — actual width comes from parent binding.
    implicitWidth: fillWidth ? 0 : 200
    width: fillWidth ? (parent ? parent.width : 200) : 200

    // Re-render when the live setting changes (slider drag)
    Connections {
        target: (typeof SettingsData !== "undefined") ? SettingsData : null
        function onDockCavaIntensityChanged() {
            canvas.requestPaint()
        }
    }

    function getGradientColor(index) {
        Theme.colorUpdateTrigger

        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const colorName = matugenColorNames[index % matugenColorNames.length]
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            if (Theme.matugenColors.colors[colorName] && Theme.matugenColors.colors[colorName][colorMode]) {
                return Theme.matugenColors.colors[colorName][colorMode]
            }
        }

        switch(index) {
            case 0: return gradientStart
            case 1: return gradientMid1
            case 2: return gradientMid2
            case 3: return gradientEnd
            default: return gradientStart
        }
    }

    // Keep CavaService refCount incremented while active
    Loader {
        active: isPlaying || alwaysOn
        sourceComponent: Component {
            Ref {
                service: CavaService
            }
        }
    }

    // Fallback animation — runs whenever nothing is feeding real data
    Timer {
        id: fallbackTimer
        running: (!CavaService.cavaAvailable || !isPlaying) && alwaysOn
        interval: 80  // ~12fps
        repeat: true
        onTriggered: {
            let fallbackValues = []
            for (let i = 0; i < barCount; i++) {
                fallbackValues.push(
                    Math.random() * 40 + 10 + Math.sin(Date.now() / 200 + i) * 20
                )
            }
            canvas.cavaData = fallbackValues
            canvas.requestPaint()
        }
    }

    // Feed real cava data when music is playing
    Connections {
        target: CavaService
        function onValuesChanged() {
            if (CavaService.cavaAvailable && isPlaying) {
                let sourceValues = CavaService.values
                if (sourceValues && sourceValues.length > 0) {
                    let resampled = []
                    let step = sourceValues.length / barCount
                    for (let i = 0; i < barCount; i++) {
                        let idx = Math.floor(i * step)
                        resampled.push(sourceValues[idx] || 0)
                    }
                    canvas.cavaData = resampled
                    canvas.requestPaint()
                }
            }
        }
    }

    // Clear stale data when playback stops so idle wave resumes
    Connections {
        target: root
        function onIsPlayingChanged() {
            if (!isPlaying) {
                canvas.cavaData = []
                canvas.requestPaint()
            }
        }
    }

    Connections {
        target: Theme
        function onColorUpdateTriggerChanged() {
            canvas.requestPaint()
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        opacity: widgetOpacity

        property var cavaData: []

        // Repaint when dock resizes so bars always span full width
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext('2d')
            ctx.clearRect(0, 0, width, height)

            if (canvas.cavaData.length > 0) {
                if (showShadow) {
                    drawMountainWave(ctx, canvas.cavaData, true)
                }
                drawMountainWave(ctx, canvas.cavaData, false)
            } else {
                drawIdleWave(ctx)
            }
        }

        function drawIdleWave(ctx) {
            var gradient = ctx.createLinearGradient(0, 0, width, 0)
            gradient.addColorStop(0.0, getGradientColor(0))
            gradient.addColorStop(0.3, getGradientColor(1))
            gradient.addColorStop(0.6, getGradientColor(2))
            gradient.addColorStop(1.0, getGradientColor(3))

            ctx.beginPath()
            ctx.globalAlpha = 0.3
            ctx.fillStyle = gradient

            ctx.moveTo(0, height)
            ctx.lineTo(0, height * 0.7)

            var waveHeight = height * 0.1
            for (var x = 0; x <= width; x += 5) {
                var y = height * 0.7 + Math.sin(x / 30) * waveHeight
                ctx.lineTo(x, y)
            }

            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fill()
            ctx.globalAlpha = 1.0
        }

        function drawMountainWave(ctx, data, isShadow) {
            if (data.length < 2) return

            var gradient = ctx.createLinearGradient(0, 0, width, 0)
            gradient.addColorStop(0.0, getGradientColor(0))
            gradient.addColorStop(0.3, getGradientColor(1))
            gradient.addColorStop(0.6, getGradientColor(2))
            gradient.addColorStop(1.0, getGradientColor(3))

            ctx.beginPath()

            if (isShadow) {
                ctx.globalAlpha = 0.25
                ctx.save()
                ctx.translate(0, -8)
                ctx.scale(1.02, 1.05)
            } else {
                ctx.globalAlpha = 1.0
            }

            ctx.fillStyle = gradient

            ctx.moveTo(0, height)
            var startY = height - (data[0] * height * visualizerIntensity / 100)
            ctx.lineTo(0, startY)

            var barWidth = width / (data.length - 1)

            for (var i = 0; i < data.length - 1; i++) {
                var xCurr = i * barWidth
                var yCurr = height - (data[i] * height * visualizerIntensity / 100)

                var xNext = (i + 1) * barWidth
                var yNext = height - (data[i + 1] * height * visualizerIntensity / 100)

                var xMid = (xCurr + xNext) / 2
                var yMid = (yCurr + yNext) / 2

                ctx.quadraticCurveTo(xCurr, yCurr, xMid, yMid)
            }

            var lastX = (data.length - 1) * barWidth
            var lastY = height - (data[data.length - 1] * height * visualizerIntensity / 100)

            ctx.lineTo(lastX, lastY)
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fill()

            if (isShadow) {
                ctx.restore()
            }
        }
    }
}
