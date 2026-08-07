import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    // Optional accent: if set, hover tints with this color; otherwise uses primary
    property color accentColor: Theme.primary

    signal pressed()

    height: 40
    radius: Theme.cornerRadius
    clip: true

    color: mouseArea.containsMouse
           ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
           : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                     Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity || 0.5))

    border.color: mouseArea.containsMouse
                  ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                  : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingM
            rightMargin: Theme.spacingM
        }
        spacing: Theme.spacingS

        EHIcon {
            name: root.iconName
            size: 16
            color: mouseArea.containsMouse ? root.accentColor : Theme.surfaceVariantText
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: mouseArea.containsMouse ? root.accentColor : Theme.surfaceText
            elide: Text.ElideRight
            Layout.fillWidth: true
            visible: root.text.length > 0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pressed()
    }

    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
    Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
}
