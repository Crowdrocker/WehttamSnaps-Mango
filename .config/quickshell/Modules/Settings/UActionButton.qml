import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: btn

    height: 38

    property string label:    ""
    property string iconName: ""
    property color  accent:   Theme.primary
    property bool   enabled:  true

    signal action()

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: hov.containsMouse && btn.enabled
               ? Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, 0.22)
               : Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, 0.10)
        border.color: Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, btn.enabled ? 0.5 : 0.2)
        border.width: 1
        opacity: btn.enabled ? 1.0 : 0.45

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            name: btn.iconName
            size: 16
            color: btn.accent
        }

        StyledText {
            text: btn.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: btn.accent
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: btn.enabled
        onClicked: btn.action()
    }
}
