import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property int currentIndex: 0

    signal tabSelected(int index)

    height: 44

    Rectangle {
        anchors.bottom: parent.bottom
        width:  parent.width
        height: 1
        color:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    }

    readonly property var tabs: [
        { label: "Search",    icon: "search"      },
        { label: "Installed", icon: "view_list"   },
        { label: "Updates",   icon: "upgrade"     }
    ]

    Row {
        anchors.left:       parent.left
        anchors.leftMargin: Theme.spacingL
        anchors.bottom:     parent.bottom
        height: parent.height
        spacing: 4

        Repeater {
            model: root.tabs

            Item {
                id: tabItem
                required property var modelData
                required property int index

                property bool isActive: root.currentIndex === index
                width:  tabRow.implicitWidth + Theme.spacingL * 2
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  tabItem.isActive ? parent.width - 8 : 0
                    height: 2
                    radius: 1
                    color:  Theme.primary
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.fill:        parent
                    anchors.bottomMargin: 2
                    radius: Theme.cornerRadius
                    color: tabItem.isActive
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        : (tabHover.containsMouse
                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                            : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    EHIcon {
                        name:  tabItem.modelData.icon
                        size:  16
                        color: tabItem.isActive ? Theme.primary
                            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    StyledText {
                        text:           tabItem.modelData.label
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    tabItem.isActive ? Font.Medium : Font.Normal
                        color: tabItem.isActive ? Theme.primary
                            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: tabHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.tabSelected(tabItem.index)
                }
            }
        }
    }
}