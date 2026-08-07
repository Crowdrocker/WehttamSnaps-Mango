import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: root

    property var    categories:       []
    property string selectedCategory: "All"
    property bool   compact:          false

    signal categorySelected(string category)

    readonly property int maxCompactItems:      8
    readonly property int itemHeight:           36
    readonly property color selectedBorderColor:   "transparent"
    readonly property color unselectedBorderColor: Qt.rgba(
        Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3
    )

    // Pre-slice once so Repeater delegates don't recompute on every paint
    readonly property var _compactSlice: categories
        ? categories.slice(0, Math.min(categories.length || 0, maxCompactItems))
        : []
    readonly property var _row1Slice:    categories
        ? categories.slice(0, Math.min(4, categories.length || 0))
        : []
    readonly property var _row2Slice:    (categories && categories.length > 4)
        ? categories.slice(4)
        : []

    function handleCategoryClick(category) {
        selectedCategory = category
        categorySelected(category)
    }

    function getButtonWidth(itemCount, containerWidth) {
        return itemCount > 0
            ? (containerWidth - (itemCount - 1) * Theme.spacingS) / itemCount
            : 0
    }

    height: compact ? itemHeight : (itemHeight * 2 + Theme.spacingS)

    // ── Compact (single row) ─────────────────────────────────────────────────
    Row {
        visible: compact
        width:   parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root._compactSlice

            Rectangle {
                readonly property int _count: root._compactSlice.length
                height: root.itemHeight
                width:  root.getButtonWidth(_count, parent.width)
                radius: Theme.cornerRadius
                color:  root.selectedCategory === modelData ? Theme.primary : "transparent"
                border.color: root.selectedCategory === modelData
                    ? root.selectedBorderColor
                    : root.unselectedBorderColor

                // No Behavior here — category selection is an instant switch,
                // animation here costs a binding evaluation on every frame.

                StyledText {
                    anchors.centerIn: parent
                    text:       modelData
                    color:      root.selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight:    root.selectedCategory === modelData ? Font.Medium : Font.Normal
                    elide:      Text.ElideRight
                }

                MouseArea {
                    anchors.fill:  parent
                    hoverEnabled:  true
                    cursorShape:   Qt.PointingHandCursor
                    onClicked:     root.handleCategoryClick(modelData)
                }
            }
        }
    }

    // ── Two-row expanded layout ───────────────────────────────────────────────
    Column {
        visible: !compact
        width:   parent.width
        spacing: Theme.spacingS

        Row {
            width:   parent.width
            spacing: Theme.spacingS

            Repeater {
                model: root._row1Slice

                Rectangle {
                    readonly property int _count: root._row1Slice.length
                    height: root.itemHeight
                    width:  root.getButtonWidth(_count, parent.width)
                    radius: Theme.cornerRadius
                    color:  root.selectedCategory === modelData ? Theme.primary : "transparent"
                    border.color: root.selectedCategory === modelData
                        ? root.selectedBorderColor
                        : root.unselectedBorderColor

                    StyledText {
                        anchors.centerIn: parent
                        text:       modelData
                        color:      root.selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    root.selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide:      Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill:  parent
                        hoverEnabled:  true
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     root.handleCategoryClick(modelData)
                    }
                }
            }
        }

        Row {
            width:   parent.width
            spacing: Theme.spacingS
            visible: root._row2Slice.length > 0

            Repeater {
                model: root._row2Slice

                Rectangle {
                    readonly property int _count: root._row2Slice.length
                    height: root.itemHeight
                    width:  root.getButtonWidth(_count, parent.width)
                    radius: Theme.cornerRadius
                    color:  root.selectedCategory === modelData ? Theme.primary : "transparent"
                    border.color: root.selectedCategory === modelData
                        ? root.selectedBorderColor
                        : root.unselectedBorderColor

                    StyledText {
                        anchors.centerIn: parent
                        text:       modelData
                        color:      root.selectedCategory === modelData ? Theme.surface : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    root.selectedCategory === modelData ? Font.Medium : Font.Normal
                        elide:      Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill:  parent
                        hoverEnabled:  true
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     root.handleCategoryClick(modelData)
                    }
                }
            }
        }
    }
}
