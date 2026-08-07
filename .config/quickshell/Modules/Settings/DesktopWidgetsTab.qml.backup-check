import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: desktopWidgetsTab

    property var expandedStates: ({})
    property var parentModal: null
    
    readonly property var primaryScreen: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property string primaryScreenKey: primaryScreen ? SettingsData.getScreenDisplayName(primaryScreen) : "primary"

    DesktopWidgetBrowser {
        id: widgetBrowser
        parentModal: desktopWidgetsTab.parentModal
        onWidgetAdded: widgetType => {
            if (typeof ToastService !== 'undefined')
                ToastService.showInfo("Widget added");
        }
    }

    DarkFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        anchors.bottomMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL
            bottomPadding: Theme.spacingL

            StyledRect {
                width: parent.width
                height: enableSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: enableSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Desktop Widgets"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "Add and configure widgets that appear on your desktop"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Row {
                        spacing: Theme.spacingM
                        width: parent.width

                        StyledRect {
                            width: Math.min(400, parent.width)
                            height: 56
                            radius: Theme.cornerRadius
                            color: addButtonArea.containsMouse ? 
                                Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : 
                                Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                            border.color: addButtonArea.containsMouse ? 
                                Theme.primary : 
                                Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 2

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: Theme.cornerRadius
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter

                                    DarkIcon {
                                        anchors.centerIn: parent
                                        name: "add"
                                        size: Theme.iconSize
                                        color: Theme.onPrimary
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: "Add Widget"
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "Browse and add widgets to your desktop"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            MouseArea {
                                id: addButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetBrowser.show()
                            }
                        }
                    }
                }
            }

            Column {
                id: instancesColumn
                width: parent.width
                spacing: Theme.spacingM
                visible: SettingsData.desktopWidgetInstances && SettingsData.desktopWidgetInstances.length > 0

                Repeater {
                    id: instanceRepeater
                    model: SettingsData.desktopWidgetInstances || []

                    DesktopWidgetInstanceCard {
                        required property var modelData
                        required property int index

                        readonly property string instanceIdRef: modelData?.id ?? ""
                        readonly property var liveInstanceData: {
                            const instances = SettingsData.desktopWidgetInstances || [];
                            if (!instanceIdRef) return modelData;
                            return instances.find(inst => inst?.id === instanceIdRef) ?? modelData;
                        }

                        width: instancesColumn.width
                        instanceData: liveInstanceData
                        isExpanded: desktopWidgetsTab.expandedStates[instanceIdRef] ?? false

                        onExpandedChanged: expanded => {
                            if (expanded === (desktopWidgetsTab.expandedStates[instanceIdRef] ?? false))
                                return;
                            var states = Object.assign({}, desktopWidgetsTab.expandedStates);
                            states[instanceIdRef] = expanded;
                            desktopWidgetsTab.expandedStates = states;
                        }

                        onDuplicateRequested: SettingsData.duplicateDesktopWidgetInstance(instanceIdRef)

                        onDeleteRequested: {
                            SettingsData.removeDesktopWidgetInstance(instanceIdRef);
                            if (typeof ToastService !== 'undefined')
                                ToastService.showInfo("Widget removed");
                        }
                    }
                }
            }

            StyledRect {
                visible: !SettingsData.desktopWidgetInstances || SettingsData.desktopWidgetInstances.length === 0
                width: parent.width
                height: emptyStateSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: emptyStateSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: "No widgets added"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: "Click \"Add Widget\" above to get started."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: gridSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: gridSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DarkIcon {
                            name: "grid_on"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Grid Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DarkToggle {
                        width: parent.width
                        text: "Enable Grid Snapping"
                        description: "Snap widgets to a grid when dragging (press G while dragging to toggle)"
                        checked: SettingsData.getDesktopWidgetGridSetting(desktopWidgetsTab.primaryScreenKey, "enabled", false)
                        onToggled: isChecked => {
                            SettingsData.setDesktopWidgetGridSetting(desktopWidgetsTab.primaryScreenKey, "enabled", isChecked)
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true

                            StyledText {
                                text: "Grid Size"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Size of grid cells in pixels"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        DarkSlider {
                            Layout.preferredWidth: 200
                            value: SettingsData.getDesktopWidgetGridSetting(desktopWidgetsTab.primaryScreenKey, "size", 40)
                            minimum: 10
                            maximum: 200
                            unit: "px"
                            showValue: true
                            onSliderValueChanged: newValue => {
                                SettingsData.setDesktopWidgetGridSetting(desktopWidgetsTab.primaryScreenKey, "size", newValue)
                            }
                        }
                    }

                    StyledText {
                        text: "Keyboard shortcuts while dragging: G = toggle grid, Z = decrease size, X = increase size"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: helpSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: helpSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DarkIcon {
                            name: "info"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Help"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: Theme.primarySelected

                            DarkIcon {
                                anchors.centerIn: parent
                                name: "drag_pan"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Move Widget"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Right-click and drag anywhere on the widget"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: Theme.primarySelected

                            DarkIcon {
                                anchors.centerIn: parent
                                name: "open_in_full"
                                size: Theme.iconSize
                                color: Theme.primary
                            }
                        }

                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Resize Widget"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Right-click and drag the bottom-right corner"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }
    }
}
