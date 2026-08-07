import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    // Desktop-widget contract (used by `DesktopPluginWrapper`)
    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: defaultWidth
    property real widgetHeight: defaultHeight
    property real defaultWidth: 420
    property real defaultHeight: 300
    property real minWidth: 320
    property real minHeight: 240

    width: widgetWidth
    height: widgetHeight

    // Stable surface: fixed design size, scale/center within the resizable window.
    readonly property int designWidth: 420
    readonly property int designHeight: 300
    readonly property real contentScale: Math.max(0.01, Math.min(widgetWidth / designWidth, widgetHeight / designHeight))

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null

    // Matugen wallpaper colors (same approach as Fastfetch)
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : (SettingsData.desktopWidgetWallpaperColors ?? false)
    readonly property var matugenColorNames: [
        "primary_container",
        "secondary_container",
        "tertiary_container"
    ]
    function getMatugenColor(index) {
        Theme.colorUpdateTrigger
        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const name = matugenColorNames[index % matugenColorNames.length]
            const mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const v = Theme.matugenColors.colors[name]?.[mode]
            if (v) return v
        }
        return null
    }

    Rectangle {
        id: popupContainer
        width: root.designWidth
        height: root.designHeight
        anchors.centerIn: parent
        scale: root.contentScale
        transformOrigin: Item.Center

        radius: 22
        color: {
            const a = (SettingsData.mediaPopupTransparency ?? 0.95)
            const mc = root.getMatugenColor(0)
            if (mc) {
                const c = Qt.color(mc)
                return Qt.rgba(c.r, c.g, c.b, a)
            }
            return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, a)
        }
        border.color: SettingsData.mediaPopupDynamicBorderColors
                     ? Theme.primary
                     : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.mediaPopupBorderOpacity ?? 0.30)
        border.width: SettingsData.mediaPopupBorderEnabled ? Math.max(2, SettingsData.mediaPopupBorderThickness ?? 2) : 0
        antialiasing: true
        clip: true

        // Inner background like the popup
        Rectangle {
            id: contentBg
            anchors.fill: parent
            anchors.margins: 14
            radius: 18
            color: {
                const a = 0.55
                const mc = root.getMatugenColor(1) // secondary_container
                if (mc) {
                    const c = Qt.color(mc)
                    return Qt.rgba(c.r, c.g, c.b, a)
                }
                return Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, a)
            }
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
            border.width: 1
            antialiasing: true
            clip: true

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 92

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            clip: true

                            EHAlbumArt {
                                anchors.fill: parent
                                activePlayer: root.activePlayer
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackTitle || (root.playerAvailable ? "Unknown Track" : "No media playing")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackArtist || ""
                            visible: text.length > 0
                            font.pixelSize: Theme.fontSizeMedium
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.75)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackAlbum || ""
                            visible: text.length > 0
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }
                    }
                }

                EHSeekbar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    activePlayer: root.activePlayer
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    StyledText {
                        text: {
                            if (!root.activePlayer) return "0:00"
                            const rawPos = Math.max(0, root.activePlayer.position || 0)
                            const pos = root.activePlayer.length ? (rawPos % Math.max(1, root.activePlayer.length)) : rawPos
                            const minutes = Math.floor(pos / 60)
                            const seconds = Math.floor(pos % 60)
                            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: {
                            if (!root.activePlayer || !root.activePlayer.length) return "0:00"
                            const dur = Math.max(0, root.activePlayer.length || 0)
                            const minutes = Math.floor(dur / 60)
                            const seconds = Math.floor(dur % 60)
                            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    EHActionButton {
                        iconName: "skip_previous"
                        iconSize: 22
                        buttonSize: 42
                        iconColor: Theme.surfaceText
                        enabled: !!root.activePlayer
                        onClicked: {
                            if (!root.activePlayer) return
                            if ((root.activePlayer.position || 0) > 8 && root.activePlayer.canSeek) {
                                root.activePlayer.position = 0
                            } else {
                                root.activePlayer.previous()
                            }
                        }
                    }

                    Rectangle {
                        width: 52
                        height: 52
                        radius: width / 2
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter

                        EHIcon {
                            anchors.centerIn: parent
                            name: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "pause" : "play_arrow"
                            size: 28
                            color: Theme.background
                            weight: 500
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer && root.activePlayer.togglePlaying()
                        }
                    }

                    EHActionButton {
                        iconName: "skip_next"
                        iconSize: 22
                        buttonSize: 42
                        iconColor: Theme.surfaceText
                        enabled: !!root.activePlayer
                        onClicked: root.activePlayer && root.activePlayer.next()
                    }
                }
            }
        }
    }
}
