import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: bRow

    height: 48

    property string backupLabel: ""
    property bool   canRestore:  true

    signal restoreRequested()
    signal deleteRequested()

    // Hover background
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius - 2
        color: rowHov.containsMouse
               ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: rowHov
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingS
            rightMargin: Theme.spacingS
        }
        spacing: Theme.spacingS

        EHIcon {
            name: "folder"
            size: 18
            color: Theme.primary
            opacity: 0.75
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: bRow.backupLabel
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            font.family: "monospace"
        }

        // Restore button
        Item {
            width: 72
            height: 28
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius - 2
                color: restHov.containsMouse && bRow.canRestore
                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                       : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, bRow.canRestore ? 0.45 : 0.2)
                border.width: 1
                opacity: bRow.canRestore ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            StyledText {
                anchors.centerIn: parent
                text: "Restore"
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
                color: Theme.primary
            }

            MouseArea {
                id: restHov
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                enabled: bRow.canRestore
                onClicked: bRow.restoreRequested()
            }
        }

        // Delete button
        Item {
            width: 28
            height: 28
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius - 2
                color: delHov.containsMouse
                       ? Qt.rgba(0.93, 0.33, 0.31, 0.22)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            EHIcon {
                anchors.centerIn: parent
                name: "delete"
                size: 16
                color: delHov.containsMouse ? "#EF5350" : Theme.surfaceVariantText
                opacity: 0.75
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: delHov
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: bRow.deleteRequested()
            }
        }
    }
}
