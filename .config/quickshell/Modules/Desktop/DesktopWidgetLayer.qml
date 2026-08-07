import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Desktop

Variants {
    id: root
    model: Quickshell.screens

    Component.onCompleted: Qt.callLater(autoEnablePluginsForInstances)

    function autoEnablePluginsForInstances() {
        const instances = SettingsData.desktopWidgetInstances || [];
        const pluginTypes = new Set();

        for (const inst of instances) {
            if (!inst.enabled)
                continue;
            if (inst.widgetType === "systemMonitorDetailed" || inst.widgetType === "desktopSystemMonitorCard" ||
                inst.widgetType === "desktopSystemMonitorCircle" || inst.widgetType === "desktopEventHorizon" || inst.widgetType === "desktopDarkDash" ||
                inst.widgetType === "desktopWeather" || inst.widgetType === "macOSClock" ||
                inst.widgetType === "desktopAnalogClock" ||
                inst.widgetType === "desktopFastfetch" || inst.widgetType === "desktopWallpaperGallery" ||
                inst.widgetType === "desktopMediaPlayer" || inst.widgetType === "desktopCava" ||
                inst.widgetType === "desktopIcon")
                continue;
            pluginTypes.add(inst.widgetType);
        }

        for (const pluginId of pluginTypes) {
            if (typeof PluginService !== 'undefined' && PluginService.isPluginLoaded(pluginId))
                continue;
            if (typeof PluginService !== 'undefined' && !PluginService.availablePlugins[pluginId])
                continue;
            if (typeof PluginService !== 'undefined')
                PluginService.enablePlugin(pluginId);
        }
    }

    Connections {
        target: typeof PluginService !== 'undefined' ? PluginService : null
        enabled: typeof PluginService !== 'undefined'
        function onPluginListUpdated() {
            Qt.callLater(root.autoEnablePluginsForInstances);
        }
    }

    QtObject {
        id: screenDelegate

        required property var modelData

        readonly property var screen: modelData
        readonly property string screenKey: SettingsData.getScreenDisplayName(screen)

        function shouldShowOnScreen(prefs) {
            if (!Array.isArray(prefs) || prefs.length === 0 || prefs.includes("all"))
                return true;
            return prefs.some(p => {
                if (typeof p === "string")
                    return p === screenKey || p === modelData.name;
                return p?.name === modelData.name || p === screenKey;
            });
        }

        property Component systemMonitorDetailedComponent: Component {
            Loader {
                source: Qt.resolvedUrl("BuiltinWidgets/SystemMonitor-3.qml")
            }
        }

        property Component systemMonitorCardComponent: Component {
            DesktopSystemMonitorCardWidget {}
        }

        property Component systemMonitorCircleComponent: Component {
            DesktopSystemMonitorCircleWidget {}
        }

        property Component eventHorizonComponent: Component {
            DesktopEventHorizonWidget {}
        }

        property Component weatherComponent: Component {
            DesktopWeatherWidget {}
        }

        property Component macOSClockComponent: Component {
            MacOSClockWidget {}
        }

        property Component desktopAnalogClockComponent: Component {
            DesktopAnalogClockWidget {}
        }

        property Component fastfetchComponent: Component {
            DesktopFastfetchWidgetSimple {}
        }

        property Component wallpaperGalleryComponent: Component {
            DesktopWallpaperGalleryWidget {}
        }

        property Component mediaPlayerComponent: Component {
            DesktopMediaPlayerWidget {}
        }

        property Component cavaComponent: Component {
            DesktopCavaWidget {}
        }

        property Component calendarComponent: Component {
            DesktopCalendarWidget {}
        }

        property Component batteryComponent: Component {
            DesktopBatteryWidget {}
        }

        property Component desktopIconComponent: Component {
            DesktopIconWidget {}
        }

        property Component desktopClockComponent: Component {
            DesktopClock {}
        }

        property Component desktopCpuTempComponent: Component {
            DesktopCpuTemp {}
        }

        property Component desktopGpuTempComponent: Component {
            DesktopGpuTemp {}
        }

        property Component desktopTerminalComponent: Component {
            DesktopTerminal {}
        }

        property Instantiator widgetInstantiator: Instantiator {
            model: ScriptModel {
                objectProp: "id"
                values: SettingsData.desktopWidgetInstances
            }

            DesktopPluginWrapper {
                required property var modelData
                required property int index

                readonly property string instanceIdRef: modelData.id
                readonly property var liveInstanceData: {
                    const instances = SettingsData.desktopWidgetInstances || [];
                    return instances.find(inst => inst.id === instanceIdRef) ?? modelData;
                }

                readonly property bool shouldBeVisible: {
                    if (!liveInstanceData.enabled)
                        return false;
                    // Use widget-specific displayPreferences if set, otherwise fall back to global desktopWidgets setting
                    var prefs = liveInstanceData.config?.displayPreferences;
                    if (!prefs || prefs.length === 0) {
                        prefs = SettingsData.screenPreferences && SettingsData.screenPreferences["desktopWidgets"];
                    }
                    if (!prefs || prefs.length === 0) {
                        prefs = ["all"];
                    }
                    return screenDelegate.shouldShowOnScreen(prefs);
                }

                pluginId: liveInstanceData.widgetType
                instanceId: instanceIdRef
                instanceData: liveInstanceData
                builtinComponent: {
                    switch (liveInstanceData.widgetType) {
                    case "systemMonitorDetailed":
                        return screenDelegate.systemMonitorDetailedComponent;
                    case "desktopSystemMonitorCard":
                        return screenDelegate.systemMonitorCardComponent;
                    case "desktopSystemMonitorCircle":
                        return screenDelegate.systemMonitorCircleComponent;
                    case "desktopEventHorizon":
                    case "desktopDarkDash":
                        return screenDelegate.eventHorizonComponent;
                    case "desktopWeather":
                        return screenDelegate.weatherComponent;
                    case "macOSClock":
                        return screenDelegate.macOSClockComponent;
                    case "desktopAnalogClock":
                        return screenDelegate.desktopAnalogClockComponent;
                    case "desktopClock":
                        return screenDelegate.desktopClockComponent;
                    case "desktopCpuTemp":
                        return screenDelegate.desktopCpuTempComponent;
                    case "desktopGpuTemp":
                        return screenDelegate.desktopGpuTempComponent;
                    case "desktopTerminal":
                        return screenDelegate.desktopTerminalComponent;
                    case "desktopFastfetch":
                        return screenDelegate.fastfetchComponent;
                    case "desktopWallpaperGallery":
                        return screenDelegate.wallpaperGalleryComponent;
                    case "desktopMediaPlayer":
                        return screenDelegate.mediaPlayerComponent;
                    case "desktopCava":
                        return screenDelegate.cavaComponent;
                    case "desktopCalendar":
                        return screenDelegate.calendarComponent;
                    case "desktopBattery":
                        return screenDelegate.batteryComponent;
                    case "desktopIcon":
                        return screenDelegate.desktopIconComponent;
                    default:
                        return null;
                    }
                }
                pluginService: null  // No plugin support initially
                screen: screenDelegate.screen
                widgetEnabled: shouldBeVisible
            }
        }
    }
}
