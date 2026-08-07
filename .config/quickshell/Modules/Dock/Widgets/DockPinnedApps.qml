import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Dock

Item {
    id: root

    property string section: "left"
    property var parentScreen: null
    property real widgetHeight: 30
    property real scaleFactor: 1
    property var contextMenu: null
    // Pinned apps must follow the main dock icon-size/spacing sliders.
    readonly property real uiScale: (SettingsData.dockScale || 1) * (Appearance.combinedScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real iconSize: (SettingsData.dockIconSize || 1) * uiScale
    // Make spacing follow icon size (so changing icon-size slider scales gaps too).
    property real iconSpacing: iconSize * ((SettingsData.dockIconSpacing || 0) / Math.max(1, (SettingsData.dockIconSize || 1)))
    property bool pillEnabled: SettingsData.dockPinnedAppsPillEnabled

    implicitWidth: pillEnabled ? pillBackground.implicitWidth : dockApps.implicitWidth
    implicitHeight: widgetHeight
    width: implicitWidth
    height: widgetHeight

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        visible: root.pillEnabled
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.widgetTransparency)
        radius: Theme.widgetRadius
        clip: true

        implicitWidth: dockApps.implicitWidth + root.spx(16)
        implicitHeight: root.widgetHeight

        DockApps {
            id: dockApps
            anchors.fill: parent
            anchors.leftMargin: root.spx(8)
            anchors.rightMargin: root.spx(8)
            widgetHeight: root.widgetHeight
            iconSize: root.iconSize
            iconSpacing: root.iconSpacing
            contextMenu: root.contextMenu
        }
    }

    DockApps {
        id: dockAppsNoPill
        anchors.fill: parent
        visible: !root.pillEnabled
        widgetHeight: root.widgetHeight
        iconSize: root.iconSize
        iconSpacing: root.iconSpacing
        contextMenu: root.contextMenu
    }
}
