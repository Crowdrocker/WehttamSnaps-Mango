import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: menuRoot
    objectName: "systemTrayMenu"

    WlrLayershell.namespace: "quickshell:dock:blur"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    screen: triggerScreen || parentScreen
    visible: shouldBeVisible
    color: "transparent"

    anchors {
        top: true
        left: true
    }

    implicitWidth: popupWidth
    implicitHeight: popupHeight



    property var trayItem: null
    property var anchorItem: null
    property var parentScreen: null
    property bool isAtBottom: false
    property bool isVertical: false
    property var axis: null
    property var menuHandle: null
    property string triggerSection: "follow-trigger"

    property bool shouldBeVisible: false
    property real popupWidth: Math.min(300, contentLoader.item ? contentLoader.item.implicitWidth : 200)
    property real popupHeight: {
        const screenHeight = screen?.height ?? 1080
        const availableHeight = screenHeight - 100
        const contentHeight = contentLoader.item && contentLoader.item.implicitHeight > 0 ? contentLoader.item.implicitHeight + 16 : 400
        return Math.min(availableHeight, Math.max(60, contentHeight))
    }

    implicitWidth: popupWidth
    implicitHeight: popupHeight

    ListModel {
        id: entryStack
    }

    function topEntry() {
        return entryStack.count ? entryStack.get(entryStack.count - 1).handle : null
    }

    function setTriggerPosition(x, y, width, section, screen) {
        // Always set trigger position for system tray (follows the clicked item)
        console.log(`[SystemTrayMenu] setTriggerPosition: x=${x}, y=${y}, width=${width}, section=${section}`)
        _calculatedTriggerX = x
        _calculatedTriggerY = y
        _triggerPositionSet = true
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
        updatePosition()
    }

    function showForTrayItem(item, anchor, screen, atBottom, vertical, axisObj) {
        console.log(`[SystemTrayMenu] showForTrayItem called with item=${item}, anchor=${anchor}, screen=${screen}`)
        trayItem = item
        anchorItem = anchor
        parentScreen = screen
        isAtBottom = atBottom
        isVertical = vertical
        axis = axisObj
        menuHandle = item?.menu

        // Get the global position of the anchor and calculate trigger position
        const globalPos = anchor.mapToGlobal(0, 0);
        console.log(`[SystemTrayMenu] Widget global position: x=${globalPos.x}, y=${globalPos.y}, width=${anchor.width}, height=${anchor.height}`)
        console.log(`[SystemTrayMenu] Bar config: vertical=${vertical}, atBottom=${atBottom}, edge=${axisObj?.edge}`)
        let triggerX = globalPos.x;
        let triggerY = globalPos.y;
        let section;

        if (vertical) {
            // Use SettingsData.topBarPosition to determine bar side
            const barPosition = SettingsData.topBarPosition;
            if (barPosition === "left") {
                // Left bar: position popup to the right of the bar
                triggerX = globalPos.x + anchor.width + 10;
                triggerY = globalPos.y + anchor.height / 2;
                section = "left";
            } else if (barPosition === "right") {
                // Right bar: position popup to the left of the bar
                triggerX = globalPos.x - popupWidth - 10;
                triggerY = globalPos.y + anchor.height / 2;
                section = "right";
            } else {
                // Fallback for horizontal bars (shouldn't happen in vertical mode)
                triggerX = globalPos.x + anchor.width / 2;
                triggerY = globalPos.y + anchor.height / 2;
                section = "center";
            }
        } else {
            if (atBottom) {
                // Bottom bar: position popup above
                triggerX = globalPos.x + anchor.width / 2;
                triggerY = globalPos.y - 260;
                section = "bottom";
            } else {
                // Top bar: position popup below
                triggerX = globalPos.x + anchor.width / 2;
                triggerY = globalPos.y + anchor.height + 10;
                section = "top";
            }
        }

        console.log(`[SystemTrayMenu] Calculated trigger position: x=${triggerX}, y=${triggerY}, section=${section}`)
        setTriggerPosition(triggerX, triggerY, anchor.width, section, screen);

        console.log(`[SystemTrayMenu] Calling open()`)
        open()
        console.log(`[SystemTrayMenu] shouldBeVisible=${shouldBeVisible}, visible=${visible}`)
    }

    function open() {
        console.log(`[SystemTrayMenu] open() called`)
        shouldBeVisible = true
        console.log(`[SystemTrayMenu] open() completed, shouldBeVisible=${shouldBeVisible}`)
    }

    function close() {
        shouldBeVisible = false
        entryStack.clear()
    }

    function showSubMenu(entry) {
        if (!entry || !entry.hasChildren) return;
        entryStack.append({ handle: entry });
        const h = entry.menu || entry;
        if (h && typeof h.updateLayout === "function") h.updateLayout();
        submenuHydrator.menu = h;
        submenuHydrator.open();
        Qt.callLater(() => submenuHydrator.close());
    }

    function goBack() {
        if (!entryStack.count) return;
        entryStack.remove(entryStack.count - 1);
    }

    function updatePosition() {
        if (!shouldBeVisible || !_triggerPositionSet) return;

        const screen = triggerScreen || parentScreen;
        if (!screen) return;

        // Calculate position with bounds checking
        let targetX = _calculatedTriggerX - (popupWidth / 2); // Center on trigger
        let targetY = _calculatedTriggerY;

        // Ensure popup stays within screen bounds
        const minX = 10;
        const maxX = screen.width - popupWidth - 10;
        targetX = Math.max(minX, Math.min(maxX, targetX));

        const minY = 10;
        const maxY = screen.height - popupHeight - 10;
        targetY = Math.max(minY, Math.min(maxY, targetY));

        // Apply position
        WlrLayershell.margins.left = targetX;
        WlrLayershell.margins.top = targetY;
    }

    // Track if trigger position was explicitly set
    property bool _triggerPositionSet: false
    property real _calculatedTriggerX: 0
    property real _calculatedTriggerY: 0
    property real triggerWidth: 0
    property var triggerScreen: null

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            visible = false;
        }
    }

    onPopupWidthChanged: updatePosition()
    onPopupHeightChanged: updatePosition()

    // Add keyboard handling to close menu
    Item {
        anchors.fill: parent
        focus: menuRoot.shouldBeVisible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                menuRoot.close()
                event.accepted = true
            }
        }

        Component.onCompleted: if (menuRoot.shouldBeVisible) forceActiveFocus()
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: menuRoot.shouldBeVisible
        asynchronous: false
        sourceComponent: Component {
        Rectangle {
            id: menuContainer

            width: parent ? parent.width : implicitWidth
            implicitWidth: menuColumn.implicitWidth + Theme.spacingS * 2
            implicitHeight: menuColumn.implicitHeight + Theme.spacingS * 2

            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.15)
                z: parent.z - 1
            }

            QsMenuAnchor {
                id: submenuHydrator
                anchor.window: menuRoot
            }

            QsMenuOpener {
                id: rootOpener
                menu: menuRoot.menuHandle
            }

            QsMenuOpener {
                id: subOpener
                menu: {
                    const e = menuRoot.topEntry();
                    return e ? (e.menu || e) : null;
                }
            }

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                spacing: 1

                // Header with App Info (Only on root level)
                Item {
                    visible: entryStack.count === 0
                    width: parent.width
                    height: 1
                }

                // Back Button
                Rectangle {
                    visible: entryStack.count > 0
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: backArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        EHIcon {
                            name: "arrow_back"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Back")
                            font.pixelSize: Theme.fontSizeSmall
                            color: "white"
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menuRoot.goBack()
                    }
                }

                // Menu Items
                Repeater {
                    model: entryStack.count ? (subOpener.children ? subOpener.children : (menuRoot.topEntry()?.children || [])) : rootOpener.children

                    delegate: Rectangle {
                        property var menuEntry: modelData
                        width: parent.width
                        implicitWidth: itemRow.implicitWidth + Theme.spacingS * 2
                        height: menuEntry?.isSeparator ? 1 : 28
                        radius: menuEntry?.isSeparator ? 0 : Theme.cornerRadius
                        color: menuEntry?.isSeparator ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2) :
                               itemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            id: itemRow
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS
                            visible: !menuEntry?.isSeparator

                            // Status indicator
                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0

                                Rectangle {
                                    anchors.fill: parent
                                    visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0
                                    radius: menuEntry?.buttonType === 2 ? 8 : 4
                                    border.width: 1.5
                                    border.color: menuEntry?.checkState === 2 ? Theme.primary : Theme.outline
                                    color: menuEntry?.checkState === 2 ? Theme.primary : "transparent"

                                    EHIcon {
                                        anchors.centerIn: parent
                                        name: menuEntry?.buttonType === 2 ? "circle" : "check"
                                        size: menuEntry?.buttonType === 2 ? 8 : 12
                                        color: Theme.onPrimary
                                        visible: menuEntry?.checkState === 2
                                    }
                                }
                            }

                            // Icon
                            IconImage {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.children[0].visible && menuEntry?.icon && menuEntry.icon !== ""
                                source: menuEntry?.icon ? Quickshell.iconPath(menuEntry.icon, true) : ""
                                smooth: true
                                asynchronous: true
                            }

                            StyledText {
                                id: menuText
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuEntry?.text || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: "white"
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                
                                // Calculate maximum width to force elision
                                // Parent width (delegate width) - padding - other items
                                property real availableWidth: parent.parent.width - (parent.anchors.leftMargin * 2) - (parent.spacing * 3)
                                property real siblingsWidth: (parent.children[0].visible ? 16 : 0) + (parent.children[1].visible ? 16 : 0) + (parent.children[3].visible ? 14 : 0)
                                width: Math.min(implicitWidth, availableWidth - siblingsWidth)
                            }

                            EHIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_right"
                                size: 14
                                color: Theme.surfaceTextMedium
                                visible: menuEntry?.hasChildren ?? false
                                opacity: 0.5
                            }
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            enabled: !menuEntry?.isSeparator && (menuEntry?.enabled !== false)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!menuEntry || menuEntry.isSeparator) return;
                                if (menuEntry.hasChildren) {
                                    menuRoot.showSubMenu(menuEntry);
                                } else {
                                    if (typeof menuEntry.activate === "function") {
                                        menuEntry.activate();
                                    } else if (typeof menuEntry.triggered === "function") {
                                        menuEntry.triggered();
                                    }
                                    menuRoot.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}