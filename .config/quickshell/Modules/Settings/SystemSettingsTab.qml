import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: systemSettingsTab

    property var parentModal: null

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            SystemThemeTab {
                id: systemThemeTabItem
                width: parent.width
                height: systemThemeFlickable.contentHeight + Theme.spacingL
                parentModal: systemSettingsTab.parentModal

                property var systemThemeFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (systemThemeFlickable) systemThemeFlickable.interactive = false
                }
            }

            SettingsThemesIconsTab {
                id: settingsThemesIconsTabItem
                width: parent.width
                height: settingsThemesFlickable.contentHeight + Theme.spacingL
                parentModal: systemSettingsTab.parentModal

                property var settingsThemesFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (settingsThemesFlickable) settingsThemesFlickable.interactive = false
                }
            }
        }
    }
}
