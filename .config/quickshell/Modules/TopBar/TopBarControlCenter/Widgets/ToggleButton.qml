import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property string secondaryText: ""
    property bool isActive: false
    property bool enabled: true
    property real iconRotation: 0

    signal clicked()

    width: parent ? parent.width : 200
    height: 60
    radius: Theme.widgetRadius

    readonly property color _bgActive: Qt.rgba(
        Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
    readonly property color _bgInactive: Qt.rgba(
        Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
        Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity || 0.5))

    color: isActive ? _bgActive : _bgInactive
    border.color: isActive
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1
    opacity: enabled ? 1.0 : 0.55
    antialiasing: true

    // Active left strip
    Rectangle {
        visible: root.isActive
        x: 0; y: Theme.widgetRadius
        width: 3
        height: parent.height - Theme.widgetRadius * 2
        radius: 2
        color: Theme.primary
        opacity: 0.85
    }

    // Hover tint
    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Theme.isLightMode
               ? Qt.darker(root.color, 1.15)
               : Qt.lighter(root.color, 1.15)
        opacity: mouseArea.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingM + 4
            rightMargin: Theme.spacingM
        }
        spacing: Theme.spacingM

        EHIcon {
            name: root.iconName
            size: Theme.iconSize
            color: root.isActive ? Theme.primary : Theme.surfaceVariantText
            Layout.alignment: Qt.AlignVCenter
            rotation: root.iconRotation
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.text
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: root.isActive ? Theme.primary : Theme.surfaceText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.secondaryText
                font.pixelSize: Theme.fontSizeSmall
                color: root.isActive
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
                    : Theme.surfaceVariantText
                visible: root.secondaryText.length > 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
}
