import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    property real padding: 0
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: isBarVertical ? widgetHeight : (colorPickerIcon.width + horizontalPadding * 2)
    height: isBarVertical ? (colorPickerIcon.width + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: "transparent"

    EHIcon {
        id: colorPickerIcon

        anchors.centerIn: parent
        name: "palette"
        size: (Theme.iconSize - 6) * (widgetHeight / 30)
        color: colorPickerArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
    }

    MouseArea {
        id: colorPickerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.colorPickerRequested();
        }
    }

    signal colorPickerRequested()

}