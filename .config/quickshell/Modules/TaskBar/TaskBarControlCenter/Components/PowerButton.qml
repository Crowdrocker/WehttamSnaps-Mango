import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real scaleFactor: uiScale


    property string iconName: ""
    property string text: ""
    readonly property real contentPadding: Math.max(6, height * 0.2)
    readonly property real contentHeight: Math.max(0, height - contentPadding * 2)

    signal pressed()

    height: spx(34)
    radius: Theme.cornerRadius
    clip: true
    
    color: {
        if (mouseArea.containsMouse) {
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        }
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, SettingsData.controlCenterWidgetBackgroundOpacity)
    }
    

    Row {
        anchors.fill: parent
        anchors.margins: root.contentPadding
        spacing: Math.max(4, root.contentHeight * 0.15)
        height: root.contentHeight

        EHIcon {
            name: root.iconName
            size: Math.min(root.contentHeight, 20)
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Typography {
            text: root.text
            style: Typography.Style.Button
            color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Math.max(10, Math.min(root.contentHeight * 0.6, Theme.fontSizeSmall))
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            height: parent.height
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed()
    }
}