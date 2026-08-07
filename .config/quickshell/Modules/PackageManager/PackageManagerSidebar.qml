import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: sidebarContainer

    property int currentIndex: 0
    property real cornerRadius: 12
    property var expandedCategories: ({})

    property int collapsedW: 64
    property int expandedW: 200

    property int effectiveWidth: sidebarBg.width

    readonly property var sidebarItems: [{
        "id": "home",
        "text": "Home",
        "icon": "home",
        "tabIndex": 0
    }, {
        "id": "search",
        "text": "Search",
        "icon": "search",
        "tabIndex": 1
    }, {
        "id": "installed",
        "text": "Installed",
        "icon": "view_list",
        "tabIndex": 2
    }, {
        "id": "updates",
        "text": "Updates",
        "icon": "upgrade",
        "tabIndex": 3
    }, {
        "id": "localinstall",
        "text": "Local Install",
        "icon": "install_desktop",
        "tabIndex": 4
    }]

    readonly property var flatItems: sidebarItems

    function toggleCategory(categoryId) {
        var newExpanded = Object.assign({}, expandedCategories)
        newExpanded[categoryId] = !isCategoryExpanded(categoryId)
        expandedCategories = newExpanded
    }

    function isCategoryExpanded(categoryId) {
        if (expandedCategories[categoryId] !== undefined)
            return expandedCategories[categoryId]
        return false
    }

    height: parent.height
    width: expandedW

    Rectangle {
        id: sidebarBg
        anchors.fill: parent

        color: Qt.rgba(Theme.surfaceContainer.r,
                       Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, 0.55)
        radius: cornerRadius
        clip: true
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        EHFlickable {
            id: sidebarFlickable
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            contentHeight: navColumn.implicitHeight
            contentWidth: width
            clip: true

            Column {
                id: navColumn
                width: parent.width
                spacing: 1
                topPadding: 6
                bottomPadding: 6

                Repeater {
                    model: sidebarContainer.sidebarItems

                    Item {
                        id: navRow
                        required property int index
                        required property var modelData
                        property bool isActive: sidebarContainer.currentIndex === modelData.tabIndex

                        width: parent.width
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            radius: 8
                            color: {
                                if (navRow.isActive)
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                if (rowHover.containsMouse)
                                    return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.07)
                                return "transparent"
                            }
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                        }

                        Rectangle {
                            visible: navRow.isActive
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 18; radius: 2
                            color: Theme.primary
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                width: 22
                                height: parent.height

                                EHIcon {
                                    anchors.centerIn: parent
                                    name: navRow.modelData.icon || ""
                                    size: 20
                                    color: navRow.isActive
                                        ? Theme.primary
                                        : (rowHover.containsMouse
                                            ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.9)
                                            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6))
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            Item {
                                width: parent.width - 22 - 10
                                height: parent.height

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navRow.modelData.text || ""
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: navRow.isActive ? 600 : 400
                                    color: navRow.isActive
                                        ? Theme.primary
                                        : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sidebarContainer.currentIndex = navRow.modelData.tabIndex
                            }
                        }
                    }
                }
            }
        }
    }
}
