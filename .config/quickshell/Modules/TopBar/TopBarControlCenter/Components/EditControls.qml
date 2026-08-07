import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    height: 40
    spacing: Theme.spacingS

    function updateFilteredWidgets() {
        if (!root.searchQuery || root.searchQuery.length === 0) {
            filteredWidgets = root.availableWidgets.slice()
            return
        }
        const q = root.searchQuery.toLowerCase()
        filteredWidgets = root.availableWidgets.filter(w =>
            (w.text || "").toLowerCase().includes(q) ||
            (w.description || "").toLowerCase().includes(q) ||
            (w.id || "").toLowerCase().includes(q)
        )
        selectedIndex = -1
        keyboardNavigationActive = false
    }

    function selectNext() {
        if (!filteredWidgets.length) return
        keyboardNavigationActive = true
        selectedIndex = Math.min(selectedIndex + 1, filteredWidgets.length - 1)
    }

    function selectPrevious() {
        if (!filteredWidgets.length) return
        keyboardNavigationActive = true
        selectedIndex = Math.max(selectedIndex - 1, -1)
        if (selectedIndex === -1) keyboardNavigationActive = false
    }

    function selectWidget() {
        if (selectedIndex < 0 || selectedIndex >= filteredWidgets.length) return
        root.addWidget(filteredWidgets[selectedIndex].id)
    }

    onAddWidget: addWidgetModal.hide()

    // ── Widget browser modal ──────────────────────────────────────────────
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

        function hide() { visible = false }

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
                        onPressed: { if (mouse.button === Qt.LeftButton) addWidgetModal.startSystemMove() }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingL
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingM

                        EHIcon { name: "widgets"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }

                        StyledText {
                            text: addWidgetModal.title
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { Layout.fillWidth: true }

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
                        anchors.fill: parent
                        focus: true

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:   addWidgetModal.hide(); event.accepted = true; return
                            case Qt.Key_Down:     root.selectNext(); event.accepted = true; return
                            case Qt.Key_Up:       root.selectPrevious(); event.accepted = true; return
                            case Qt.Key_Return:
                            case Qt.Key_Enter:    root.selectWidget(); event.accepted = true; return
                            }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingL

                        // Header
                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            EHIcon { name: "widgets"; size: Theme.iconSizeLarge; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }

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
                        }

                        EHTextField {
                            id: searchField
                            width: parent.width
                            height: 44
                            placeholderText: "Search widgets…"
                            text: root.searchQuery
                            focus: true
                            onTextEdited: { root.searchQuery = text; root.updateFilteredWidgets() }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) { addWidgetModal.hide(); event.accepted = true }
                            }
                        }

                        EHFlickable {
                            width: parent.width
                            height: parent.height - y - Theme.spacingL
                            clip: true
                            contentHeight: browseGrid.height

                            Grid {
                                id: browseGrid
                                width: parent.width
                                columns: Math.max(1, Math.floor((width + Theme.spacingM) / (280 + Theme.spacingM)))
                                spacing: Theme.spacingM

                                Repeater {
                                    model: root.filteredWidgets

                                    StyledRect {
                                        required property var modelData
                                        required property int index

                                        width: (browseGrid.width - (browseGrid.columns - 1) * browseGrid.spacing) / browseGrid.columns
                                        height: 130
                                        radius: Theme.cornerRadius
                                        color: {
                                            if (root.selectedIndex === index && root.keyboardNavigationActive) return Theme.primarySelected
                                            if (cardArea.containsMouse) return Theme.surfaceContainerHigh
                                            return Theme.surfaceContainer
                                        }
                                        border.color: root.selectedIndex === index && root.keyboardNavigationActive ? Theme.primary : Theme.outlineMedium
                                        border.width: root.selectedIndex === index && root.keyboardNavigationActive ? 2 : 1

                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            Rectangle {
                                                width: 44; height: 44
                                                radius: Theme.cornerRadius
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                                border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter

                                                EHIcon { anchors.centerIn: parent; name: modelData.icon || "widgets"; size: Theme.iconSize; color: Theme.primary }
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Theme.spacingXS
                                                width: parent.width - 44 - Theme.spacingM

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

                                        MouseArea {
                                            id: cardArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.addWidget(modelData.id)
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM
                                visible: root.filteredWidgets.length === 0

                                EHIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "search_off"; size: 56; color: Theme.surfaceVariantText }
                                StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "No widgets found"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: root.searchQuery ? "Try a different search term" : "No widgets available"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Edit toolbar ──────────────────────────────────────────────────────
    Row {
        width: parent.width
        spacing: Theme.spacingS

        // Reusable edit action button
        component EditBtn : Rectangle {
            property string btnIcon: ""
            property string btnLabel: ""
            property color btnColor: Theme.primary
            signal btnClicked()

            width: (parent.width - Theme.spacingS * 2) / 3
            height: 40
            radius: Theme.cornerRadius
            color: btnArea.containsMouse
                   ? Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.22)
                   : Qt.rgba(btnColor.r, btnColor.g, btnColor.b, 0.10)
            border.color: Qt.rgba(btnColor.r, btnColor.g, btnColor.b, btnArea.containsMouse ? 0.6 : 0.3)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                EHIcon { name: parent.parent.btnIcon; size: 14; color: parent.parent.btnColor; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: parent.parent.btnLabel; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: parent.parent.btnColor; anchors.verticalCenter: parent.verticalCenter }
            }

            MouseArea { id: btnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.btnClicked() }

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
        }

        EditBtn {
            btnIcon: "add"
            btnLabel: "Add"
            btnColor: Theme.primary
            onBtnClicked: { root.searchQuery = ""; root.updateFilteredWidgets(); addWidgetModal.show() }
        }

        EditBtn {
            btnIcon: "settings_backup_restore"
            btnLabel: "Defaults"
            btnColor: Theme.warning
            onBtnClicked: root.resetToDefault()
        }

        EditBtn {
            btnIcon: "clear_all"
            btnLabel: "Clear"
            btnColor: Theme.error
            onBtnClicked: root.clearAll()
        }
    }
}
