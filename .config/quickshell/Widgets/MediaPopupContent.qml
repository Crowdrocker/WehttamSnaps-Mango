// Shared body for MediaPopup + desktop Event Horizon Dash
// Layout: album art centered → track → artist → album → seekbar → transport
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Common
import qs.Widgets
import qs.Services

Rectangle {
    id: root

    property MprisPlayer activePlayer: MprisController.activePlayer
    property real ui: 1.0
    property real fillScale: 1.0
    /// Multiplier on transport row hit targets (prev / play / next); embeds can set >1.
    property real transportBoost: 1.24
    property bool showCloseButton: true
    /// Match MacOSClockWidget card: surfaceContainer fill, glass alpha; radius squircle or semi via semiRoundedChrome.
    property bool clockCardChrome: false
    /// With clockCardChrome: use semi-rounded corners (e.g. Event Horizon home) instead of squircle.
    property bool semiRoundedChrome: false
    /// Event Horizon: multiply root Rectangle fill alpha only.
    property real chromeBackgroundOpacityScale: 1.0

    antialiasing: clockCardChrome

    signal closeRequested()

    property int _mprisRev: 0

    function spx(px) {
        // Low floor so narrow embeds (e.g. Event Horizon home column) can scale down; cap high for popouts.
        return Math.round(px * (ui || 1.0) * Math.min(Math.max(fillScale, 0.22), 1.65))
    }

    readonly property bool playerAvailable: {
        if (MprisController.hasPlayer !== undefined)
            return MprisController.hasPlayer
        return activePlayer !== null
    }

    // Strict integer square so EHAlbumArt / circular frame stay optically centered.
    readonly property real _artSideRaw: {
        void _mprisRev
        return Math.max(spx(80), Math.min(spx(220), col.width * 0.52))
    }
    readonly property int artSquare: Math.max(spx(80), Math.round(_artSideRaw))

    readonly property real _contentTopPad: root.spx(8) + (root.clockCardChrome ? 5 : 0)
    readonly property real _contentBottomPad: root.clockCardChrome ? (root.spx(18) + 4) : root.spx(10)

    implicitHeight: col.implicitHeight + _contentTopPad + _contentBottomPad
    // clockCardChrome: same as MacOSClockWidget `card` when no instance transparency (glassAlpha 0.88).
    radius: root.clockCardChrome && width > 0 && height > 0
            ? (root.semiRoundedChrome
               ? Math.min(20, Math.min(width, height) * 0.11)
               : Math.min(width, height) * 0.22)
            : root.spx(18)
    color: root.clockCardChrome
           ? Qt.rgba(
               Theme.surfaceContainer.r,
               Theme.surfaceContainer.g,
               Theme.surfaceContainer.b,
               Math.min(1, 0.88 * root.chromeBackgroundOpacityScale)
           )
           : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Math.min(1, 0.55 * root.chromeBackgroundOpacityScale))
    border.color: root.clockCardChrome
                  ? Qt.rgba(
                      Theme.outline.r,
                      Theme.outline.g,
                      Theme.outline.b,
                      SettingsData.desktopWidgetBorderOpacity !== undefined
                      ? SettingsData.desktopWidgetBorderOpacity
                      : 0.22
                  )
                  : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
    border.width: root.clockCardChrome
                  ? Math.max(1, SettingsData.desktopWidgetBorderThickness !== undefined
                             ? SettingsData.desktopWidgetBorderThickness
                             : 1)
                  : root.spx(1)

    Timer {
        interval: 800
        running: MprisController.activePlayer !== null
                  && MprisController.activePlayer.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root._mprisRev++
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged()     { root._mprisRev++ }
        function onAvailablePlayersChanged() { root._mprisRev++ }
    }

    // Close button floated top-right so it doesn't shift the centred layout.
    EHActionButton {
        visible: root.showCloseButton
        anchors.top:     parent.top
        anchors.right:   parent.right
        anchors.margins: root.spx(8)
        iconName:   "close"
        iconSize:   root.spx(18)
        buttonSize: root.spx(32)
        iconColor:  Theme.surfaceText
        onClicked:  root.closeRequested()
        z: 2
    }

    ColumnLayout {
        id: col
        width: parent.width - root.spx(28)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top:              parent.top
            topMargin:        root._contentTopPad
            bottom:           parent.bottom
            bottomMargin:     root._contentBottomPad
        }
        // Half of previous spacing — tighter block under art, frees vertical room for transport.
        spacing: root.spx(3)

        // ── Album art ─────────────────────────────────────────────────────
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.artSquare
            Layout.preferredHeight: root.artSquare
            clip: true

            EHAlbumArt {
                anchors.fill: parent
                activePlayer: MprisController.activePlayer
            }
        }

        // ── Track name ────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth:    true
            horizontalAlignment: Text.AlignHCenter
            text: {
                void root._mprisRev
                const fromCtl = (typeof MprisController.displayTitle === "string" && MprisController.displayTitle)
                    ? MprisController.displayTitle : ""
                if (fromCtl) return fromCtl
                return root.activePlayer?.trackTitle
                    || (root.playerAvailable ? "Unknown Track" : "No media playing")
            }
            font.pixelSize:   Theme.fontSizeLarge
                              * (root.ui / (Appearance.combinedScale || 1))
                              * Math.min(Math.max(root.fillScale, 0.9), 1.25)
            font.weight:      Font.DemiBold
            color:            Theme.surfaceText
            elide:            Text.ElideRight
            maximumLineCount: 2
            wrapMode:         Text.WordWrap
        }

        // ── Artist ────────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth:    true
            Layout.topMargin:    root.spx(3)
            horizontalAlignment: Text.AlignHCenter
            text: {
                void root._mprisRev
                const fromCtl = (typeof MprisController.displayArtist === "string" && MprisController.displayArtist)
                    ? MprisController.displayArtist : ""
                if (fromCtl) return fromCtl
                return root.activePlayer?.trackArtist || ""
            }
            visible:          text.length > 0
            font.pixelSize:   Theme.fontSizeMedium
                              * (root.ui / (Appearance.combinedScale || 1))
                              * Math.min(Math.max(root.fillScale, 0.9), 1.2)
            color:            Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.75)
            elide:            Text.ElideRight
            maximumLineCount: 1
            wrapMode:         Text.NoWrap
        }

        // ── Album name ────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth:    true
            horizontalAlignment: Text.AlignHCenter
            text: {
                void root._mprisRev
                return root.activePlayer?.trackAlbum || ""
            }
            visible:          text.length > 0
            font.pixelSize:   Theme.fontSizeSmall
                              * (root.ui / (Appearance.combinedScale || 1))
                              * Math.min(Math.max(root.fillScale, 0.9), 1.15)
            color:            Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
            elide:            Text.ElideRight
            maximumLineCount: 1
            wrapMode:         Text.NoWrap
        }

        Item { Layout.preferredHeight: root.spx(1) }

        // ── Seek bar (pulled up — minimal gap after album line) ───────────
        EHSeekbar {
            Layout.fillWidth:       true
            Layout.preferredHeight: root.spx(22)
            activePlayer: MprisController.activePlayer
        }

        Item {
            Layout.preferredHeight: root.clockCardChrome ? (root.spx(6) + 4) : 0
        }

        // ── Timestamps ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.clockCardChrome ? 3 : 0
            spacing: root.spx(5)

            StyledText {
                text: {
                    void root._mprisRev
                    const p = MprisController.activePlayer
                    if (!p) return "0:00"
                    const rawPos = Math.max(0, p.position || 0)
                    const pos    = p.length ? (rawPos % Math.max(1, p.length)) : rawPos
                    const m = Math.floor(pos / 60)
                    const s = Math.floor(pos % 60)
                    return m + ":" + (s < 10 ? "0" : "") + s
                }
                font.pixelSize: Theme.fontSizeSmall * (root.ui / (Appearance.combinedScale || 1))
                color: Theme.surfaceVariantText
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: {
                    void root._mprisRev
                    const p = MprisController.activePlayer
                    if (!p || !p.length) return "0:00"
                    const dur = Math.max(0, p.length || 0)
                    const m   = Math.floor(dur / 60)
                    const s   = Math.floor(dur % 60)
                    return m + ":" + (s < 10 ? "0" : "") + s
                }
                font.pixelSize: Theme.fontSizeSmall * (root.ui / (Appearance.combinedScale || 1))
                color: Theme.surfaceVariantText
            }
        }

        // ── Transport controls ─────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -root.spx(2)
            spacing: root.spx(14 * root.transportBoost)

            EHActionButton {
                iconName:   "skip_previous"
                iconSize:   root.spx(22 * root.transportBoost)
                buttonSize: root.spx(42 * root.transportBoost)
                iconColor:  Theme.surfaceText
                enabled:    !!MprisController.hasPlayer
                onClicked:  MprisController.previousOrRewind()
            }

            Rectangle {
                width:  root.spx(52 * root.transportBoost)
                height: root.spx(52 * root.transportBoost)
                radius: width / 2
                color:  Theme.primary
                Layout.alignment: Qt.AlignVCenter

                EHIcon {
                    anchors.centerIn: parent
                    name: {
                        void root._mprisRev
                        if (MprisController.isPlaying !== undefined)
                            return MprisController.isPlaying ? "pause" : "play_arrow"
                        const p = MprisController.activePlayer
                        return (p && p.playbackState === MprisPlaybackState.Playing) ? "pause" : "play_arrow"
                    }
                    size:   root.spx(28 * root.transportBoost)
                    color:  Theme.background
                    weight: 500
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (MprisController.togglePlaying)
                            MprisController.togglePlaying()
                        else if (MprisController.activePlayer)
                            MprisController.activePlayer.togglePlaying()
                    }
                }
            }

            EHActionButton {
                iconName:   "skip_next"
                iconSize:   root.spx(22 * root.transportBoost)
                buttonSize: root.spx(42 * root.transportBoost)
                iconColor:  Theme.surfaceText
                enabled:    MprisController.canGoNext !== undefined
                            ? MprisController.canGoNext
                            : !!MprisController.activePlayer
                onClicked: {
                    if (MprisController.next)
                        MprisController.next()
                    else if (MprisController.activePlayer)
                        MprisController.activePlayer.next()
                }
            }
        }
    }
}
