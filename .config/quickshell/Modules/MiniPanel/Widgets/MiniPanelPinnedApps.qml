import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.MiniPanel.Widgets

Item {
    id: root

    property string section: "left"
    property var parentScreen: null
    property real widgetHeight: 30
    property var contextMenu: null
    property real iconSize: SettingsData.miniPanelPinnedAppsIconSize * SettingsData.miniPanelScale
    property real iconSpacing: SettingsData.miniPanelPinnedAppsIconSpacing * SettingsData.miniPanelScale
    property bool pillEnabled: SettingsData.dockPinnedAppsPillEnabled

    implicitWidth: pillEnabled ? pillBackground.implicitWidth : miniPanelApps.implicitWidth
    implicitHeight: pillEnabled ? pillBackground.implicitHeight : miniPanelApps.implicitHeight
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

        implicitWidth: miniPanelApps.implicitWidth + 16
        implicitHeight: miniPanelApps.implicitHeight

        MiniPanelApps {
            id: miniPanelApps
            anchors.centerIn: parent
            widgetHeight: root.widgetHeight
            iconSize: root.iconSize
            iconSpacing: root.iconSpacing
            contextMenu: root.contextMenu
        }
    }

    MiniPanelApps {
        id: miniPanelAppsNoPill
        anchors.fill: parent
        visible: !root.pillEnabled
        widgetHeight: root.widgetHeight
        iconSize: root.iconSize
        iconSpacing: root.iconSpacing
        contextMenu: root.contextMenu
    }
}
