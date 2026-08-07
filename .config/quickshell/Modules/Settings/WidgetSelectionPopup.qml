import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets

FloatingWindow {
    id: root

    property var allWidgets: []
    property string targetSection: ""
    property bool isOpening: false
    property string searchQuery: ""
    property var filteredWidgets: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal widgetSelected(string widgetId, string targetSection)

    title: "Add Widget"
    width: 800
    height: 650
    minimumSize: Qt.size(400, 300)
    backgroundColor: "transparent"

    function updateFilteredWidgets() {
        if (!searchQuery || searchQuery.length === 0) {
            filteredWidgets = allWidgets.slice()
            return
        }

        var filtered = []
        var query = searchQuery.toLowerCase()

        for (var i = 0; i < allWidgets.length; i++) {
            var widget = allWidgets[i]
            var text = widget.text ? widget.text.toLowerCase() : ""
            var description = widget.description ? widget.description.toLowerCase() : ""
            var id = widget.id ? widget.id.toLowerCase() : ""

            if (text.indexOf(query) !== -1 ||
                description.indexOf(query) !== -1 ||
                id.indexOf(query) !== -1) {
                filtered.push(widget)
            }
        }

        filteredWidgets = filtered
        selectedIndex = -1
        keyboardNavigationActive = false
    }

    onAllWidgetsChanged: {
        updateFilteredWidgets()
    }

    function selectNext() {
        if (filteredWidgets.length === 0) return
        keyboardNavigationActive = true
        selectedIndex = Math.min(selectedIndex + 1, filteredWidgets.length - 1)
    }

    function selectPrevious() {
        if (filteredWidgets.length === 0) return
        keyboardNavigationActive = true
        selectedIndex = Math.max(selectedIndex - 1, -1)
        if (selectedIndex === -1) {
            keyboardNavigationActive = false
        }
    }

    function selectWidget() {
        if (selectedIndex >= 0 && selectedIndex < filteredWidgets.length) {
            var widget = filteredWidgets[selectedIndex]
            root.widgetSelected(widget.id, root.targetSection)
            root.close()
        }
    }

    function safeOpen() {
        if (!visible) {
            isOpening = true
            
            // Center on parent screen if possible
            var activeScreen = null;
            // Try to find screen from parent context
            if (parent && parent.Window && parent.Window.window) {
                activeScreen = parent.Window.window.screen;
            } else if (Quickshell.screens && Quickshell.screens.length > 0) {
                activeScreen = Quickshell.screens[0];
            }

            if (activeScreen) {
                root.screen = activeScreen;
                // Use .x/.y directly, fallback to 0 if undefined
                var screenX = activeScreen.x || 0;
                var screenY = activeScreen.y || 0;
                root.x = screenX + (activeScreen.width - width) / 2
                root.y = screenY + (activeScreen.height - height) / 2
            }

            show()
            requestActivate()
        }
    }

    onVisibleChanged: {
        if (visible) {
            isOpening = false
            Qt.callLater(() => {
                searchField.forceActiveFocus()
            })
        } else {
            isOpening = false
            allWidgets = []
            targetSection = ""
            searchQuery = ""
            filteredWidgets = []
            selectedIndex = -1
            keyboardNavigationActive = false
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }

    Rectangle {
        id: contentItem
        anchors.fill: parent
        color: Theme.surfaceContainer
        border.color: Theme.outlineMedium
        border.width: 1
        radius: Theme.cornerRadius
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.selectNext()
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.selectPrevious()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.keyboardNavigationActive) {
                    root.selectWidget()
                } else if (root.filteredWidgets.length > 0) {
                    var firstWidget = root.filteredWidgets[0]
                    root.widgetSelected(firstWidget.id, root.targetSection)
                    root.close()
                }
                event.accepted = true
            } else if (event.text && event.text.length > 0 && event.text.match(/[a-zA-Z0-9\\s]/)) {
                if (!searchField.activeFocus) {
                    searchField.forceActiveFocus()
                }
                searchField.insertText(event.text)
                event.accepted = true
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingL

            // Header
            Item {
                width: parent.width
                height: 40

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "widgets"
                        size: Theme.iconSizeLarge
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Add Widget"
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: filteredWidgets.length + " widget" + (filteredWidgets.length !== 1 ? "s" : "") + " available"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: closeHoverArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    
                    EHIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 20
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: closeHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            EHTextField {
                id: searchField
                objectName: "searchField"
                width: parent.width
                height: 48
                placeholderText: "Search widgets by name or description..."
                text: root.searchQuery
                focus: true
                onTextEdited: {
                    root.searchQuery = text
                    root.updateFilteredWidgets()
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0))
                        event.accepted = false
                }
            }

            // Widget grid
            EHFlickable {
                width: parent.width
                height: parent.height - y - Theme.spacingL
                clip: true
                contentHeight: widgetGrid.height

                Grid {
                    id: widgetGrid
                    width: parent.width
                    columns: 2
                    spacing: Theme.spacingM

                    Repeater {
                        model: root.filteredWidgets

                        delegate: StyledRect {
                            required property var modelData
                            required property int index

                            width: (widgetGrid.width - (widgetGrid.columns - 1) * widgetGrid.spacing) / widgetGrid.columns
                            height: contentColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: {
                                if (root.selectedIndex === index && root.keyboardNavigationActive)
                                    return Theme.primarySelected;
                                if (widgetCardArea.containsMouse)
                                    return Theme.surfaceContainerHigh;
                                return Theme.surfaceContainer;
                            }
                            border.color: root.selectedIndex === index && root.keyboardNavigationActive ? Theme.primary : Theme.outlineMedium
                            border.width: root.selectedIndex === index && root.keyboardNavigationActive ? 2 : 1

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

                            Column {
                                id: contentColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: Theme.cornerRadius
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                        border.width: 1

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: modelData.icon || "widgets"
                                            size: Theme.iconSize
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        width: parent.width - 48 - Theme.spacingM

                                        StyledText {
                                            text: modelData.text || modelData.id
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: modelData.enabled !== undefined && !modelData.enabled ? "Disabled" : "Available"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }

                                StyledText {
                                    text: modelData.description || "No description available"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    maximumLineCount: 3
                                    lineHeight: 1.3
                                }
                            }

                            MouseArea {
                                id: widgetCardArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.widgetSelected(modelData.id, root.targetSection);
                                    root.close();
                                }
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: root.filteredWidgets.length === 0
                    width: parent.width

                    EHIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "search_off"
                        size: 64
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No widgets found"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchQuery ? "Try a different search term" : "No widgets available"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
