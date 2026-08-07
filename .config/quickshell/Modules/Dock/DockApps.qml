import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var contextMenu: null
    property bool requestDockShow: false
    property int pinnedAppCount: 0
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool suppressShiftAnimation: false
    property bool isVertical: false
    property real widgetHeight: 48
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    // Allow callers (e.g. pinned apps) to override sizing via `iconSize/iconSpacing`.
    // Defaults follow dock settings.
    property real iconSize: SettingsData.dockIconSize * uiScale
    // Make spacing follow icon size (so changing icon-size slider scales gaps too).
    // Use ratio from the dock sliders: (dockIconSpacing / dockIconSize).
    property real iconSpacing: iconSize * ((SettingsData.dockIconSpacing || 0) / Math.max(1, (SettingsData.dockIconSize || 1)))
    // Never allow icons to touch/overlap, regardless of scale/slider values.
    // (Some themes/sliders can drive spacing close to 0.)
    readonly property real effectiveIconSpacing: Math.max(iconSpacing, Math.round(iconSize * 0.12))
    property real scaleFactor: (typeof root.unifiedScaleFactor !== "undefined" && !isNaN(root.unifiedScaleFactor)) ? root.unifiedScaleFactor : 1

    implicitWidth: listView.width
    implicitHeight: listView.height

    // Expose for children (e.g. `DockAppButton`) to do pointer→index math.
    property alias dockListView: listView

    Component.onCompleted: {
        dockModel.updateModel()
    }

    function movePinnedApp(fromIndex, toIndex) {
        if (fromIndex === toIndex) {
            return
        }

        const currentPinned = [...(SessionData.pinnedApps || [])]
        if (fromIndex < 0 || fromIndex >= currentPinned.length || toIndex < 0 || toIndex >= currentPinned.length) {
            return
        }

        const movedApp = currentPinned.splice(fromIndex, 1)[0]
        currentPinned.splice(toIndex, 0, movedApp)

        SessionData.setPinnedApps(currentPinned)
    }

    function updateAllDropTargets() {
        var draggingButton = null
        var draggingIndex = -1
        for (var i = 0; i < listView.count; i++) {
            var item = listView.itemAtIndex(i)
            if (item && item.dockButton && item.dockButton.dragging) {
                draggingButton = item.dockButton
                draggingIndex = i
                break
            }
        }
        
        if (!draggingButton) {
            return
        }
        
        
        for (var i = 0; i < listView.count; i++) {
            var item = listView.itemAtIndex(i)
            if (item) {
                item.isDropTarget = false
            }
        }
        
        var targetIndex = draggingButton.targetIndex
        var originalIndex = draggingButton.originalIndex
        
        
        if (targetIndex >= 0 && targetIndex < listView.count && targetIndex !== originalIndex) {
            var targetItem = listView.itemAtIndex(targetIndex)
            if (targetItem) {
                targetItem.isDropTarget = true
            } else {
            }
        } else {
        }
    }
    
    function clearAllDropTargets() {
        for (var i = 0; i < listView.count; i++) {
            var item = listView.itemAtIndex(i)
            if (item) {
                item.isDropTarget = false
            }
        }
    }

    ListView {
        id: listView
        orientation: ListView.Horizontal
        spacing: root.effectiveIconSpacing
        anchors.centerIn: parent
        height: root.iconSize
        width: contentWidth
        interactive: false
        
        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        
        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        model: ListModel {
                id: dockModel

                Component.onCompleted: updateModel()

                function normalizeAppId(appId) {
                    if (!appId) return ""
                    var normalized = appId.toString()
                    if (normalized.endsWith(".desktop")) {
                        normalized = normalized.substring(0, normalized.length - 8)
                    }
                    return normalized.toLowerCase()
                }
                
                function isPinnedApp(appId, pinnedApps) {
                    if (!appId || !pinnedApps || pinnedApps.length === 0) return false
                    const normalizedAppId = normalizeAppId(appId)
                    for (var i = 0; i < pinnedApps.length; i++) {
                        const normalizedPinned = normalizeAppId(pinnedApps[i])
                        if (normalizedAppId === normalizedPinned) return true
                    }
                    return false
                }
                
                function findMatchingPinnedAppId(appId, pinnedApps) {
                    if (!appId || !pinnedApps || pinnedApps.length === 0) return null
                    const normalizedAppId = normalizeAppId(appId)
                    for (var i = 0; i < pinnedApps.length; i++) {
                        const normalizedPinned = normalizeAppId(pinnedApps[i])
                        if (normalizedAppId === normalizedPinned) return pinnedApps[i]
                    }
                    return null
                }

                function updateModel() {
                    clear()

                    const items = []
                    const pinnedApps = [...(SessionData.pinnedApps || [])]
                    const sortedToplevels = CompositorService.sortedToplevels

                    // Pre-normalize pinned app IDs for O(1) lookups
                    const normalizedPinnedMap = new Map()
                    const pinnedIdToNormalized = new Map()
                    pinnedApps.forEach(pinnedId => {
                        const normalized = normalizeAppId(pinnedId)
                        normalizedPinnedMap.set(normalized, pinnedId)
                        pinnedIdToNormalized.set(pinnedId, normalized)
                    })

                    if (SettingsData.dockGroupApps) {
                        const groupedApps = {}
                        const unpinnedRunningApps = new Set()
                        const normalizedToGroupKey = new Map()
                        
                        sortedToplevels.forEach((toplevel, index) => {
                            const appId = toplevel.appId || "unknown"
                            const normalizedAppId = normalizeAppId(appId)
                            const matchingPinnedId = normalizedPinnedMap.get(normalizedAppId) || null
                            const effectiveAppId = matchingPinnedId || normalizedAppId
                            
                            if (!groupedApps[effectiveAppId]) {
                                groupedApps[effectiveAppId] = {
                                    isPinned: !!matchingPinnedId,
                                    windows: [],
                                    actualAppId: appId,
                                    pinnedAppId: matchingPinnedId
                                }
                                normalizedToGroupKey.set(normalizedAppId, effectiveAppId)
                            } else {
                                if (matchingPinnedId && !groupedApps[effectiveAppId].pinnedAppId) {
                                    groupedApps[effectiveAppId].pinnedAppId = matchingPinnedId
                                    groupedApps[effectiveAppId].isPinned = true
                                }
                            }
                            
                            const title = toplevel.title || "(Unnamed)"
                            const truncatedTitle = title.length > 50 ? title.substring(0, 47) + "..." : title
                            const uniqueId = toplevel.title + "|" + (toplevel.appId || "") + "|" + index
                            
                            groupedApps[effectiveAppId].windows.push({
                                toplevel: toplevel,
                                title: title,
                                truncatedTitle: truncatedTitle,
                                uniqueId: uniqueId,
                                index: index
                            })
                            
                            if (!matchingPinnedId) {
                                unpinnedRunningApps.add(effectiveAppId)
                            }
                        })
                        
                        const pinnedAppMap = {}
                        pinnedApps.forEach(pinnedAppId => {
                            const normalizedPinned = pinnedIdToNormalized.get(pinnedAppId)
                            const matchedKey = normalizedToGroupKey.get(normalizedPinned)
                            const app = matchedKey ? groupedApps[matchedKey] : null
                            const isGrouped = app && app.windows.length > 1
                            
                            items.push({
                                "type": isGrouped ? "grouped" : (app && app.windows && app.windows.length > 0 ? "window" : "pinned"),
                                "appId": pinnedAppId || "",
                                "windowId": isGrouped ? -1 : (app && app.windows && app.windows.length > 0 ? app.windows[0].index : -1),
                                "windowTitle": isGrouped ? "" : (app && app.windows && app.windows.length > 0 ? app.windows[0].truncatedTitle : ""),
                                "workspaceId": -1,
                                "isPinned": true,
                                "isRunning": !!(app && app.windows && app.windows.length > 0),
                                "isFocused": false,
                                "isGrouped": !!isGrouped,
                                "windowCount": app && app.windows ? app.windows.length : 0,
                                "windows": app && app.windows ? app.windows : [],
                                "uniqueId": isGrouped ? pinnedAppId + "_group" : (app && app.windows && app.windows.length > 0 ? app.windows[0].uniqueId : pinnedAppId + "_pinned")
                            })
                            
                            if (matchedKey) {
                                pinnedAppMap[matchedKey] = true
                            }
                        })
                        
                        if (pinnedApps.length > 0 && unpinnedRunningApps.size > 0) {
                            items.push({
                                "type": "separator",
                                "appId": "__SEPARATOR__",
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": false,
                                "isFocused": false,
                                "isGrouped": false,
                                "windowCount": 0,
                                "windows": [],
                                "uniqueId": "__SEPARATOR__"
                            })
                        }
                        
                        unpinnedRunningApps.forEach(appId => {
                            if (pinnedAppMap[appId]) return
                            
                            const app = groupedApps[appId]
                            if (!app) return
                            
                            const isGrouped = app.windows.length > 1
                            
                            items.push({
                                "type": isGrouped ? "grouped" : "window",
                                "appId": app.actualAppId || appId || "",
                                "windowId": isGrouped ? -1 : (app.windows && app.windows[0] ? app.windows[0].index : -1),
                                "windowTitle": isGrouped ? "" : (app.windows && app.windows[0] ? app.windows[0].truncatedTitle : ""),
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": true,
                                "isFocused": false,
                                "isGrouped": !!isGrouped,
                                "windowCount": app.windows ? app.windows.length : 0,
                                "windows": app.windows || [],
                                "uniqueId": isGrouped ? (app.actualAppId || appId) + "_group" : (app.windows && app.windows[0] ? app.windows[0].uniqueId : (app.actualAppId || appId) + "_window")
                            })
                        })
                        
                        root.pinnedAppCount = pinnedApps.length
                    } else {
                        pinnedApps.forEach(appId => {
                            items.push({
                                "type": "pinned",
                                "appId": appId || "",
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": true,
                                "isRunning": false,
                                "isFocused": false,
                                "isGrouped": false,
                                "windowCount": 0,
                                "windows": [],
                                "uniqueId": (appId || "") + "_pinned"
                            })
                        })

                        root.pinnedAppCount = pinnedApps.length

                        if (pinnedApps.length > 0 && sortedToplevels.length > 0) {
                            items.push({
                                "type": "separator",
                                "appId": "__SEPARATOR__",
                                "windowId": -1,
                                "windowTitle": "",
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": false,
                                "isFocused": false,
                                "isGrouped": false,
                                "windowCount": 0,
                                "windows": [],
                                "uniqueId": "__SEPARATOR__"
                            })
                        }

                        for (var i = 0; i < sortedToplevels.length; i++) {
                            const toplevel = sortedToplevels[i]
                            const title = toplevel.title || "(Unnamed)"
                            const truncatedTitle = title.length > 50 ? title.substring(0, 47) + "..." : title
                            const uniqueId = title + "|" + (toplevel.appId || "") + "|" + i

                            items.push({
                                "type": "window",
                                "appId": toplevel.appId || "",
                                "windowId": i,
                                "windowTitle": truncatedTitle,
                                "workspaceId": -1,
                                "isPinned": false,
                                "isRunning": true,
                                "isFocused": false,
                                "isGrouped": false,
                                "isMinimized": false,
                                "windowCount": 1,
                                "windows": [],
                                "uniqueId": uniqueId
                            })
                        }
                    }

                    // Batch append items for better performance
                    for (var i = 0; i < items.length; i++) {
                        append(items[i])
                    }
                }
            }

        delegate: Item {
                id: delegateItem
                property alias dockButton: button
                property bool isDropTarget: false
                clip: false
                z: button.dragging ? 100 : 0

                width: model.type === "separator" ? root.spx(16) : root.iconSize
                height: root.iconSize

                property real shiftOffset: {
                    if (root.draggedIndex < 0 || !model.isPinned || model.type === "separator")
                        return 0
                    if (model.index === root.draggedIndex)
                        return 0

                    const dragIdx = root.draggedIndex
                    const dropIdx = root.dropTargetIndex
                    const myIdx = model.index
                    const spacing = listView.spacing
                    // Must match actual delegate sizing when iconSize is overridden (e.g. pinned apps).
                    const shiftAmount = (root.iconSize * 1.2) + spacing

                    if (dropIdx < 0)
                        return 0
                    if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx)
                        return -shiftAmount
                    if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx)
                        return shiftAmount
                    return 0
                }

                transform: Translate {
                    x: root.isVertical ? 0 : delegateItem.shiftOffset
                    y: root.isVertical ? delegateItem.shiftOffset : 0

                    Behavior on x {
                        enabled: !root.suppressShiftAnimation
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        enabled: !root.suppressShiftAnimation
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Qt.rgba(0, 1, 0, 0.2)
                    border.width: 3
                    border.color: "#00ff00"
                    visible: isDropTarget
                    z: 5
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: parent.radius + 3
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(0, 1, 0, 0.6)
                    }
                    
                    SequentialAnimation on opacity {
                        running: isDropTarget
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.6; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                    }
                    
                    scale: isDropTarget ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    visible: model.type === "separator"
                    width: root.spx(2)
                    height: root.spx(20)
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    radius: root.spx(1)
                    anchors.centerIn: parent
                }

                DockAppButton {
                    id: button
                    visible: model.type !== "separator"
                    anchors.centerIn: parent

                    width: root.iconSize
                    height: root.iconSize

                    appData: model
                    contextMenu: root.contextMenu
                    dockApps: root
                    index: model.index

                    showWindowTitle: model.type === "window"
                    windowTitle: model.windowTitle || ""
                }
                
                Connections {
                    target: button
                    function onDraggingChanged() {
                        if (button && button.dragging) {
                            root.updateAllDropTargets()
                        } else {
                            root.clearAllDropTargets()
                        }
                    }
                    
                    function onTargetIndexChanged() {
                        if (button && button.dragging) {
                            root.updateAllDropTargets()
                        }
                    }
                }
            }
        }

    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() {
            dockModel.updateModel()
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            root.suppressShiftAnimation = true
            root.draggedIndex = -1
            root.dropTargetIndex = -1
            dockModel.updateModel()
            Qt.callLater(() => {
                root.suppressShiftAnimation = false
            })
        }
    }

    Connections {
        target: SettingsData
        function onDockGroupAppsChanged() {
            dockModel.updateModel()
        }
    }
    
}
