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
    property real barHeight: 48
    property real widgetHeight: 30
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
            mediaPopup.barPosition = SettingsData.topBarPosition || "top"
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
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
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
        spacing: Math.max(2, root.widgetHeight * 0.2)
        rotation: isBarVertical ? (SettingsData.topBarPosition === "left" ? 90 : -90) : 0

        Item {
            width: root.widgetHeight * 0.8
            height: root.widgetHeight * 0.8
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: coverArtContainer

                anchors.fill: parent
                radius: Theme.cornerRadius
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
                        radius: Theme.cornerRadius
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

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(1, root.widgetHeight * 0.05)

            StyledText {
                id: songTitle

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

                // Note: Don't use verticalCenter anchor inside Column - Column handles vertical positioning
                text: displayText
                font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
                color: Theme.surfaceText
                font.weight: Font.Medium
                wrapMode: Text.NoWrap
                visible: SettingsData.mediaSize > 0


                MouseArea {
                    id: mediaHoverArea
                    anchors.fill: parent
                    enabled: root.playerAvailable && root.opacity > 0 && root.width > 0 && parent.visible
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }


            StyledText {
                id: songArtist

                property string displayText: {
                    if (!activePlayer || !activePlayer.metadata["xesam:artist"]) {
                        return "";
                    }

                    let artist = activePlayer.metadata["xesam:artist"];
                    if (typeof artist === "string") {
                        return artist;
                    }

                    return artist.length > 0 ? artist[0] : "Unknown Artist";
                }

                font.pixelSize: root.widgetHeight * 0.35
                color: Theme.surfaceVariantText
                visible: !root.compactMode
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(2, root.widgetHeight * 0.1)
            visible: !root.compactMode

            EHActionButton {
                iconName: "skip_previous"
                iconSize: root.widgetHeight * 0.5
                iconColor: Theme.surfaceText
                onClicked: activePlayer?.previous()
            }

            EHActionButton {
                iconName: activePlayer?.playbackStatus === "Playing" ? "pause" : "play_arrow"
                iconSize: root.widgetHeight * 0.6
                iconColor: Theme.surfaceText
                onClicked: activePlayer?.playPause()
            }

            EHActionButton {
                iconName: "skip_next"
                iconSize: root.widgetHeight * 0.5
                iconColor: Theme.surfaceText
                onClicked: activePlayer?.next()
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
