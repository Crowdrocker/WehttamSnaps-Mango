import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets
import qs.Modules.Dock.DockControlCenter.Components
import qs.Modules.Dock.DockControlCenter.Models

/**
 * ControlCenterPopout
 *
 * Redesigned with a macOS Tahoe-style aesthetic:
 *   • Generous, consistent padding (spacingM throughout)
 *   • Larger corner radius for a rounder, softer card
 *   • Thinner, lower-opacity border — almost invisible
 *   • Subtle frosted-glass background
 *   • Smooth open/close scale + opacity animation
 */
Item {
    id: root

    // ─── Control Center state ─────────────────────────────────────────────────
    property string expandedSection:      ""
    property bool   powerOptionsExpanded: false
    property bool   editMode:             false
    property int    expandedWidgetIndex:  -1
    property real   scaleFactor:          Appearance.uiScaleRatio

    // ─── Positioning ──────────────────────────────────────────────────────────
    property string barPosition:   "bottom"   // "top" | "bottom" | "left" | "right"
    property real   barThickness:  48 * Appearance.uiScaleRatio
    property real   popupDistance: 10
    property real   triggerX:      0
    property real   triggerY:      0
    property real   triggerWidth:  0

    property bool   showMenu:     false
    property var    parentScreen: null

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    PowerConfirmationModal {
        id: powerConfirmationModal
        onConfirmed: function(action) {
            switch (action) {
                case "logout":    SessionService.logout();    break
                case "suspend":   SessionService.suspend();   break
                case "hibernate": SessionService.hibernate(); break
                case "reboot":    SessionService.reboot();    break
                case "poweroff":  SessionService.poweroff();  break
            }
        }
    }

    function requestPowerAction(action, title, message) {
        root.powerOptionsExpanded = false
        root.close()
        powerConfirmationModal.showConfirmation(action, title, message)
    }

    // ─── Public API ───────────────────────────────────────────────────────────
    function toggle() { showMenu ? close() : open() }
    function open()   { showMenu = true  }
    function close()  { showMenu = false }
    function showContextMenu(x, y, screen) { /* reserved */ }

    // ─── Widget model ─────────────────────────────────────────────────────────
    WidgetModel { id: widgetModel }

    // ─── Panel window ─────────────────────────────────────────────────────────
    PanelWindow {
        id: menuWindow
        visible: root.showMenu
        screen: root.parentScreen ?? Quickshell.screens[0]
        WlrLayershell.namespace:     "quickshell:dock:blur"
        WlrLayershell.layer:         WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors { top: true; left: true; right: true; bottom: true }

        property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

        onVisibleChanged: { if (visible) updatePosition() }

        function updatePosition() {
            if (!root.parentScreen) {
                anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                return
            }
            // NOTE: PanelWindow with anchors { top/left/right/bottom: true } and
            // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
            // Do NOT add screen.x / screen.y here — those are global compositor
            // offsets and would double-displace the popup on any monitor whose
            // virtual-desktop origin is not 0,0 (e.g. a bottom monitor in a
            // stacked layout).
            const scale = Appearance.uiScaleRatio
            const thick = root.barThickness
            const dist  = root.popupDistance * scale
            const off   = 15 * scale
            let tx, ty

            switch (root.barPosition) {
                case "top":
                    tx = (root.triggerWidth > 0) ? (root.triggerX + root.triggerWidth / 2) : (screen.width  / 2)
                    ty = thick + dist + off
                    break
                case "bottom":
                    tx = (root.triggerWidth > 0) ? (root.triggerX + root.triggerWidth / 2) : (screen.width  / 2)
                    ty = screen.height - thick - dist - off
                    break
                case "left":
                    tx = thick + dist + off
                    ty = (root.triggerWidth > 0) ? (root.triggerY + root.triggerWidth / 2) : (screen.height / 2)
                    break
                case "right":
                    tx = screen.width - thick - dist - off
                    ty = (root.triggerWidth > 0) ? (root.triggerY + root.triggerWidth / 2) : (screen.height / 2)
                    break
                default:
                    tx = screen.width  / 2
                    ty = screen.height / 2
            }
            anchorPos = Qt.point(tx, ty)
        }

        // ─── Card container ───────────────────────────────────────────────────
        Rectangle {
            id: menuContainer

            // Tahoe sizing: a bit wider, generous padding
            readonly property real _hPad: Theme.spacingM          // 16 px typical
            readonly property real _vPad: Theme.spacingM

            width:  Math.min(780 * Appearance.uiScaleRatio,
                             Math.max(560 * Appearance.uiScaleRatio,
                                      menuColumn.implicitWidth + _hPad * 2))
            height: Math.max(220 * Appearance.uiScaleRatio,
                             menuColumn.childrenRect.height + _vPad * 2 + 14)

            onWidthChanged:  menuWindow.updatePosition()
            onHeightChanged: menuWindow.updatePosition()

            // ── Horizontal clamping ──
            x: {
                const margin = 12 * Appearance.uiScaleRatio
                const want   = menuWindow.anchorPos.x - width / 2
                return Math.max(margin, Math.min(menuWindow.screen.width - width - margin, want))
            }

            // ── Vertical clamping ──
            y: {
                const margin = 12 * Appearance.uiScaleRatio
                if (root.barPosition === "top") {
                    return Math.max(margin, menuWindow.anchorPos.y)
                } else if (root.barPosition === "bottom") {
                    return Math.min(menuWindow.screen.height - height - margin,
                                   menuWindow.anchorPos.y - height)
                }
                const want = menuWindow.anchorPos.y - height / 2
                return Math.max(margin, Math.min(menuWindow.screen.height - height - margin, want))
            }

            // ── Tahoe card appearance ──
            color: Qt.rgba(
                Theme.surfaceContainer.r,
                Theme.surfaceContainer.g,
                Theme.surfaceContainer.b,
                Math.max(0.55, SettingsData.controlCenterTransparency || 0.88)
            )

            // Larger radius for that rounded Tahoe panel feel
            radius: Math.max(Theme.cornerRadius, 20)

            // Whisper-thin border — adds definition without heaviness
            border.color: SettingsData.controlCenterDynamicBorderColors
                             ? Theme.primary
                             : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                                   SettingsData.controlCenterBorderOpacity || 0.30)
            border.width: SettingsData.controlCenterBorderEnabled ? Math.max(1, SettingsData.controlCenterBorderThickness || 1) : 0

            antialiasing: true
            smooth: true

            transformOrigin: root.barPosition === "top"
                ? Item.TopRight
                : (root.barPosition === "left" ? Item.BottomLeft : Item.BottomRight)

            // ── Open/close animation (scale + opacity) ──
            property real _targetScale:   root.showMenu ? 1.0 : 0.96
            property real _targetOpacity: root.showMenu ? 1.0 : 0.0

            scale:   1.0
            opacity: 1.0

            Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // ── Inner layout ──
            Column {
                id: menuColumn
                width: parent.width - menuContainer._hPad * 2
                x: menuContainer._hPad
                y: menuContainer._vPad
                // Tahoe-style: uniform, slightly tighter section gap
                spacing: Theme.spacingS + 2

                HeaderPane {
                    id: headerPane
                    width: parent.width
                    powerOptionsExpanded: root.powerOptionsExpanded
                    editMode: root.editMode
                    onPowerOptionsExpandedChanged: root.powerOptionsExpanded = powerOptionsExpanded
                    onEditModeToggled: root.editMode = !root.editMode
                    onPowerActionRequested: (action, title, message) => {
                        root.requestPowerAction(action, title, message)
                    }
                    onLockRequested: {
                        root.close()
                        root.lockRequested()
                    }
                }

                // Subtle divider between header and widgets
                Rectangle {
                    width:  parent.width
                    height: 1
                    color:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    visible: !root.powerOptionsExpanded
                }

                PowerOptionsPane {
                    id: powerOptionsPane
                    width: parent.width
                    expanded: root.powerOptionsExpanded
                    onPowerActionRequested: (action, title, message) => {
                        root.requestPowerAction(action, title, message)
                    }
                }

                WidgetGrid {
                    id: widgetGrid
                    width: parent.width
                    editMode: root.editMode
                    expandedSection: root.expandedSection
                    expandedWidgetIndex: root.expandedWidgetIndex
                    model: widgetModel
                    onExpandClicked: (widgetData, globalIndex, x, y, width, height) => {
                        root.expandedWidgetIndex = globalIndex
                        root.toggleSection(widgetData.id)
                    }
                    onRemoveWidget:     (index)             => widgetModel.removeWidget(index)
                    onMoveWidget:       (fromIndex, toIndex) => widgetModel.moveWidget(fromIndex, toIndex)
                    onToggleWidgetSize: (index)             => widgetModel.toggleWidgetSize(index)
                }
            }
        }

        // Click-outside-to-dismiss
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.close()
        }
    }

    // ─── Section toggle ───────────────────────────────────────────────────────
    function toggleSection(section) {
        if (root.expandedSection === section) {
            root.expandedSection     = ""
            root.expandedWidgetIndex = -1
        } else {
            root.expandedSection = section
        }
    }
}
