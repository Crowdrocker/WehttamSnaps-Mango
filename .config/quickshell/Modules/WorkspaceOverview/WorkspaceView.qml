pragma ComponentBehavior: Bound

import qs.Common
import qs.Widgets
import Quickshell
import Quickshell.Hyprland
import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets

ClippingRectangle {
  id: root
  visible: true

  required property int index
  required property Item parentWindow
  required property var screen          // the WaylandScreen this overview lives on
  property bool isActive: false
  property bool isHovered: false
  property bool isDragging: false  // set true by any active DragHandler inside

  signal windowActivated()  // emitted when user clicks a window or empty tile space

  property HyprlandWorkspace wsp: Hyprland.workspaces.values.find(s => s.id == (index + 1)) || null
  property real scaleFactor: (wsp?.monitor) ? ((wsp.monitor.width / wsp.monitor.scale) / implicitWidth) : -1
  property bool hasWindows: wsp && wsp.toplevels && wsp.toplevels.values && wsp.toplevels.values.length > 0

  // The Hyprland monitor this workspace lives on (may differ from the overview's monitor)
  readonly property var wspMonitor: wsp?.monitor ?? null

  // True when this workspace is the active one on whichever monitor it belongs to
  readonly property bool isActiveWorkspace: wspMonitor?.activeWorkspace?.id === (index + 1)

  // The WaylandScreen corresponding to the workspace's monitor — used for screencopy.
  // Falls back to root.screen if no match (e.g. workspace not yet assigned to a monitor).
  readonly property var captureScreen: {
    if (!wspMonitor) return root.screen
    const screens = Quickshell.screens || []
    return screens.find(s => s.name === wspMonitor.name) ?? root.screen
  }

  // ── Tile background ───────────────────────────────────────────────────────
  // For the active workspace we screencopy the whole monitor (wallpaper + windows).
  // For inactive workspaces we fall back to the themed colour; Hyprland does not
  // render off-screen workspaces so a full capture is not possible there.
  color: isActiveWorkspace
    ? "transparent"
    : (isActive
      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
      : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6))
  // Drop the tile comment about Hyprland not rendering off-screen workspaces —
  // we now capture whichever monitor the workspace is assigned to
  Behavior on color { ColorAnimation { duration: 150 } }

  radius: Theme.cornerRadius

  border.width: isActive ? 2 : 1
  border.color: isActive
    ? Theme.primary
    : (isHovered
      ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
      : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2))
  Behavior on border.color { ColorAnimation { duration: 150 } }
  Behavior on border.width { NumberAnimation { duration: 150 } }

  // ── Full monitor screencopy ──────────────────────────────────────────────
  // Shown whenever this workspace is the active one on its monitor — whether
  // that monitor is the same as the overview's or a different display entirely.
  ScreencopyView {
    anchors.fill: parent
    captureSource: root.captureScreen
    live: true
    visible: root.isActiveWorkspace
    z: 0
  }

  // ── Tile click: switch to this workspace ─────────────────────────────────
  // z:-1 so window items always receive pointer events first.
  MouseArea {
    anchors.fill: parent
    z: -1
    onClicked: {
      Hyprland.dispatch("hl.dsp.focus({workspace = " + (root.index + 1) + "})")
      root.windowActivated()
    }
  }

  // ── Drop target: accept windows dragged from other tiles ─────────────────
  DropArea {
    anchors.fill: parent
    z: 100
    onDropped: function(drag) {
      console.log("Drop received, source:", drag.source, "address:", drag.source?.address)
      const addr = drag.source.address
      const workspaceId = root.index + 1
      // Hyprland 0.55+ uses Lua-style dispatchers: hl.dsp.window.move({workspace = id, window = "address:xxx"})
      const cmd = `hl.dsp.window.move({workspace = ${workspaceId}, window = 'address:${addr}'})`
      console.log("Dispatching:", cmd)
      Hyprland.dispatch(cmd)
      Hyprland.refreshWorkspaces()
      Hyprland.refreshMonitors()
      Hyprland.refreshToplevels()
    }
  }

  // ── Scroll wheel: cycle focus through open apps ───────────────────────────
  WheelHandler {
    target: null
    acceptedDevices: PointerDevice.Mouse
    onWheel: function(event) {
      if (event.angleDelta.y < 0)
        Hyprland.dispatch("cyclenext")
      else if (event.angleDelta.y > 0)
        Hyprland.dispatch("cyclenext prev")
    }
  }

  // ── Connections to keep toplevels fresh ──────────────────────────────────
  Connections {
    target: root.wsp ? root.wsp.toplevels : null
    function onObjectInsertedPost() { Hyprland.refreshToplevels() }
    function onObjectRemovedPre()   { Hyprland.refreshToplevels() }
    function onObjectRemovedPost()  { Hyprland.refreshToplevels() }
    function onObjectInsertedPre()  { Hyprland.refreshToplevels() }
  }

  // ── Workspace number label (top-left, like GNOME) ─────────────────────────
  Rectangle {
    id: numberBadge
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 8
    width: numberText.implicitWidth + 10
    height: 20
    radius: 10
    color: root.isActive
      ? Theme.primary
      : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
    Behavior on color { ColorAnimation { duration: 150 } }

    StyledText {
      id: numberText
      anchors.centerIn: parent
      text: root.index + 1
      font.pixelSize: Theme.fontSizeXSmall
      font.weight: Font.Medium
      color: root.isActive ? Theme.primaryText : Theme.surfaceVariantText
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  // ── Empty workspace placeholder ───────────────────────────────────────────
  Column {
    anchors.centerIn: parent
    spacing: 6
    visible: !root.hasWindows && !root.isActiveWorkspace
    opacity: 0.35

    EHIcon {
      anchors.horizontalCenter: parent.horizontalCenter
      name: "desktop_windows"
      size: Math.min(root.width, root.height) * 0.22
      color: root.isActive ? Theme.primary : Theme.surfaceText
    }

    StyledText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Empty"
      font.pixelSize: Theme.fontSizeXSmall
      color: root.isActive ? Theme.primary : Theme.surfaceText
    }
  }

  // ── Live window thumbnails (all workspaces) ──────────────────────────────
  // Shown on every workspace — ScreencopyView (z:0) is the desktop behind these (z:1).
  Repeater {
    model: root.wsp ? root.wsp.toplevels : []

    Item {
      id: windowItem
      // Smaller windows get a higher z so they aren't buried by larger neighbours.
      // This also means their TapHandler receives events first when windows overlap.
      z: 1 + (root.width * root.height > 0
               ? (1 - (width * height) / (root.width * root.height)) * 10
               : 0)

      required property HyprlandToplevel modelData
      property string address: {
        const a = modelData.lastIpcObject.address ?? ""
        return a.toString().startsWith("0x") ? a : `0x${a}`
      }
      property bool windowHovered: windowHoverHandler.hovered

      x: (modelData.lastIpcObject.at && root.wsp?.monitor)
        ? ((modelData.lastIpcObject.at[0] - root.wsp.monitor.x) / root.scaleFactor)
        : 0
      y: (modelData.lastIpcObject.at && root.wsp?.monitor)
        ? ((modelData.lastIpcObject.at[1] - root.wsp.monitor.y) / root.scaleFactor)
        : 0
      width: (modelData.lastIpcObject.size && root.scaleFactor > 0)
        ? (modelData.lastIpcObject.size[0] / root.scaleFactor)
        : 0
      height: (modelData.lastIpcObject.size && root.scaleFactor > 0)
        ? (modelData.lastIpcObject.size[1] / root.scaleFactor)
        : 0

      // Subtle highlight on hover
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
        radius: 4
        opacity: windowItem.windowHovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        z: 2
      }

      ScreencopyView {
        id: scView
        width:  windowItem.width
        height: windowItem.height
        captureSource: windowItem.modelData.wayland
        live: true

        Component.onCompleted: Hyprland.refreshToplevels()

        DragHandler {
          id: dragHandler
          target: scView
          // Give drag exclusive grab so TapHandler doesn't interfere mid-drag
          grabPermissions: PointerHandler.CanTakeOverFromAnything
          onActiveChanged: {
            root.isDragging = active
            if (!active) target.Drag.drop()
          }
        }

        Drag.active: dragHandler.active
        Drag.source: windowItem
        Drag.supportedActions: Qt.MoveAction
        Drag.hotSpot.x: scView.width / 2
        Drag.hotSpot.y: scView.height / 2

        states: [
          State {
            when: dragHandler.active
            ParentChange { target: scView; parent: root.parentWindow }
            PropertyChanges { target: scView; width: windowItem.width; height: windowItem.height }
          }
        ]
      }

      // ── App name tooltip on hover ─────────────────────────────────────────
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 4
        width: Math.min(appLabel.implicitWidth + 12, parent.width - 8)
        height: 18
        radius: 6
        color: Qt.rgba(0, 0, 0, 0.65)
        visible: windowItem.windowHovered && parent.width > 40
        opacity: windowItem.windowHovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        z: 3
        clip: true

        StyledText {
          id: appLabel
          anchors.centerIn: parent
          text: windowItem.modelData.lastIpcObject.class ?? ""
          font.pixelSize: Theme.fontSizeXSmall
          color: "#ffffff"
          elide: Text.ElideRight
          width: parent.width - 8
          horizontalAlignment: Text.AlignHCenter
        }
      }

      // HoverHandler for cursor tracking — cooperates with DragHandler natively
      HoverHandler {
        id: windowHoverHandler
      }

      // TapHandler for click-to-focus — cooperates with DragHandler without
      // stealing the pointer grab the way MouseArea does.
      TapHandler {
        id: windowTapHandler
        // Only take the grab if DragHandler hasn't already claimed it
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesTakeOverByHandlers
        onTapped: {
      Hyprland.dispatch("hl.dsp.focus({workspace = " + (root.index + 1) + "})")
          Hyprland.dispatch("hl.dsp.window.focus({address = 'address:" + windowItem.address + "'})")
          root.windowActivated()
        }
      }
    }
  }
}
