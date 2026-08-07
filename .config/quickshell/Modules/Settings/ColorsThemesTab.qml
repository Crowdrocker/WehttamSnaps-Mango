import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: colorsThemesTab

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

            // Each sub-tab is given an explicit height matching its own
            // internal contentHeight so its inner EHFlickable has a real size.

            ColorPaletteTab {
                id: colorPaletteTabItem
                width: parent.width
                height: colorPaletteFlickable.contentHeight + Theme.spacingL
                parentModal: colorsThemesTab.parentModal

                property var colorPaletteFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (colorPaletteFlickable) colorPaletteFlickable.interactive = false
                }
            }

            TextColorTab {
                id: textColorTabItem
                width: parent.width
                height: textColorFlickable.contentHeight + Theme.spacingL
                parentModal: colorsThemesTab.parentModal

                property var textColorFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (textColorFlickable) textColorFlickable.interactive = false
                }
            }

            ColorAdjustmentsTab {
                id: colorAdjustmentsTabItem
                width: parent.width
                height: colorAdjustFlickable.contentHeight + Theme.spacingL
                parentModal: colorsThemesTab.parentModal

                property var colorAdjustFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (colorAdjustFlickable) colorAdjustFlickable.interactive = false
                }
            }

            VisualEffectsTab {
                id: visualEffectsTabItem
                width: parent.width
                height: visualEffectsFlickable.contentHeight + Theme.spacingL
                parentModal: colorsThemesTab.parentModal

                property var visualEffectsFlickable: {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i].contentHeight !== undefined) return children[i]
                    }
                    return null
                }

                Component.onCompleted: {
                    if (visualEffectsFlickable) visualEffectsFlickable.interactive = false
                }
            }
        }
    }
}
