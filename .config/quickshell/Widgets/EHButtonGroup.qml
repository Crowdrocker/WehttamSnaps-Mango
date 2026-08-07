import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var model: []
    property int currentIndex: -1
    property string selectionMode: "single"
    property bool multiSelect: selectionMode === "multi"
    property bool checkEnabled: true
    property int buttonHeight: 36
    property int minButtonWidth: 60
    property int buttonPadding: Theme.spacingM
    property int checkIconSize: Theme.iconSizeSmall
    property int textSize: Theme.fontSizeMedium
    property int spacing: 4

    signal selectionChanged(int index, bool selected)

    implicitWidth: buttonRow.implicitWidth
    implicitHeight: buttonRow.implicitHeight

    function isSelected(index) {
        if (multiSelect) {
            return repeater.itemAt(index)?.selected || false
        }
        return index === currentIndex
    }

    function selectItem(index) {
        if (multiSelect) {
            const item = repeater.itemAt(index)
            if (item) {
                item.selected = !item.selected
                selectionChanged(index, item.selected)
            }
        } else {
            const oldIndex = currentIndex
            currentIndex = index
            selectionChanged(index, true)
            if (oldIndex !== index && oldIndex >= 0) {
                selectionChanged(oldIndex, false)
            }
        }
    }

    Row {
        id: buttonRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            id: repeater
            model: root.model

            delegate: Rectangle {
            id: segment

            property bool selected: multiSelect ? false : (index === root.currentIndex)
            property bool hovered: mouseArea.containsMouse
            property bool pressed: mouseArea.pressed
            property bool isFirst: index === 0
            property bool isLast: index === repeater.count - 1
            property bool prevSelected: index > 0 ? root.isSelected(index - 1) : false
            property bool nextSelected: index < repeater.count - 1 ? root.isSelected(index + 1) : false

            width: Math.max(contentItem.implicitWidth + root.buttonPadding * 2, root.minButtonWidth)
            height: root.buttonHeight

            color: selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
            border.color: selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: selected ? 1.5 : 1
            radius: 10

            Behavior on color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                id: stateLayer
                anchors.fill: parent
                radius: parent.radius
                color: selected ? Theme.primary : Theme.surfaceTint
                opacity: {
                    if (pressed) return selected ? 0.2 : 0.16
                    if (hovered && !selected) return 0.12
                    if (hovered && selected) return 0.15
                    if (selected) return 0.05
                    return 0
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: selected
                opacity: 0.6
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.02) }
                }
            }

            Item {
                id: contentItem
                anchors.centerIn: parent
                implicitWidth: buttonText.implicitWidth
                implicitHeight: buttonText.implicitHeight

                StyledText {
                    id: buttonText
                    text: typeof modelData === "string" ? modelData : modelData.text || ""
                    font.pixelSize: root.textSize
                    font.weight: (segment.selected === true) ? 600 : 500
                    color: segment.selected ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
                    anchors.centerIn: parent

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Behavior on font.weight {
                        PropertyAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectItem(index)
            }
        }
    }
    }
}