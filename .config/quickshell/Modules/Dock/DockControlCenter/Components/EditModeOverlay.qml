import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool editMode: false
    property var widgetData: null
    property int widgetIndex: -1
    property bool showSizeControls: true
    property bool isSlider: false

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)
    signal moveWidget(int fromIndex, int toIndex)

    Rectangle {
        width: 28
        height: 28
        radius: 14
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -6
        visible: editMode
        z: 10


        EHIcon {
            anchors.centerIn: parent
            name: "close"
            size: 18
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeWidget(widgetIndex)
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -8
        spacing: Theme.spacingXS
        visible: editMode && showSizeControls
        z: 10

        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: (widgetData?.width || 50) === 25 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 2
            visible: !isSlider


            StyledText {
                anchors.centerIn: parent
                text: "25"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 25 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 25
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: (widgetData?.width || 50) === 50 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 2


            StyledText {
                anchors.centerIn: parent
                text: "50"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 50 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 50
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: (widgetData?.width || 50) === 75 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 2
            visible: !isSlider


            StyledText {
                anchors.centerIn: parent
                text: "75"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 75 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 75
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: (widgetData?.width || 50) === 100 ? Theme.primary : Theme.primaryContainer
            border.color: Theme.primary
            border.width: 2


            StyledText {
                anchors.centerIn: parent
                text: "100"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: (widgetData?.width || 50) === 100 ? Theme.primaryText : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                        widgets[widgetIndex].width = 100
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 6
        spacing: Theme.spacingXS
        visible: editMode
        z: 20

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 2


            EHIcon {
                anchors.centerIn: parent
                name: "keyboard_arrow_left"
                size: 18
                color: Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                enabled: widgetIndex > 0
                hoverEnabled: true
                opacity: enabled ? 1.0 : 0.5
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.moveWidget(widgetIndex, widgetIndex - 1)
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: Theme.surfaceContainer
            border.color: Theme.outline
            border.width: 2


            EHIcon {
                anchors.centerIn: parent
                name: "keyboard_arrow_right"
                size: 18
                color: Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                enabled: widgetIndex < ((SettingsData.controlCenterWidgets?.length ?? 0) - 1)
                hoverEnabled: true
                opacity: enabled ? 1.0 : 0.5
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.moveWidget(widgetIndex, widgetIndex + 1)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
        radius: Theme.cornerRadius
        border.color: Theme.primary
        border.width: editMode ? 1 : 0
        visible: editMode
        z: -1

        Behavior on border.width {
            NumberAnimation { duration: Theme.shortDuration }
        }
    }
}