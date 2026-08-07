import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    property bool compactMode: false
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    property real maxTextWidth: {
        const baseWidth = 180 * (widgetHeight / 30)
        const titleLength = activePlayer?.trackTitle?.length || 0
        const artistLength = activePlayer?.trackArtist?.length || 0
        const totalLength = titleLength + artistLength
        // Reduce max width for very long titles
        if (totalLength > 60) return baseWidth * 0.6
        if (totalLength > 40) return baseWidth * 0.75
        if (totalLength > 25) return baseWidth * 0.85
        return baseWidth
    }
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property real verticalPadding: horizontalPadding

    signal clicked()

    MediaPopup {
        id: mediaPopup
        panelScale: 1.0
    }

    function openMediaPopupFrom(item) {
        const p = item.mapToItem(null, 0, 0)
        mediaPopup.parentScreen = root.parentScreen
        mediaPopup.barPosition = SettingsData.topBarPosition || "top"
        mediaPopup.barThickness = root.barHeight
        mediaPopup.triggerX = p.x
        mediaPopup.triggerY = p.y
        mediaPopup.triggerWidth = item.width
        mediaPopup.open()
        root.clicked()
    }

    width: isBarVertical ? (widgetHeight + horizontalPadding * 2) : (playerAvailable ? currentContentWidth : 0)
    height: isBarVertical ? (playerAvailable ? currentContentWidth : widgetHeight) : widgetHeight

    readonly property int currentContentWidth: {
        return mediaRow.implicitWidth + horizontalPadding * 2;
    }

    states: [
        State {
            name: "shown"
            when: playerAvailable

            PropertyChanges {
                target: root
                opacity: 1
                width: isBarVertical ? (widgetHeight + horizontalPadding * 2) : currentContentWidth
                height: isBarVertical ? currentContentWidth : widgetHeight
            }
        },
        State {
            name: "hidden"
            when: !playerAvailable

            PropertyChanges {
                target: root
                opacity: 0
                width: isBarVertical ? (widgetHeight + horizontalPadding * 2) : 0
                height: widgetHeight
            }
        }
    ]

    transitions: [
        Transition {
            from: "shown"
            to: "hidden"

            SequentialAnimation {
                PauseAnimation { duration: 500 }
                NumberAnimation {
                    properties: "opacity,width"
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        },
        Transition {
            from: "hidden"
            to: "shown"

            NumberAnimation {
                properties: "opacity,width"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    ]

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius * (widgetHeight / 30)
        color: {
            const baseColor = Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }

        Row {
            id: mediaRow

            anchors.centerIn: parent
            spacing: Theme.spacingXS * (widgetHeight / 30)
            rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? 90 : -90) : 0

            // Album art with circular visualizer
            Item {
                width: root.widgetHeight * 0.75
                height: root.widgetHeight * 0.75
                anchors.verticalCenter: parent.verticalCenter

                // Cava audio visualization reference
                Loader {
                    active: activePlayer?.playbackState === MprisPlaybackState.Playing
                    sourceComponent: Component {
                        Ref {
                            service: CavaService
                        }
                    }
                }

                Timer {
                    running: !CavaService.cavaAvailable && activePlayer?.playbackState === MprisPlaybackState.Playing
                    interval: 256
                    repeat: true
                    onTriggered: {
                        CavaService.values = [Math.random() * 40 + 10, Math.random() * 60 + 20, Math.random() * 50 + 15, Math.random() * 35 + 20, Math.random() * 45 + 15, Math.random() * 55 + 25]
                    }
                }

                // Circular cava visualizer around album art
                Shape {
                    id: circularVisualizer
                    width: parent.width * 1.3
                    height: parent.height * 1.3
                    anchors.centerIn: parent
                    visible: activePlayer?.playbackState === MprisPlaybackState.Playing
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

                // Album art
                Rectangle {
                    id: coverArtContainer
                    anchors.fill: parent
                    radius: width / 2
                    z: 1

                    MouseArea {
                        id: artPopupArea
                        anchors.fill: parent
                        z: 999
                        hoverEnabled: true
                        enabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMediaPopupFrom(coverArtContainer)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.35)
                        opacity: artPopupArea.containsMouse ? 1 : 0
                        z: 1000
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Theme.standardEasing } }

                        EHIcon {
                            anchors.centerIn: parent
                            name: "open_in_new"
                            size: root.widgetHeight * 0.32
                            color: Theme.surfaceText
                        }
                    }

                    Image {
                        id: coverArt
                        anchors.fill: parent
                        source: activePlayer?.metadata["mpris:artUrl"] || ""
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
                            radius: width / 2
                            color: "black"
                        }
                    }

                    EHIcon {
                        anchors.centerIn: parent
                        name: "music_note"
                        size: root.widgetHeight * 0.3
                        color: Theme.surfaceText
                        visible: coverArt.status !== Image.Ready
                    }
                }
            }

            // Track info
            Row {
                spacing: Theme.spacingXS * (widgetHeight / 30)
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    id: textClip
                    readonly property real scrollDistance: Math.max(0, mediaText.implicitWidth - width)
                    readonly property bool shouldScroll: SettingsData.mediaScrollEnabled && scrollDistance > 0

                    width: Math.min(mediaText.implicitWidth, root.maxTextWidth)
                    height: mediaText.implicitHeight
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SettingsData.mediaSize > 0

                    StyledText {
                        id: mediaText

                        property string displayText: {
                            if (!activePlayer || !activePlayer.trackTitle) {
                                return "";
                            }

                            let identity = activePlayer.identity || "";
                            let isWebMedia = identity.toLowerCase().includes("firefox") || identity.toLowerCase().includes("chrome") || identity.toLowerCase().includes("chromium") || identity.toLowerCase().includes("edge") || identity.toLowerCase().includes("safari");
                            let title = "";
                            let subtitle = "";
                            if (isWebMedia && activePlayer.trackTitle) {
                                title = activePlayer.trackTitle;
                                subtitle = activePlayer.trackArtist || identity;
                            } else {
                                title = activePlayer.trackTitle || "Unknown Track";
                                subtitle = activePlayer.trackArtist || "";
                            }
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        text: displayText
                        font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        wrapMode: Text.NoWrap
                    }

                    onShouldScrollChanged: {
                        if (!shouldScroll) {
                            mediaText.x = 0
                        }
                    }

                    SequentialAnimation {
                        running: textClip.shouldScroll
                        loops: Animation.Infinite

                        PauseAnimation { duration: 700 }
                        NumberAnimation {
                            target: mediaText
                            property: "x"
                            from: 0
                            to: -textClip.scrollDistance
                            duration: Math.max(1200, textClip.scrollDistance * 20)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 700 }
                        NumberAnimation {
                            target: mediaText
                            property: "x"
                            from: -textClip.scrollDistance
                            to: 0
                            duration: Math.max(1200, textClip.scrollDistance * 20)
                            easing.type: Easing.Linear
                        }
                    }

                    MouseArea {
                        id: mediaHoverArea
                        anchors.fill: parent
                        enabled: root.playerAvailable && root.opacity > 0 && root.width > 0 && parent.visible
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                // Previous button
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
                    visible: root.playerAvailable
                    opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                    EHIcon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: 10 * (widgetHeight / 30)
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        enabled: root.playerAvailable && root.width > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (activePlayer) {
                                activePlayer.previous();
                            }
                        }
                    }
                }

                // Play/Pause button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                    visible: root.playerAvailable
                    opacity: activePlayer ? 1 : 0.3

                    EHIcon {
                        anchors.centerIn: parent
                        name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                        size: 12 * (widgetHeight / 30)
                        color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.playerAvailable && root.width > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (activePlayer) {
                                activePlayer.playPause();
                            }
                        }
                    }
                }

                // Next button
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
                    visible: root.playerAvailable
                    opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                    EHIcon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: 10 * (widgetHeight / 30)
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        enabled: root.playerAvailable && root.width > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (activePlayer) {
                                activePlayer.next();
                            }
                        }
                    }
                }

            }
        }
    }
}
