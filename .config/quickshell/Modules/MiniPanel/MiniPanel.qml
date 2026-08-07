import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.MiniPanel.Widgets
import qs.Modules.MiniPanel.MiniPanelControlCenter
import qs.Modules.MiniPanel.MiniPanelAppDrawer
import qs.Modules.Applications
import "../../Common/PowerActionUtils.js" as PowerActionUtils

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:dock:blur"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var modelData
    screen: modelData

    color: "transparent"
    visible: SettingsData.showMiniPanel

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: SettingsData.miniPanelExclusiveGap + SettingsData.miniPanelExclusiveZone
        bottom: SettingsData.miniPanelExclusiveZone
    }

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }

    property real baseHeight: SettingsData.miniPanelHeight || 40

    // PanelWindow implicit height is in actual pixels (no transform scaling).
    // Keep this stable so the exclusive zone matches the real rendered height.
    implicitHeight: Math.max(spx(baseHeight), mainContainer.implicitHeight)

    // Derived sizing exposed to all MiniPanelWidgets children
    readonly property real effectiveWidgetHeight:
        Math.max(spx(20), spx(SettingsData.miniPanelHeight || 40) - spx(8))
    readonly property int pinnedIconSize:
        SettingsData.miniPanelPinnedAppsIconSize || 24

    readonly property int pinnedIconSpacing:
        SettingsData.miniPanelPinnedAppsIconSpacing || 4

    property bool autoHide: SettingsData.miniPanelAutohide
    property bool reveal: !autoHide || hoverArea.containsMouse

    // Loaders for popouts
    Loader {
        id: controlCenterLoader
        active: false
        sourceComponent: MiniPanelControlCenterPopout {
            onPowerActionRequested: (action, title, message) => {
                const actionMessages = {
                    "logout": {"title": "Log Out", "message": "Are you sure you want to log out?"},
                    "suspend": {"title": "Suspend", "message": "Are you sure you want to suspend?"},
                    "hibernate": {"title": "Hibernate", "message": "Are you sure you want to hibernate?"},
                    "reboot": {"title": "Restart", "message": "Are you sure you want to restart?"},
                    "poweroff": {"title": "Shutdown", "message": "Are you sure you want to shut down?"}
                }
                const selected = actionMessages[action]
                if (selected) {
                    powerConfirmModalLoader.active = true
                    if (powerConfirmModalLoader.item) {
                        powerConfirmModalLoader.item.showConfirmation(action, selected.title, selected.message)
                    }
                }
            }
        }
    }

    Loader {
        id: powerConfirmModalLoader
        active: false
        sourceComponent: Component {
            Rectangle {
                // Simple power confirmation - could be expanded
                function showConfirmation(action, title, message) {
                    PowerActionUtils.executeAction(action)
                }
            }
        }
    }

    Loader {
        id: appDrawerLoader
        active: false
        sourceComponent: AppDrawerPopout {}
    }

    Loader {
        id: applicationsLoader
        active: false
        sourceComponent: ApplicationsPopout {}
    }

    Loader {
        id: volumeMixerLoader
        active: false
        sourceComponent: MiniPanelVolumeMixerPopout {}
    }

    Loader {
        id: systemUpdateLoader
        active: false
        sourceComponent: MiniPanelSystemUpdatePopout {}
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        preventStealing: false
        
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
        onClicked: mouse.accepted = false

        Rectangle {
            id: mainContainer
            // Background opacity — stored as 0–1; default to 0.5 when unset
            color: Qt.rgba(Theme.surfaceContainer.r,
                           Theme.surfaceContainer.g,
                           Theme.surfaceContainer.b,
                           SettingsData.miniPanelOpacity !== undefined
                               ? SettingsData.miniPanelOpacity : 0.5)
            radius: Theme.cornerRadius
            border.width: SettingsData.miniPanelBorderEnabled ? (SettingsData.miniPanelBorderWidth || 1) : 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                                  SettingsData.miniPanelBorderOpacity)

            opacity: root.reveal ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            anchors {
                top:               parent.top
                horizontalCenter:  parent.horizontalCenter
                topMargin:         0
            }

            implicitWidth:  rowLayout.implicitWidth  + spx((Theme.spacingM || 16) * 2)
            implicitHeight: Math.max(spx(root.baseHeight), rowLayout.implicitHeight + spx((Theme.spacingM || 12) * 2))

            width:  Math.max(implicitWidth,  240)
            height: implicitHeight

            RowLayout {
                id: rowLayout
                anchors.centerIn: parent
                spacing: spx(Theme.spacingM || 12)

                MiniPanelWidgets {
                    id: leftWidgets
                    Layout.alignment: Qt.AlignVCenter
                    side: "left"
                    widgetList: SettingsData.miniPanelLeftWidgets || []
                    widgetHeight: root.effectiveWidgetHeight
                    parentScreen: root.modelData
                    parentWindow: root
                    controlCenterLoader: controlCenterLoader
                    appDrawerLoader: appDrawerLoader
                    applicationsLoader: applicationsLoader
                    volumeMixerLoader: volumeMixerLoader
                    systemUpdateLoader: systemUpdateLoader
                }

                MiniPanelWidgets {
                    id: centerWidgets
                    Layout.alignment: Qt.AlignVCenter
                    side: "center"
                    widgetList: SettingsData.miniPanelCenterWidgets || []
                    widgetHeight: root.effectiveWidgetHeight
                    parentScreen: root.modelData
                    parentWindow: root
                    controlCenterLoader: controlCenterLoader
                    appDrawerLoader: appDrawerLoader
                    applicationsLoader: applicationsLoader
                    volumeMixerLoader: volumeMixerLoader
                    systemUpdateLoader: systemUpdateLoader
                }

                MiniPanelWidgets {
                    id: rightWidgets
                    Layout.alignment: Qt.AlignVCenter
                    side: "right"
                    widgetList: SettingsData.miniPanelRightWidgets || []
                    widgetHeight: root.effectiveWidgetHeight
                    parentScreen: root.modelData
                    parentWindow: root
                    controlCenterLoader: controlCenterLoader
                    appDrawerLoader: appDrawerLoader
                    applicationsLoader: applicationsLoader
                    volumeMixerLoader: volumeMixerLoader
                    systemUpdateLoader: systemUpdateLoader
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("MiniPanel → screen:", screen?.name || "unknown")
        console.log("Surface size:", width, "×", height)
        console.log("Main container final size:", mainContainer.width, "×", mainContainer.height)
        console.log("Main container topMargin:", mainContainer.anchors.topMargin)
        console.log("RowLayout implicit:", rowLayout.implicitWidth, "×", rowLayout.implicitHeight)
    }
}