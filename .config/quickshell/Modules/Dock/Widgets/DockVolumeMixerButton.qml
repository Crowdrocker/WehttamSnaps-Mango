import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    readonly property int textWidth: 0
    readonly property int currentContentWidth: {
        return volumeRow.implicitWidth + horizontalPadding * 2;
    }
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real padding: 8
    property real iconSize: 24
    property real iconSpacing: 8
    property real scaleFactor: 1
    property real barHeight: 48
    property real widgetHeight: 48
    property bool isBarVertical: false
    readonly property real horizontalPadding: Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 48))

    signal clicked()

    width: isBarVertical ? widgetHeight : currentContentWidth
    height: isBarVertical ? currentContentWidth : widgetHeight
    radius: Theme.widgetRadius * (widgetHeight / 48)
    color: {
        const baseColor = volumeArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    MouseArea {
        id: volumeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            root.clicked()
        }
    }

    Row {
        id: volumeRow
        anchors.centerIn: parent
        spacing: iconSpacing * (widgetHeight / 48)

        EHIcon {
            name: AudioService.getOutputIcon()
            size: iconSize * (widgetHeight / 48)

            anchors.verticalCenter: parent.verticalCenter

        }

        StyledText {
            color: AudioService.muted ? Theme.error : Theme.surfaceText
            text: Math.round(AudioService.volume * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 48)

            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            visible: SettingsData.mediaSize > 0

        }
    }

    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}