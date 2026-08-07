import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: activePlayer !== null
    readonly property bool isPlaying: hasMedia && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property real _pad: 12
    readonly property real _artSize: Math.max(36, height - _pad * 2)

    radius: 12
    antialiasing: true
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1

    function titleText() {
        if (!hasMedia || !activePlayer.trackTitle) return "No Media"
        return activePlayer.trackTitle
    }

    function subtitleText() {
        if (!hasMedia) return "Nothing playing"
        if (activePlayer.trackArtist && activePlayer.trackArtist.length > 0) return activePlayer.trackArtist
        return activePlayer.identity || ""
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin:   root._pad
        anchors.rightMargin:  root._pad
        anchors.topMargin:    root._pad - 4
        anchors.bottomMargin: root._pad + 4
        spacing: 10

        // Album art — semi-rounded
        Item {
            width: root._artSize
            height: root._artSize

            EHAlbumArt {
                anchors.fill: parent
                activePlayer: root.activePlayer
                visible: root.hasMedia
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                antialiasing: true
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
                visible: !root.hasMedia || !root.activePlayer?.trackArtUrl
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                EHIcon {
                    anchors.centerIn: parent
                    name: "music_note"
                    size: Math.min(16, parent.width * 0.45)
                    color: Theme.surfaceVariantText
                }
            }
        }

        // Title / artist
        Column {
            id: textColumn
            width: Math.max(0, parent.width - (root._artSize + controlsRow.width + 10 * 2))
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.titleText()
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                text: root.subtitleText()
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Controls
        Row {
            id: controlsRow
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 28; height: 28; radius: 8
                antialiasing: true
                color: prevArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : "transparent"
                opacity: root.hasMedia && root.activePlayer?.canGoPrevious ? 1 : 0.35
                Behavior on color { ColorAnimation { duration: 120 } }

                EHIcon { anchors.centerIn: parent; name: "skip_previous"; size: 15; color: Theme.surfaceText }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    enabled: root.hasMedia && root.activePlayer?.canGoPrevious
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.activePlayer?.previous()
                }
            }

            Rectangle {
                width: 32; height: 32; radius: 9
                antialiasing: true
                color: root.isPlaying
                    ? Theme.primary
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                opacity: root.hasMedia ? 1 : 0.35
                Behavior on color { ColorAnimation { duration: 120 } }

                EHIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: 17
                    color: root.isPlaying ? Theme.primaryContainer : Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasMedia
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.activePlayer?.togglePlaying()
                }
            }

            Rectangle {
                width: 28; height: 28; radius: 8
                antialiasing: true
                color: nextArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : "transparent"
                opacity: root.hasMedia && root.activePlayer?.canGoNext ? 1 : 0.35
                Behavior on color { ColorAnimation { duration: 120 } }

                EHIcon { anchors.centerIn: parent; name: "skip_next"; size: 15; color: Theme.surfaceText }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    enabled: root.hasMedia && root.activePlayer?.canGoNext
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.activePlayer?.next()
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => { wheelEvent.accepted = true }
    }
}
