import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property var screen: null

    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: isInstance ? (cfg?.width ?? 400) : 400
    property real widgetHeight: isInstance ? (cfg?.height ?? 200) : 200
    property real defaultWidth: 400
    property real defaultHeight: 200
    property real minWidth: 200
    property real minHeight: 100

    readonly property real visualizerIntensity: isInstance ? (cfg?.visualizerIntensity ?? 1.0) : (SettingsData.desktopCavaVisualizerIntensity ?? 1.0)
    readonly property int barCount: isInstance ? (cfg?.barCount ?? 40) : (SettingsData.desktopCavaBarCount ?? 40)
    readonly property bool showShadow: isInstance ? (cfg?.showShadow ?? true) : (SettingsData.desktopCavaShowShadow ?? true)
    readonly property bool useWallpaperColors: isInstance ? (cfg?.wallpaperColors ?? false) : (SettingsData.desktopCavaWallpaperColors ?? false)
    readonly property int widgetRotation: isInstance ? (cfg?.rotation ?? 0) : (SettingsData.desktopCavaRotation ?? 0)
    readonly property real widgetOpacity: isInstance ? (cfg?.transparency ?? 1.0) : (SettingsData.desktopCavaOpacity ?? 1.0)

    // Default gradient colors (used when wallpaperColors is false)
    readonly property color defaultGradientStart: isInstance ? (cfg?.gradientStart ?? "#4158D0") : (SettingsData.desktopCavaGradientStart ?? "#4158D0")
    readonly property color defaultGradientMid1: isInstance ? (cfg?.gradientMid1 ?? "#C850C0") : (SettingsData.desktopCavaGradientMid1 ?? "#C850C0")
    readonly property color defaultGradientMid2: isInstance ? (cfg?.gradientMid2 ?? "#FFCC70") : (SettingsData.desktopCavaGradientMid2 ?? "#FFCC70")
    readonly property color defaultGradientEnd: isInstance ? (cfg?.gradientEnd ?? "#ffe53b") : (SettingsData.desktopCavaGradientEnd ?? "#ffe53b")

    // Matugen color names for wallpaper-based colors
    readonly property var matugenColorNames: [
        "primary", "secondary", "tertiary", "surface_tint",
        "primary_container", "secondary_container", "tertiary_container",
        "primary_fixed", "secondary_fixed", "tertiary_fixed"
    ]

    // Get color from matugen or fallback to default
    function getGradientColor(index) {
        Theme.colorUpdateTrigger  // Trigger updates when theme changes

        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const colorName = matugenColorNames[index % matugenColorNames.length]
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            if (Theme.matugenColors.colors[colorName] && Theme.matugenColors.colors[colorName][colorMode]) {
                return Theme.matugenColors.colors[colorName][colorMode]
            }
        }

        // Fallback to default colors
        switch(index) {
            case 0: return defaultGradientStart
            case 1: return defaultGradientMid1
            case 2: return defaultGradientMid2
            case 3: return defaultGradientEnd
            default: return defaultGradientStart
        }
    }

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight


    Process {
        id: cavaProc
        running: true

        command: ["sh", "-c", `
            cava -p /dev/stdin <<EOF
[general]
bars = ${barCount}
framerate = 60
autosens = 1

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = 1.5
waves = 0
gravity = 100
noise_reduction = 0.20

[eq]
1 = 1
2 = 1
3 = 1
4 = 1
5 = 1
EOF
        `]

        stdout: SplitParser {
            onRead: data => {
                let newPoints = data.split(";")
                    .map(p => parseFloat(p.trim()) / 1000)
                    .filter(p => !isNaN(p));
                let smoothFactor = 0.3;
                if (canvas.cavaData.length === 0 || canvas.cavaData.length !== newPoints.length) {
                    canvas.cavaData = newPoints;
                } else {
                    let smoothed = [];
                    for (let i = 0; i < newPoints.length; i++) {
                        let oldVal = canvas.cavaData[i];
                        let newVal = newPoints[i];
                        smoothed.push(oldVal + (newVal - oldVal) * smoothFactor);
                    }
                    canvas.cavaData = smoothed;
                }

                canvas.requestPaint();
            }
        }
    }

    // Trigger repaint when colors change
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

        onPaint: {
            var ctx = getContext('2d')
            ctx.clearRect(0, 0, width, height)

            if (showShadow) {
                drawMountainWave(ctx, cavaData, true)
            }
            drawMountainWave(ctx, cavaData, false)
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
                ctx.globalAlpha = 0.3  // 30% opacity
                ctx.save()             // Save current state
                ctx.translate(0, -10)  // Move up slightly
                ctx.scale(1.02, 1.05)  // Stretch slightly
            } else {
                ctx.globalAlpha = 1.0  // Full opacity
            }

            ctx.fillStyle = gradient

            ctx.moveTo(0, height)
            var startY = height - (data[0] * height * visualizerIntensity)
            ctx.lineTo(0, startY)

            var barWidth = width / (data.length - 1)

            for (var i = 0; i < data.length - 1; i++) {
                var xCurr = i * barWidth
                var yCurr = height - (data[i] * height * visualizerIntensity)

                var xNext = (i + 1) * barWidth
                var yNext = height - (data[i + 1] * height * visualizerIntensity)

                var xMid = (xCurr + xNext) / 2
                var yMid = (yCurr + yNext) / 2

                ctx.quadraticCurveTo(xCurr, yCurr, xMid, yMid)
            }

            var lastX = (data.length - 1) * barWidth
            var lastY = height - (data[data.length - 1] * height * visualizerIntensity)

            ctx.lineTo(lastX, lastY)
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fill()

            // Clean up shadow settings
            if (isShadow) {
                ctx.restore()
            }
        }
    }
}
