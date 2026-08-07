import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: btn

    property string iconName: ""
    property bool   active:   false
    property bool   isDanger: false
    property real   scale_s:  1.0

    signal tapped

    width:  32 * scale_s
    height: 32 * scale_s
    radius: Theme.cornerRadius

    color: active
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
        : area.containsMouse
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
            : "transparent"
    border.color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : "transparent"
    border.width: active ? 1 : 0
    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

    EHIcon {
        anchors.centerIn: parent
        name:  btn.iconName
        size:  18 * btn.scale_s
        color: btn.isDanger  ? Theme.error
             : btn.active    ? Theme.primary
             : Theme.surfaceText
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    btn.tapped()
    }
}
