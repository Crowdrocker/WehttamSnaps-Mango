import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    // ── External props ───────────────────────────────────────────────────────
    property string section:      "center"
    property real   padding:      1        // set externally by DockWidgets
    property real   iconSize:     64       // set externally by DockWidgets
    property real   iconSpacing:  4        // set externally by DockWidgets
    property real   scaleFactor:  1        // set externally by DockWidgets
    property bool   compactMode:  false
    property var    popupTarget:  null
    property var    parentScreen: null
    property real   barHeight:    48
    property real   widgetHeight: 30
    property bool   isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"

    signal clicked()

    MediaPopup {
        id: mediaPopup
        panelScale: 1.0
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.TakeOverForbidden
        enabled: MprisController.hasPlayer
        onTapped: {
            const p = root.mapToItem(null, 0, 0)
            mediaPopup.parentScreen = root.parentScreen
            mediaPopup.barPosition = SettingsData.dockPosition || "bottom"
            mediaPopup.barThickness = root.barHeight
            mediaPopup.triggerX = p.x
            mediaPopup.triggerY = p.y
            mediaPopup.triggerWidth = root.isBarVertical ? root.height : root.width
            mediaPopup.open()
            root.clicked()
        }
    }

    // ── Internal ─────────────────────────────────────────────────────────────
    readonly property real   s:                widgetHeight / 30
    readonly property real   hPad:             SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * s)
    readonly property real   maxTextWidth:      180 * s
    readonly property int    currentContentWidth: mediaRow.implicitWidth + hPad * 2

    // ── Size / visibility ────────────────────────────────────────────────────
    width:  isBarVertical ? widgetHeight : (MprisController.hasPlayer ? currentContentWidth : 0)
    height: isBarVertical ? (MprisController.hasPlayer ? currentContentWidth : 0) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * s

    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const b = Theme.widgetBaseBackgroundColor
        return Qt.rgba(b.r, b.g, b.b, b.a * Theme.widgetTransparency)
    }

    opacity: MprisController.hasPlayer ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on width   { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on height  { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

    // ── Layout ───────────────────────────────────────────────────────────────
    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS * root.s

        // Audio visualizer dot (if present)
        DockAudioVisualization {
            anchors.verticalCenter: parent.verticalCenter
        }

        // Title + artist (stacked, two lines)
        Item {
            id: textClip
            readonly property real scrollDistance: Math.max(0, titleText.implicitWidth - width)
            readonly property bool shouldScroll:   SettingsData.mediaScrollEnabled && scrollDistance > 0

            width:  Math.min(titleText.implicitWidth, root.maxTextWidth)
            height: textColumn.implicitHeight
            clip:   true
            anchors.verticalCenter: parent.verticalCenter
            visible: SettingsData.mediaSize > 0 && MprisController.hasPlayer

            Column {
                id: textColumn
                spacing: 1

                StyledText {
                    id: titleText
                    text: MprisController.displayTitle
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.weight:    Font.SemiBold
                    color:          Theme.surfaceText
                    wrapMode:       Text.NoWrap
                }

                StyledText {
                    id: artistText
                    text:    MprisController.displayArtist
                    font.pixelSize: (Theme.fontSizeSmall - 1) * root.s
                    font.weight:    Font.Normal
                    color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                    wrapMode:       Text.NoWrap
                    visible:        text.length > 0
                }
            }

            onShouldScrollChanged: if (!shouldScroll) textColumn.x = 0

            SequentialAnimation {
                running: textClip.shouldScroll
                loops:   Animation.Infinite
                PauseAnimation  { duration: 800 }
                NumberAnimation { target: textColumn; property: "x"; from: 0; to: -textClip.scrollDistance; duration: Math.max(1500, textClip.scrollDistance * 18); easing.type: Easing.Linear }
                PauseAnimation  { duration: 800 }
                NumberAnimation { target: textColumn; property: "x"; from: -textClip.scrollDistance; to: 0; duration: Math.max(1500, textClip.scrollDistance * 18); easing.type: Easing.Linear }
            }
        }

        // ── Prev ─────────────────────────────────────────────────────────────
        Rectangle {
            width:  22 * root.s;  height: width;  radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color:   prevArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
            opacity: MprisController.canGoPrevious ? 1.0 : 0.3
            visible: MprisController.hasPlayer
            Behavior on color { ColorAnimation { duration: 120 } }

            EHIcon { anchors.centerIn: parent; name: "skip_previous"; size: 13 * root.s; color: Theme.surfaceText }

            MouseArea {
                id: prevArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: MprisController.previous()
            }
        }

        // ── Play/Pause ────────────────────────────────────────────────────────
        Rectangle {
            width:  26 * root.s;  height: width;  radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: MprisController.isPlaying
                ? Theme.primary
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            visible: MprisController.hasPlayer
            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

            EHIcon {
                anchors.centerIn: parent
                name:  MprisController.isPlaying ? "pause" : "play_arrow"
                size:  15 * root.s
                color: MprisController.isPlaying ? Theme.onPrimary : Theme.primary
                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: MprisController.togglePlaying()
            }
        }

        // ── Next ──────────────────────────────────────────────────────────────
        Rectangle {
            width:  22 * root.s;  height: width;  radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color:   nextArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
            opacity: MprisController.canGoNext ? 1.0 : 0.3
            visible: MprisController.hasPlayer
            Behavior on color { ColorAnimation { duration: 120 } }

            EHIcon { anchors.centerIn: parent; name: "skip_next"; size: 13 * root.s; color: Theme.surfaceText }

            MouseArea {
                id: nextArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: MprisController.next()
            }
        }
    }
}
