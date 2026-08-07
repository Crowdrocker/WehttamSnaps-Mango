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
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
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
        MangoService.refreshToken;
        if (CompositorService.isNiri) {
            const baseList = getNiriWorkspaces()
            return SettingsData.showWorkspacePadding && !SettingsData.dynamicWorkspaces ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isHyprland) {
            const baseList = getHyprlandWorkspaces()
            return SettingsData.showWorkspacePadding && !SettingsData.dynamicWorkspaces ? padWorkspaces(baseList) : baseList
        }
        if (CompositorService.isMango) {
            const baseList = getMangoWorkspaces()
            return SettingsData.showWorkspacePadding && !SettingsData.dynamicWorkspaces ? padWorkspaces(baseList) : baseList
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
        const maxTag = Math.min(SettingsData.maxWorkspaces, Math.max(1, CompositorService.mangoTagCount))

        if (!SettingsData.dynamicWorkspaces) {
            const result = []
            for (let i = 1; i <= maxTag; i++) {
                result.push({"id": i, "name": i.toString()})
            }
            return result
        }

        // Dynamic: show only tags that are selected or occupied (matching DMS approach)
        const out = MangoService.outputForDisplay(root.screenName, SettingsData.workspacesPerMonitor)
        const screenData = MangoService.outputTags[out]
        if (!screenData) return [{"id": 1, "name": "1"}]

        const visibleTags = new Set([1])
        const selected = screenData.selected || 0
        const occupied = screenData.occupied || 0
        const inUseMask = selected | occupied

        for (let i = 1; i <= maxTag; i++) {
            if (inUseMask & (1 << (i - 1))) {
                visibleTags.add(i)
            }
        }

        return Array.from(visibleTags).sort((a, b) => a - b).map(id => ({"id": id, "name": id.toString()}))
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
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
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
        spacing: Theme.spacingXS

        Repeater {
            model: root.workspaceList

            Item {
                id: wsDelegate

                property bool isActive: {
                    MangoService.refreshToken;
                    return CompositorService.isMango
                        ? (modelData && MangoService.isTagActiveOnOutput(root.screenName, modelData.id, SettingsData.workspacesPerMonitor))
                        : CompositorService.isHyprland
                            ? (modelData && modelData.id === root.currentWorkspace)
                            : (modelData === root.currentWorkspace)
                }
                property bool isPlaceholder: (CompositorService.isHyprland || CompositorService.isMango)
                    ? (modelData && modelData.id === -1)
                    : (modelData === -1)
                property bool isHovered: wsMouseArea.containsMouse
                property var workspaceData: {
                    if (isPlaceholder) return null
                    if (CompositorService.isNiri)
                        return NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                    return (CompositorService.isHyprland || CompositorService.isMango) ? modelData : null
                }
                property var iconData:   workspaceData?.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIcon:   iconData !== null
                property var icons: {
                    MangoService.refreshToken;
                    return SettingsData.showWorkspaceApps
                        ? root.getWorkspaceIcons((CompositorService.isHyprland || CompositorService.isMango) ? modelData : (modelData === -1 ? null : modelData))
                        : []
                }
                property bool showIcons: SettingsData.showWorkspaceApps && icons.length > 0

                // Pill width: expands when active or when showing app icons
                readonly property real dotH:    widgetHeight * 0.52
                readonly property real pillW:   showIcons
                    ? (isActive ? dotH + Theme.spacingS * 2 + iconsRow.implicitWidth
                                : dotH * 0.9   + Theme.spacingXS + iconsRow.implicitWidth)
                    : (isActive ? dotH * 2.2 : dotH)

                width:  isPlaceholder ? dotH * 0.55 : pillW
                height: dotH
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    enabled: !SettingsData.showWorkspaceApps || SettingsData.maxWorkspaceIcons <= 3
                    NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                }

                // ── Pill background ──────────────────────────────────────────
                Rectangle {
                    id: pillBg
                    anchors.fill: parent
                    radius: height / 2

                    color: wsDelegate.isActive
                        ? Theme.primary
                        : wsDelegate.isPlaceholder
                            ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                            : wsDelegate.isHovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.32)

                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }

                    // Subtle inner glow on active
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, wsDelegate.isActive ? 0.18 : 0)
                        Behavior on border.color { ColorAnimation { duration: Theme.mediumDuration } }
                    }
                }

                // ── Content: app icons ───────────────────────────────────────
                Row {
                    id: iconsRow
                    anchors.centerIn: parent
                    spacing: root.spx(3)
                    visible: wsDelegate.showIcons

                        Repeater {
                            model: wsDelegate.icons.slice(0, SettingsData.maxWorkspaceIcons)

                            Item {
                                id: iconItem
                                width:  wsDelegate.dotH * 0.62
                                height: wsDelegate.dotH * 0.62
                                layer.enabled: SettingsData.systemIconTinting && modelData.type !== "count"

                                // Count-only indicator (MangoWM non-active tag)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.15)
                                    visible: modelData.type === "count"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.count
                                        font.pixelSize: Math.max(7, parent.width * 0.55)
                                        font.weight: Font.Bold
                                        color: wsDelegate.isActive ? Theme.onPrimary : Theme.surfaceText
                                    }
                                }

                                Image {
                                    id: appIcon
                                    property var windowId: modelData.windowId
                                    anchors.fill: parent
                                    source:   modelData.type !== "count" ? modelData.icon : ""
                                    smooth:   true
                                    fillMode: Image.PreserveAspectFit
                                    opacity:  modelData.active ? 1.0 : (appMouseArea.containsMouse ? 0.85 : 0.6)
                                    visible:  modelData.type !== "count" && !modelData.isSteamApp
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                layer.effect: MultiEffect {
                                    colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                    colorizationColor: Theme.primary
                                }

                                EHIcon {
                                    anchors.centerIn: parent
                                    size:    parent.width
                                    name:    "sports_esports"
                                    color:   wsDelegate.isActive ? Theme.onPrimary : Theme.surfaceText
                                    opacity: modelData.active ? 1.0 : 0.6
                                    visible: modelData.type !== "count" && modelData.isSteamApp
                                }

                                // Count badge
                                Rectangle {
                                    visible: modelData.type !== "count" && modelData.count > 1
                                    width:  root.spx(10); height: root.spx(10)
                                    radius: root.spx(5)
                                    color:  Theme.primary
                                    border.color: Theme.surfaceContainer
                                    border.width: 1
                                    anchors.right:  parent.right
                                    anchors.bottom: parent.bottom
                                    z: 2

                                    StyledText {
                                        anchors.centerIn: parent
                                        text:            modelData.count
                                        font.pixelSize:  Math.max(6, root.spx(6))
                                        font.weight:     700
                                        color:           Theme.onPrimary
                                    }
                                }

                                MouseArea {
                                    id: appMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled:      wsDelegate.isActive && modelData.type !== "count"
                                    cursorShape:  Qt.PointingHandCursor
                                    onClicked: {
                                        if (CompositorService.isHyprland)
                                            Hyprland.dispatch(`hl.dsp.window.focus({address = "address:${appIcon.windowId}"})`)
                                        else if (CompositorService.isMango && appIcon.windowId && appIcon.windowId.activate)
                                            appIcon.windowId.activate()
                                        else if (CompositorService.isNiri)
                                            NiriService.focusWindow(appIcon.windowId)
                                    }
                                }
                            }
                        }
                }

                // ── Content: workspace icon / index label ──
                EHIcon {
                    visible: wsDelegate.hasIcon && wsDelegate.iconData.type === "icon" && !wsDelegate.showIcons
                    anchors.centerIn: parent
                    name:   (wsDelegate.hasIcon && wsDelegate.iconData.type === "icon") ? wsDelegate.iconData.value : ""
                    size: (Theme.fontSizeSmall || 12)
                    color:  wsDelegate.isActive ? Theme.onPrimary : Theme.surfaceTextMedium
                    weight: wsDelegate.isActive ? 500 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                StyledText {
                    visible: wsDelegate.hasIcon && wsDelegate.iconData.type === "text" && !wsDelegate.showIcons
                    anchors.centerIn: parent
                    text:       (wsDelegate.hasIcon && wsDelegate.iconData.type === "text") ? wsDelegate.iconData.value : ""
                    color:      wsDelegate.isActive ? Theme.onPrimary : Theme.surfaceTextMedium
                    font.pixelSize: (Theme.fontSizeSmall || 12)
                    font.weight:    wsDelegate.isActive ? 600 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                StyledText {
                    visible: SettingsData.showWorkspaceIndex && !wsDelegate.hasIcon && !wsDelegate.showIcons
                    anchors.centerIn: parent
                    text: {
                                        if (wsDelegate.isPlaceholder) return index + 1
                                        if (modelData === undefined || modelData === null) return ""
                                        return (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id || "") : (modelData - 1)
                                    }
                    color:      wsDelegate.isActive ? Theme.onPrimary : wsDelegate.isPlaceholder ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25) : Theme.surfaceTextMedium
                    font.pixelSize: Math.max(10, (Theme.fontSizeSmall || 12) - 1)
                    font.weight:    wsDelegate.isActive ? 600 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                // ── Click / hover ────────────────────────────────────────────
                MouseArea {
                    id: wsMouseArea
                    anchors.fill: parent
                    hoverEnabled:  !wsDelegate.isPlaceholder
                    cursorShape:   wsDelegate.isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled:       !wsDelegate.isPlaceholder
                    onClicked: {
                        if (CompositorService.isNiri)
                            NiriService.switchToWorkspace(modelData - 1)
                        else if (CompositorService.isMango && modelData?.id)
                            MangoService.switchToTag(modelData.id, root.screenName, SettingsData.workspacesPerMonitor)
                        else if (CompositorService.isHyprland && modelData?.id)
                            Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData.id}})`)
                    }
                }
            }
        }
    }
    
    Column {
        id: workspaceColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        Repeater {
            model: root.workspaceList

            Item {
                id: wsDelegateV

                property bool isActive: {
                    MangoService.refreshToken;
                    return CompositorService.isMango
                        ? (modelData && MangoService.isTagActiveOnOutput(root.screenName, modelData.id, SettingsData.workspacesPerMonitor))
                        : CompositorService.isHyprland
                            ? (modelData && modelData.id === root.currentWorkspace)
                            : (modelData === root.currentWorkspace)
                }
                property bool isPlaceholder: (CompositorService.isHyprland || CompositorService.isMango)
                    ? (modelData && modelData.id === -1)
                    : (modelData === -1)
                property bool isHovered: mouseAreaVertical.containsMouse
                property var workspaceData: {
                    if (isPlaceholder) return null
                    if (CompositorService.isNiri)
                        return NiriService.allWorkspaces.find(ws => ws.idx + 1 === modelData && ws.output === root.screenName) || null
                    return (CompositorService.isHyprland || CompositorService.isMango) ? modelData : null
                }
                property var iconData:   workspaceData?.name ? SettingsData.getWorkspaceNameIcon(workspaceData.name) : null
                property bool hasIcon:   iconData !== null
                property var icons: {
                    MangoService.refreshToken;
                    return SettingsData.showWorkspaceApps
                        ? root.getWorkspaceIcons((CompositorService.isHyprland || CompositorService.isMango) ? modelData : (modelData === -1 ? null : modelData))
                        : []
                }
                property bool showIcons:  SettingsData.showWorkspaceApps && icons.length > 0
                readonly property int maxIconsVertical: Math.min(SettingsData.maxWorkspaceIcons, 2)

                readonly property real dotW:  widgetHeight * 0.52
                readonly property real pillH: showIcons
                    ? (isActive ? dotW + Theme.spacingS * 2 + iconsColV.implicitHeight
                                : dotW * 0.9 + Theme.spacingXS + iconsColV.implicitHeight)
                    : (isActive ? dotW * 2.2 : dotW)

                width:  dotW
                height: isPlaceholder ? dotW * 0.55 : pillH
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on height {
                    enabled: !SettingsData.showWorkspaceApps || maxIconsVertical <= 2
                    NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2

                    color: wsDelegateV.isActive
                        ? Theme.primary
                        : wsDelegateV.isPlaceholder
                            ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                            : wsDelegateV.isHovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.32)

                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, wsDelegateV.isActive ? 0.18 : 0)
                        Behavior on border.color { ColorAnimation { duration: Theme.mediumDuration } }
                    }
                }

                Column {
                    id: iconsColV
                    anchors.centerIn: parent
                    spacing: root.spx(3)
                    visible: wsDelegateV.showIcons

                    Repeater {
                            model: wsDelegateV.icons.slice(0, wsDelegateV.maxIconsVertical)

                            Item {
                                width:  wsDelegateV.dotW * 0.62
                                height: wsDelegateV.dotW * 0.62
                                anchors.horizontalCenter: parent.horizontalCenter
                                layer.enabled: SettingsData.systemIconTinting && modelData.type !== "count"

                                // Count-only indicator (MangoWM non-active tag)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.15)
                                    visible: modelData.type === "count"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.count
                                        font.pixelSize: Math.max(7, parent.width * 0.55)
                                        font.weight: Font.Bold
                                        color: wsDelegateV.isActive ? Theme.onPrimary : Theme.surfaceText
                                    }
                                }

                                Image {
                                    id: appIconV
                                    property var windowId: modelData.windowId
                                    anchors.fill: parent
                                    source:   modelData.type !== "count" ? modelData.icon : ""
                                    smooth:   true
                                    fillMode: Image.PreserveAspectFit
                                    opacity:  modelData.active ? 1.0 : (appMouseAreaV.containsMouse ? 0.85 : 0.6)
                                    visible:  modelData.type !== "count" && !modelData.isSteamApp
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                layer.effect: MultiEffect {
                                    colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                    colorizationColor: Theme.primary
                                }

                                EHIcon {
                                    anchors.centerIn: parent
                                    size:    parent.width
                                    name:    "sports_esports"
                                    color:   wsDelegateV.isActive ? Theme.onPrimary : Theme.surfaceText
                                    opacity: modelData.active ? 1.0 : 0.6
                                    visible: modelData.type !== "count" && modelData.isSteamApp
                                }

                                Rectangle {
                                    visible: modelData.type !== "count" && modelData.count > 1
                                    width: root.spx(10); height: root.spx(10)
                                    radius: root.spx(5)
                                    color:  Theme.primary
                                    border.color: Theme.surfaceContainer
                                    border.width: 1
                                    anchors.right:  parent.right
                                    anchors.bottom: parent.bottom
                                    z: 2

                                    StyledText {
                                        anchors.centerIn: parent
                                        text:           modelData.count
                                        font.pixelSize: Math.max(6, root.spx(6))
                                        font.weight:    700
                                        color:          Theme.onPrimary
                                    }
                                }

                                MouseArea {
                                    id: appMouseAreaV
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled:      wsDelegateV.isActive && modelData.type !== "count"
                                    cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (CompositorService.isHyprland)
                                        Hyprland.dispatch(`hl.dsp.window.focus({address = "address:${appIconV.windowId}"})`)
                                    else if (CompositorService.isMango && appIconV.windowId && appIconV.windowId.activate)
                                        appIconV.windowId.activate()
                                    else if (CompositorService.isNiri)
                                        NiriService.focusWindow(appIconV.windowId)
                                }
                            }
                        }
                    }
                }

                EHIcon {
                    visible: wsDelegateV.hasIcon && wsDelegateV.iconData.type === "icon" && !wsDelegateV.showIcons
                    anchors.centerIn: parent
                    name:   (wsDelegateV.hasIcon && wsDelegateV.iconData.type === "icon") ? wsDelegateV.iconData.value : ""
                    size: Math.max(10, (Theme.fontSizeSmall || 12) - 2)
                    color:  wsDelegateV.isActive ? Theme.onPrimary : Theme.surfaceTextMedium
                    weight: wsDelegateV.isActive ? 500 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                StyledText {
                    visible: wsDelegateV.hasIcon && wsDelegateV.iconData.type === "text" && !wsDelegateV.showIcons
                    anchors.centerIn: parent
                    text:           (wsDelegateV.hasIcon && wsDelegateV.iconData.type === "text") ? wsDelegateV.iconData.value : ""
                    color:          wsDelegateV.isActive ? Theme.onPrimary : Theme.surfaceTextMedium
                    font.pixelSize: Math.max(10, (Theme.fontSizeSmall || 12) - 2)
                    font.weight:    wsDelegateV.isActive ? 600 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                StyledText {
                    visible: SettingsData.showWorkspaceIndex && !wsDelegateV.hasIcon && !wsDelegateV.showIcons
                    anchors.centerIn: parent
                    text: {
                                        if (wsDelegateV.isPlaceholder) return index + 1
                                        if (modelData === undefined || modelData === null) return ""
                                        return (CompositorService.isHyprland || CompositorService.isMango) ? (modelData?.id || "") : (modelData - 1)
                                    }
                    color:          wsDelegateV.isActive ? Theme.onPrimary : wsDelegateV.isPlaceholder ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25) : Theme.surfaceTextMedium
                    font.pixelSize: Math.max(10, (Theme.fontSizeSmall || 12) - 2)
                    font.weight:    wsDelegateV.isActive ? 600 : 400
                    Behavior on color { ColorAnimation { duration: Theme.mediumDuration } }
                }

                MouseArea {
                    id: mouseAreaVertical
                    anchors.fill: parent
                    hoverEnabled:  !wsDelegateV.isPlaceholder
                    cursorShape:   wsDelegateV.isPlaceholder ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled:       !wsDelegateV.isPlaceholder
                    onClicked: {
                        if (CompositorService.isNiri)
                            NiriService.switchToWorkspace(modelData - 1)
                        else if (CompositorService.isMango && modelData?.id)
                            MangoService.switchToTag(modelData.id, root.screenName, SettingsData.workspacesPerMonitor)
                        else if (CompositorService.isHyprland && modelData?.id)
                            Hyprland.dispatch(`hl.dsp.focus({workspace = ${modelData.id}})`)
                    }
                }
            }
        }
    }
}
