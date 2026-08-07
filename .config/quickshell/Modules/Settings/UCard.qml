import QtQuick
import qs.Common

Item {
    id: cardRoot

    property real cWidth: 400
    property int  innerMargins: Theme.spacingL

    width: cWidth
    height: Math.max(inner.childrenRect.height + innerMargins * 2, innerMargins * 2)

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        border.width: 1
    }

    default property alias content: inner.data

    Item {
        id: inner
        anchors {
            fill: parent
            margins: cardRoot.innerMargins
        }
    }
}
