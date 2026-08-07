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
    property int pinnedAppCount: 0
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool suppressShiftAnimation: false
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real widgetHeight: (SettingsData.taskbarIconSize || 30) * uiScale
    property real iconSize:     (SettingsData.taskbarIconSize || 30) * uiScale
    property real iconSpacing:  (SettingsData.taskbarIconSpacing || 2) * uiScale

    Binding { target: root; property: "iconSize";     value: (SettingsData.taskbarIconSize    || 30) * uiScale }
    Binding { target: root; property: "iconSpacing";  value: (SettingsData.taskbarIconSpacing || 2)  * uiScale }
    Binding { target: root; property: "widgetHeight"; value: (SettingsData.taskbarIconSize    || 30) * uiScale }

    implicitWidth: listView.width
    implicitHeight: listView.height

    Component.onCompleted: {
        taskBarModel.updateModel()
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
            if (item && item.taskBarButton && item.taskBarButton.dragging) {
                draggingButton = item.taskBarButton
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
            }
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
        spacing: root.iconSpacing
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
                id: taskBarModel

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

                    // Always use grouped logic (ported from dock)
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

                    // Batch append items for better performance
                    for (var i = 0; i < items.length; i++) {
                        append(items[i])
                    }
                }
            }

        delegate: Item {
                id: delegateItem
                property alias taskBarButton: button
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
                    const shiftAmount = root.iconSize + spacing

                    if (dropIdx < 0)
                        return 0
                    if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx)
                        return -shiftAmount
                    if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx)
                        return shiftAmount
                    return 0
                }

                transform: Translate {
                    x: delegateItem.shiftOffset

                    Behavior on x {
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
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.width: 2
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                    visible: isDropTarget
                    z: 5
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    visible: model.type === "separator"
                    width: 2
                    height: 20
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    radius: 1
                    anchors.centerIn: parent
                }

                TaskBarAppButton {
                    id: button
                    visible: model.type !== "separator"
                    anchors.centerIn: parent

                    width: root.iconSize
                    height: root.iconSize

                    appData: model
                    contextMenu: root.contextMenu
                    taskBarApps: root
                    index: model.index
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
            taskBarModel.updateModel()
        }
    }

    Connections {
        target: SessionData
        function onPinnedAppsChanged() {
            root.suppressShiftAnimation = true
            root.draggedIndex = -1
            root.dropTargetIndex = -1
            taskBarModel.updateModel()
            Qt.callLater(() => {
                root.suppressShiftAnimation = false
            })
        }
    }

    
}
