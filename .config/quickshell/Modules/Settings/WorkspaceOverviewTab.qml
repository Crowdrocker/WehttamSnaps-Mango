import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: workspaceOverviewTab

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

            // ════════════════════════════════════════════════════════════
            // APPEARANCE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: appearanceSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: appearanceSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "space_dashboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Appearance"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Background Opacity
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Opacity of the overview window background"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(SettingsData.workspaceOverviewOpacity * 100)
                            minimum: 10; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: v => SettingsData.setWorkspaceOverviewOpacity(v / 100)
                        }
                    }

                    // Tile Size Scale
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Tile Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Size of each workspace tile (panel scrolls if tiles overflow)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(SettingsData.workspaceOverviewScale * 100)
                            minimum: 30; maximum: 150; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: v => SettingsData.setWorkspaceOverviewScale(v / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // POSITION & ORIENTATION
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: layoutSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: layoutSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "open_with"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Position & Orientation"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Screen position picker
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Screen Position"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Where on screen the overview panel appears"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                        Row {
                            spacing: Theme.spacingS

                            Repeater {
                                model: [
                                    { label: "Top",    icon: "vertical_align_top",    value: "top"    },
                                    { label: "Center", icon: "vertical_align_center", value: "center" },
                                    { label: "Bottom", icon: "vertical_align_bottom", value: "bottom" }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    property bool selected: SettingsData.workspaceOverviewPosition === modelData.value

                                    width: 90; height: 56
                                    radius: Theme.cornerRadius
                                    color: selected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                    border.color: selected ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                    border.width: selected ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        EHIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: modelData.icon
                                            size: Theme.iconSize
                                            color: selected ? Theme.primary : Theme.surfaceVariantText
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.label
                                            font.pixelSize: Theme.fontSizeXSmall || Math.max(10, Theme.fontSizeSmall - 2)
                                            color: selected ? Theme.primary : Theme.surfaceVariantText
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: SettingsData.setWorkspaceOverviewPosition(modelData.value)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // GRID LAYOUT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: gridSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: gridSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "grid_view"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Grid Layout"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text: "Showing " + SettingsData.workspaceOverviewColumns + " × " + SettingsData.workspaceOverviewRows + " = " + (SettingsData.workspaceOverviewColumns * SettingsData.workspaceOverviewRows) + " workspaces"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; font.weight: Font.Medium
                        width: parent.width
                    }

                    // Columns
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Columns"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Number of workspace columns in the grid"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.workspaceOverviewColumns
                            minimum: 1; maximum: 10; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setWorkspaceOverviewColumns(Math.round(v))
                        }
                    }

                    // Rows
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Rows"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Number of workspace rows in the grid"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.workspaceOverviewRows
                            minimum: 1; maximum: 5; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setWorkspaceOverviewRows(Math.round(v))
                        }
                    }

                    // Spacing
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Tile Spacing"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Gap between workspace tiles in the grid"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.workspaceOverviewSpacing
                            minimum: 0; maximum: 32; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => SettingsData.setWorkspaceOverviewSpacing(v)
                        }
                    }
                }
            }
        }
    }
}
