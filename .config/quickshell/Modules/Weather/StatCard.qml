import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property string iconName: ""
    property string label: ""
    property string value: ""

    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 6

        EHIcon {
            name: iconName
            size: 20
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: label
            font.pixelSize: Theme.fontSizeSmall - 1
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: value
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}