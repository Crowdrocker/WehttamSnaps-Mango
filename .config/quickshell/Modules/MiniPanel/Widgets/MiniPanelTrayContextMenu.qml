import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

/**
 * TrayContextMenu - A reusable context menu component for system tray items
 *
 * This component provides proper separation of concerns by extracting menu logic
 * from the SystemTrayBar widget into its own reusable component.
 */
Item {
    id: root

    /**
     * Open a context menu for a tray item
     * @param {var} trayItem - The system tray item
     * @param {Item} anchorItem - The visual element to anchor to
     * @param {Screen} screen - The screen to display on
     * @param {string} barPosition - Position of the bar ("top", "bottom", "left", "right")
     * @param {bool} isVertical - Whether the bar is vertical
     * @param {real} barThickness - Thickness of the bar
     */
    function openForItem(trayItem, anchorItem, screen, barPosition, isVertical, barThickness) {
        // Close any existing menu
        if (currentTrayMenu) {
            currentTrayMenu.showMenu = false
            currentTrayMenu.destroy()
            currentTrayMenu = null
        }

        // Create new menu instance
        currentTrayMenu = trayMenuComponent.createObject(null)
        if (currentTrayMenu) {
            currentTrayMenu.showForTrayItem(trayItem, anchorItem, screen, barPosition, isVertical, barThickness)
        }
    }

    // Current menu instance
    property var currentTrayMenu: null

    Component {
        id: trayMenuComponent

        Item {
            id: menuRoot
            property var trayItem: null
            property var anchorItem: null
            property var parentScreen: null
            property string barPosition: "top"
            property bool isVertical: false
            property real barThickness: 30
            property real popupDistance: Theme.popupDistance !== undefined ? Theme.popupDistance : 8
            property bool showMenu: false
            property var menuHandle: null

            ListModel {
                id: entryStack
            }

            function topEntry() {
                return entryStack.count ? entryStack.get(entryStack.count - 1).handle : null
            }

            function showForTrayItem(item, anchor, screen, barPos, vertical, barThick) {
                trayItem = item
                anchorItem = anchor
                parentScreen = screen
                barPosition = barPos || "top"
                isVertical = vertical || false
                barThickness = barThick || 30
                menuHandle = item?.menu

                if (parentScreen) {
                    for (var i = 0; i < Quickshell.screens.length; i++) {
                        const s = Quickshell.screens[i]
                        if (s === parentScreen) {
                            menuWindow.screen = s
                            break
                        }
                    }
                }
                showMenu = true
            }

            function close() {
                showMenu = false
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

            width: 0
            height: 0

            PanelWindow {
                id: menuWindow
                visible: menuRoot.showMenu && (menuRoot.trayItem?.hasMenu ?? false)
                WlrLayershell.namespace: "quickshell:dock:blur"
                WlrLayershell.layer: WlrLayershell.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

                onVisibleChanged: {
                    if (visible) {
                        updatePosition()
                    }
                }

                function updatePosition() {
                    if (!menuRoot.anchorItem || !menuRoot.trayItem) {
                        anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                        return
                    }

                    const screenX = screen.x || 0
                    const screenY = screen.y || 0
                    const scale = (Appearance.combinedScale || 1)
                    const scaledBarThickness = menuRoot.barThickness

                    // For vertical bars (left/right), position relative to bar edge, not icon position
                    // For horizontal bars (top/bottom), center on the icon
                    let targetX, targetY

                    if (menuRoot.barPosition === "top") {
                        // Get icon's horizontal center
                        const globalPos = menuRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - screenX + menuRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = screenY + scaledBarThickness + menuRoot.popupDistance + (15 * scale)
                    } else if (menuRoot.barPosition === "bottom") {
                        // Get icon's horizontal center
                        const globalPos = menuRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterX = globalPos.x - screenX + menuRoot.anchorItem.width / 2
                        targetX = iconCenterX
                        targetY = screenY + screen.height - scaledBarThickness - menuRoot.popupDistance + (-15 * scale)
                    } else if (menuRoot.barPosition === "left") {
                        // Get icon's vertical center
                        const globalPos = menuRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - screenY + menuRoot.anchorItem.height / 2
                        targetX = screenX + scaledBarThickness + menuRoot.popupDistance + (15 * scale)
                        targetY = iconCenterY
                    } else if (menuRoot.barPosition === "right") {
                        // Get icon's vertical center
                        const globalPos = menuRoot.anchorItem.mapToGlobal(0, 0)
                        const iconCenterY = globalPos.y - screenY + menuRoot.anchorItem.height / 2
                        targetX = screenX + screen.width - scaledBarThickness - menuRoot.popupDistance + (-15 * scale)
                        targetY = iconCenterY
                    } else {
                        // Fallback
                        targetX = screenX + screen.width / 2
                        targetY = screenY + screen.height / 2
                    }

                    anchorPos = Qt.point(targetX, targetY)
                }

                Rectangle {
                    id: menuContainer
                    width: Math.min(500, Math.max(250, menuColumn.implicitWidth + Theme.spacingS * 2))
                    height: Math.max(40, menuColumn.implicitHeight + Theme.spacingS * 2)

                    onWidthChanged: menuWindow.updatePosition()
                    onHeightChanged: menuWindow.updatePosition()

                    x: {
                        if (menuRoot.barPosition === "right") {
                            // Right bar: menu appears to the left of the anchor
                            return Math.max(10, menuWindow.anchorPos.x - width)
                        }
                        if (menuRoot.barPosition === "left") {
                            // Left bar: menu appears to the right of the anchor
                            return Math.min(menuWindow.screen.width - width - 10, menuWindow.anchorPos.x)
                        }

                        // Top/bottom bars: center on the anchor
                        const left = 10
                        const right = menuWindow.screen.width - width - 10
                        const want = menuWindow.anchorPos.x - width / 2
                        return Math.max(left, Math.min(right, want))
                    }

                    y: {
                        if (menuRoot.barPosition === "top") {
                            // Top bar: menu appears below the anchor
                            return Math.max(10, menuWindow.anchorPos.y)
                        }
                        if (menuRoot.barPosition === "bottom") {
                            // Bottom bar: menu appears above the anchor
                            return Math.min(menuWindow.screen.height - height - 10, menuWindow.anchorPos.y - height)
                        }

                        // Left/right bars: center on the anchor
                        const top = 10
                        const bottom = menuWindow.screen.height - height - 10
                        const want = menuWindow.anchorPos.y - height / 2
                        return Math.max(top, Math.min(bottom, want))
                    }

                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
                    radius: Theme.widgetRadius
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    opacity: menuRoot.showMenu ? 1 : 0
                    scale: menuRoot.showMenu ? 1 : 0.85

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.leftMargin: 2
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -4
                        radius: parent.radius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                        z: parent.z - 1
                    }

                    QsMenuAnchor {
                        id: submenuHydrator
                        anchor.window: menuWindow
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
                        width: parent.width - Theme.spacingS * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingS
                        spacing: 1

                        Rectangle {
                            visible: entryStack.count > 0
                            width: parent.width
                            height: 28
                            radius: Theme.widgetRadius
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
                                    text: I18n.tr("Back")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
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

                        Rectangle {
                            visible: entryStack.count > 0
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        }

                        Repeater {
                            model: entryStack.count ? (subOpener.children ? subOpener.children : (menuRoot.topEntry()?.children || [])) : rootOpener.children

                            Rectangle {
                                property var menuEntry: modelData
                                width: menuColumn.width
                                height: menuEntry?.isSeparator ? 1 : 28
                                radius: menuEntry?.isSeparator ? 0 : Theme.widgetRadius
                                color: {
                                    if (menuEntry?.isSeparator) {
                                        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    }
                                    return itemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
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
                                            const closeTimer = menuCloseTimerComponent.createObject(menuRoot, {
                                                menuRoot: menuRoot
                                            })
                                            if (!closeTimer) {
                                                if (typeof menuRoot.close === 'function') {
                                                    Qt.callLater(() => menuRoot.close())
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    visible: !menuEntry?.isSeparator

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0
                                        radius: menuEntry?.buttonType === 2 ? 8 : 2
                                        border.width: 1
                                        border.color: Theme.outline
                                        color: "transparent"

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width - 6
                                            height: parent.height - 6
                                            radius: parent.radius - 3
                                            color: Theme.primary
                                            visible: menuEntry?.checkState === 2
                                        }

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: 10
                                            color: Theme.primaryText
                                            visible: menuEntry?.buttonType === 1 && menuEntry?.checkState === 2
                                        }
                                    }

                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: menuEntry?.icon && menuEntry.icon !== ""

                                        Image {
                                            anchors.fill: parent
                                            source: menuEntry?.icon || ""
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }

                                    StyledText {
                                        text: menuEntry?.text || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: (menuEntry?.enabled !== false) ? Theme.surfaceText : Theme.surfaceTextMedium
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(150, parent.width - 64)
                                        wrapMode: Text.NoWrap
                                    }

                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: "chevron_right"
                                            size: 14
                                            color: Theme.surfaceText
                                            visible: menuEntry?.hasChildren ?? false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: menuRoot.close()
                }
            }

            Component {
                id: menuCloseTimerComponent
                Timer {
                    property var menuRoot: null
                    interval: 80
                    repeat: false
                    running: true
                    onTriggered: {
                        if (menuRoot && typeof menuRoot.close === 'function') {
                            menuRoot.close()
                        }
                        destroy()
                    }
                    Component.onDestruction: {
                        if (running) {
                            stop()
                        }
                    }
                }
            }
        }
    }
}