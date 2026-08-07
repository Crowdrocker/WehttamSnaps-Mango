import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showContextMenu: false
    property var  appData:    null
    property var  anchorItem: null
    property real dockVisibleHeight: 40
    property int  margin: 10
    property bool workspaceOptionsVisible: false
    property var  desktopEntry: null

    // ── API ───────────────────────────────────────────────────────────────────

    function showForButton(button, data, dockHeight, entry) {
        if (showContextMenu && anchorItem === button) { close(); return }
        anchorItem   = button
        appData      = data
        dockVisibleHeight = dockHeight || 40
        desktopEntry = entry || null
        root.workspaceOptionsVisible = false

        const dockWindow = button.Window.window
        if (dockWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (dockWindow.x >= s.x && dockWindow.x < s.x + s.width) {
                    root.screen = s; break
                }
            }
        }
        showContextMenu = true
    }

    function close() { showContextMenu = false }

    function getToplevelObject() {
        if (!appData || (appData.type !== "window" && appData.type !== "pinned")) return null
        if (appData.type === "pinned" && appData.windows?.length > 0) {
            for (var i = 0; i < appData.windows.length; i++)
                if (appData.windows[i].toplevel?.activated) return appData.windows[i].toplevel
            return appData.windows[0].toplevel
        }
        const tops = CompositorService.sortedToplevels
        if (!tops) return null
        if (appData.windowId !== undefined && appData.windowId >= 0 && appData.windowId < tops.length)
            return tops[appData.windowId]
        return null
    }

    // ── Window setup ──────────────────────────────────────────────────────────

    screen: Quickshell.screens[0]
    visible: showContextMenu
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }

    // Scale animation duration to the screen's actual refresh rate
    readonly property int rateAwareDuration: Math.round(Theme.mediumDuration * 60 / Math.max(60, screen ? screen.refreshRate : 60))

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: { if (visible) updatePosition() }

    function updatePosition() {
        if (!anchorItem) { anchorPos = Qt.point(screen.width / 2, screen.height - 100); return }
        const dockWindow = anchorItem.Window.window
        if (!dockWindow) { anchorPos = Qt.point(screen.width / 2, screen.height - 100); return }

        const buttonPos = anchorItem.mapToItem(dockWindow.contentItem, 0, 0)
        let dockH = root.dockVisibleHeight

        function findDockBg(item) {
            if (item.objectName === "dockBackground") return item
            for (var i = 0; i < item.children.length; i++) {
                const f = findDockBg(item.children[i])
                if (f) return f
            }
            return null
        }
        const bg = findDockBg(dockWindow.contentItem)
        if (bg) dockH = bg.height

        const screenX  = Math.round((root.screen.width - dockWindow.width) / 2) + buttonPos.x + anchorItem.width / 2
        const screenY  = root.screen.height - dockH - 16 - 20
        anchorPos = Qt.point(screenX, screenY)
    }

    // ── Menu container ────────────────────────────────────────────────────────
    // Outer Item clips the inner Rectangle so only the top two corners are
    // rounded. The inner rect is taller than the clip by `r` pixels so its
    // bottom rounded corners fall outside the clip boundary and disappear.

    Item {
        id: menuContainer

        readonly property int r: Theme.cornerRadius + 2

        width:  Math.min(320, Math.max(220, menuColumn.implicitWidth + Theme.spacingM * 2))
        height: menuColumn.implicitHeight + Theme.spacingS * 2

        x: Math.max(10, Math.min(root.width - width - 10, root.anchorPos.x - width / 2))
        y: Math.max(10, root.anchorPos.y - height + 30)

        clip:    false
        opacity: showContextMenu ? 1 : 0
        scale:   showContextMenu ? 1 : 0.92

        Behavior on opacity { NumberAnimation { duration: root.rateAwareDuration; easing.type: Theme.emphasizedEasing } }
        Behavior on scale   { NumberAnimation { duration: root.rateAwareDuration; easing.type: Theme.emphasizedEasing } }

        // Drop shadow
        Rectangle {
            anchors { fill: parent; topMargin: 4; leftMargin: 2; rightMargin: -2; bottomMargin: -4 }
            radius: menuContainer.r
            color:  Qt.rgba(0, 0, 0, 0.18)
            z:      -1
        }

        // Background — fully rounded on all four corners
        Rectangle {
            id: menuBg
            anchors.fill: parent
            radius: menuContainer.r
            color:        Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1
        }

        // ── App header ───────────────────────────────────────────────────────
        Column {
            id: menuColumn
            width: parent.width - Theme.spacingM * 2
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.spacingS }
            spacing: 0

            // App name header — shown when there's a desktop entry
            Item {
                width:   parent.width
                height:  root.desktopEntry ? 40 : 0
                visible: root.desktopEntry

                Row {
                    anchors { left: parent.left; leftMargin: Theme.spacingM; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spacingS

                    // App icon
                    Item {
                        width: 20; height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.desktopEntry?.icon !== undefined && root.desktopEntry?.icon !== ""

                        IconImage {
                            anchors.fill: parent
                            source: root.desktopEntry?.icon ? Quickshell.iconPath(root.desktopEntry.icon, true) : ""
                            asynchronous: true
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  root.desktopEntry?.name ?? (root.appData?.appId ?? "")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    600
                        color:          Theme.surfaceText
                    }
                }
            }

            // Separator after header
            DockMenuSeparator { visible: root.desktopEntry !== null }

            // ── Desktop entry actions ─────────────────────────────────────
            Repeater {
                model: root.desktopEntry?.actions ?? []
                DockMenuRow {
                    label:    modelData.name ?? ""
                    iconName: ""
                    iconSrc:  modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    onActivated: {
                        if (modelData && root.desktopEntry)
                            SessionService.launchDesktopAction(root.desktopEntry, modelData)
                        root.close()
                    }
                }
            }

            DockMenuSeparator { visible: root.desktopEntry?.actions?.length > 0 }

            // ── Pin / Unpin ───────────────────────────────────────────────
            DockMenuRow {
                label:    root.appData?.isPinned ? "Unpin from Dock" : "Pin to Dock"
                iconName: root.appData?.isPinned ? "push_pin" : "push_pin"
                onActivated: {
                    if (!root.appData) return
                    root.appData.isPinned
                        ? SessionData.removePinnedApp(root.appData.appId)
                        : SessionData.addPinnedApp(root.appData.appId)
                    root.close()
                }
            }

            // ── New Window ────────────────────────────────────────────────
            DockMenuRow {
                label:    "New Window"
                iconName: "add_box"
                visible:  root.appData && (root.appData.type === "window" || root.appData.type === "pinned")
                onActivated: {
                    if (root.appData?.appId) {
                        const de = DesktopEntries.heuristicLookup(root.appData.appId)
                        if (de) {
                            AppUsageHistoryData.addAppUsage({ "id": root.appData.appId, "name": de.name || root.appData.appId, "icon": de.icon || "", "exec": de.exec || "", "comment": de.comment || "" })
                            SessionService.launchDesktopEntry(de)
                        }
                    }
                    root.close()
                }
            }

            // ── Launch on dGPU ────────────────────────────────────────────
            DockMenuRow {
                label:    "Launch on dGPU"
                iconName: "memory"
                visible:  root.appData && (root.appData.type === "window" || root.appData.type === "pinned") && SessionService.nvidiaCommand
                onActivated: {
                    if (root.appData?.appId) {
                        const de = DesktopEntries.heuristicLookup(root.appData.appId)
                        if (de) {
                            AppUsageHistoryData.addAppUsage({ "id": root.appData.appId, "name": de.name || root.appData.appId, "icon": de.icon || "", "exec": de.exec || "", "comment": de.comment || "" })
                            SessionService.launchDesktopEntry(de, true)
                        }
                    }
                    root.close()
                }
            }

            DockMenuSeparator {
                visible: root.appData && (root.appData.type === "window" || root.appData.type === "pinned")
            }

            // ── Window list (grouped / pinned with multiple windows) ──────
            Repeater {
                model: (root.appData?.windows?.length > 0 &&
                        (root.appData.type === "grouped" ||
                         (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows.length > 1)))
                    ? root.appData.windows : []

                DockMenuRow {
                    label:    modelData?.truncatedTitle ?? ""
                    iconName: "web_asset"
                    onActivated: {
                        modelData?.toplevel?.activate()
                        root.close()
                    }
                }
            }

            // ── Move to Workspace ─────────────────────────────────────────
            DockMenuRow {
                label:    "Move to Workspace"
                iconName: "grid_view"
                visible:  root.appData?.type === "window"
                trailing: root.workspaceOptionsVisible ? "expand_less" : "chevron_right"
                onActivated: root.workspaceOptionsVisible = !root.workspaceOptionsVisible
            }

            // Workspace sub-items
            Repeater {
                model: root.appData?.type === "window" && root.workspaceOptionsVisible
                    ? SettingsData.maxWorkspaces : 0

                DockMenuRow {
                    label:        "Workspace " + (index + 1)
                    iconName:     ""
                    indented:     true
                    onActivated: {
                        const toplevel = root.getToplevelObject()
                        if (toplevel) {
                            const wsId = index + 1
                            if (CompositorService.isHyprland) {
                                const hyprTops = Array.from(Hyprland.toplevels?.values || [])
                                const ht = hyprTops.find(h => h.wayland === toplevel)
                                if (ht) {
                                    const addr = ht.address || ht.id
if (addr) {
                                        // Hyprland 0.55+ uses Lua dispatcher syntax
                                        const fmt = addr.toString().startsWith("0x") ? addr : `0x${addr}`
                                        Hyprland.dispatch(`hl.dsp.window.move({workspace = ${wsId}, window = "address:${fmt}"})`)
                                    }
                                }
                            } else if (CompositorService.isNiri) {
                                const wid = toplevel.niriWindowId
                                if (wid !== undefined) {
                                    NiriService.focusWindow(wid)
                                    Qt.callLater(() => NiriService.moveWindowToWorkspace(wsId - 1))
                                }
                            }
                        }
                        root.close()
                    }
                }
            }

            // ── Toggle Floating ───────────────────────────────────────────
            DockMenuRow {
                label: {
                    if (!root.appData) return "Toggle Floating"
                    if (CompositorService.isHyprland) {
                        const tops = Array.from(Hyprland.toplevels?.values || [])
                        const ht   = tops.find(h => h.wayland === root.getToplevelObject())
                        if (ht?.floating) return "Unfloat Window"
                    }
                    return "Toggle Floating"
                }
                iconName: "open_with"
                visible:  root.appData?.type === "window" && (CompositorService.isHyprland || CompositorService.isNiri)
                onActivated: {
                    const toplevel = root.getToplevelObject()
                    if (toplevel) {
                        if (CompositorService.isHyprland) {
                            const tops = Array.from(Hyprland.toplevels?.values || [])
                            const ht   = tops.find(h => h.wayland === toplevel)
                            if (ht) {
                                const addr = ht.address || ht.id
                                if (addr) {
                                    // Hyprland 0.55+ uses Lua dispatcher syntax
                                    const fmt = addr.toString().startsWith("0x") ? addr : `0x${addr}`
                                    Hyprland.dispatch(`hl.dsp.window.toggle_floating({address = "address:${fmt}"})`)
                                }
                            }
                        } else if (CompositorService.isNiri) {
                            const wid = toplevel.niriWindowId
                            if (wid !== undefined) {
                                NiriService.focusWindow(wid)
                                Qt.callLater(() => NiriService.toggleFloating())
                            }
                        }
                    }
                    root.close()
                }
            }

            DockMenuSeparator {
                visible: root.appData && (root.appData.type === "window" ||
                    (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows?.length > 1))
            }

            // ── Minimize / Minimize All ───────────────────────────────────
            DockMenuRow {
                label:    "Minimize Window"
                iconName: "remove"
                visible:  root.appData && (root.appData.type === "window" || root.appData.type === "pinned")
                onActivated: {
                    // toplevel.minimize() — wire up when API available
                    root.close()
                }
            }

            DockMenuRow {
                label:    "Minimize All Windows"
                iconName: "remove"
                visible:  root.appData && ((root.appData.type === "grouped" && root.appData.windows?.length > 1) ||
                          (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows?.length > 1))
                onActivated: root.close()
            }

            DockMenuSeparator {
                visible: root.appData?.type === "window" ||
                    (root.appData?.type === "pinned" && root.appData?.isRunning && root.appData?.windows?.length > 1)
            }

            // ── Close / Close All — danger tint ───────────────────────────
            DockMenuRow {
                label:       "Close Window"
                iconName:    "close"
                isDanger:    true
                visible:     root.appData?.type === "window"
                onActivated: {
                    root.getToplevelObject()?.close()
                    root.close()
                }
            }

            DockMenuRow {
                label:    "Close All Windows"
                iconName: "close"
                isDanger: true
                visible:  root.appData && ((root.appData.type === "grouped" && root.appData.windows?.length > 1) ||
                          (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows?.length > 1))
                onActivated: {
                    if (root.appData?.windows)
                        for (var i = 0; i < root.appData.windows.length; i++)
                            root.appData.windows[i].toplevel?.close()
                    root.close()
                }
            }
        }
    }

    // Close on outside click
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
