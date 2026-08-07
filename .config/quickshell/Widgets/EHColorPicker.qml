import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string pickerTitle: "Choose Color"
    property color selectedColor: Theme.primary
    property bool isOpen: false

    signal colorSelected(color selectedColor)

    function open() {
        customColorField.text = ""
        isOpen = true
        Qt.callLater(() => root.forceActiveFocus())
    }

    function close() {
        isOpen = false
    }

    anchors.centerIn: parent
    width: 300
    height: 320
    radius: 14
    color: Theme.surfaceContainer
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1
    z: 1000
    visible: isOpen
    focus: isOpen

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        }
    }

    EHActionButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        buttonSize: 28
        iconName: "close"
        iconSize: 16
        iconColor: Theme.surfaceText
        onClicked: root.close()
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        StyledText {
            text: pickerTitle
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Grid {
            columns: 8
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter

            property var colors: ["#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#795548", "#9e9e9e", "#607d8b", "#000000", "#ffffff", "#ff1744", "#f50057", "#d500f9", "#651fff", "#3d5afe", "#2979ff", "#00b0ff", "#00e5ff", "#1de9b6", "#00e676", "#76ff03", "#c6ff00", "#ffff00", "#ffc400", "#ff9100", "#ff3d00", "#bf360c", "#424242", "#37474f"]

            Repeater {
                model: parent.colors
                Rectangle {
                    width: 26
                    height: 26
                    color: modelData
                    radius: 6
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: root.selectedColor == modelData ? 2 : 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedColor = modelData
                            root.colorSelected(modelData)
                            root.close()
                        }
                    }
                }
            }
        }

        StyledText {
            text: "Custom Color:"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        EHTextField {
            id: customColorField
            width: parent.width
            height: 40
            placeholderText: "#ff0000"
            text: ""
            onAccepted: {
                var hexColor = text.startsWith("#") ? text : "#" + text
                if (/^#[0-9A-Fa-f]{6}$/.test(hexColor)) {
                    root.selectedColor = hexColor
                    root.colorSelected(hexColor)
                    root.close()
                }
            }
        }
    }
}
