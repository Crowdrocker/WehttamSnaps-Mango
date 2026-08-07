import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.MiniPanel.Widgets
import qs.Services
import qs.Widgets

Row {
    id: root

    property var widgetList: []
    property string side: "left"
    property var contextMenu
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }

    property real widgetHeight: spx(SettingsData.miniPanelHeight || 48)
    property real unifiedScaleFactor: uiScale
    property real unifiedIconSize: spx(SettingsData.minipanelIconSize || 24)
    property real unifiedFontSize: spx(11)
    property real unifiedIconSpacing: spx(SettingsData.minipanelIconSpacing || 8)
    property real unifiedPadding: spx(SettingsData.minipanelPadding || 8)
    property var parentScreen: null
    property var parentWindow: null
    property var controlCenterLoader: null
    property var appDrawerLoader: null
    property var applicationsLoader: null
    property var volumeMixerLoader: null
    property var systemUpdateLoader: null
    property bool isAtBottom: false
    property bool isVertical: false
    property bool isBarVertical: false
    property bool allowEdgeAnchors: false
    property var axis: null

    property var widgetMap: {
        "launcherButton": launcherButtonComponent,
        "workspaceSwitcher": workspaceSwitcherComponent,
        "focusedWindow": focusedWindowComponent,
        "music": mediaComponent,
        "clock": clockComponent,
        "weather": weatherComponent,
        "systemTray": systemTrayComponent,
        "cpuUsage": cpuUsageComponent,
        "memUsage": ramUsageComponent,
        "notificationButton": notificationButtonComponent,
        "battery": batteryComponent,
        "controlCenterButton": controlCenterButtonComponent,
        "systemUpdate": systemUpdateComponent,
        "volumeMixer": volumeMixerComponent,
        "vpn": vpnComponent,
        "gpuTemp": gpuTempComponent,
        "cpuTemp": cpuTempComponent,
        "networkSpeed": networkMonitorComponent,
        "mediaDisplay": mediaDisplayComponent,
        "applications": applicationsComponent,
        "colorPicker": colorPickerComponent,
        "idleInhibitor": idleInhibitorComponent,
        "keyboardLayout": keyboardLayoutComponent,
        "notepadButton": notepadButtonComponent,
        "privacyIndicator": privacyIndicatorComponent,
        "runningApps": runningAppsComponent,
        "darkDash": darkDashComponent,
        "audioVisualization": audioVisualizationComponent,
        "pinnedApps": pinnedAppsComponent,
        "spacer": spacerComponent
    }

    spacing: 2

    readonly property bool isDock: false

    function getWidget(widgetId) {
        return widgetMap[widgetId] || null
    }

    Component { id: launcherButtonComponent; MiniPanelLauncherButton { 
        appDrawerLoader: root.appDrawerLoader
    } }
    Component { id: workspaceSwitcherComponent; MiniPanelWorkspaceSwitcher { } }
    Component { id: focusedWindowComponent; MiniPanelFocusedApp { } }
    Component { id: mediaComponent; MiniPanelMedia { } }
    Component { id: clockComponent; MiniPanelClock { } }
    Component { id: weatherComponent; MiniPanelWeather { } }
    Component { id: systemTrayComponent; MiniPanelSystemTrayBar { } }
    Component { id: cpuUsageComponent; MiniPanelCpuMonitor { } }
    Component { id: ramUsageComponent; MiniPanelRamMonitor { } }
    Component { id: notificationButtonComponent; MiniPanelNotificationCenterButton { } }
    Component { id: batteryComponent; MiniPanelBattery { } }
    Component { id: controlCenterButtonComponent; MiniPanelControlCenterButton { 
        controlCenterLoader: root.controlCenterLoader
    } }
    Component { id: systemUpdateComponent; MiniPanelSystemUpdate { } }
    Component { id: volumeMixerComponent; MiniPanelVolumeMixerButton { 
        volumeMixerLoader: root.volumeMixerLoader
    } }
    Component { id: vpnComponent; MiniPanelVpn { } }
    Component { id: gpuTempComponent; MiniPanelGpuTemperature { } }
    Component { id: cpuTempComponent; MiniPanelCpuTemperature { } }
    Component { id: networkMonitorComponent; MiniPanelNetworkMonitor { } }
    Component { id: mediaDisplayComponent; MiniPanelMediaDisplay { } }
    Component { id: applicationsComponent; MiniPanelApplications { 
        applicationsLoader: root.applicationsLoader
    } }
    Component { id: colorPickerComponent; MiniPanelColorPicker { } }
    Component { id: idleInhibitorComponent; MiniPanelIdleInhibitor { } }
    Component { id: keyboardLayoutComponent; MiniPanelKeyboardLayoutName { } }
    Component { id: notepadButtonComponent; MiniPanelNotepadButton { } }
    Component { id: privacyIndicatorComponent; MiniPanelPrivacyIndicator { } }
    Component { id: runningAppsComponent; MiniPanelRunningApps { } }
    Component { id: darkDashComponent; MiniPanelDarkDash { } }
    Component { id: audioVisualizationComponent; MiniPanelAudioVisualization { } }
    Component { id: pinnedAppsComponent; MiniPanelPinnedApps { } }
    Component { id: spacerComponent; Item {
        visible: (SettingsData.miniPanelSpacerWidth || 0) > 0
        width: root.spx(SettingsData.miniPanelSpacerWidth || 20)
        height: root.widgetHeight
    } }

    Repeater {
        model: root.widgetList

        delegate: Item {
            width: loader.width
            height: root.widgetHeight
            visible: loader.status === Loader.Ready

            Loader {
                id: loader
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: {
                    // Handle both string widgets and object widgets with 'id' or 'widgetId' property
                    var widgetId = modelData
                    if (typeof modelData === 'object' && modelData !== null) {
                        widgetId = modelData.widgetId || modelData.id
                    }
                    return root.getWidget(widgetId)
                }

                property var widgetData: model && (model.widgetId || model.id) ? ({
                    "widgetId": model.widgetId || model.id,
                    "enabled": model.enabled,
                    "size": model.size,
                    "selectedGpuIndex": model.selectedGpuIndex,
                    "pciId": model.pciId
                }) : null
                property var modelIndex: index

                onLoaded: {
                    if (item) {
                        if ("widgetData" in item && widgetData) item.widgetData = widgetData
                        if ("modelIndex" in item) item.modelIndex = modelIndex
                        if ("contextMenu" in item) item.contextMenu = root.contextMenu
                        if ("section" in item) item.section = root.side
                        if ("parentScreen" in item) item.parentScreen = root.parentScreen
                        if ("popupTarget" in item) item.popupTarget = root.controlCenterLoader?.item ?? null
                        if ("controlCenterLoader" in item) item.controlCenterLoader = root.controlCenterLoader
                        if ("appDrawerLoader" in item) item.appDrawerLoader = root.appDrawerLoader
                        if ("applicationsLoader" in item) item.applicationsLoader = root.applicationsLoader
                        if ("volumeMixerLoader" in item) item.volumeMixerLoader = root.volumeMixerLoader
                        if ("systemUpdateLoader" in item) item.systemUpdateLoader = root.systemUpdateLoader
                    }
                }
            }
        }
    }
}
