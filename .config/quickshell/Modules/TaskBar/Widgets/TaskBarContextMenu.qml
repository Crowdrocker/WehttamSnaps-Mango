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
    property real taskBarVisibleHeight: 40
    property int  margin: 10
    property bool workspaceOptionsVisible: false
    property var  desktopEntry: null

    // ── Scale & sizing ────────────────────────────────────────────────────────
    // Match TaskBar scaling: global UI × taskbar scale.
    readonly property real sc: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    readonly property real rowH:        Math.round(32 * sc)
    readonly property real headerH:     Math.round(44 * sc)
    readonly property real iconSz:      Math.round(16 * sc)
    readonly property real trailingSz:  Math.round(14 * sc)
    readonly property real headerIconSz:Math.round(20 * sc)
    readonly property real sepH:        Math.max(1, Math.round(1 * sc))
    readonly property real padH:        Math.round(Theme.spacingS  * sc)
    readonly property real padM:        Math.round(Theme.spacingM  * sc)
    readonly property real padXS:       Math.round(Theme.spacingXS * sc)
    readonly property real minW:        Math.round(220 * sc)
    readonly property real maxW:        Math.round(320 * sc)
    readonly property real radius:      Math.round((Theme.widgetRadius + 2) * sc)
    readonly property real popupGap:    Math.round(12 * sc)

    // ── Inline components ─────────────────────────────────────────────────────

    component TBMenuSeparator: Rectangle {
        width:  parent.width
        height: root.sepH
        color:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
    }

    component TBMenuRow: Item {
        id: row
        property string label:    ""
        property string iconName: ""
        property string iconSrc:  ""
        property string trailing: ""
        property bool   indented: false
        property bool   isDanger: false
        signal activated()

        width:  parent.width
        height: root.rowH

        Rectangle {
            anchors.fill: parent
            radius: Theme.widgetRadius
            color: rowMa.containsMouse
                ? (row.isDanger
                    ? Qt.rgba(Theme.error.r,   Theme.error.g,   Theme.error.b,   0.12)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12))
                : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Row {
            anchors {
                left:           parent.left
                leftMargin:     row.indented ? root.padM + root.padH : root.padM
                right:          parent.right
                rightMargin:    root.padM
                verticalCenter: parent.verticalCenter
            }
            spacing: root.padH

            // Leading icon
            Item {
                width:  root.iconSz
                height: root.iconSz
                anchors.verticalCenter: parent.verticalCenter
                visible: row.iconName !== "" || row.iconSrc !== ""

                EHIcon {
                    anchors.fill: parent
                    name:    row.iconName
                    size:    root.iconSz
                    color:   row.isDanger ? Theme.error : Theme.surfaceText
                    visible: row.iconName !== ""
                }
                Image {
                    anchors.fill: parent
                    source:       row.iconSrc
                    smooth:       true
                    asynchronous: true
                    fillMode:     Image.PreserveAspectFit
                    visible:      row.iconName === "" && row.iconSrc !== ""
                }
            }

            // Label — fills remaining space
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text:           row.label
                font.pixelSize: Math.round(Theme.fontSizeSmall * root.sc)
                font.weight:    400
                color:          row.isDanger ? Theme.error : Theme.surfaceText
                elide:          Text.ElideRight
                width:          parent.width
                                - (row.iconName !== "" || row.iconSrc !== "" ? root.iconSz    + root.padH : 0)
                                - (row.trailing !== ""                       ? root.trailingSz + root.padH : 0)
            }

            // Trailing icon
            EHIcon {
                anchors.verticalCenter: parent.verticalCenter
                name:    row.trailing
                size:    root.trailingSz
                color:   Theme.surfaceTextMedium
                visible: row.trailing !== ""
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    row.activated()
        }
    }

    // ── API ───────────────────────────────────────────────────────────────────

    function showForButton(button, data, taskBarHeight, entry) {
        if (showContextMenu && anchorItem === button) { close(); return }
        anchorItem           = button
        appData              = data
        taskBarVisibleHeight = taskBarHeight || 40
        desktopEntry         = entry || null
        root.workspaceOptionsVisible = false

        const taskBarWindow = button.Window.window
        if (taskBarWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i]
                if (taskBarWindow.x >= s.x && taskBarWindow.x < s.x + s.width) {
                    root.screen = s; break
                }
            }
        }
        showContextMenu = true
    }

    function close() { showContextMenu = false }

    function getToplevelObject() {
        if (!appData || (appData.type !== "window" && appData.type !== "pinned" && appData.type !== "grouped"))
            return null
        if (appData.type === "pinned" && appData.windows?.length > 0) {
            for (var i = 0; i < appData.windows.length; i++)
                if (appData.windows[i].toplevel?.activated) return appData.windows[i].toplevel
            return appData.windows[0].toplevel
        }
        if (appData.type === "grouped") {
            if (appData.windows?.length > 0) {
                for (var i = 0; i < appData.windows.length; i++)
                    if (appData.windows[i].toplevel?.activated) return appData.windows[i].toplevel
                return appData.windows[0].toplevel
            }
            return null
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

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onAnchorItemChanged: updatePosition()
    onVisibleChanged: { if (visible) updatePosition() }

    function updatePosition() {
        if (!anchorItem) { anchorPos = Qt.point(screen.width / 2, screen.height - 100); return }
        const taskBarWindow = anchorItem.Window.window
        if (!taskBarWindow) { anchorPos = Qt.point(screen.width / 2, screen.height - 100); return }

        const buttonPos = anchorItem.mapToItem(taskBarWindow.contentItem, 0, 0)

        // Resolve actual bar height from the background rect if available
        let tbH = root.taskBarVisibleHeight
        function findTaskBarBg(item) {
            if (item.objectName === "panelBackground") return item
            for (var i = 0; i < item.children.length; i++) {
                const f = findTaskBarBg(item.children[i])
                if (f) return f
            }
            return null
        }
        const bg = findTaskBarBg(taskBarWindow.contentItem)
        if (bg) tbH = bg.height

        // Account for float bottom margin — when the bar floats it sits above
        // the screen edge by taskBarBottomMargin, so the menu must rise further.
        const floatOffset = SettingsData.taskBarFloat ? (SettingsData.taskBarBottomMargin || 0) : 0

        const taskBarWindowX = taskBarWindow.x - root.screen.x
        const screenX = taskBarWindowX + buttonPos.x + anchorItem.width / 2
        const screenY = root.screen.height - tbH - floatOffset - root.popupGap

        anchorPos = Qt.point(screenX, screenY)
    }

    // ── Menu container ────────────────────────────────────────────────────────
    // Clipped Item so menuBg's bottom rounded corners fall outside the clip
    // boundary, giving a flat bottom that sits flush against the taskbar.

    Item {
        id: menuContainer

        width:  Math.min(root.maxW, Math.max(root.minW, menuColumn.implicitWidth + root.padM * 2))
        height: menuColumn.implicitHeight + root.padH * 2

        x: Math.max(root.margin, Math.min(root.width  - width  - root.margin, root.anchorPos.x - width / 2))
        y: Math.max(root.margin, root.anchorPos.y - height)

        clip:    false
        opacity: showContextMenu ? 1 : 0
        scale:   showContextMenu ? 1 : 0.92

        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
        Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        // Drop shadow
        Rectangle {
            anchors { fill: parent; topMargin: root.sepH * 4; leftMargin: root.sepH * 2; rightMargin: -(root.sepH * 2); bottomMargin: -(root.sepH * 4) }
            radius: root.radius
            color:  Qt.rgba(0, 0, 0, 0.18)
            z:      -1
        }

        // Background — fully rounded on all four corners
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color:        Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1
        }

        // ── Menu content ──────────────────────────────────────────────────────
        Column {
            id: menuColumn
            width: parent.width - root.padM * 2
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: root.padH }
            spacing: 0

            // ── App header ────────────────────────────────────────────────────
            Item {
                width:   parent.width
                height:  root.desktopEntry ? root.headerH : 0
                visible: root.desktopEntry

                Row {
                    anchors { left: parent.left; leftMargin: root.padM; verticalCenter: parent.verticalCenter }
                    spacing: root.padH

                    Item {
                        width:  root.headerIconSz
                        height: root.headerIconSz
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.desktopEntry?.icon !== undefined && root.desktopEntry?.icon !== ""

                        IconImage {
                            anchors.fill: parent
                            source: root.desktopEntry?.icon ? Quickshell.iconPath(root.desktopEntry.icon, true) : ""
                            smooth: true; asynchronous: true
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.desktopEntry?.name ?? (root.appData?.appId ?? "")
                        font.pixelSize: Math.round(Theme.fontSizeMedium * root.sc)
                        font.weight:    600
                        color:          Theme.surfaceText
                    }
                }
            }

            TBMenuSeparator { visible: root.desktopEntry !== null }

            // ── Desktop entry actions ─────────────────────────────────────────
            Repeater {
                model: root.desktopEntry?.actions ?? []
                TBMenuRow {
                    label:   modelData.name ?? ""
                    iconSrc: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    onActivated: {
                        if (modelData && root.desktopEntry)
                            SessionService.launchDesktopAction(root.desktopEntry, modelData)
                        root.close()
                    }
                }
            }

            TBMenuSeparator { visible: (root.desktopEntry?.actions?.length ?? 0) > 0 }

            // ── Pin / Unpin ───────────────────────────────────────────────────
            TBMenuRow {
                label:    root.appData?.isPinned ? "Unpin from Task Bar" : "Pin to Task Bar"
                iconName: "push_pin"
                onActivated: {
                    if (!root.appData) return
                    root.appData.isPinned
                        ? SessionData.removePinnedApp(root.appData.appId)
                        : SessionData.addPinnedApp(root.appData.appId)
                    root.close()
                }
            }

            // ── New Window ────────────────────────────────────────────────────
            TBMenuRow {
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

            // ── Launch on dGPU ────────────────────────────────────────────────
            TBMenuRow {
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

            TBMenuSeparator {
                visible: root.appData && (root.appData.type === "window" || root.appData.type === "pinned")
            }

            // ── Window list (grouped / pinned multi-window) ───────────────────
            Repeater {
                model: (root.appData?.windows?.length > 0 &&
                        (root.appData.type === "grouped" ||
                         (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows.length > 1)))
                    ? root.appData.windows : []

                TBMenuRow {
                    label:    modelData?.truncatedTitle ?? ""
                    iconName: "web_asset"
                    onActivated: {
                        modelData?.toplevel?.activate()
                        root.close()
                    }
                }
            }

            // ── Move to Workspace ─────────────────────────────────────────────
            TBMenuRow {
                label:    "Move to Workspace"
                iconName: "grid_view"
                visible:  root.appData?.type === "window"
                trailing: root.workspaceOptionsVisible ? "expand_less" : "chevron_right"
                onActivated: root.workspaceOptionsVisible = !root.workspaceOptionsVisible
            }

            Repeater {
                model: root.appData?.type === "window" && root.workspaceOptionsVisible
                    ? SettingsData.maxWorkspaces : 0

TBMenuRow {
                          label:    "Workspace " + (index + 1)
                          iconName: ""
                          indented: true
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

            // ── Toggle Floating ───────────────────────────────────────────────
            TBMenuRow {
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

            TBMenuSeparator {
                visible: root.appData && (root.appData.type === "window" ||
                    (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows?.length > 1))
            }

            // ── Minimize / Minimize All ───────────────────────────────────────
            TBMenuRow {
                label:    "Minimize Window"
                iconName: "remove"
                visible:  root.appData && (root.appData.type === "window" || root.appData.type === "pinned")
                onActivated: root.close()
            }

            TBMenuRow {
                label:    "Minimize All Windows"
                iconName: "remove"
                visible:  root.appData && ((root.appData.type === "grouped" && root.appData.windows?.length > 1) ||
                          (root.appData.type === "pinned" && root.appData.isRunning && root.appData.windows?.length > 1))
                onActivated: root.close()
            }

            TBMenuSeparator {
                visible: root.appData?.type === "window" ||
                    (root.appData?.type === "pinned" && root.appData?.isRunning && root.appData?.windows?.length > 1)
            }

            // ── Close / Close All — danger tint ───────────────────────────────
            TBMenuRow {
                label:       "Close Window"
                iconName:    "close"
                isDanger:    true
                visible:     root.appData?.type === "window"
                onActivated: {
                    root.getToplevelObject()?.close()
                    root.close()
                }
            }

            TBMenuRow {
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
