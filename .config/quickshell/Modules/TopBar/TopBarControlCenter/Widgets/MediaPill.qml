import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: MprisController.hasPlayer
    readonly property bool isPlaying: MprisController.isPlaying
    readonly property real _pad: Theme.spacingM
    readonly property real _artSize: Math.max(40, height - _pad * 2)

    radius: Theme.widgetRadius
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    border.width: 1

    function titleText() {
        if (!hasMedia) return "No Media"
        return MprisController.displayTitle || "No Media"
    }

    function subtitleText() {
        if (!hasMedia) return "Nothing playing"
        const artist = MprisController.displayArtist
        if (artist && artist.length > 0) return artist
        return ""
    }

    Row {
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: Theme.spacingM

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
                radius: Theme.widgetRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                visible: !root.hasMedia || !MprisController.artUrl
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                EHIcon {
                    anchors.centerIn: parent
                    name: "music_note"
                    size: Math.min(Theme.iconSize, parent.width * 0.5)
                    color: Theme.surfaceText
                }
            }
        }

        Column {
            id: textColumn
            width: Math.max(0, parent.width - (root._artSize + controlsRow.width + Theme.spacingM * 2))
            spacing: Theme.spacingXS
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
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Row {
            id: controlsRow
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: prevArea.containsMouse ? Theme.primaryHover : "transparent"
                opacity: root.hasMedia && MprisController.canGoPrevious ? 1 : 0.4

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: 14
                    color: Theme.surfaceText
                }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        enabled: root.hasMedia && MprisController.canGoPrevious
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.hasMedia) {
                                MprisController.previous()
                            }
                        }
                    }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: root.isPlaying ? Theme.primary : Theme.primaryHover
                opacity: root.hasMedia ? 1 : 0.4

                EHIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: 16
                    color: root.isPlaying ? Theme.background : Theme.primary
                }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasMedia
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.hasMedia) {
                                MprisController.togglePlaying()
                            }
                        }
                    }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: nextArea.containsMouse ? Theme.primaryHover : "transparent"
                opacity: root.hasMedia && MprisController.canGoNext ? 1 : 0.4

                EHIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: 14
                    color: Theme.surfaceText
                }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        enabled: root.hasMedia && MprisController.canGoNext
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.hasMedia) {
                                MprisController.next()
                            }
                        }
                    }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => {
            wheelEvent.accepted = true
        }
    }
}
