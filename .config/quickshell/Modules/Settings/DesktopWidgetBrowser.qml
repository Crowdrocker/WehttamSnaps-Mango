import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Common

DarkModal {
    id: root

    property string searchQuery: ""
    property var filteredWidgets: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property var parentModal: null

    signal widgetAdded(string widgetType)

    function updateFilteredWidgets() {
        const allWidgets = typeof DesktopWidgetRegistry !== 'undefined' ? (DesktopWidgetRegistry.registeredWidgetsList || []) : [];
        if (!searchQuery || searchQuery.length === 0) {
            filteredWidgets = allWidgets.slice();
            return;
        }

        var filtered = [];
        var query = searchQuery.toLowerCase();

        for (var i = 0; i < allWidgets.length; i++) {
            var widget = allWidgets[i];
            var name = widget.name ? widget.name.toLowerCase() : "";
            var description = widget.description ? widget.description.toLowerCase() : "";
            var id = widget.id ? widget.id.toLowerCase() : "";

            if (name.indexOf(query) !== -1 || description.indexOf(query) !== -1 || id.indexOf(query) !== -1)
                filtered.push(widget);
        }

        filteredWidgets = filtered;
        selectedIndex = -1;
        keyboardNavigationActive = false;
    }

    function selectNext() {
        if (filteredWidgets.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, filteredWidgets.length - 1);
    }

    function selectPrevious() {
        if (filteredWidgets.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(selectedIndex - 1, -1);
        if (selectedIndex === -1)
            keyboardNavigationActive = false;
    }

    function selectWidget() {
        if (selectedIndex < 0 || selectedIndex >= filteredWidgets.length)
            return;
        var widget = filteredWidgets[selectedIndex];
        addWidget(widget);
    }

    function addWidget(widget) {
        const widgetType = widget.id;
        const defaultConfig = typeof DesktopWidgetRegistry !== 'undefined' ? DesktopWidgetRegistry.getDefaultConfig(widgetType) : {
            transparency: 0.9,
            displayPreferences: ["all"]
        };
        const name = widget.name || widgetType;
        SettingsData.createDesktopWidgetInstance(widgetType, name, defaultConfig);
        root.widgetAdded(widgetType);
        root.hide();
    }

    Connections {
        target: typeof DesktopWidgetRegistry !== 'undefined' ? DesktopWidgetRegistry : null
        enabled: typeof DesktopWidgetRegistry !== 'undefined'
        function onRegistryChanged() {
            if (root.visible)
                root.updateFilteredWidgets();
        }
    }

    function show() {
        updateFilteredWidgets();
        open();
        Qt.callLater(() => {
            if (contentLoader.item) {
                function findSearchField(item) {
                    if (!item) return null;
                    if (item.objectName === "searchField" || (item.placeholderText && item.placeholderText.includes("Search"))) {
                        return item;
                    }
                    for (let i = 0; i < item.children.length; i++) {
                        const found = findSearchField(item.children[i]);
                        if (found) return found;
                    }
                    return null;
                }
                const searchField = findSearchField(contentLoader.item);
                if (searchField && searchField.forceActiveFocus) {
                    searchField.forceActiveFocus();
                }
            }
        });
    }

    function hide() {
        close();
    }

    objectName: "desktopWidgetBrowser"
    width: 800
    height: 650
    positioning: "center"
    backgroundColor: Theme.surfaceContainer
    closeOnEscapeKey: true
    closeOnBackgroundClick: true

    content: Component {
        Item {
            FocusScope {
                id: widgetKeyHandler
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.hide();
                        event.accepted = true;
                        return;
                    case Qt.Key_Down:
                        root.selectNext();
                        event.accepted = true;
                        return;
                    case Qt.Key_Up:
                        root.selectPrevious();
                        event.accepted = true;
                        return;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.selectWidget();
                        event.accepted = true;
                        return;
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                // Header
                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
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
                                text: "Add Desktop Widget"
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

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                // Search field
                EHTextField {
                    id: searchField
                    objectName: "searchField"
                    width: parent.width
                    height: 48
                    placeholderText: "Search widgets by name or description..."
                    text: root.searchQuery
                    focus: true
                    onTextEdited: {
                        root.searchQuery = text;
                        root.updateFilteredWidgets();
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.hide();
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0))
                            event.accepted = false;
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
                        columns: Math.floor((width + Theme.spacingM) / (280 + Theme.spacingM))
                        spacing: Theme.spacingM

                        Repeater {
                            model: root.filteredWidgets

                            StyledRect {
                                required property var modelData
                                required property int index

                                width: (widgetGrid.width - (widgetGrid.columns - 1) * widgetGrid.spacing) / widgetGrid.columns
                                height: 140
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
                                    anchors.fill: parent
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
                                            spacing: Theme.spacingXS
                                            width: parent.width - 48 - Theme.spacingM

                                            StyledText {
                                                text: modelData.name || modelData.id
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            StyledText {
                                                text: modelData.type === "builtin" ? "Built-in" : "Plugin"
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
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: widgetCardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.addWidget(modelData);
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
}
