import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property color iconColor: Theme.primary
    property string primaryText: ""
    property string secondaryText: ""
    property bool expanded: false
    property bool isActive: false
    property bool showExpandArea: true

    // These are kept for API compatibility but no longer used for layout —
    // the RowLayout handles distribution automatically.
    property real horizontalPadding: Theme.spacingM
    property real contentSpacing: Theme.spacingM

    signal toggled()
    signal expandClicked()
    signal wheelEvent(var wheelEvent)

    width: parent ? parent.width : 220
    height: 60
    radius: Theme.widgetRadius

    readonly property color _bg: Qt.rgba(
        Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
        Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity || 0.5)
    )

    color: _bg
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1
    antialiasing: true

    // Hover overlay
    Rectangle {
        id: hoverOverlay
        anchors.fill: parent
        radius: parent.radius
        color: Theme.isLightMode ? Qt.darker(root._bg, 1.2) : Qt.lighter(root._bg, 1.2)
        opacity: 0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingM
            rightMargin: Theme.spacingM
        }
        spacing: Theme.spacingM

        // Icon tile
        Rectangle {
            id: iconTile
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.widgetRadius

            readonly property color _activeColor: Theme.primary
            readonly property color _inactiveColor: Qt.rgba(
                Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                Theme.popupTransparency || 0.9
            )

            color: root.isActive ? _activeColor : _inactiveColor
            border.color: root.isActive
                ? Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)
                : "transparent"
            border.width: root.isActive ? 1 : 0
            antialiasing: true

            // Icon tile hover
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: Theme.isLightMode ? Qt.darker(parent.color, 1.2) : Qt.lighter(parent.color, 1.2)
                opacity: tileMouse.pressed ? 0.3 : (tileMouse.containsMouse ? 0.18 : 0)
                antialiasing: true
                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
            }

            EHIcon {
                anchors.centerIn: parent
                name: root.iconName
                size: Theme.iconSize
                color: root.isActive ? Theme.primaryContainer : root.iconColor
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }

        // Text block — fills all remaining space
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.primaryText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.secondaryText
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                visible: root.secondaryText.length > 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }

    // Body click / hover / wheel area — sits over the text region
    MouseArea {
        id: bodyMouse
        anchors {
            left: parent.left
            leftMargin: Theme.spacingM + 40 + Theme.spacingM   // clear the icon tile
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered:  hoverOverlay.opacity = 0.08
        onExited:   hoverOverlay.opacity = 0
        onPressed:  hoverOverlay.opacity = 0.16
        onReleased: hoverOverlay.opacity = containsMouse ? 0.08 : 0
        onClicked: root.expandClicked()
        onWheel: ev => root.wheelEvent(ev)
    }

    focus: true
    Keys.onPressed: ev => {
        if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Return) { root.toggled(); ev.accepted = true }
        else if (ev.key === Qt.Key_Right) { root.expandClicked(); ev.accepted = true }
    }
}
