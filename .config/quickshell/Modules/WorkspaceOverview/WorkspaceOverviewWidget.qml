pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services

// One instance per screen — visibility gated by screenPreferences["workspaceOverview"]
Variants {
  id: root
  model: Quickshell.screens

  // Public API — called from keybind / toggle button
  function show()   { _forEachDelegate(d => d.show())   }
  function hide()   { _forEachDelegate(d => d.hide())   }
  function close()  { _forEachDelegate(d => d.close())  }
  function toggle() { _forEachDelegate(d => d.toggle()) }

  function _forEachDelegate(fn) {
    for (let i = 0; i < root.instances.length; i++)
      fn(root.instances[i])
  }

  QtObject {
    id: screenDelegate
    required property var modelData
    readonly property var screen: modelData
    readonly property string screenName: screen?.name ?? ""

    // Mirror the shouldShowOnScreen logic from DesktopWidgetLayer / DisplaysTab
    function shouldShowOnScreen() {
      const prefs = SettingsData.screenPreferences?.["workspaceOverview"]
      if (!prefs || prefs.length === 0 || prefs.includes("all"))
        return true
      return prefs.some(p => typeof p === "string" ? p === screenName : p?.name === screenName)
    }

    // ── Per-screen sizing ───────────────────────────────────────────────────
    readonly property real spacing:  SettingsData.workspaceOverviewSpacing
    readonly property real columns:  SettingsData.workspaceOverviewColumns
    readonly property real rows:     SettingsData.workspaceOverviewRows
    readonly property string position: SettingsData.workspaceOverviewPosition       // "top"|"center"|"bottom"

    readonly property real screenW: (screen?.width  / (screen?.scale ?? 1)) ?? 1920
    readonly property real screenH: (screen?.height / (screen?.scale ?? 1)) ?? 1080

    readonly property int totalTiles: rows * columns

    readonly property real tileWidth: (screenW / 1.5 * SettingsData.workspaceOverviewScale - spacing * (columns + 1)) / columns
    readonly property real tileHeight: tileWidth * 9 / 16

    readonly property real panelW: tileWidth * columns + spacing * (columns + 1)
    readonly property real panelH: tileHeight * rows + spacing * (rows + 1)

    // ── Visibility ──────────────────────────────────────────────────────────
    property bool shouldBeVisible: false
    function show()   { if (shouldShowOnScreen()) { shouldBeVisible = true;  overviewWindow.visible = true  } }
    function hide()   { shouldBeVisible = false; overviewWindow.visible = false }
    function close()  { hide() }
    function toggle() { if (shouldBeVisible) hide(); else show() }

    // ── Drag state ──────────────────────────────────────────────────────────
    property bool anyTileDragging: false

    // ── Window ──────────────────────────────────────────────────────────────
    property PanelWindow overviewWindow: PanelWindow {
      id: overviewWindow
      screen: screenDelegate.screen
      color: "transparent"
      visible: screenDelegate.shouldBeVisible

      WlrLayershell.namespace: "quickshell:dock:blur"
      WlrLayershell.layer: WlrLayershell.Overlay
      WlrLayershell.keyboardFocus: screenDelegate.shouldBeVisible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

      implicitWidth:  screenDelegate.panelW
      implicitHeight: screenDelegate.panelH

      anchors {
        top:    screenDelegate.position === "top"
        bottom: screenDelegate.position === "bottom"
      }

      HyprlandFocusGrab {
        active: screenDelegate.shouldBeVisible
        windows: [overviewWindow]
      }

      Rectangle {
        id: overviewWindowRect
        color: Theme.popupBackground()
        anchors.fill: parent
        radius: Theme.cornerRadius
        border.color: Theme.outlineMedium
        border.width: 1

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

        Repeater {
          id: tilesRepeater
          model: screenDelegate.totalTiles
          WorkspaceView {
            id: tile
            parentWindow: overviewWindowRect
            screen: screenDelegate.screen
            implicitWidth:  screenDelegate.tileWidth
            implicitHeight: screenDelegate.tileHeight

            x: screenDelegate.vertical
              ? screenDelegate.spacing
              : screenDelegate.spacing + (index % screenDelegate.columns) * (screenDelegate.tileWidth + screenDelegate.spacing)
            y: screenDelegate.vertical
              ? screenDelegate.spacing + index * (screenDelegate.tileHeight + screenDelegate.spacing)
              : screenDelegate.spacing + Math.floor(index / screenDelegate.columns) * (screenDelegate.tileHeight + screenDelegate.spacing)

            onIsDraggingChanged: {
              if (isDragging) {
                screenDelegate.anyTileDragging = true
              } else {
                let any = false
                for (let i = 0; i < tilesRepeater.count; i++) {
                  const t = tilesRepeater.itemAt(i)
                  if (t && t.isDragging) { any = true; break }
                }
                screenDelegate.anyTileDragging = any
              }
            }

            onWindowActivated: screenDelegate.hide()
          }
        }
      }
    }
  }
}
