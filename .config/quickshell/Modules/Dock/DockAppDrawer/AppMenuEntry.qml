import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: entry

    property string label:    ""
    property string iconName: ""
    property real   scale_s:  1.0

    signal activated

    width:  parent.width
    height: 32 * scale_s

    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        // No Behavior on color here — menus are small and Behavior adds per-frame
        // binding cost for every entry even when the menu isn't animating.
        color: area.containsMouse
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
            : "transparent"
    }

    Row {
        anchors { left: parent.left; leftMargin: Theme.spacingS; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacingS

        EHIcon {
            name:    entry.iconName
            size:    (Theme.iconSize - 4) * entry.scale_s
            color:   Theme.surfaceVariantText
            opacity: 0.8
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text:           entry.label
            font.pixelSize: Theme.fontSizeSmall * entry.scale_s
            color:          Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    entry.activated()
    }
}
