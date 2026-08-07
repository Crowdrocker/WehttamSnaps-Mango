import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property string iconName: ""
    property string label: ""
    property string value: ""

    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
    border.width: 1

    Row {
        anchors.centerIn: parent
        spacing: 10

        EHIcon {
            name: iconName
            size: 18
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: label
                font.pixelSize: Theme.fontSizeSmall - 2
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            }

            StyledText {
                text: value
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
        }
    }
}
