import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var contextMenu: null
    property int pinnedAppCount: 0
    property real widgetHeight: 30
    property real iconSize: SettingsData.miniPanelPinnedAppsIconSize * SettingsData.miniPanelScale
    property real iconSpacing: SettingsData.miniPanelPinnedAppsIconSpacing * SettingsData.miniPanelScale

    implicitWidth: row.width
    implicitHeight: row.height

    Row {
        id: row
        spacing: root.iconSpacing

        Repeater {
            model: SessionData.pinnedApps || []

            delegate: Item {
                width: root.iconSize
                height: root.iconSize

                property string appId: modelData || ""
                property var desktopEntry: appId ? DesktopEntries.heuristicLookup(appId) : null
                property string iconPath: desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : ""

                Image {
                    id: appIcon
                    anchors.fill: parent
                    anchors.margins: 2
                    source: iconPath
                    sourceSize.width: root.iconSize * 2
                    sourceSize.height: root.iconSize * 2
                    smooth: true
                    cache: false
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (appId) {
                            CompositorService.launchApp(appId)
                        }
                    }
                }
            }
        }
    }
}
