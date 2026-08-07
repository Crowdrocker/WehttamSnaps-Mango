import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    // Match the stable popout pattern used by Calendar/Weather
    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showPopup: false
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0
    property var parentScreen: null
    property string barPosition: "bottom"
    // IMPORTANT: treat barThickness as already-scaled (the bar has already applied its own scale)
    property real barThickness: 48
    // Popup sizing scale (usually just `1.0` so it follows only combinedScale)
    property real panelScale: 1.0

    readonly property real ui: (Appearance.combinedScale || 1) * (panelScale || 1.0)
    function spx(px) { return Math.round(px * ui) }

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null

    function open() {
        if (parentScreen) {
            root.screen = parentScreen
        } else if (Quickshell.screens && Quickshell.screens.length > 0) {
            root.screen = Quickshell.screens[0]
        }
        showPopup = true
    }

    function close() {
        showPopup = false
    }

    // Prevent "open click" from immediately closing the popup
    property bool _backdropArmed: false
    Timer {
        id: _armBackdropTimer
        interval: 180
        repeat: false
        onTriggered: root._backdropArmed = true
    }

    screen: Quickshell.screens[1] ?? Quickshell.screens[0]
    visible: showPopup
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true; bottom: true }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onVisibleChanged: {
        if (visible) {
            root._backdropArmed = false
            _armBackdropTimer.restart()
            updatePosition()
        }
    }
    onScreenChanged: if (visible) updatePosition()
    onTriggerXChanged: if (visible) updatePosition()
    onTriggerYChanged: if (visible) updatePosition()
    onTriggerWidthChanged: if (visible) updatePosition()
    onBarPositionChanged: if (visible) updatePosition()
    onBarThicknessChanged: if (visible) updatePosition()

    function updatePosition() {
        if (!screen) return

        // NOTE: PanelWindow with anchors { top/left/right/bottom: true } and
        // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
        // Do NOT add screen.x / screen.y here — those are global compositor
        // offsets and would double-displace the popup on any monitor whose
        // virtual-desktop origin is not 0,0 (e.g. a bottom monitor in a
        // stacked layout).
        const scale = (Appearance.combinedScale || 1)
        const thick = barThickness
        const dist = 10 * scale
        const off = 15 * scale
        let tx, ty

        switch (barPosition) {
            case "top":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width / 2)
                ty = thick + dist + off
                break
            case "bottom":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width / 2)
                ty = screen.height - thick - dist - off
                break
            case "left":
                tx = thick + dist + off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (screen.height / 2)
                break
            case "right":
                tx = screen.width - thick - dist - off
                ty = (triggerWidth > 0) ? (triggerY + triggerWidth / 2) : (screen.height / 2)
                break
            default:
                tx = screen.width / 2
                ty = screen.height / 2
        }

        anchorPos = Qt.point(tx, ty)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root._backdropArmed) root.close()
        }
    }

    PopupSurface {
        id: popupContainer

        readonly property int margin: root.spx(12)
        readonly property int wantW: root.spx(420)
        readonly property int minW: root.spx(360)
        readonly property int maxW: root.spx(520)
        readonly property int outerPad: root.spx(14) // MediaPopupContent margins from surface

        width: Math.max(minW, Math.min(maxW, wantW))
        implicitHeight: Math.max(root.spx(260), col.implicitHeight + outerPad * 2)
        height: implicitHeight

        x: Math.max(margin, Math.min(root.screen.width - width - margin, root.anchorPos.x - width / 2))
        y: {
            if (root.barPosition === "top") {
                return Math.max(margin, root.anchorPos.y)
            } else if (root.barPosition === "bottom") {
                return Math.min(root.screen.height - height - margin, root.anchorPos.y - height)
            }
            const want = root.anchorPos.y - height / 2
            return Math.max(margin, Math.min(root.screen.height - height - margin, want))
        }

        radius: root.spx(22)
        surfaceColor: Theme.surfaceContainer
        surfaceAlpha: SettingsData.mediaPopupTransparency || 0.95
        wallpaperTintEnabled: SettingsData.desktopWidgetWallpaperColors || false
        wallpaperTintRole: "primary_container"
        borderColor: SettingsData.mediaPopupDynamicBorderColors ? Theme.primary : Theme.outline
        borderAlpha: SettingsData.mediaPopupDynamicBorderColors ? 1.0 : (SettingsData.mediaPopupBorderOpacity || 0.30)
        borderWidth: SettingsData.mediaPopupBorderEnabled ? Math.max(2, SettingsData.mediaPopupBorderThickness || 2) : 0

        layer.enabled: false

        MouseArea {
            anchors.fill: parent
            onClicked: {} // swallow inside clicks so backdrop closes only outside
        }

        MediaPopupContent {
            id: col
            anchors.fill: parent
            anchors.margins: root.spx(14)
            activePlayer: root.activePlayer
            ui: root.ui
            showCloseButton: true
            onCloseRequested: root.close()
        }
    }
}
