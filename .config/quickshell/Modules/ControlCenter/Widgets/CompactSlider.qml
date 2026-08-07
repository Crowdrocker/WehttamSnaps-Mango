import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property string labelText: ""
    property real value: 0.0
    property real maximumValue: 1.0
    property real minimumValue: 0.0
    property bool enabled: true

    signal sliderValueChanged(real value)

    width: parent ? parent.width : 200
    height: 56
    radius: 12
    antialiasing: true
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * 0.6
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    opacity: enabled ? 1.0 : 0.6

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.right: sliderContainer.left
        anchors.rightMargin: 8
        spacing: 8

        EHIcon {
            name: root.iconName
            size: 18
            color: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.labelText
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: sliderContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        width: 120
        height: parent.height - 16

        EHSlider {
            anchors.centerIn: parent
            width: parent.width
            enabled: root.enabled
            minimum: Math.round(root.minimumValue * 100)
            maximum: Math.round(root.maximumValue * 100)
            value: Math.round(root.value * 100)
            onSliderValueChanged: root.sliderValueChanged(newValue / 100.0)
        }
    }
}
