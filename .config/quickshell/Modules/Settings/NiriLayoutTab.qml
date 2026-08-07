import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: niriLayoutTab

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

            // ════════════════════════════════════════════════════════════
            // GAPS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: gapsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: gapsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "space_dashboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Gaps"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            spacing: Theme.spacingXS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Window Gaps"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Space around windows in logical pixels"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                        EHSlider {
                            width: 120; height: 24
                            value: SettingsData.niriLayoutGaps
                            minimum: 0; maximum: 64; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutGaps(finalValue) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // COLUMN SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: columnSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: columnSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "view_column"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Column Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            spacing: Theme.spacingXS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Center Focused Column"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "When to center a column when changing focus"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                        ComboBox {
                            width: 140
                            model: ["Never", "Always", "On Overflow"]
                            onCurrentIndexChanged: {
                                var v = ["never", "always", "on-overflow"]
                                SettingsData.setNiriLayoutCenterFocusedColumn(v[currentIndex])
                            }
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Always Center Single Column"
                        description: "Center a single column regardless of other settings"
                        checked: SettingsData.niriLayoutAlwaysCenterSingleColumn || false
                        onToggled: checked => { SettingsData.setNiriLayoutAlwaysCenterSingleColumn(checked) }
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            spacing: Theme.spacingXS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Default Column Display"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Default display mode for new columns"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        ComboBox {
                            width: 140
                            model: ["Normal", "Tabbed"]
                            onCurrentIndexChanged: { SettingsData.setNiriLayoutDefaultColumnDisplay(currentIndex === 1 ? "tabbed" : "normal") }
                        }
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            spacing: Theme.spacingXS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Default Column Width: " + Math.round((SettingsData.niriLayoutDefaultColumnWidth || 0.5) * 100) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Default width of new windows as proportion of output"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        EHSlider {
                            width: 120; height: 24
                            value: (SettingsData.niriLayoutDefaultColumnWidth || 0.5) * 100
                            minimum: 10; maximum: 90; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutDefaultColumnWidth(finalValue / 100) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // STRUTS (OUTER GAPS)
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: strutsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: strutsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "border_outer"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Struts (Outer Gaps)"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText {
                        text: "Struts shrink the area occupied by windows, acting as outer gaps. Use negative values for inner gaps without outer gaps."
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        StyledText { text: "Top"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; Layout.minimumWidth: 60 }
                        EHSlider {
                            Layout.fillWidth: true; height: 24
                            value: SettingsData.niriLayoutStrutTop || 0
                            minimum: -64; maximum: 128; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutStrutTop(finalValue) }
                        }
                    }
                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        StyledText { text: "Bottom"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; Layout.minimumWidth: 60 }
                        EHSlider {
                            Layout.fillWidth: true; height: 24
                            value: SettingsData.niriLayoutStrutBottom || 0
                            minimum: -64; maximum: 128; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutStrutBottom(finalValue) }
                        }
                    }
                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        StyledText { text: "Left"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; Layout.minimumWidth: 60 }
                        EHSlider {
                            Layout.fillWidth: true; height: 24
                            value: SettingsData.niriLayoutStrutLeft || 0
                            minimum: -64; maximum: 128; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutStrutLeft(finalValue) }
                        }
                    }
                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM
                        StyledText { text: "Right"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; Layout.minimumWidth: 60 }
                        EHSlider {
                            Layout.fillWidth: true; height: 24
                            value: SettingsData.niriLayoutStrutRight || 0
                            minimum: -64; maximum: 128; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutStrutRight(finalValue) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // FOCUS RING
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: focusRingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: focusRingSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "highlight"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Focus Ring"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Focus Ring"
                        description: "Draw a ring around the active window"
                        checked: SettingsData.niriLayoutFocusRingEnabled !== false
                        onToggled: checked => { SettingsData.setNiriLayoutFocusRingEnabled(checked) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        visible: SettingsData.niriLayoutFocusRingEnabled !== false

                        StyledText {
                            text: "Focus Ring Width: " + (SettingsData.niriLayoutFocusRingWidth || 4) + "px"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.niriLayoutFocusRingWidth || 4
                            minimum: 1; maximum: 20; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutFocusRingWidth(finalValue) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // WINDOW SHADOW
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: shadowSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: shadowSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "layers"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Window Shadow"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Shadow"
                        description: "Draw shadows behind windows"
                        checked: SettingsData.niriLayoutShadowEnabled || false
                        onToggled: checked => { SettingsData.setNiriLayoutShadowEnabled(checked) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.niriLayoutShadowEnabled

                        Column {
                            width: parent.width; spacing: Theme.spacingXS
                            StyledText { text: "Softness: " + (SettingsData.niriLayoutShadowSoftness || 30); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.niriLayoutShadowSoftness || 30
                                minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutShadowSoftness(finalValue) }
                            }
                        }
                        Column {
                            width: parent.width; spacing: Theme.spacingXS
                            StyledText { text: "Spread: " + (SettingsData.niriLayoutShadowSpread || 5); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.niriLayoutShadowSpread || 5
                                minimum: -20; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutShadowSpread(finalValue) }
                            }
                        }
                        Column {
                            width: parent.width; spacing: Theme.spacingXS
                            StyledText { text: "Vertical Offset: " + (SettingsData.niriLayoutShadowOffsetY || 5); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.niriLayoutShadowOffsetY || 5
                                minimum: -50; maximum: 50; unit: "px"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutShadowOffsetY(finalValue) }
                            }
                        }
                        EHToggle {
                            width: parent.width
                            text: "Draw Behind Window"
                            description: "Draw shadow behind the window rather than around it"
                            checked: SettingsData.niriLayoutShadowDrawBehindWindow || false
                            onToggled: checked => { SettingsData.setNiriLayoutShadowDrawBehindWindow(checked) }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // TAB INDICATOR
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: tabIndicatorSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: tabIndicatorSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tab"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Tab Indicator"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Tab Indicator"
                        description: "Show tab indicator for tabbed columns"
                        checked: SettingsData.niriLayoutTabIndicatorEnabled !== false
                        onToggled: checked => { SettingsData.setNiriLayoutTabIndicatorEnabled(checked) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.niriLayoutTabIndicatorEnabled !== false

                        EHToggle {
                            width: parent.width
                            text: "Hide When Single Tab"
                            description: "Hide indicator for columns with only one window"
                            checked: SettingsData.niriLayoutTabIndicatorHideWhenSingle || false
                            onToggled: checked => { SettingsData.setNiriLayoutTabIndicatorHideWhenSingle(checked) }
                        }

                        RowLayout {
                            width: parent.width; spacing: Theme.spacingM
                            Column {
                                spacing: Theme.spacingXS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                StyledText { text: "Position"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Position of the tab indicator relative to windows"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                            }
                            ComboBox {
                                width: 120
                                model: ["Left", "Top", "Bottom", "Right"]
                                onCurrentIndexChanged: {
                                    var v = ["left", "top", "bottom", "right"]
                                    SettingsData.setNiriLayoutTabIndicatorPosition(v[currentIndex])
                                }
                            }
                        }

                        Column {
                            width: parent.width; spacing: Theme.spacingXS
                            StyledText { text: "Width: " + (SettingsData.niriLayoutTabIndicatorWidth || 4) + "px"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.niriLayoutTabIndicatorWidth || 4
                                minimum: 1; maximum: 20; unit: "px"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutTabIndicatorWidth(finalValue) }
                            }
                        }
                        Column {
                            width: parent.width; spacing: Theme.spacingXS
                            StyledText { text: "Gap: " + (SettingsData.niriLayoutTabIndicatorGap || 5) + "px"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.niriLayoutTabIndicatorGap || 5
                                minimum: -10; maximum: 30; unit: "px"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderDragFinished: finalValue => { SettingsData.setNiriLayoutTabIndicatorGap(finalValue) }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // INSERT HINT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: insertHintSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: insertHintSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "add_circle"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Insert Hint"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Insert Hint"
                        description: "Show hint during interactive window moves"
                        checked: SettingsData.niriLayoutInsertHintEnabled !== false
                        onToggled: checked => { SettingsData.setNiriLayoutInsertHintEnabled(checked) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // WORKSPACE BACKGROUND
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: backgroundSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: backgroundSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "format_color_fill"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Workspace Background"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Custom Background"
                        description: "Set a custom background color for workspaces"
                        checked: SettingsData.niriLayoutBackgroundColorEnabled || false
                        onToggled: checked => { SettingsData.setNiriLayoutBackgroundColorEnabled(checked) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // EMPTY WORKSPACE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: emptyWorkspaceSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && CompositorService.isNiri

                Column {
                    id: emptyWorkspaceSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "add_to_photos"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Empty Workspace"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Empty Workspace Above First"
                        description: "Add an empty workspace at the very start"
                        checked: SettingsData.niriLayoutEmptyWorkspaceAboveFirst || false
                        onToggled: checked => { SettingsData.setNiriLayoutEmptyWorkspaceAboveFirst(checked) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // NOT AVAILABLE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: notAvailableSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: typeof CompositorService !== 'undefined' && !CompositorService.isNiri

                Column {
                    id: notAvailableSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "info"; size: Theme.iconSize; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Niri Not Active"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Niri layout settings are only available when running Niri as your window manager."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }
                }
            }
        }
    }
}
