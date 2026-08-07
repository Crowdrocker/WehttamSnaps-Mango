import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Dock.DockControlCenter.Components
import qs.Modules.Dock.DockControlCenter.Models

/**
 * TopBarControlCenterPopout
 *
 * Control center popout anchored to a bar button. Supports top/bottom/left/right
 * bar positions and left/right horizontal alignment.
 */
Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────────
    property string expandedSection: ""
    property bool powerOptionsExpanded: false
    property bool editMode: false
    property int expandedWidgetIndex: -1

    // ── Positioning ───────────────────────────────────────────────────────
    property string barPosition: "top"   // "top" | "bottom" | "left" | "right"
    property string menuSection: "right" // "left" | "right"
    property real barThickness: SettingsData.topBarHeight
    property real popupDistance: 8

    property var anchorItem: null
    property real anchorWidth: 0
    property var parentScreen: null

    property real _anchorX: 0
    property real _anchorY: 0

    // External trigger position API (set by TaskBarWidgets / DockWidgets)
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0

    // ── Visibility ────────────────────────────────────────────────────────
    property bool showMenu: false

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested

    function toggle() { showMenu ? close() : open() }
    function open()   { showMenu = true }
    function close()  { showMenu = false }

    function openAt(x, y, width, barPos, barThick, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width || 0
        if (barPos) barPosition = barPos
        if (barThick) barThickness = barThick
        if (screen) parentScreen = screen
        if (menuWindow && menuWindow.visible) menuWindow.updatePosition()
        showMenu = true
    }

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX     = x
        triggerY     = y
        triggerWidth = width
        _anchorX    = x
        _anchorY    = y
        anchorWidth = width
        parentScreen = screen
        menuSection = section || "right"

        if (screen && menuWindow) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i] === screen) {
                    menuWindow.screen = Quickshell.screens[i]
                    break
                }
            }
            if (menuWindow.visible) menuWindow.updatePosition()
        }
    }

    function showContextMenu(x, y, screen) {}

    function toggleSection(section) {
        if (root.expandedSection === section) {
            root.expandedSection = ""
            root.expandedWidgetIndex = -1
        } else {
            root.expandedSection = section
        }
    }

    // ── Widget model ──────────────────────────────────────────────────────
    WidgetModel { id: widgetModel }

    // ── Panel window ──────────────────────────────────────────────────────
    PanelWindow {
        id: menuWindow
        visible: root.showMenu
        WlrLayershell.namespace: "quickshell:dock:blur"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors { top: true; left: true; right: true; bottom: true }

        property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

        onVisibleChanged: { if (visible) updatePosition() }

        function updatePosition() {
            // PanelWindow with anchors { top/left/right/bottom: true } and
            // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
            // Do NOT add screen.x / screen.y here — those are global compositor
            // offsets and would double-displace the popup on any monitor whose
            // virtual-desktop origin is not 0,0 (e.g. a bottom monitor in a
            // stacked layout).
            if (!root.parentScreen) {
                anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                return
            }

            const barUi = (Appearance.combinedScale || 1) * (SettingsData.topbarScale || 1)
            const bar   = root.barThickness * barUi
            const dist  = (root.popupDistance + 15) * barUi
            const useTrigger = root.triggerWidth > 0
            let tx, ty

            switch (root.barPosition) {
            case "top":
                tx = useTrigger ? (root.triggerX + root.triggerWidth / 2) : (screen.width / 2)
                ty = bar + dist
                break
            case "bottom":
                tx = useTrigger ? (root.triggerX + root.triggerWidth / 2) : (screen.width / 2)
                ty = screen.height - bar - dist
                break
            case "left":
                tx = bar + dist
                ty = useTrigger ? (root.triggerY + root.triggerWidth / 2) : (screen.height / 2)
                break
            case "right":
                tx = screen.width - bar - dist
                ty = useTrigger ? (root.triggerY + root.triggerWidth / 2) : (screen.height / 2)
                break
            default:
                tx = screen.width  / 2
                ty = screen.height / 2
            }

            anchorPos = Qt.point(tx, ty)
        }

        // ── Menu card ─────────────────────────────────────────────────────
        Rectangle {
            id: menuContainer

            // Content sizing should NOT balloon with topbarScale.
            // Use global UI scale × controlCenterScale for consistent popout size.
            readonly property real contentScale: (Appearance.combinedScale || 1) * (SettingsData.controlCenterScale || 1.0)
            function spx(px) { return Math.round(px * contentScale) }

            readonly property real _minW: spx(560)
            readonly property real _maxW: spx(780)
            readonly property real _margin: spx(10)
            readonly property real _availW: Math.max(0, menuWindow.screen.width - _margin * 2)
            readonly property real _availH: Math.max(0, menuWindow.screen.height - _margin * 2)

            width: Math.min(_availW, Math.min(_maxW, Math.max(_minW, menuColumn.implicitWidth + Theme.spacingL * 2)))
            height: Math.min(_availH, Math.max(spx(200), menuColumn.childrenRect.height + Theme.spacingL * 2 + 14))

            onWidthChanged:  menuWindow.updatePosition()
            onHeightChanged: menuWindow.updatePosition()

            // ── X position ────────────────────────────────────────────────
            x: {
                const margin = menuContainer._margin
                const screenW = menuWindow.screen.width
                // For left/right bars: snap to the correct side
                if (root.barPosition === "left")  return Math.max(margin, menuWindow.anchorPos.x)
                if (root.barPosition === "right")  return Math.min(screenW - width - margin, menuWindow.anchorPos.x - width)
                // For top/bottom bars: centre on anchor, bias by menuSection
                const centred = menuWindow.anchorPos.x - width / 2
                const biasedL = menuWindow.anchorPos.x - width + menuContainer.spx(40)
                const biasedR = menuWindow.anchorPos.x - menuContainer.spx(40)
                const want = root.menuSection === "left" ? biasedL : (root.menuSection === "right" ? biasedR : centred)
                return Math.max(margin, Math.min(screenW - width - margin, want))
            }

            // ── Y position ────────────────────────────────────────────────
            y: {
                const margin   = menuContainer._margin
                const screenH  = menuWindow.screen.height
                if (root.barPosition === "top")    return Math.max(margin, menuWindow.anchorPos.y)
                if (root.barPosition === "bottom")  return Math.min(screenH - height - margin, menuWindow.anchorPos.y - height)
                // Left/right: centre vertically on anchor
                const want = menuWindow.anchorPos.y - height / 2
                return Math.max(margin, Math.min(screenH - height - margin, want))
            }

            // ── Appearance ────────────────────────────────────────────────
            color: Qt.rgba(
                Theme.surfaceContainer.r,
                Theme.surfaceContainer.g,
                Theme.surfaceContainer.b,
                Math.max(0.5, SettingsData.controlCenterTransparency || 0.85)
            )
            radius: Theme.cornerRadius + 2
            border.color: SettingsData.controlCenterDynamicBorderColors
                             ? Theme.primary
                             : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                                   SettingsData.controlCenterBorderOpacity || 0.30)
            border.width: SettingsData.controlCenterBorderEnabled ? Math.max(1, SettingsData.controlCenterBorderThickness || 1) : 0
            antialiasing: true
            smooth: true

            opacity: root.showMenu ? 1 : 0
            scale:   root.showMenu ? 1 : 0.93

            // Scale origin: grow from the bar edge where the button lives
            transformOrigin: {
                switch (root.barPosition) {
                case "top":    return root.menuSection === "left" ? Item.TopLeft  : Item.TopRight
                case "bottom": return root.menuSection === "left" ? Item.BottomLeft : Item.BottomRight
                case "left":   return Item.Left
                case "right":  return Item.Right
                default:       return Item.Top
                }
            }

            // ── Content column ────────────────────────────────────────────
            Column {
                id: menuColumn
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingM

                HeaderPane {
                    width: parent.width
                    powerOptionsExpanded: root.powerOptionsExpanded
                    editMode: root.editMode
                    onPowerOptionsExpandedChanged: root.powerOptionsExpanded = powerOptionsExpanded
                    onEditModeToggled: root.editMode = !root.editMode
                    onPowerActionRequested: (action, title, message) =>
                        root.powerActionRequested(action, title, message)
                    onLockRequested: {
                        root.close()
                        root.lockRequested()
                    }
                }

                PowerOptionsPane {
                    width: parent.width
                    expanded: root.powerOptionsExpanded
                    onPowerActionRequested: (action, title, message) => {
                        root.powerOptionsExpanded = false
                        root.close()
                        root.powerActionRequested(action, title, message)
                    }
                }

                WidgetGrid {
                    width: parent.width
                    editMode: root.editMode
                    expandedSection: root.expandedSection
                    expandedWidgetIndex: root.expandedWidgetIndex
                    model: widgetModel
                    onExpandClicked: (widgetData, globalIndex, x, y, width, height) => {
                        root.expandedWidgetIndex = globalIndex
                        root.toggleSection(widgetData.id)
                    }
                    onRemoveWidget:    (index)           => widgetModel.removeWidget(index)
                    onMoveWidget:      (fromIndex, toIndex) => widgetModel.moveWidget(fromIndex, toIndex)
                    onToggleWidgetSize:(index)           => widgetModel.toggleWidgetSize(index)
                }

                EditControls {
                    width: parent.width
                    visible: root.editMode
                    availableWidgets: {
                        const existingIds = (SettingsData.controlCenterWidgets || []).map(w => w.id)
                        return widgetModel.baseWidgetDefinitions.filter(w => !existingIds.includes(w.id))
                    }
                    onAddWidget:      (widgetId) => widgetModel.addWidget(widgetId)
                    onResetToDefault: ()         => widgetModel.resetToDefault()
                    onClearAll:       ()         => widgetModel.clearAll()
                }
            }

            // ── Animations ────────────────────────────────────────────────
            Behavior on opacity {
                NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.mediumDuration; easing.type: Easing.OutCubic }
            }
        }

        // Dismiss on background click
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.close()
        }
    }
}
