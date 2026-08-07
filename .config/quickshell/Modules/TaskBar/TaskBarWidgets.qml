import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.TaskBar.Widgets
import qs.Services
import qs.Widgets

Row {
    id: root

    property var widgetList: []
    property string side: "left"
    property bool isBackground: side === "background"
    property var contextMenu
    property real widgetHeight: Math.round(48 * Appearance.uiScaleRatio)
    property real unifiedScaleFactor: Appearance.uiScaleRatio
    property real unifiedIconSize: Math.round(24 * Appearance.uiScaleRatio)
    property real unifiedFontSize: Math.round(11 * Appearance.uiScaleRatio)
    property real unifiedIconSpacing: Math.round(8 * Appearance.uiScaleRatio)
    property real unifiedPadding: Math.round(8 * Appearance.uiScaleRatio)
    property var parentScreen: null
    property var parentWindow: null
    property var controlCenterLoader: null
    property var appDrawerLoader: null
    property var volumeMixerLoader: null
    property var systemUpdateLoader: null
    property var weatherPopupLoader: null
    property bool isAtBottom: false
    property bool isVertical: false
    property bool isBarVertical: false
    property bool allowEdgeAnchors: false
    property var axis: null
    property real dockBarHeight: widgetHeight

    property var widgetMap: {
        // Hyphenated IDs
        "appbutton": appButtonComponent,
        "applications": applicationsComponent,
        "audio-visualization": audioVisualizationComponent,
        "cava-background": cavaBackgroundComponent,
        "clock": clockComponent,
        "darkdash": darkDashComponent,
        "launchpad": launchpadComponent,
        "media": mediaComponent,
        "media-display": mediaDisplayComponent,
        "music": musicComponent,
        "spacer": spacerComponent,
        "systemtray": systemTrayComponent,
        "system-update": systemUpdateComponent,
        "volume-mixer": volumeMixerComponent,
        "volumeMixer": volumeMixerComponent,
        "volumeMixerButton": volumeMixerComponent,
        "weather": weatherComponent,
        "workspace-switcher": workspaceSwitcherComponent,
        "trash": trashComponent,
        "pinned-apps": pinnedAppsComponent,
        "notification-button": notificationButtonComponent,
        "control-center-button": controlCenterButtonComponent,
        "privacy-indicator": privacyIndicatorComponent,
        "cpu-usage": cpuUsageComponent,
        "gpu-temp": gpuTempComponent,
        "cpu-temp": cpuTempComponent,
        "ram-usage": ramUsageComponent,
        "network-speed": networkSpeedComponent,
        "battery": batteryComponent,
        "vpn": vpnComponent,
        "keyboard-layout": keyboardLayoutComponent,
        "idle-inhibitor": idleInhibitorComponent,
        "notepad-button": notepadButtonComponent,
        "minimized-preview": minimizedPreviewComponent,
        "window-preview": windowPreviewComponent,
        "color-picker": colorPickerComponent,
        "settings-button": settingsButtonComponent,
        // CamelCase aliases (for layout JSON compatibility)
        "launcherButton": appButtonComponent,
        "audioVisualization": audioVisualizationComponent,
        "cavaBackground": cavaBackgroundComponent,
        "mediaDisplay": mediaDisplayComponent,
        "systemTray": systemTrayComponent,
        "systemUpdate": systemUpdateComponent,
        "volumeMixer": volumeMixerComponent,
        "workspaceSwitcher": workspaceSwitcherComponent,
        "pinnedApps": pinnedAppsComponent,
        "notificationButton": notificationButtonComponent,
        "controlCenterButton": controlCenterButtonComponent,
        "privacyIndicator": privacyIndicatorComponent,
        "cpuUsage": cpuUsageComponent,
        "gpuTemp": gpuTempComponent,
        "cpuTemp": cpuTempComponent,
        "ramUsage": ramUsageComponent,
        "networkSpeed": networkSpeedComponent,
        "keyboardLayout": keyboardLayoutComponent,
        "idleInhibitor": idleInhibitorComponent,
        "notepadButton": notepadButtonComponent,
        "minimizedPreview": minimizedPreviewComponent,
        "windowPreview": windowPreviewComponent,
        "colorPicker": colorPickerComponent,
        "settingsButton": settingsButtonComponent
    }

    spacing: (SettingsData.dockIconSpacing || 0) * (SettingsData.dockScale || 1) * (Appearance.combinedScale || 1) * unifiedScaleFactor

    readonly property bool isDock: true

    function getWidget(widgetId) {
        return widgetMap[widgetId] || null
    }

    Component {
        id: appButtonComponent
        DockLauncherButton {
            isAtBottom: root.isAtBottom
            isVertical: root.isVertical
            widgetHeight: root.widgetHeight
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            scaleFactor: root.unifiedScaleFactor
            isActive: root.appDrawerLoader && root.appDrawerLoader.item ? root.appDrawerLoader.item.shouldBeVisible : false
            popupTarget: {
                if (!root.appDrawerLoader)
                    return null
                root.appDrawerLoader.active = true
                return root.appDrawerLoader.item
            }
            parentScreen: root.parentScreen
            onClicked: {
                if (root.appDrawerLoader) {
                    root.appDrawerLoader.active = true
                    const item = root.appDrawerLoader.item
                    if (item) {
                        if (_pendingTriggerPosition) {
                            item.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, root.parentScreen)
                            _pendingTriggerPosition = false
                        }
                        item.toggle()
                    }
                }
            }
        }
    }

    Component {
        id: applicationsComponent
        DockApplications {
            widgetHeight: root.widgetHeight
            parentScreen: root.parentScreen
            contextMenu: root.contextMenu
            iconSize: root.unifiedIconSize * 1.5
            iconSpacing: root.unifiedIconSpacing
            scaleFactor: root.unifiedScaleFactor
        }
    }

    Component {
        id: audioVisualizationComponent
        DockAudioVisualization {
            width: 20
            height: root.widgetHeight
        }
    }

    Component {
        id: cavaBackgroundComponent
        DockCavaBackground {
            height: root.widgetHeight
            fillWidth: root.isBackground
            visualizerIntensity: root.isBackground ? 3.5 : 1.0
            barCount: 40
            showShadow: true
            widgetOpacity: 0.8
        }
    }

    Component {
        id: clockComponent
        DockClock {
            widgetHeight: root.widgetHeight
            parentScreen: root.parentScreen
            onOpenCalendarPopup: {
                calendarPopupLoader.active = true
                Qt.callLater(() => {
                    if (calendarPopupLoader.item) {
                        const pos = mapToItem(null, 0, 0)
                        calendarPopupLoader.item.parentScreen = root.parentScreen
                        calendarPopupLoader.item.panelScale   = (SettingsData.dockScale || 1)
                        calendarPopupLoader.item.barPosition  = "bottom"
                        calendarPopupLoader.item.barThickness = root.dockBarHeight
                        calendarPopupLoader.item.triggerX     = pos.x
                        calendarPopupLoader.item.triggerY     = pos.y
                        calendarPopupLoader.item.triggerWidth = width
                        calendarPopupLoader.item.open()
                    }
                })
            }
        }
    }

    Component {
        id: darkDashComponent
        DockDarkDash {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }

    Component {
        id: launchpadComponent
        DockLaunchpad {
            widgetHeight: root.widgetHeight
            parentScreen: root.parentScreen
            padding: root.unifiedPadding
        }
    }

    Component {
        id: mediaComponent
        DockMedia {
            widgetHeight: root.widgetHeight
            parentScreen: root.parentScreen
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }

    Component {
        id: mediaDisplayComponent
        DockMediaDisplay {
            widgetHeight: root.widgetHeight
            barHeight: root.widgetHeight
            parentScreen: root.parentScreen
            isBarVertical: root.isBarVertical
        }
    }

    Component {
        id: musicComponent
        DockMusic {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            barHeight: root.widgetHeight
            parentScreen: root.parentScreen
        }
    }

    Component {
        id: spacerComponent
        Item {
            width: 8 * root.unifiedScaleFactor
            height: root.widgetHeight
        }
    }

    Component {
        id: weatherComponent
        DockWeather {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            onOpenWeatherPopup: {
                if (weatherPopupLoader) {
                    weatherPopupLoader.active = true
                    if (weatherPopupLoader.item) {
                        const pos = mapToItem(null, 0, 0);

                        weatherPopupLoader.item.parentScreen = root.parentScreen
                        weatherPopupLoader.item.barPosition = "bottom"
                        weatherPopupLoader.item.barThickness = root.dockBarHeight
                        weatherPopupLoader.item.triggerX = pos.x
                        weatherPopupLoader.item.triggerY = pos.y
                        weatherPopupLoader.item.triggerWidth = width

                        weatherPopupLoader.item.open()
                    }
                }
            }
        }
    }

    Component {
        id: systemTrayComponent
        DockSystemTrayBar {
            parentScreen: root.parentScreen
            parentWindow: root.parentWindow
            isAtBottom: true
            isVertical: false
            axis: null
            widgetHeight: root.unifiedIconSize * 2
            barThickness: root.unifiedIconSize * 2
            isBarVertical: false
        }
    }
    Component {
        id: systemUpdateComponent
        DockSystemUpdate {
            id: systemUpdateButton
            widgetHeight: root.widgetHeight
            onClicked: {
                if (root.systemUpdateLoader) {
                    root.systemUpdateLoader.active = true
                    // Wait for loader to be active before opening popup
                    Qt.callLater(() => {
                        if (root.systemUpdateLoader.item) {
                            root.systemUpdateLoader.item.openForItem(systemUpdateButton, root.parentScreen, "bottom", false, root.dockBarHeight)
                        }
                    })
                }
            }
        }
    }
    Component {
        id: volumeMixerComponent
        DockVolumeMixerButton {
            id: volumeMixerButton
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            parentScreen: root.parentScreen
            popupTarget: root.volumeMixerLoader && root.volumeMixerLoader.item ? root.volumeMixerLoader.item : null
            onClicked: {
                if (root.volumeMixerLoader) {
                    root.volumeMixerLoader.active = true
                    // Wait for loader to be active before opening popup
                    Qt.callLater(() => {
                        if (root.volumeMixerLoader.item) {
                            root.volumeMixerLoader.item.openForItem(volumeMixerButton, root.parentScreen, "bottom", false, root.dockBarHeight)
                        }
                    })
                }
            }
        }
    }
    Component {
        id: privacyIndicatorComponent 
        DockPrivacyIndicator { 
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        } 
    }
    Component {
        id: controlCenterButtonComponent
        TaskBarControlCenterButton {
            isActive: root.controlCenterLoader && root.controlCenterLoader.item ? root.controlCenterLoader.item.showMenu : false
            widgetHeight: root.unifiedIconSize * 2
            popupTarget: root.controlCenterLoader && root.controlCenterLoader.item ? root.controlCenterLoader.item : null
            parentScreen: root.parentScreen
            onClicked: {
                if (root.controlCenterLoader) {
                    root.controlCenterLoader.active = true
                    if (root.controlCenterLoader.item) {
                        const pos = mapToItem(null, 0, 0);

                        root.controlCenterLoader.item.triggerX = pos.x
                        root.controlCenterLoader.item.triggerY = pos.y
                        root.controlCenterLoader.item.triggerWidth = width
                        root.controlCenterLoader.item.barPosition = "bottom"
                        root.controlCenterLoader.item.barThickness = root.dockBarHeight
                        root.controlCenterLoader.item.parentScreen = root.parentScreen

                        root.controlCenterLoader.item.toggle()
                    }
                }
            }
        }
    }
    Component {
        id: notificationButtonComponent
        DockNotificationCenterButton {
            isActive: false
            widgetHeight: root.widgetHeight
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            parentScreen: root.parentScreen
            popupTarget: {
                notificationCenterLoader.active = true
                return notificationCenterLoader.item
            }
            onClicked: {
                notificationCenterLoader.active = true
                notificationCenterLoader.item?.toggle()
            }
        }
    }
    Component {
        id: workspaceSwitcherComponent
        DockWorkspaceSwitcher {
            widgetHeight: root.widgetHeight
            isBarVertical: false
            screenName: root.parentScreen?.name ?? ""
        }
    }
    Component {
        id: trashComponent
        DockTrashBin {
            widgetHeight: root.widgetHeight
            parentScreen: root.screen
        }
    }
    Component {
        id: pinnedAppsComponent
        DockPinnedApps {
            widgetHeight: root.widgetHeight
            parentScreen: root.screen
            contextMenu: root.contextMenu
            scaleFactor: root.unifiedScaleFactor
            iconSpacing: SettingsData.dockIconSpacing * SettingsData.dockScale
        }
    }
    Component {
        id: cpuUsageComponent
        DockCpuMonitor {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: cpuTempComponent
        DockCpuTemperature {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: gpuTempComponent
        DockGpuTemperature {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: ramUsageComponent
        DockRamMonitor {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: networkSpeedComponent
        DockNetworkMonitor {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: batteryComponent
        DockBattery {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: vpnComponent
        DockVpn {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: keyboardLayoutComponent
        DockKeyboardLayoutName {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: idleInhibitorComponent
        DockIdleInhibitor {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: notepadButtonComponent
        DockNotepadButton {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            contextMenu: root.contextMenu
        }
    }
    Component {
        id: minimizedPreviewComponent
        DockRunningApps {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            isAtBottom: root.isAtBottom
            isVertical: root.isVertical
            parentScreen: root.parentScreen
        }
    }
    Component {
        id: windowPreviewComponent
        DockFocusedApp {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
            isAtBottom: root.isAtBottom
            isVertical: root.isVertical
            parentScreen: root.parentScreen
        }
    }
    Component {
        id: colorPickerComponent
        DockColorPicker {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }
    Component {
        id: settingsButtonComponent
        DockSettingsButton {
            widgetHeight: root.widgetHeight
            scaleFactor: root.unifiedScaleFactor
            iconSize: root.unifiedIconSize
            iconSpacing: root.unifiedIconSpacing
            padding: root.unifiedPadding
        }
    }

    Repeater {
        model: root.widgetList

        delegate: Item {
            width: loader.width
            height: root.height

            Loader {
                id: loader
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: model ? root.getWidget(model.widgetId) : null

                property var widgetData: model ? ({
                    "widgetId": model.widgetId,
                    "enabled": model.enabled,
                    "size": model.size,
                    "selectedGpuIndex": model.selectedGpuIndex,
                    "pciId": model.pciId
                }) : null
                property var modelIndex: index

                onLoaded: {
                    if (item) {
                        if ("widgetData" in item)
                            item.widgetData = widgetData
                        if ("modelIndex" in item)
                            item.modelIndex = modelIndex
                        // Bind: dockContextMenuLoader may finish after this Loader; one-shot null broke right-click.
                        if ("contextMenu" in item)
                            item.contextMenu = Qt.binding(function () {
                                return root.contextMenu
                            })
                        if ("section" in item)
                            item.section = root.side
                    }
                }
            }
        }
    }

    Loader {
        id: weatherPopupLoader
        active: false
        sourceComponent: Component {
            WeatherPopup {
                parentScreen: root.parentScreen
            }
        }
    }

    Loader {
        id: calendarPopupLoader
        active: false
        sourceComponent: Component {
            CalendarPopup {
                parentScreen: root.parentScreen
            }
        }
    }
}
