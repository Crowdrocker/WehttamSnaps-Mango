import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property string primaryText: ""
    property string secondaryText: ""
    property bool expanded: false
    property bool isActive: false
    property bool showExpandArea: true
    property real horizontalPadding: 14
    property real contentSpacing: 12

    signal toggled()
    signal expandClicked()
    signal wheelEvent(var wheelEvent)

    width: parent ? parent.width : 220
    height: 60
    radius: 16
    antialiasing: true

    // ─── Colour helpers ───────────────────────────────────────────────────────
    function hoverTint(base) {
        const factor = 1.12
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _containerBg: {
        const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }

    // Tahoe: near-invisible border, very subtle so the card feels airy
    color: _containerBg
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.07)
    border.width: 1

    readonly property color _labelPrimary:    Theme.surfaceText
    readonly property color _labelSecondary:  Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.7)

    // Active tile: brand accent fill; inactive: lightly tinted surface
    readonly property color _tileBgActive:   Theme.primary
    readonly property color _tileBgInactive: {
        const transparency = Theme.popupTransparency || 0.88
        const surface = Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)
        return Qt.rgba(surface.r, surface.g, surface.b, transparency)
    }
    readonly property color _tileRingActive:   Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.18)
    readonly property color _tileIconActive:   Theme.primaryContainer
    readonly property color _tileIconInactive: Theme.primary

    // Tile: slightly larger, rounder to echo SF Symbols containers in Tahoe
    readonly property int _tileSize:   38
    readonly property int _tileRadius: 12

    // ─── Hover overlay ────────────────────────────────────────────────────────
    Rectangle {
        id: hoverOverlay
        anchors.fill: parent
        radius: root.radius
        z: 0
        visible: false
        color: hoverTint(_containerBg)
        opacity: 0.0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    // ─── Content row ──────────────────────────────────────────────────────────
    Row {
        id: row
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: 0
            bottomMargin: 0
        }
        spacing: root.contentSpacing

        // Icon tile
        Rectangle {
            id: iconTile
            z: 1
            width:  _tileSize
            height: _tileSize
            anchors.verticalCenter: parent.verticalCenter
            radius: _tileRadius
            color: isActive ? _tileBgActive : _tileBgInactive
            border.color: isActive
                ? _tileRingActive
                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
            border.width: 1
            antialiasing: true

            // Press / hover wash
            Rectangle {
                anchors.fill: parent
                radius: _tileRadius
                color: hoverTint(iconTile.color)
                opacity: tileMouse.pressed ? 0.22 : (tileMouse.containsMouse ? 0.12 : 0.0)
                visible: opacity > 0
                antialiasing: true
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            EHIcon {
                anchors.centerIn: parent
                name: iconName
                size: 17
                color: isActive ? _tileIconActive : _tileIconInactive
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // Text body
        Item {
            id: body
            width: row.width - iconTile.width - row.spacing
            height: row.height

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                StyledText {
                    width: parent.width
                    text: root.primaryText
                    color: _labelPrimary
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    renderType: Text.NativeRendering
                }

                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    color: _labelSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: bodyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered:  { hoverOverlay.visible = true;  hoverOverlay.opacity = 0.06 }
                onExited:   { hoverOverlay.opacity = 0.0;   hoverOverlay.visible = false }
                onPressed:  hoverOverlay.opacity = 0.12
                onReleased: hoverOverlay.opacity = containsMouse ? 0.06 : 0.0
                onClicked:  root.expandClicked()
                onWheel: function(ev) { root.wheelEvent(ev) }
            }
        }
    }

    focus: true
    Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Return) { root.toggled();      ev.accepted = true }
        else if (ev.key === Qt.Key_Right)                         { root.expandClicked(); ev.accepted = true }
    }
}
