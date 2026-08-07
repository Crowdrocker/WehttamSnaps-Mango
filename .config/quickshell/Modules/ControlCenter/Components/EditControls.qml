import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Widgets
import qs.Modals.Common

Row {
    id: root

    property var availableWidgets: []
    property string searchQuery: ""
    property var filteredWidgets: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    signal addWidget(string widgetId)
    signal resetToDefault()
    signal clearAll()

    height: 48
    spacing: Theme.spacingS

    function updateFilteredWidgets() {
        if (!root.searchQuery || root.searchQuery.length === 0) {
            filteredWidgets = root.availableWidgets.slice();
            return;
        }

        var filtered = [];
        var query = root.searchQuery.toLowerCase();

        for (var i = 0; i < root.availableWidgets.length; i++) {
            var widget = root.availableWidgets[i];
            var name = widget.text ? widget.text.toLowerCase() : "";
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
        root.addWidget(widget.id);
        addWidgetModal.hide()
    }

    // Note: Modal hiding is now handled in the onClicked handler after adding the widget
    // to ensure the widget is added before the modal is hidden

    Item {
        FloatingWindow {
            id: addWidgetModal
            objectName: "controlCenterWidgetBrowser"
            implicitWidth: 800
            implicitHeight: 650
            title: "Add Control Center Widgets"
            backgroundColor: Theme.surfaceContainer

        function show() {
                root.updateFilteredWidgets()
                visible = true
                requestActivate()
            }

            function hide() {
                visible = false
            }

            StyledRect {
                anchors.fill: parent
                color: Theme.surfaceContainer
                radius: Theme.cornerRadius

                Column {
                    anchors.fill: parent
                    spacing: 0

                    // Title bar
                    StyledRect {
                        width: parent.width
                        height: 48
                        color: Theme.surfaceContainerHigh

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                // Check if it's the primary button
                                if (mouse.button === Qt.LeftButton) {
                                    addWidgetModal.startSystemMove()
                                }
                            }
                        }
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingL
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingM

                            EHIcon {
                               name: "widgets"
                               size: Theme.iconSize
                               color: Theme.primary
                               anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: addWidgetModal.title
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            EHActionButton {
                                iconName: "close"
                                iconSize: Theme.iconSize
                                onClicked: addWidgetModal.hide()
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Content
                    Item {
                        width: parent.width
                        height: parent.height - 48

                        FocusScope {
                            id: widgetKeyHandler
                            anchors.fill: parent
                            focus: true

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    addWidgetModal.hide()
                                    event.accepted = true
                                    return
                                case Qt.Key_Down:
                                    root.selectNext()
                                    event.accepted = true
                                    return
                                case Qt.Key_Up:
                                    root.selectPrevious()
                                    event.accepted = true
                                    return
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    root.selectWidget()
                                    event.accepted = true
                                    return
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
                                            text: "Add Control Center Widget"
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
                                    root.searchQuery = text
                                    root.updateFilteredWidgets()
                                }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        addWidgetModal.hide()
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
                                                    return Theme.primarySelected
                                                if (widgetCardArea.containsMouse)
                                                    return Theme.surfaceContainerHigh
                                                return Theme.surfaceContainer
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
                                                            text: modelData.text || modelData.id
                                                            font.pixelSize: Theme.fontSizeMedium
                                                            font.weight: Font.Medium
                                                            color: Theme.surfaceText
                                                            elide: Text.ElideRight
                                                            width: parent.width
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
                                                }
                                            }

                                            MouseArea {
                                                id: widgetCardArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    console.log("Widget clicked:", JSON.stringify(modelData))
                                                    if (!modelData || !modelData.id) {
                                                        console.error("Invalid widget data:", JSON.stringify(modelData))
                                                        return
                                                    }
                                                    // Add widget and then hide the modal
                                                    // This order is important to avoid crashes
                                                    root.addWidget(modelData.id)
                                                    addWidgetModal.hide()
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
        }
    }

    // Compact dock-style buttons (reverted to original size)
    Item {
        Row {
        width: parent.width
        spacing: Theme.spacingS

        Rectangle {
            width: (parent.width - Theme.spacingS * 2) / 3
            height: 48
            radius: Theme.cornerRadius
            color: addArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
            border.color: Theme.primary
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 8

                EHIcon {
                    name: "add"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Add"
                    font.pixelSize: 13
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.searchQuery = ""
                    root.updateFilteredWidgets()
                    addWidgetModal.show()
                }
            }
        }

        Rectangle {
            width: (parent.width - Theme.spacingS * 2) / 3
            height: 48
            radius: Theme.cornerRadius
            color: defaultsArea.containsMouse ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.2) : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
            border.color: Theme.warning
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 6

                EHIcon {
                    name: "settings_backup_restore"
                    size: 14
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Defaults"
                    font.pixelSize: 13
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: defaultsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefault()
            }
        }

        Rectangle {
            width: (parent.width - Theme.spacingS * 2) / 3
            height: 48
            radius: Theme.cornerRadius
            color: resetArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
            border.color: Theme.error
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 6

                EHIcon {
                    name: "clear_all"
                    size: 14
                    color: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Reset"
                    font.pixelSize: 13
                    color: Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
            }
        }
    }
}
}
