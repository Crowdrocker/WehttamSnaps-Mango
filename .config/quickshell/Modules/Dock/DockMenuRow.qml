import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: row

    property string label:    ""
    property string iconName: ""
    property string iconSrc:  ""     // external icon URL (desktop entry actions)
    property string trailing: ""     // optional right-side icon name
    property bool   isDanger: false
    property bool   indented: false
    property int    rowH:     34
    property int    rowPadH:  12     // should match DockContextMenu.rowPadH

    signal activated

    width:   parent.width
    height:  rowH
    visible: true

    readonly property color _hoverBg: isDanger
        ? Qt.rgba(Theme.error.r,   Theme.error.g,   Theme.error.b,   0.12)
        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        rowArea.containsMouse ? row._hoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
    }

    Row {
        anchors {
            left:           parent.left
            leftMargin:     row.indented ? row.rowPadH * 2 : row.rowPadH
            right:          parent.right
            rightMargin:    row.rowPadH
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spacingS

        // Leading icon — Material or external image
        Item {
            width:   16; height: 16
            visible: row.iconName !== "" || row.iconSrc !== ""
            anchors.verticalCenter: parent.verticalCenter

            EHIcon {
                anchors.centerIn: parent
                name:    row.iconName
                size:    15
                color:   row.isDanger ? Theme.error : Theme.surfaceVariantText
                visible: row.iconName !== ""
            }

            IconImage {
                anchors.fill: parent
                source:       row.iconSrc
                asynchronous: true
                visible:      row.iconSrc !== "" && row.iconName === ""
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text:           row.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight:    Font.Normal
            color:          row.isDanger ? Theme.error : Theme.surfaceText
            elide:          Text.ElideRight
            wrapMode:       Text.NoWrap
            width:          parent.width
                            - (row.iconName !== "" || row.iconSrc !== "" ? 16 + Theme.spacingS : 0)
                            - (row.trailing !== "" ? 16 + Theme.spacingS : 0)
        }

        // Trailing chevron / expand icon
        EHIcon {
            anchors.verticalCenter: parent.verticalCenter
            name:    row.trailing
            size:    13
            color:   Theme.surfaceVariantText
            visible: row.trailing !== ""
        }
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    row.activated()
    }
}
