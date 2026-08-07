import QtQuick
import QtQuick.Effects
import Quickshell          // ← Added this import (required for Quickshell.execDetached)
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property bool isVertical: false
    property bool isAtBottom: true
    property string section: "right"
    property real scaleFactor: 1
    property real iconSpacing: 8
    property real iconSize: 24
    property real padding: 1
    property var popupTarget: null
    property var parentScreen: null
    property var contextMenu: null
    property real widgetHeight: 30
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    width: isBarVertical ? widgetHeight : (settingsIcon.width + horizontalPadding * 2)
    height: isBarVertical ? (settingsIcon.width + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = settingsArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    EHIcon {
        id: settingsIcon

        anchors.centerIn: parent
        name: "settings"
        size: Theme.iconSize - 6
        color: settingsArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
    }

    MouseArea {
        id: settingsArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            // Fixed: Open settings using IPC (no more ReferenceError)
            ModalManager.openSettingsRequested()

            root.clicked();
        }
    }
}
