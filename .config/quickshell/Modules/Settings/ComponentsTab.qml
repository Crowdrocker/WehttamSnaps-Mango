import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: componentsTab

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

            DarkDashTab {
                id: darkDashTabItem
                width: parent.width
                height: darkDashFlickable.contentHeight + Theme.spacingL
                parentModal: componentsTab.parentModal

                property var darkDashFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (darkDashFlickable) darkDashFlickable.interactive = false
                }
            }

            DesktopWidgetsStylingTab {
                id: desktopWidgetsStylingTabItem
                width: parent.width
                height: desktopWidgetsFlickable.contentHeight + Theme.spacingL
                parentModal: componentsTab.parentModal

                property var desktopWidgetsFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (desktopWidgetsFlickable) desktopWidgetsFlickable.interactive = false
                }
            }
        }
    }
}
