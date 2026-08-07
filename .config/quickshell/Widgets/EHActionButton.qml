import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string iconName: ""
    property int iconSize: Math.round((Theme.iconSize - 2) * scaleFactor)
    property color iconColor: Theme.surfaceText
    property color backgroundColor: "transparent"
    property bool circular: true
    property int buttonSize: Math.round(36 * scaleFactor)
    property int buttonPadding: Math.round(8 * scaleFactor)
    property real scaleFactor: Appearance.combinedScale

    signal clicked

    width: buttonSize
    height: buttonSize
    radius: circular ? buttonSize / 2 : Math.round(10 * scaleFactor)
    color: backgroundColor
    border.width: 0

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }


    EHIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: root.iconSize
        color: root.iconColor
    }

    StateLayer {
        stateColor: Theme.primary
        cornerRadius: root.radius
        onClicked: root.clicked()
    }
}
