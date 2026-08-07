import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string screenName: ""
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    property int currentWorkspace: {
        MangoService.refreshToken;
        if (CompositorService.isNiri) {
            return getNiriActiveWorkspace()
        } else if (CompositorService.isHyprland) {
            return getHyprlandActiveWorkspace()
        } else if (CompositorService.isMango) {
            return MangoService.activeTagForScreen(root.screenName, SettingsData.workspacesPerMonitor)
        }
        return 1
    }
    property var workspaceList: {
        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isMango) {
            const baseList = getMangoWorkspaces()
            return SettingsData.showWorkspacePadding ? padWorkspaces(baseList) : baseList
        }
        return [1]
    }

    function getWorkspaceIcons(ws) {
        if (!SettingsData.showWorkspaceApps || !ws) {
            return []
        }
        if (CompositorService.isMango) {
            const tagId = ws.id !== undefined ? ws.id : ws
            if (typeof tagId !== "number" || tagId <= 0) {
                return []
            }
            return MangoService.workspaceIconsForTag(root.screenName, tagId, SettingsData.workspacesPerMonitor)
        }

        let targetWorkspaceId
        if (CompositorService.isNiri) {
            const wsNumber = typeof ws === "number" ? ws : -1
            if (wsNumber <= 0) {
                return []
            }
            const workspace = NiriService.allWorkspaces.find(w => w.idx + 1 === wsNumber && w.output === root.screenName)
            if (!workspace) {
                return []
            }
            targetWorkspaceId = workspace.id
        } else if (CompositorService.isHyprland) {
            targetWorkspaceId = ws.id !== undefined ? ws.id : ws
        } else {
            return []
        }

        const wins = CompositorService.isNiri ? (NiriService.windows || []) : CompositorService.sortedToplevels


        const byApp = {}
        const isActiveWs = CompositorService.isNiri ? NiriService.allWorkspaces.some(ws => ws.id === targetWorkspaceId && ws.is_active) : targetWorkspaceId === root.currentWorkspace

        wins.forEach((w, i) => {
                         if (!w) {
                             return
                         }

                         let winWs = null
                         if (CompositorService.isNiri) {
                             winWs = w.workspace_id
                         } else {
                             const hyprlandToplevels = Array.from(Hyprland.toplevels?.values || [])
                             const hyprToplevel = hyprlandToplevels.find(ht => ht.wayland === w)
                             winWs = hyprToplevel?.workspace?.id
                         }


                         if (winWs === undefined || winWs === null || winWs !== targetWorkspaceId) {
                             return
                         }

                         const keyBase = (w.app_id || w.appId || w.class || w.windowClass || "unknown").toLowerCase()
                         const key = isActiveWs ? `${keyBase}_${i}` : keyBase

                         if (!byApp[key]) {
                             const moddedId = Paths.moddedAppId(keyBase)
                             const isSteamApp = moddedId.toLowerCase().includes("steam_app")
                             const icon = isSteamApp ? "" : Quickshell.iconPath(DesktopEntries.heuristicLookup(moddedId)?.icon, true)
                             byApp[key] = {
                                 "type": "icon",
                                 "icon": icon,
                                 "isSteamApp": isSteamApp,
                                 "active": !!(w.activated || (CompositorService.isNiri && w.is_focused)),
                                 "count": 1,
                                 "windowId": w.address || w.id,
                                 "fallbackText": w.appId || w.class || w.title || ""
                             }
                         } else {
                             byApp[key].count++
                             if (w.activated || (CompositorService.isNiri && w.is_focused)) {
                                 byApp[key].active = true
                             }
                         }
                     })

        return Object.values(byApp)
    }

    function padWorkspaces(list) {
        const padded = list.slice()
        const placeholder = (CompositorService.isHyprland || CompositorService.isMango) ? {
                                                                                             "id": -1,
                                                                                             "name": ""
                                                                                         } : -1
        while (padded.length < SettingsData.maxWorkspaces) {
            padded.push(placeholder)
        }
        return padded
    }

    function getNiriWorkspaces() {
        if (NiriService.allWorkspaces.length === 0) {
            return [1, 2]
        }

        let workspaces = []
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            workspaces = NiriService.getCurrentOutputWorkspaceNumbers()
        } else {
            const displayWorkspaces = NiriService.allWorkspaces.filter(ws => ws.output === root.screenName).map(ws => ws.idx + 1)
            workspaces = displayWorkspaces.length > 0 ? displayWorkspaces : [1, 2]
        }
        
        return workspaces.slice(0, SettingsData.maxWorkspaces)
    }

    function getNiriActiveWorkspace() {
        if (NiriService.allWorkspaces.length === 0) {
            return 1
        }

        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return NiriService.getCurrentWorkspaceNumber()
        }

        const activeWs = NiriService.allWorkspaces.find(ws => ws.output === root.screenName && ws.is_active)
        return activeWs ? activeWs.idx + 1 : 1
    }

    function getHyprlandWorkspaces() {
        const workspaces = Hyprland.workspaces?.values || []
        
        let result = []
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            const sorted = workspaces.slice().sort((a, b) => a.id - b.id)
            result = sorted.length > 0 ? sorted : [{
                        "id": 1,
                        "name": "1"
                    }]
        } else {
            const monitorWorkspaces = workspaces.filter(ws => {
                return ws.lastIpcObject && ws.lastIpcObject.monitor === root.screenName
            })
            
            if (monitorWorkspaces.length === 0) {
                result = [{
                            "id": 1,
                            "name": "1"
                        }]
            } else {
                result = monitorWorkspaces.sort((a, b) => a.id - b.id)
            }
        }
        
        if (result.length < SettingsData.maxWorkspaces) {
            const existingIds = new Set(result.map(ws => ws.id))
            for (let i = 1; i <= SettingsData.maxWorkspaces; i++) {
                if (!existingIds.has(i)) {
                    result.push({
                        "id": i,
                        "name": i.toString()
                    })
                }
            }
            result = result.sort((a, b) => a.id - b.id)
        }
        
        return result.slice(0, SettingsData.maxWorkspaces)
    }

    function getHyprlandActiveWorkspace() {
        if (!root.screenName || !SettingsData.workspacesPerMonitor) {
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        }

        const monitors = Hyprland.monitors?.values || []
        const currentMonitor = monitors.find(monitor => monitor.name === root.screenName)
        
        if (!currentMonitor) {
            return 1
        }

        return currentMonitor.activeWorkspace?.id ?? 1
    }

    function getMangoWorkspaces() {
        const n = Math.min(SettingsData.maxWorkspaces, Math.max(1, CompositorService.mangoTagCount))
        const result = []
        for (let i = 1; i <= n; i++) {
            result.push({
                "id": i,
                "name": i.toString()
            })
        }
        return result
    }

    readonly property real padding: isBarVertical ? (widgetHeight - workspaceColumn.implicitWidth) / 2 : (widgetHeight - workspaceRow.implicitHeight) / 2

    function getRealWorkspaces() {
        return root.workspaceList.filter(ws => {
                                             if (CompositorService.isHyprland || CompositorService.isMango) {
                                                 return ws && ws.id !== -1
                                             }
                                             return ws !== -1
                                         })
    }

    function switchWorkspace(direction) {
        if (CompositorService.isNiri) {
            const realWorkspaces = getRealWorkspaces()
            if (realWorkspaces.length < 2) {
                return
            }

            const currentIndex = realWorkspaces.findIndex(ws => ws === root.currentWorkspace)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0 ? (validIndex + 1) % realWorkspaces.length : (validIndex - 1 + realWorkspaces.length) % realWorkspaces.length

            NiriService.switchToWorkspace(realWorkspaces[nextIndex] - 1)
        } else if (CompositorService.isHyprland) {
            const command = direction > 0 ? "r+1" : "r-1"
            Hyprland.dispatch(`hl.dsp.focus({workspace = "${command}"})`)
        } else if (CompositorService.isMango) {
            MangoService.cycleTag(root.screenName, SettingsData.workspacesPerMonitor, direction)
        }
    }

    width: isBarVertical ? widgetHeight : (workspaceRow.implicitWidth + padding * 2)
    height: isBarVertical ? (workspaceColumn.implicitHeight + padding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground)
            return "transparent"
        const baseColor = Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }
    visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        property real scrollAccumulator: 0
        property real touchpadThreshold: 500

        onWheel: wheel => {
                     const deltaY = wheel.angleDelta.y
                     const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0
                     const direction = deltaY < 0 ? 1 : -1

                     if (isMouseWheel) {
                         switchWorkspace(direction)
                     } else {
                         scrollAccumulator += deltaY

                         if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                             const touchDirection = scrollAccumulator < 0 ? 1 : -1
                             switchWorkspace(touchDirection)
                             scrollAccumulator = 0
                         }
                     }

                     wheel.accepted = true
                 }
    }

    Row {
        id: workspaceRow
        visible: !isBarVertical
        anchors.centerIn: parent
        spacing: Math.max(2, root.widgetHeight * 0.15)

        Repeater {
            model: root.workspaceList

            Rectangle {
                property bool isActive: {
                    MangoService.refreshToken;
                    if (CompositorService.isMango) {
                        return modelData && MangoService.isTagActiveOnOutput(root.screenName, modelData.id, SettingsData.workspacesPerMonitor)
                    }
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === root.currentWorkspace
                    }
                    return modelData === root.currentWorkspace
                }
                property bool isPlaceholder: {
                    if (CompositorService.isHyprland || CompositorService.isMango) {
                        return modelData && modelData.id === -1
                    }
                    return modelData === -1
                }
                property bool isHovered: mouseArea.containsMouse
                property var workspaceData: {
                    if (isPlaceholder) {
                        return null
                    }

                    if (CompositorService.isNiri) {
                        return NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                    }
                    return (CompositorService.isHyprland || CompositorService.isMango) ? modelData : null
                }
                property var iconData: workspaceData?.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIcon: iconData !== null
                property var icons: {
                    MangoService.refreshToken;
                    return SettingsData.showWorkspaceApps ? root.getWorkspaceIcons((CompositorService.isHyprland || CompositorService.isMango) ? modelData : (modelData === -1 ? null : modelData)) : []
                }

                width: {
                    if (SettingsData.showWorkspaceApps) {
                        if (icons.length > 0) {
                            return isActive ? widgetHeight * 1.0 + root.widgetHeight * 0.15 + contentRow.implicitWidth : widgetHeight * 0.8 + contentRow.implicitWidth
                        } else {
                            return isActive ? widgetHeight * 1.0 + root.widgetHeight * 0.15 : widgetHeight * 0.8
                        }
                    }
                    return isActive ? widgetHeight * 1.2 + root.widgetHeight * 0.15 : widgetHeight * 0.8
                }
                height: SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
                radius: Theme.cornerRadius * (root.widgetHeight / 30)
                color: isActive ? Theme.primary : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder) {
                            return
                        }

                        if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(modelData - 1)
                        } else if (CompositorService.isMango && modelData?.id) {
                            MangoService.switchToTag(modelData.id, root.screenName, SettingsData.workspacesPerMonitor)
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData.id}})`)

                        }
                    }
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: Math.max(2, root.widgetHeight * 0.1)
                    visible: SettingsData.showWorkspaceApps && icons.length > 0

                    Repeater {
                        model: icons.slice(0, SettingsData.maxWorkspaceIcons)
                        delegate: Item {
                            width: root.widgetHeight * 0.6
                            height: root.widgetHeight * 0.6
                            layer.enabled: SettingsData.systemIconTinting

                            Image {
                                id: appIcon
                                property var windowId: modelData.windowId
                                anchors.fill: parent
                                source: modelData.icon
                                opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                visible: !modelData.isSteamApp
                                
                            }

                            layer.effect: MultiEffect {
                                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                colorizationColor: Theme.primary
                            }

                            EHIcon {
                                anchors.centerIn: parent
                                size: root.widgetHeight * 0.6
                                name: "sports_esports"
                                color: Theme.surfaceText
                                opacity: modelData.active ? 1.0 : appMouseArea.containsMouse ? 0.8 : 0.6
                                visible: modelData.isSteamApp
                                
                            }

                            MouseArea {
                                id: appMouseArea
                                hoverEnabled: true
                                anchors.fill: parent
                                enabled: isActive
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (CompositorService.isHyprland) {
                                        Hyprland.dispatch(`hl.dsp.window.focus({address = "address:${appIcon.windowId}"})`)
                                    } else if (CompositorService.isMango && appIcon.windowId && appIcon.windowId.activate) {
                                        appIcon.windowId.activate()
                                    } else if (CompositorService.isNiri) {
                                        NiriService.focusWindow(appIcon.windowId)
                                    }
                                }
                            }

                            Rectangle {
                                visible: modelData.count > 1 && !isActive
                                width: root.widgetHeight * 0.4
                                height: root.widgetHeight * 0.4
                                radius: Theme.cornerRadius * (root.widgetHeight / 30)
                                color: "black"
                                border.color: "white"
                                border.width: 1
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                z: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    font.pixelSize: root.widgetHeight * 0.25
                                    color: "white"
                                }
                            }
                        }
                    }
                }

                EHIcon {
                    visible: hasIcon && iconData.type === "icon" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    name: (hasIcon && iconData.type === "icon") ? iconData.value : ""
                    size: root.widgetHeight * 0.5
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    weight: isActive && !isPlaceholder ? 500 : 400
                    
                }

                StyledText {
                    visible: hasIcon && iconData.type === "text" && (!SettingsData.showWorkspaceApps || icons.length === 0)
                    anchors.centerIn: parent
                    text: (hasIcon && iconData.type === "text") ? iconData.value : ""
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    font.pixelSize: root.widgetHeight * 0.5
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                    
                }

                StyledText {
                    visible: (SettingsData.showWorkspaceIndex && !hasIcon && (!SettingsData.showWorkspaceApps || icons.length === 0))
                    anchors.centerIn: parent
                    text: {
                        const isPlaceholder = (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id === -1) : (modelData === -1)

                        if (isPlaceholder) {
                            return index + 1
                        }

                        return (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id || "") : (modelData - 1)
                    }
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                    font.pixelSize: root.widgetHeight * 0.5
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                    
                }

                Behavior on width {
		    enabled: (!SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3)
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }

            }
        }
    }
    
    Column {
        id: workspaceColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: Math.max(2, root.widgetHeight * 0.15)

        Repeater {
            model: root.workspaceList

            Rectangle {
                property bool isActive: {
                    MangoService.refreshToken;
                    if (CompositorService.isMango) {
                        return modelData && MangoService.isTagActiveOnOutput(root.screenName, modelData.id, SettingsData.workspacesPerMonitor)
                    }
                    if (CompositorService.isHyprland) {
                        return modelData && modelData.id === root.currentWorkspace
                    }
                    return modelData === root.currentWorkspace
                }
                property bool isPlaceholder: {
                    if (CompositorService.isHyprland || CompositorService.isMango) {
                        return modelData && modelData.id === -1
                    }
                    return modelData === -1
                }
                property bool isHovered: mouseAreaVertical.containsMouse
                property var workspaceData: {
                    if (isPlaceholder) {
                        return null
                    }
                    if (CompositorService.isNiri) {
                        return NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                    }
                    return (CompositorService.isHyprland || CompositorService.isMango) ? modelData : null
                }
                property var iconDataVertical: workspaceData?.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIconVertical: iconDataVertical !== null
                property var iconsVertical: {
                    MangoService.refreshToken;
                    return SettingsData.showWorkspaceApps ? root.getWorkspaceIcons((CompositorService.isHyprland || CompositorService.isMango) ? modelData : (modelData === -1 ? null : modelData)) : []
                }
                property int maxIconsVertical: SettingsData.maxWorkspaceIcons

                width: SettingsData.showWorkspaceApps ? widgetHeight * 0.8 : widgetHeight * 0.6
                height: {
                    if (SettingsData.showWorkspaceApps) {
                        if (iconsVertical.length > 0) {
                            return isActive ? widgetHeight * 1.0 + root.widgetHeight * 0.15 + contentColumn.implicitHeight : widgetHeight * 0.8 + contentColumn.implicitHeight
                        } else {
                            return isActive ? widgetHeight * 1.0 + root.widgetHeight * 0.15 : widgetHeight * 0.8
                        }
                    }
                    return isActive ? widgetHeight * 1.2 + root.widgetHeight * 0.15 : widgetHeight * 0.8
                }
                radius: Theme.cornerRadius * (root.widgetHeight / 30)
                color: isActive ? Theme.primary : isPlaceholder ? Theme.surfaceTextLight : isHovered ? Theme.outlineButton : Theme.surfaceTextAlpha

                MouseArea {
                    id: mouseAreaVertical

                    anchors.fill: parent
                    hoverEnabled: !isPlaceholder
                    cursorShape: isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !isPlaceholder
                    onClicked: {
                        if (isPlaceholder) {
                            return
                        }

                        if (CompositorService.isNiri) {
                            NiriService.switchToWorkspace(modelData - 1)
                        } else if (CompositorService.isMango && modelData?.id) {
                            MangoService.switchToTag(modelData.id, root.screenName, SettingsData.workspacesPerMonitor)
                        } else if (CompositorService.isHyprland && modelData?.id) {
                            Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData.id}})`)

                        }
                    }
                }

                Column {
                    id: contentColumn
                    anchors.centerIn: parent
                    spacing: Math.max(2, root.widgetHeight * 0.1)
                    visible: SettingsData.showWorkspaceApps && iconsVertical.length > 0

                    Repeater {
                        model: iconsVertical.slice(0, SettingsData.maxWorkspaceIcons)
                        delegate: Item {
                            width: root.widgetHeight * 0.6
                            height: root.widgetHeight * 0.6
                            layer.enabled: SettingsData.systemIconTinting

                            Image {
                                id: appIconVertical
                                property var windowId: modelData.windowId
                                anchors.fill: parent
                                source: modelData.icon
                                opacity: modelData.active ? 1.0 : appMouseAreaVertical.containsMouse ? 0.8 : 0.6
                                visible: !modelData.isSteamApp
                                
                            }

                            layer.effect: MultiEffect {
                                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                colorizationColor: Theme.primary
                            }

                            EHIcon {
                                anchors.centerIn: parent
                                size: root.widgetHeight * 0.6
                                name: "sports_esports"
                                color: Theme.surfaceText
                                opacity: modelData.active ? 1.0 : appMouseAreaVertical.containsMouse ? 0.8 : 0.6
                                visible: modelData.isSteamApp
                                
                            }

                            MouseArea {
                                id: appMouseAreaVertical
                                hoverEnabled: true
                                anchors.fill: parent
                                enabled: isActive
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (CompositorService.isHyprland) {
                                        Hyprland.dispatch(`hl.dsp.window.focus({address = "address:${appIconVertical.windowId}"})`)
                                    } else if (CompositorService.isMango && appIconVertical.windowId && appIconVertical.windowId.activate) {
                                        appIconVertical.windowId.activate()
                                    } else if (CompositorService.isNiri) {
                                        NiriService.focusWindow(appIconVertical.windowId)
                                    }
                                }
                            }

                            Rectangle {
                                visible: modelData.count > 1 && !isActive
                                width: root.widgetHeight * 0.4
                                height: root.widgetHeight * 0.4
                                radius: Theme.cornerRadius * (root.widgetHeight / 30)
                                color: "black"
                                border.color: "white"
                                border.width: 1
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                z: 2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    font.pixelSize: root.widgetHeight * 0.25
                                    color: "white"
                                }
                            }
                        }
                    }
                }

                EHIcon {
                    visible: hasIconVertical && iconDataVertical.type === "icon" && (!SettingsData.showWorkspaceApps || iconsVertical.length === 0)
                    anchors.centerIn: parent
                    name: (hasIconVertical && iconDataVertical.type === "icon") ? iconDataVertical.value : ""
                    size: root.widgetHeight * 0.5
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    weight: isActive && !isPlaceholder ? 500 : 400
                    
                }

                StyledText {
                    visible: hasIconVertical && iconDataVertical.type === "text" && (!SettingsData.showWorkspaceApps || iconsVertical.length === 0)
                    anchors.centerIn: parent
                    text: (hasIconVertical && iconDataVertical.type === "text") ? iconDataVertical.value : ""
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : Theme.surfaceTextMedium
                    font.pixelSize: root.widgetHeight * 0.5
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                    
                }

                StyledText {
                    visible: (SettingsData.showWorkspaceIndex && !hasIconVertical && (!SettingsData.showWorkspaceApps || iconsVertical.length === 0))
                    anchors.centerIn: parent
                    text: {
                        const isPlaceholder = (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id === -1) : (modelData === -1)

                        if (isPlaceholder) {
                            return index + 1
                        }

                        return (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id || "") : (modelData - 1)
                    }
                    color: isActive ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95) : isPlaceholder ? Theme.surfaceTextAlpha : Theme.surfaceTextMedium
                    font.pixelSize: root.widgetHeight * 0.5
                    font.weight: (isActive && !isPlaceholder) ? Font.DemiBold : Font.Normal
                    
                }

                Behavior on height {
                    enabled: (!SettingsData.showWorkspaceApps || maxIconsVertical <= 2)
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
}
