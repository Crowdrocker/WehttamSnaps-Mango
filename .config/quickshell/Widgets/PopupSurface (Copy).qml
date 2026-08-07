import QtQuick
import qs.Common

Item {
    id: root

    // External API
    property alias content: contentItem.data

    property real radius: Theme.cornerRadius

    // Surface + border (matugen-driven via Theme.*)
    // If you want popups to match Desktop widgets' "wallpaper colors",
    // enable this and pick a matugen role like "primary_container".
    property bool wallpaperTintEnabled: false
    property string wallpaperTintRole: "primary_container"

    property color surfaceColor: Theme.surfaceContainer
    property real surfaceAlpha: 0.88

    property color borderColor: Theme.outline
    property real borderAlpha: 0.20
    property real borderWidth: 1

    // Shadow color must be Theme.* (no raw black constants)
    property bool shadowEnabled: true
    property color shadowColor: Theme.shadowMedium
    property real shadowAlpha: 1.0
    property int shadowTopMargin: 4
    property int shadowLeftMargin: 2
    property int shadowRightMargin: -2
    property int shadowBottomMargin: -4

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    function _toColor(v) {
        if (v === undefined || v === null) return Qt.rgba(0, 0, 0, 0)
        // Theme.getMatugenColor may return a string ("#rrggbb") or a color
        try { return Qt.color(v) } catch (e) { return v }
    }

    readonly property color _surfaceRgb: {
        if (!wallpaperTintEnabled) return surfaceColor
        const v = Theme.getMatugenColor(wallpaperTintRole, surfaceColor)
        return _toColor(v)
    }

    // Shadow (drawn behind the surface)
    Rectangle {
        anchors.fill: surface
        anchors.topMargin: root.shadowTopMargin
        anchors.leftMargin: root.shadowLeftMargin
        anchors.rightMargin: root.shadowRightMargin
        anchors.bottomMargin: root.shadowBottomMargin
        radius: root.radius
        // Preserve Theme shadow alpha; allow scaling via shadowAlpha.
        color: Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b,
                       (root.shadowColor.a !== undefined ? root.shadowColor.a : 1.0) * root.shadowAlpha)
        visible: root.shadowEnabled
        z: -1
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(root._surfaceRgb.r, root._surfaceRgb.g, root._surfaceRgb.b, root.surfaceAlpha)
        border.color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.borderAlpha)
        border.width: root.borderWidth
        antialiasing: true

        Item {
            id: contentItem
            anchors.fill: parent
        }
    }
}

