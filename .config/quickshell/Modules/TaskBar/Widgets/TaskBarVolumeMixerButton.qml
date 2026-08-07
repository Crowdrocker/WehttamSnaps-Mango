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
    property real barHeight: 48
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.taskBarPosition === "left" || SettingsData.taskBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.taskBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: isBarVertical ? widgetHeight : currentContentWidth
    height: isBarVertical ? currentContentWidth : widgetHeight
    radius: SettingsData.taskBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.taskBarNoBackground) {
            return "transparent";
        }

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
        spacing: Theme.spacingXS

        EHIcon {
            name: AudioService.getOutputIcon()
            size: 16 * (widgetHeight / 30)

            anchors.verticalCenter: parent.verticalCenter

        }

        StyledText {
            color: AudioService.muted ? Theme.error : Theme.surfaceText
            text: Math.round(AudioService.volume * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall

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