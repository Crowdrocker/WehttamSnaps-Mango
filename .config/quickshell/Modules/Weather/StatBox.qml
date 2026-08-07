import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Fixed-size stat card: accent bar top, icon, label, value.
// width and height are always set explicitly by the parent.
Rectangle {
    id: root

    property string label:    ""
    property string value:    ""
    property string iconName: ""
    property real   s:        1.0

    radius:       Math.round(Theme.cornerRadius * 1.0)
    color:        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
    border.color: Theme.primary
    border.width: 2

    // Top accent bar
    Rectangle {
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width:  Math.round(parent.width * 0.40)
        height: 2
        radius: 1
        color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
    }

    Column {
        anchors.centerIn: parent
        spacing:          Math.round(5 * root.s)

        EHIcon {
            name:  root.iconName || "info"
            size:  Math.round(22 * root.s)
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text:                root.label
            font.pixelSize:      Math.round(11 * root.s)
            font.letterSpacing:  0.3
            color:               Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.50)
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            text:                root.value
            font.pixelSize:      Math.round(16 * root.s)
            font.weight:         Font.SemiBold
            color:               Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
