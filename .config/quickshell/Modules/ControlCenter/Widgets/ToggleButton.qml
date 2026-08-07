import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property bool isActive: false
    property bool enabled: true
    property string secondaryText: ""
    property real iconRotation: 0

    signal clicked()

    width: parent ? parent.width : 200
    height: 56
    radius: 12
    antialiasing: true

    readonly property color _tileBgActive: Theme.primary
    readonly property color _tileBgInactive:
        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                (Theme.getContentBackgroundAlpha ? Theme.getContentBackgroundAlpha() : 1) * SettingsData.controlCenterWidgetBackgroundOpacity)
    readonly property color _tileRingActive:
        Qt.rgba(Theme.primaryText.r, Theme.primaryText.g, Theme.primaryText.b, 0.22)

    color: isActive ? _tileBgActive : _tileBgInactive
    border.color: isActive ? _tileRingActive : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    opacity: enabled ? 1.0 : 0.6

    function hoverTint(base) {
        const factor = 1.15
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor)
    }

    readonly property color _containerBg:
        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                (Theme.getContentBackgroundAlpha ? Theme.getContentBackgroundAlpha() : 1) * SettingsData.controlCenterWidgetBackgroundOpacity)

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hoverTint(_containerBg)
        opacity: mouseArea.pressed ? 0.14 : (mouseArea.containsMouse ? 0.07 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 10

        EHIcon {
            name: root.iconName
            size: 18
            color: isActive ? (Theme.primaryContainer || Theme.primary) : (Theme.primary || "#888888")
            Layout.alignment: Qt.AlignVCenter
            rotation: root.iconRotation
        }

        Item {
            Layout.fillWidth: true
            height: parent.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    text: root.text
                    font.pixelSize: Theme.fontSizeMedium
                    color: isActive ? (Theme.primaryContainer || "#000000") : Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    renderType: Text.NativeRendering
                }

                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    font.pixelSize: Theme.fontSizeSmall
                    color: isActive ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.75) : Theme.surfaceVariantText
                    visible: text.length > 0
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                    wrapMode: Text.NoWrap
                }
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

    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
}
