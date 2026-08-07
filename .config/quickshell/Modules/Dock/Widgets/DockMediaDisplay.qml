import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    // ── External props ───────────────────────────────────────────────────────
    property string section:       "center"
    property bool   compactMode:   false
    property var    popupTarget:   null
    property var    parentScreen:  null
    property real   barHeight:     48
    property real   widgetHeight:  30
    property bool   isBarVertical: false

    signal clicked()

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
        root.clicked()
    }

    // ── Internal ─────────────────────────────────────────────────────────────
    readonly property real s:    widgetHeight / 30
    readonly property real hPad: Math.max(Theme.spacingXS, Theme.spacingS * s)
    readonly property real maxTextWidth: 180 * s
    readonly property int  currentContentWidth: mediaRow.implicitWidth + hPad * 2

    // ── Size / visibility ────────────────────────────────────────────────────
    width:  isBarVertical ? widgetHeight : (MprisController.hasPlayer ? currentContentWidth : 0)
    height: isBarVertical ? (MprisController.hasPlayer ? currentContentWidth : 0) : widgetHeight

    opacity: MprisController.hasPlayer ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on width   { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on height  { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.widgetRadius * s
        color: {
            const b = Theme.widgetBaseBackgroundColor
            return Qt.rgba(b.r, b.g, b.b, b.a * Theme.widgetTransparency)
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: Theme.spacingS * s

        // ── Album art + circular visualizer ──────────────────────────────────
        Item {
            id: artItem
            readonly property real artSize: root.widgetHeight * 0.78
            width:  artSize
            height: artSize
            anchors.verticalCenter: parent.verticalCenter
            z: 10

            MouseArea {
                id: artPopupArea
                anchors.fill: parent
                z: 999
                hoverEnabled: true
                enabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openMediaPopupFrom(artItem)
            }

            // Keep cava running when playing
            Loader {
                active: MprisController.isPlaying
                sourceComponent: Component { Ref { service: CavaService } }
            }

            // Fallback random values when cava unavailable
            Timer {
                running: !CavaService.cavaAvailable && MprisController.isPlaying
                interval: 256
                repeat: true
                onTriggered: CavaService.values = [
                    Math.random() * 40 + 10, Math.random() * 60 + 20,
                    Math.random() * 50 + 15, Math.random() * 35 + 20,
                    Math.random() * 45 + 15, Math.random() * 55 + 25
                ]
            }

            // Circular blob visualizer
            Shape {
                id: visualizer
                width:  parent.width  * 1.35
                height: parent.height * 1.35
                anchors.centerIn: parent
                visible: MprisController.isPlaying
                z: 0
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                layer.enabled: true
                layer.smooth:  true
                layer.samples: 4

                readonly property real centerX:    width  / 2
                readonly property real centerY:    height / 2
                readonly property real baseRadius: Math.min(width, height) * 0.42
                readonly property int  segments:   24

                property var audioLevels:   CavaService.values.length > 0 ? CavaService.values : [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                property var smoothedLevels: [0.5, 0.3, 0.7, 0.4, 0.6, 0.5]
                property var cubics: []

                onAudioLevelsChanged: updatePath()

                FrameAnimation {
                    running: visualizer.visible
                    onTriggered: visualizer.updatePath()
                }

                Component { id: cubicSegment; PathCubic {} }

                Component.onCompleted: {
                    shapePath.pathElements.push(
                        Qt.createQmlObject('import QtQuick; import QtQuick.Shapes; PathMove {}', shapePath)
                    )
                    for (let i = 0; i < segments; i++) {
                        const seg = cubicSegment.createObject(shapePath)
                        shapePath.pathElements.push(seg)
                        cubics.push(seg)
                    }
                    updatePath()
                }

                function expSmooth(prev, next, alpha) { return prev + alpha * (next - prev) }

                function updatePath() {
                    if (cubics.length === 0) return
                    for (let i = 0; i < Math.min(smoothedLevels.length, audioLevels.length); i++) {
                        smoothedLevels[i] = expSmooth(smoothedLevels[i], audioLevels[i], 0.4)
                    }
                    const points = []
                    for (let i = 0; i < segments; i++) {
                        const angle = (i / segments) * 2 * Math.PI - Math.PI / 2
                        const audioIndex  = i % Math.min(smoothedLevels.length, 6)
                        const rawLevel    = smoothedLevels[audioIndex] || 0
                        const scaledLevel = Math.sqrt(Math.min(Math.max(rawLevel, 0), 100) / 100) * 100
                        const audioLevel  = Math.max(0.1, scaledLevel / 100) * 0.35
                        const radius = baseRadius * (1.0 + audioLevel)
                        points.push({ x: centerX + Math.cos(angle) * radius, y: centerY + Math.sin(angle) * radius })
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
                        const seg = cubics[i]
                        seg.control1X = p1.x + (p2.x - p0.x) * tension / 3
                        seg.control1Y = p1.y + (p2.y - p0.y) * tension / 3
                        seg.control2X = p2.x - (p3.x - p1.x) * tension / 3
                        seg.control2Y = p2.y - (p3.y - p1.y) * tension / 3
                        seg.x = p2.x
                        seg.y = p2.y
                    }
                }

                ShapePath {
                    id: shapePath
                    fillColor:   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                    strokeColor: "transparent"
                    strokeWidth: 0
                    joinStyle:   ShapePath.RoundJoin
                    fillRule:    ShapePath.WindingFill
                }
            }

            // Album art circle
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                z: 1
                color: Theme.surfaceVariant
                clip: false

                Image {
                    id: coverArt
                    anchors.fill: parent
                    source:   MprisController.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth:   true
                    asynchronous: true
                    visible: false
                }

                Item {
                    id: coverArtMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                }

                MultiEffect {
                    anchors.fill: parent
                    source:              coverArt
                    maskEnabled:         true
                    maskSource:          coverArtMask
                    maskThresholdMin:    0.5
                    maskSpreadAtMin:     1
                }

                EHIcon {
                    anchors.centerIn: parent
                    name:    "music_note"
                    size:    root.widgetHeight * 0.32
                    color:   Theme.surfaceVariantText
                    visible: coverArt.status !== Image.Ready
                    opacity: 0.6
                }
            }
        }

        // ── Track info + controls ─────────────────────────────────────────────
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS * s

            // Title + artist
            Item {
                id: textClip
                readonly property real scrollDistance: Math.max(0, titleText.implicitWidth - width)
                readonly property bool shouldScroll:   SettingsData.mediaScrollEnabled && scrollDistance > 0

                width:  Math.min(titleText.implicitWidth, root.maxTextWidth)
                height: textStack.implicitHeight
                clip:   true
                visible: SettingsData.mediaSize > 0 && MprisController.hasPlayer

                Column {
                    id: textStack
                    spacing: 1

                    StyledText {
                        id: titleText
                        text:            MprisController.displayTitle
                        font.pixelSize:  Theme.fontSizeSmall * s
                        font.weight:     Font.SemiBold
                        color:           Theme.surfaceText
                        wrapMode:        Text.NoWrap
                    }

                    StyledText {
                        text:            MprisController.displayArtist
                        font.pixelSize:  (Theme.fontSizeSmall - 1) * s
                        font.weight:     Font.Normal
                        color:           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        wrapMode:        Text.NoWrap
                        visible:         text.length > 0
                    }
                }

                onShouldScrollChanged: if (!shouldScroll) textStack.x = 0

                SequentialAnimation {
                    running: textClip.shouldScroll
                    loops:   Animation.Infinite
                    PauseAnimation  { duration: 800 }
                    NumberAnimation { target: textStack; property: "x"; from: 0; to: -textClip.scrollDistance; duration: Math.max(1500, textClip.scrollDistance * 18); easing.type: Easing.Linear }
                    PauseAnimation  { duration: 800 }
                    NumberAnimation { target: textStack; property: "x"; from: -textClip.scrollDistance; to: 0; duration: Math.max(1500, textClip.scrollDistance * 18); easing.type: Easing.Linear }
                }
            }

            // Playback buttons
            Row {
                spacing: Theme.spacingXS * s

                // Prev
                Rectangle {
                    width: 20 * s; height: width; radius: width / 2
                    color:   prevArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                    opacity: MprisController.canGoPrevious ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 120 } }

                    EHIcon { anchors.centerIn: parent; name: "skip_previous"; size: 11 * s; color: Theme.surfaceText }
                    MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
                }

                // Play/Pause
                Rectangle {
                    width: 24 * s; height: width; radius: width / 2
                    color: MprisController.isPlaying
                        ? Theme.primary
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

                    EHIcon {
                        anchors.centerIn: parent
                        name:  MprisController.isPlaying ? "pause" : "play_arrow"
                        size:  13 * s
                        color: MprisController.isPlaying ? Theme.onPrimary : Theme.primary
                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
                }

                // Next
                Rectangle {
                    width: 20 * s; height: width; radius: width / 2
                    color:   nextArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                    opacity: MprisController.canGoNext ? 1.0 : 0.3
                    Behavior on color { ColorAnimation { duration: 120 } }

                    EHIcon { anchors.centerIn: parent; name: "skip_next"; size: 11 * s; color: Theme.surfaceText }
                    MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.next() }
                }

                // Shuffle (shown only if player supports it)
                Rectangle {
                    width: 20 * s; height: width; radius: width / 2
                    visible: MprisController.canShuffle
                    color: shuffleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    EHIcon {
                        anchors.centerIn: parent
                        name:    "shuffle"
                        size:    11 * s
                        color:   MprisController.shuffle ? Theme.primary : Theme.surfaceText
                        opacity: MprisController.shuffle ? 1.0 : 0.5
                        Behavior on color   { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea { id: shuffleArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.toggleShuffle() }
                }

                // Loop (shown only if player supports it)
                Rectangle {
                    width: 20 * s; height: width; radius: width / 2
                    visible: MprisController.canLoop
                    color: loopArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    EHIcon {
                        anchors.centerIn: parent
                        name: MprisController.loop === "track" ? "repeat_one" : "repeat"
                        size: 11 * s
                        color:   MprisController.loop !== "none" ? Theme.primary : Theme.surfaceText
                        opacity: MprisController.loop !== "none" ? 1.0 : 0.5
                        Behavior on color   { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea { id: loopArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.cycleLoop() }
                }

            }
        }
    }
}
