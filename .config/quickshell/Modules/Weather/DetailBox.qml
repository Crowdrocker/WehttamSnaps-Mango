import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property string label: ""
    property string value: ""

    radius: Theme.cornerRadius * 0.5
    height: 44

    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)

    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        StyledText {
            text: label
            font.pixelSize: Theme.fontSizeSmall
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: value
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }
}