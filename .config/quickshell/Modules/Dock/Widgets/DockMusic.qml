import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    // Unified scaling properties from DockWidgets
    property real widgetHeight: 40
    property real scaleFactor: 1.0
    property real iconSize: 20
    property real fontSize: 13
    property real iconSpacing: 6
    property real padding: 8
    
    property bool isBarVertical: false
    property var parentScreen: null
    property real barHeight: 48

    MediaPopup {
        id: mediaPopup
        panelScale: 1.0
    }

    function openMediaPopupFrom(item) {
        const p = item.mapToItem(null, 0, 0)
        mediaPopup.parentScreen = root.parentScreen
        mediaPopup.barPosition = SettingsData.dockPosition || "bottom"
        mediaPopup.barThickness = root.barHeight
        mediaPopup.triggerX = p.x
        mediaPopup.triggerY = p.y
        mediaPopup.triggerWidth = item.width
        mediaPopup.open()
    }

    width: musicRow.implicitWidth + padding * 2
    height: widgetHeight

    Rectangle {
        anchors.fill: parent
        color: {
            const baseColor = Theme.widgetBaseBackgroundColor
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
        }
        radius: Theme.widgetRadius * scaleFactor
        border.width: 0
        border.color: "transparent"

        Row {
            id: musicRow
            anchors.centerIn: parent
            spacing: iconSpacing

            Item {
                width: root.widgetHeight * 0.8
                height: root.widgetHeight * 0.8
                anchors.verticalCenter: parent.verticalCenter

                // Cava audio visualization behind album art
                Loader {
                    active: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
                    sourceComponent: Component {
                        Ref {
                            service: CavaService
                        }
                    }
                }

                Timer {
                    running: !CavaService.cavaAvailable && MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
                    interval: 256
                    repeat: true
                    onTriggered: {
                        CavaService.values = [Math.random() * 40 + 10, Math.random() * 60 + 20, Math.random() * 50 + 15, Math.random() * 35 + 20, Math.random() * 45 + 15, Math.random() * 55 + 25]
                    }
                }

                // Circular cava visualizer around album art
                Shape {
                    id: circularVisualizer
                    width: parent.width * 1.35
                    height: parent.height * 1.35
                    anchors.centerIn: parent
                    visible: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
                    z: 0
                    asynchronous: false
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4

                    readonly property real centerX: width / 2
                    readonly property real centerY: height / 2
                    readonly property real baseRadius: Math.min(width, height) * 0.42
                    readonly property int segments: 24

                    property var audioLevels: {
                        if (!CavaService.cavaAvailable || CavaService.values.length === 0) {
                            return [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                        }
                        return CavaService.values
                    }

                    property var smoothedLevels: [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                    property var cubics: []

                    onAudioLevelsChanged: updatePath()

                    FrameAnimation {
                        running: circularVisualizer.visible
                        onTriggered: circularVisualizer.updatePath()
                    }

                    Component {
                        id: cubicSegment
                        PathCubic {}
                    }

                    Component.onCompleted: {
                        shapePath.pathElements.push(Qt.createQmlObject(
                            'import QtQuick; import QtQuick.Shapes; PathMove {}', shapePath
                        ))

                        for (let i = 0; i < segments; i++) {
                            const seg = cubicSegment.createObject(shapePath)
                            shapePath.pathElements.push(seg)
                            cubics.push(seg)
                        }

                        updatePath()
                    }

                    function expSmooth(prev, next, alpha) {
                        return prev + alpha * (next - prev)
                    }

                    function updatePath() {
                        if (cubics.length === 0) return

                        for (let i = 0; i < Math.min(smoothedLevels.length, audioLevels.length); i++) {
                            smoothedLevels[i] = expSmooth(smoothedLevels[i], audioLevels[i], 0.4)
                        }

                        const points = []
                        for (let i = 0; i < segments; i++) {
                            const angle = (i / segments) * 2 * Math.PI - Math.PI / 2
                            const audioIndex = i % Math.min(smoothedLevels.length, 6)

                            const rawLevel = smoothedLevels[audioIndex] || 0
                            const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100
                            const normalizedLevel = scaledLevel / 100
                            const audioLevel = Math.max(0.1, normalizedLevel) * 0.35

                            const radius = baseRadius * (1.0 + audioLevel)
                            const x = centerX + Math.cos(angle) * radius
                            const y = centerY + Math.sin(angle) * radius
                            points.push({x: x, y: y})
                        }

                        const startMove = shapePath.pathElements[0]
                        startMove.x = points[0].x
                        startMove.y = points[0].y

                        const tension = 0.5
                        for (let i = 0; i < segments; i++) {
                            const p0 = points[(i - 1 + segments) % segments]
                            const p1 = points[i]
                            const p2 = points[(i + 1) % segments]
                            const p3 = points[(i + 2) % segments]

                            const c1x = p1.x + (p2.x - p0.x) * tension / 3
                            const c1y = p1.y + (p2.y - p0.y) * tension / 3
                            const c2x = p2.x - (p3.x - p1.x) * tension / 3
                            const c2y = p2.y - (p3.y - p1.y) * tension / 3

                            const seg = cubics[i]
                            seg.control1X = c1x
                            seg.control1Y = c1y
                            seg.control2X = c2x
                            seg.control2Y = c2y
                            seg.x = p2.x
                            seg.y = p2.y
                        }
                    }

                    ShapePath {
                        id: shapePath
                        fillColor: Theme.primary
                        strokeColor: "transparent"
                        strokeWidth: 0
                        joinStyle: ShapePath.RoundJoin
                        fillRule: ShapePath.WindingFill
                    }
                }

                Rectangle {
                    id: coverArtContainer

                    anchors.fill: parent
                    radius: Theme.widgetRadius * scaleFactor
                    z: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMediaPopupFrom(coverArtContainer)
                    }

                    Image {
                        id: coverArt
                        anchors.fill: parent
                        source: MprisController.activePlayer?.metadata["mpris:artUrl"] || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: coverArt
                        maskEnabled: true
                        maskSource: coverArtMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    Item {
                        id: coverArtMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.widgetRadius * root.scaleFactor
                            color: "black"
                        }
                    }

                    EHIcon {
                        anchors.centerIn: parent
                        name: "music_note"
                        size: root.widgetHeight * 0.4
                        color: Theme.surfaceText
                        visible: coverArt.status !== Image.Ready
                    }
                }
            }

            Item {
                id: textClip
                readonly property real baseMaxTextWidth: 160 * scaleFactor
                readonly property real maxTextWidth: {
                    const player = MprisController.activePlayer
                    const titleLength = player?.trackTitle?.length || 0
                    const artistLength = player?.trackArtist?.length || 0
                    const totalLength = titleLength + artistLength
                    // Reduce max width for very long titles
                    if (totalLength > 60) return baseMaxTextWidth * 0.6
                    if (totalLength > 40) return baseMaxTextWidth * 0.75
                    if (totalLength > 25) return baseMaxTextWidth * 0.85
                    return baseMaxTextWidth
                }
                readonly property real scrollDistance: Math.max(0, titleText.implicitWidth - width)
                readonly property bool shouldScroll: SettingsData.mediaScrollEnabled && scrollDistance > 0

                width: Math.min(titleText.implicitWidth, maxTextWidth)
                height: titleText.implicitHeight
                clip: true
                anchors.verticalCenter: parent.verticalCenter

            StyledText {
                    id: titleText
                text: {
                    const player = MprisController.activePlayer
                    if (!player || !player.trackTitle) {
                        return "No music"
                    }

                    let identity = player.identity || ""
                    let isWebMedia = identity.toLowerCase().includes("firefox") || identity.toLowerCase().includes("chrome") || identity.toLowerCase().includes("chromium") || identity.toLowerCase().includes("edge") || identity.toLowerCase().includes("safari")
                    let title = ""
                    let subtitle = ""
                    if (isWebMedia && player.trackTitle) {
                        title = player.trackTitle
                        subtitle = player.trackArtist || identity
                    } else {
                        title = player.trackTitle || "Unknown Track"
                        subtitle = player.trackArtist || ""
                    }
                    return subtitle.length > 0 ? title + " • " + subtitle : title
                }
                font.pixelSize: fontSize
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                }

                onShouldScrollChanged: {
                    if (!shouldScroll) {
                        titleText.x = 0
                    }
                }

                SequentialAnimation {
                    running: textClip.shouldScroll
                    loops: Animation.Infinite

                    PauseAnimation { duration: 700 }
                    NumberAnimation {
                        target: titleText
                        property: "x"
                        from: 0
                        to: -textClip.scrollDistance
                        duration: Math.max(1200, textClip.scrollDistance * 20)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 700 }
                    NumberAnimation {
                        target: titleText
                        property: "x"
                        from: -textClip.scrollDistance
                        to: 0
                        duration: Math.max(1200, textClip.scrollDistance * 20)
                        easing.type: Easing.Linear
                    }
                }
            }

            // Previous button
            Rectangle {
                width: root.widgetHeight * 0.55
                height: root.widgetHeight * 0.55
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
                visible: MprisController.activePlayer !== null
                opacity: (MprisController.activePlayer?.canGoPrevious) ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: root.iconSize * 0.8
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    enabled: MprisController.activePlayer !== null
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (MprisController.activePlayer) {
                            MprisController.activePlayer.previous();
                        }
                    }
                }
            }

            // Play/Pause button
            Rectangle {
                width: root.widgetHeight * 0.65
                height: root.widgetHeight * 0.65
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? Theme.primary : Theme.primaryHover
                visible: MprisController.activePlayer !== null
                opacity: MprisController.activePlayer ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                    size: root.iconSize
                    color: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing ? Theme.background : Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: MprisController.activePlayer !== null
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (MprisController.activePlayer) {
                            MprisController.activePlayer.togglePlaying();
                        }
                    }
                }
            }

            // Next button
            Rectangle {
                width: root.widgetHeight * 0.55
                height: root.widgetHeight * 0.55
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
                visible: MprisController.activePlayer !== null
                opacity: (MprisController.activePlayer?.canGoNext) ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: root.iconSize * 0.8
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    enabled: MprisController.activePlayer !== null
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (MprisController.activePlayer) {
                            MprisController.activePlayer.next();
                        }
                    }
                }
            }
        }
    }
}







