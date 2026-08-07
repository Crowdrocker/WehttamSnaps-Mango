import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string section: "left"
    property var parentScreen
    property var hoveredItem: null
    property var topBar: null
    property real widgetHeight: 30
    property var contextMenu: null
    property bool isVertical: false
    property bool isAtBottom: true
    property real scaleFactor: 1
    property real iconSize: 24
    property real iconSpacing: 8
    property real padding: 0
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"

    property bool pillEnabled: true
    readonly property real uiScale: (SettingsData.dockScale || 1) * (Appearance.combinedScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    // ── Icon theme live-reload ────────────────────────────────────────────────
    property int iconCacheBuster: 0
    Connections {
        target: DesktopEntries
        function onScanStateChanged() { root.iconCacheBuster++ }
    }

    property Item windowRoot: (Window.window ? Window.window.contentItem : null)
    readonly property var sortedToplevels: {
        if (SettingsData.runningAppsCurrentWorkspace) {
            return CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, parentScreen.name);
        }
        return CompositorService.sortedToplevels;
    }
    readonly property int windowCount: sortedToplevels.length
    readonly property int calculatedWidth: {
        if (windowCount === 0) {
            return 0;
        }
        if (SettingsData.runningAppsCompactMode) {
            return windowCount * iconSize + (windowCount - 1) * iconSpacing;
        } else {
            return windowCount * (iconSize + iconSpacing + 120)
                    + (windowCount - 1) * iconSpacing;
        }
    }
    readonly property int calculatedHeight: {
        if (windowCount === 0) {
            return 0;
        }
        if (SettingsData.runningAppsCompactMode) {
            return windowCount * iconSize + (windowCount - 1) * iconSpacing;
        } else {
            return windowCount * (iconSize + iconSpacing + 120)
                    + (windowCount - 1) * iconSpacing;
        }
    }

    width: windowCount > 0 ? (pillEnabled ? (isBarVertical ? widgetHeight : calculatedWidth) + root.spx(16) : (isBarVertical ? widgetHeight : calculatedWidth)) : 0
    height: windowCount > 0 ? (pillEnabled ? (isBarVertical ? calculatedHeight : widgetHeight) + root.spx(16) : (isBarVertical ? calculatedHeight : widgetHeight)) : 0
    visible: windowCount > 0
    clip: false

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        visible: root.pillEnabled
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.widgetTransparency)
        radius: Theme.widgetRadius
        clip: true
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: false  // Disable hover to prevent conflicts with main taskbar mouse area
        acceptedButtons: Qt.NoButton
        
        property real scrollAccumulator: 0
        property real touchpadThreshold: 500
        
        onWheel: (wheel) => {
            const deltaY = wheel.angleDelta.y;
            const isMouseWheel = Math.abs(deltaY) >= 120
                && (Math.abs(deltaY) % 120) === 0;
            
            const windows = root.sortedToplevels;
            if (windows.length < 2) {
                return;
            }
            
            if (isMouseWheel) {
                let currentIndex = -1;
                for (let i = 0; i < windows.length; i++) {
                    if (windows[i].activated) {
                        currentIndex = i;
                        break;
                    }
                }

                let nextIndex;
                if (deltaY < 0) {
                    if (currentIndex === -1) {
                        nextIndex = 0;
                    } else {
                        nextIndex = (currentIndex + 1) % windows.length;
                    }
                } else {
                    if (currentIndex === -1) {
                        nextIndex = windows.length - 1;
                    } else {
                        nextIndex = (currentIndex - 1 + windows.length) % windows.length;
                    }
                }

                const nextWindow = windows[nextIndex];
                if (nextWindow) {
                    nextWindow.activate();
                }
            } 
            
            else {
                scrollAccumulator += deltaY;
                
                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                    let currentIndex = -1;
                    for (let i = 0; i < windows.length; i++) {
                        if (windows[i].activated) {
                            currentIndex = i;
                            break;
                        }
                    }

                    let nextIndex;
                    if (scrollAccumulator < 0) {
                        if (currentIndex === -1) {
                            nextIndex = 0;
                        } else {
                            nextIndex = (currentIndex + 1) % windows.length;
                        }
                    } else {
                        if (currentIndex === -1) {
                            nextIndex = windows.length - 1;
                        } else {
                            nextIndex = (currentIndex - 1 + windows.length) % windows.length;
                        }
                    }

                    const nextWindow = windows[nextIndex];
                    if (nextWindow) {
                        nextWindow.activate();
                    }
                    
                    scrollAccumulator = 0;
                }
            }
            
            wheel.accepted = true;
        }
    }

    Row {
        id: windowRow

        anchors.centerIn: parent
        spacing: root.iconSpacing

        Repeater {
            id: windowRepeater

            model: sortedToplevels

            delegate: Item {
                id: delegateItem

                property bool isFocused: modelData.activated
                property bool isMinimized: modelData.minimized || false
                property string appId: modelData.appId || ""
                property string windowTitle: modelData.title || "(Unnamed)"
                property var toplevelObject: modelData
                property string tooltipText: {
                    let appName = "Unknown";
                    if (appId) {
                        const desktopEntry = DesktopEntries.heuristicLookup(appId);
                        appName = desktopEntry
                                && desktopEntry.name ? desktopEntry.name : appId;
                    }
                    return appName + (windowTitle ? " • " + windowTitle : "")
                }

                width: SettingsData.runningAppsCompactMode ? root.iconSize : (root.iconSize + Theme.spacingXS + 120)
                height: root.iconSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.widgetRadius
                    color: "transparent"
                    border.width: isFocused ? 1 : 0
                    border.color: Theme.primary
                    visible: isFocused
                }

                Item {
                    id: iconContainer
                    anchors.centerIn: parent
                    width: root.iconSize * 0.8
                    height: root.iconSize * 0.8

                    IconImage {
                        id: iconImg
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        source: {
                            const moddedId = Paths.moddedAppId(appId)
                            if (moddedId.toLowerCase().includes("steam_app")) return ""
                            const icon = DesktopEntries.heuristicLookup(moddedId)?.icon
                            if (!icon) return ""
                            const base = Quickshell.iconPath(icon, true)
                            return base ? base + (base.includes("?") ? "&" : "?") + "v=" + root.iconCacheBuster : ""
                        }
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    EHIcon {
                        anchors.centerIn: parent
                        size: root.iconSize * 0.8
                        name: "sports_esports"
                        color: Theme.surfaceText
                        visible: {
                            const moddedId = Paths.moddedAppId(appId)
                            return moddedId.toLowerCase().includes("steam_app")
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: {
                            const moddedId = Paths.moddedAppId(appId)
                            const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                            return !iconImg.visible && !isSteamApp
                        }
                        text: {
                            if (!appId) {
                                return "?";
                            }

                            const desktopEntry = DesktopEntries.heuristicLookup(appId);
                            if (desktopEntry && desktopEntry.name) {
                                return desktopEntry.name.charAt(0).toUpperCase();
                            }

                            return appId.charAt(0).toUpperCase();
                        }
                        font.pixelSize: root.iconSize * 0.4
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors.horizontalCenter: iconContainer.horizontalCenter
                        anchors.bottom: iconContainer.bottom
                        anchors.bottomMargin: 2
                        width: 4
                        height: 4
                        radius: 2
                        visible: true
                        color: {
                            if (isMinimized) {
                                return Qt.rgba(1, 0.5, 0, 0.8)
                            }
                            if (isFocused) {
                                return Theme.primary
                            }
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        }
                    }
                }

                StyledText {
                    anchors.left: iconContainer.right
                    anchors.leftMargin: Theme.spacingXS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !SettingsData.runningAppsCompactMode
                    text: windowTitle
                    font.pixelSize: Theme.fontSizeMedium - 1
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            if (toplevelObject) {
                                toplevelObject.activate();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            
                            if (contextMenu && typeof contextMenu.showForButton === "function") {
                                // Create appData similar to TaskBarApps format
                                const desktopEntry = DesktopEntries.heuristicLookup(appId);
                                const appData = {
                                    "type": "window",
                                    "appId": appId || "",
                                    "windowId": sortedToplevels.indexOf(toplevelObject),
                                    "windowTitle": windowTitle,
                                    "workspaceId": -1,
                                    "isPinned": false,
                                    "isRunning": true,
                                    "isFocused": isFocused,
                                    "isGrouped": false,
                                    "windowCount": 1,
                                    "windows": [{
                                        toplevel: toplevelObject,
                                        title: windowTitle,
                                        truncatedTitle: windowTitle.length > 50 ? windowTitle.substring(0, 47) + "..." : windowTitle,
                                        uniqueId: windowTitle + "|" + (appId || "") + "|" + sortedToplevels.indexOf(toplevelObject),
                                        index: sortedToplevels.indexOf(toplevelObject)
                                    }],
                                    "uniqueId": windowTitle + "|" + (appId || "") + "|" + sortedToplevels.indexOf(toplevelObject)
                                };
                                contextMenu.showForButton(delegateItem, appData, root.widgetHeight, desktopEntry);
                            }
                        }
                    }

                    onEntered: {
                        root.hoveredItem = delegateItem;
                    }
                    onExited: {
                        if (root.hoveredItem === delegateItem) {
                            root.hoveredItem = null;
                        }
                    }
                }
            }
        }
    }

}
