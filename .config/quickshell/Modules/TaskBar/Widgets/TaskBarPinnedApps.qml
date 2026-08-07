import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.TaskBar

Item {
    id: root

    property string section: "left"
    property var parentScreen: null
    property real widgetHeight: (SettingsData.taskBarIconSize || 39) * SettingsData.taskbarScale
    property var contextMenu: null
    property real iconSize: (SettingsData.taskBarIconSize || 39) * SettingsData.taskbarScale
    property real iconSpacing: (SettingsData.taskBarIconSpacing || 0) * SettingsData.taskbarScale
    property bool pillEnabled: SettingsData.dockPinnedAppsPillEnabled

    implicitWidth: pillEnabled ? pillBackground.implicitWidth : taskBarApps.implicitWidth
    implicitHeight: pillEnabled ? pillBackground.implicitHeight : taskBarApps.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        visible: root.pillEnabled
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.widgetTransparency)
        radius: Theme.widgetRadius
        border.width: 0
        border.color: "transparent"
        clip: true

        implicitWidth: taskBarApps.implicitWidth + 16
        implicitHeight: taskBarApps.implicitHeight

        TaskBarApps {
            id: taskBarApps
            anchors.centerIn: parent
            widgetHeight: root.widgetHeight
            iconSize: root.iconSize
            iconSpacing: root.iconSpacing
            contextMenu: root.contextMenu
        }
    }

    TaskBarApps {
        id: taskBarAppsNoPill
        anchors.fill: parent
        visible: !root.pillEnabled
        widgetHeight: root.widgetHeight
        iconSize: root.iconSize
        iconSpacing: root.iconSpacing
        contextMenu: root.contextMenu
    }
}
