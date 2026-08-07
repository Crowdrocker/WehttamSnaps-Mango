import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets 1.0
import qs.Modules.Dock 1.0

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool danger: false
    property int maxVisibleRows: 8
    property real rowHeight: 34

    // display
    property string text: {
        if (!model || model.length === 0) return ""
        const i = Math.max(0, Math.min(model.length - 1, currentIndex))
        return "" + model[i]
    }

    signal activated(int index)

    implicitWidth: 56
    implicitHeight: 26

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.20)
        border.width: 1
        border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.22)

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            Item { width: 1; height: 1; anchors.verticalCenter: parent.verticalCenter; }

            EHIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                size: 14
                color: Theme.surfaceVariantText
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => {
                mouse.accepted = true
                const p = root.mapToItem(null, mouse.x, mouse.y)
                popup.showAt(root.Window.window ? (root.Window.window.x + p.x) : p.x,
                             root.Window.window ? (root.Window.window.y + p.y) : p.y)
            }
        }
    }

    PanelWindow {
        id: popup

        WlrLayershell.namespace: "quickshell:dock:blur"

        property bool open: false
        property point anchorPos: Qt.point(200, 200)

        function showAt(screenX, screenY) {
            // pick screen for point
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (screenX >= s.x && screenX < s.x + s.width &&
                    screenY >= s.y && screenY < s.y + s.height) {
                    popup.screen = s
                    break
                }
            }
            anchorPos = Qt.point(screenX - popup.screen.x, screenY - popup.screen.y)
            open = true
        }

        function close() { open = false }

        screen: Quickshell.screens[0]
        visible: open
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        readonly property int rateAwareDuration: Math.round(Theme.mediumDuration * 60 / Math.max(60, screen ? screen.refreshRate : 60))

        Item {
            id: menuContainer

            readonly property int r: Theme.cornerRadius + 2
            readonly property int visibleRows: Math.min(root.maxVisibleRows, root.model ? root.model.length : 0)
            readonly property int innerW: menuContainer.width - Theme.spacingM * 2

            width:  Math.max(160, root.width + 40)
            height: (visibleRows * root.rowHeight) + Theme.spacingS * 2

            x: Math.max(10, Math.min(popup.width - width - 10, popup.anchorPos.x - width / 2))
            y: Math.max(10, Math.min(popup.height - height - 10, popup.anchorPos.y - 10))

            opacity: popup.open ? 1 : 0
            scale:   popup.open ? 1 : 0.92

            Behavior on opacity { NumberAnimation { duration: popup.rateAwareDuration; easing.type: Theme.emphasizedEasing } }
            Behavior on scale   { NumberAnimation { duration: popup.rateAwareDuration; easing.type: Theme.emphasizedEasing } }

            Rectangle {
                anchors { fill: parent; topMargin: 4; leftMargin: 2; rightMargin: -2; bottomMargin: -4 }
                radius: menuContainer.r
                color:  Qt.rgba(0, 0, 0, 0.18)
                z:      -1
            }

            Rectangle {
                anchors.fill: parent
                radius: menuContainer.r
                color: Theme.popupBackground()
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                border.width: 1
            }

            Flickable {
                id: menuFlick
                width:  menuContainer.innerW
                height: menuContainer.height - Theme.spacingS * 2
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.spacingS }
                clip: true
                interactive: contentHeight > height
                flickableDirection: Flickable.VerticalFlick

                contentWidth: width
                contentHeight: menuCol.implicitHeight

                Column {
                    id: menuCol
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.model || []
                        Item {
                            id: opt
                            required property int index
                            required property var modelData
                            width: menuCol.width
                            height: root.rowHeight

                            property bool hovered: area.containsMouse
                            readonly property bool selected: index === root.currentIndex

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: hovered
                                    ? (root.danger
                                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10))
                                    : "transparent"
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                EHIcon {
                                    width: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: selected ? "check" : ""
                                    size: 15
                                    color: root.danger ? Theme.error : Theme.surfaceVariantText
                                    visible: selected
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "" + modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.danger ? Theme.error : Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width - (selected ? 16 + Theme.spacingS : 0)
                                }
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentIndex = index
                                    root.activated(index)
                                    popup.close()
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: popup.close()
        }
    }
}

