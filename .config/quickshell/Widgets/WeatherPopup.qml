import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"

    property bool showPopup: false
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0
    property var parentScreen: null
    property string barPosition: "bottom"
    property real barThickness: 48

    function open() {
        if (parentScreen) {
            root.screen = parentScreen
        } else {
            root.screen = Quickshell.screens[0]
        }
        showPopup = true
    }

    function close() {
        showPopup = false
    }

    screen: Quickshell.screens[1] ?? Quickshell.screens[0]
    visible: showPopup
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property point anchorPos: Qt.point(screen.width / 2, screen.height - 100)

    onVisibleChanged: {
        if (visible) {
            updatePosition()
        }
    }

function updatePosition() {
        if (!parentScreen) {
            anchorPos = Qt.point(screen.width / 2, screen.height / 2)
            return
        }
        // NOTE: PanelWindow with anchors { top/left/right/bottom: true } and
        // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
        // Do NOT add screen.x / screen.y here — those are global compositor
        // offsets and would double-displace the popup on any monitor whose
        // virtual-desktop origin is not 0,0 (e.g. a bottom monitor in a
        // stacked layout).
        const scale = Appearance.uiScaleRatio || 1
        const thick = barThickness * scale
        const dist  = 10 * scale
        const off   = 15 * scale
        let tx, ty

        switch (barPosition) {
            case "top":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width  / 2)
                ty = thick + dist + off
                break
            case "bottom":
                tx = (triggerWidth > 0) ? (triggerX + triggerWidth / 2) : (screen.width  / 2)
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
                tx = screen.width  / 2
                ty = screen.height / 2
        }
        anchorPos = Qt.point(tx, ty)
    }

    PopupSurface {
        id: popupContainer

        width: Math.min(400, Math.max(350, weatherContent.implicitWidth + Theme.spacingM * 2))
        implicitHeight: Math.max(200, weatherContent.implicitHeight + Theme.spacingM * 2)

        x: Math.max(10, Math.min(root.screen.width - width - 10, root.anchorPos.x - width / 2))
        y: {
            const margin = 10
            if (root.barPosition === "top") {
                return Math.max(margin, root.anchorPos.y)
            } else if (root.barPosition === "bottom") {
                return Math.min(root.screen.height - height - margin, root.anchorPos.y - height)
            }
            const want = root.anchorPos.y - height / 2
            return Math.max(margin, Math.min(root.screen.height - height - margin, want))
        }

        surfaceColor: Theme.surfaceContainer
        surfaceAlpha: Math.max(0.55, SettingsData.weatherPopupTransparency || 0.95)
        wallpaperTintEnabled: SettingsData.desktopWidgetWallpaperColors || false
        wallpaperTintRole: "primary_container"
        radius: Theme.cornerRadius
        borderColor: SettingsData.weatherPopupDynamicBorderColors ? Theme.primary : Theme.outline
        borderAlpha: SettingsData.weatherPopupDynamicBorderColors ? 1.0 : (SettingsData.weatherPopupBorderOpacity || 0.30)
        borderWidth: SettingsData.weatherPopupBorderEnabled ? Math.max(2, SettingsData.weatherPopupBorderThickness || 2) : 0

        opacity: showPopup ? 1 : 0
        scale: showPopup ? 1 : 0.85

        shadowEnabled: true
        shadowColor: Theme.shadowMedium
        shadowAlpha: 1.0
        shadowTopMargin: 4
        shadowLeftMargin: 2
        shadowRightMargin: -2
        shadowBottomMargin: -4

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        WeatherPopupContent {
            id: weatherContent

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacingS
            }
            showCloseButton: true
            onCloseRequested: root.close()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}