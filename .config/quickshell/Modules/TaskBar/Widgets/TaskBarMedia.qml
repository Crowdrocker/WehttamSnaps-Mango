import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    property bool compactMode: false
    readonly property int textWidth: {
        return 0;
    }
    readonly property int currentContentWidth: {
        return mediaRow.implicitWidth + horizontalPadding * 2;
    }
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real barHeight: spx(48)
    property real widgetHeight: 30
    property real padding: 0
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property real maxTextWidth: 220 * (widgetHeight / 30)
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    MediaPopup {
        id: mediaPopup
        panelScale: 1.0
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.TakeOverForbidden
        enabled: playerAvailable
        onTapped: {
            const p = root.mapToItem(null, 0, 0)
            mediaPopup.parentScreen = root.parentScreen
            mediaPopup.barPosition = "bottom"
            mediaPopup.barThickness = root.barHeight
            mediaPopup.triggerX = p.x
            mediaPopup.triggerY = p.y
            mediaPopup.triggerWidth = root.isBarVertical ? root.height : root.width
            mediaPopup.open()
            root.clicked()
        }
    }

    width: isBarVertical ? widgetHeight : (playerAvailable ? currentContentWidth : 0)
    height: isBarVertical ? (playerAvailable ? currentContentWidth : 0) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * (widgetHeight / 30)
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    states: [
        State {
            name: "shown"
            when: playerAvailable

            PropertyChanges {
                target: root
                opacity: 1
                width: isBarVertical ? widgetHeight : currentContentWidth
                height: isBarVertical ? currentContentWidth : widgetHeight
            }

        },
        State {
            name: "hidden"
            when: !playerAvailable

            PropertyChanges {
                target: root
                opacity: 0
                width: isBarVertical ? widgetHeight : 0
                height: isBarVertical ? 0 : widgetHeight
            }

        }
    ]
    transitions: [
        Transition {
            from: "shown"
            to: "hidden"

            SequentialAnimation {
                PauseAnimation {
                    duration: 500
                }

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

    Row {
        id: mediaRow

        anchors.centerIn: parent
        spacing: Theme.spacingXS * (widgetHeight / 30)

        TaskBarAudioVisualization {
            anchors.verticalCenter: parent.verticalCenter
        }

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


            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
                visible: root.playerAvailable
                opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: 12 * (widgetHeight / 30)
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

            Rectangle {
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                visible: root.playerAvailable
                opacity: activePlayer ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                    size: 14 * (widgetHeight / 30)
                    color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                    
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.playerAvailable && root.width > 0
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (activePlayer) {
                            activePlayer.togglePlaying();
                        }
                    }
                }

            }

            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
                visible: playerAvailable
                opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: 12 * (widgetHeight / 30)
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


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
