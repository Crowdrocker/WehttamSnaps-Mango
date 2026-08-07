import QtQuick
import qs.Common
import qs.Modules.Settings
import Quickshell.Wayland

Item {
    id: root

    property int currentIndex: 0
    property var parentModal: null
    
    Component.onCompleted: {
        
        Qt.callLater(function() {
            refreshAllSettings()
        })
    }

    Timer {
        id: settingsInitTimer
        interval: 100
        repeat: true
        running: false
        
        onTriggered: {
            if (typeof ColorPaletteService !== 'undefined' && 
                typeof SettingsData !== 'undefined' && 
                typeof Theme !== 'undefined') {
                running = false
                refreshAllSettings()
            } else {
            }
        }
    }

    function refreshAllSettings() {
        
        if (typeof ColorPaletteService !== 'undefined') {
            ColorPaletteService.updateAvailableThemes()
        }
        
        if (typeof SettingsData !== 'undefined') {
            SettingsData.loadSettings()
        }
        
        if (typeof Theme !== 'undefined') {
            Theme.generateSystemThemesFromCurrentTheme()
        }
        
    }

    function forceInitialize() {
        settingsInitTimer.running = true
    }

    Item {
        anchors.fill: parent

        Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            width: Math.min(parent.width - 48, 1400)
            anchors.horizontalCenter: parent.horizontalCenter
            clip: false

            Loader {
                id: personalizationLoader

                anchors.fill: parent
            active: root.currentIndex === 98
            visible: active
            asynchronous: false

            sourceComponent: Component {
                PersonalizationTab {
                    parentModal: root.parentModal
                }

            }

        }

        Loader {
            id: fontsLoader

            anchors.fill: parent
            active: root.currentIndex === 99
            visible: active
            asynchronous: true

            sourceComponent: Component {
                FontsTab {
                    parentModal: root.parentModal
                }
            }

        }

        // Appearance sub-tabs (indices 97-104)
        Loader {
            id: userLoader

            anchors.fill: parent
            active: root.currentIndex === 0
            visible: active
            asynchronous: false

            sourceComponent: Component {
                UserTab {
                    parentModal: root.parentModal
                }
            }

        }

        Loader {
            id: colorsThemesLoader
            anchors.fill: parent
            active: root.currentIndex === 100
            visible: active
            asynchronous: true
            sourceComponent: Component {
                ColorsThemesTab {
                    parentModal: root.parentModal
                }
            }
        }
        
        Loader {
            id: appearanceLoader
            anchors.fill: parent
            active: root.currentIndex === 101
            visible: active
            asynchronous: true
            sourceComponent: Component {
                AppearanceTab {
                    parentModal: root.parentModal
                }
            }
        }
        
        Loader {
            id: componentsLoader
            anchors.fill: parent
            active: root.currentIndex === 102
            visible: active
            asynchronous: true
            sourceComponent: Component {
                ComponentsTab {
                    parentModal: root.parentModal
                }
            }
        }
        
        Loader {
            id: systemSettingsLoader
            anchors.fill: parent
            active: root.currentIndex === 103
            visible: active
            asynchronous: true
            sourceComponent: Component {
                SystemSettingsTab {
                    parentModal: root.parentModal
                }
            }
        }
        
        Loader {
            id: displaysLoader
            anchors.fill: parent
            active: root.currentIndex === 104
            visible: active
            asynchronous: true
            sourceComponent: Component {
                DisplaysTab {
                    parentModal: root.parentModal
                }
            }
        }
        
        // Legacy ThemeColorsTab for Displays tab (index 2) - will be replaced with DisplaysTab later
        // Hyprland Theme sub-tabs (indices 105-113)
        Loader {
            id: hyprlandBorderColorsLoader

            anchors.fill: parent
            active: root.currentIndex === 105
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandBorderColorsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandRoundingLoader

            anchors.fill: parent
            active: root.currentIndex === 106
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandRoundingTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandRenderLoader

            anchors.fill: parent
            active: root.currentIndex === 107
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandRenderTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandInputLoader

            anchors.fill: parent
            active: root.currentIndex === 108
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandInputTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandCursorLoader

            anchors.fill: parent
            active: root.currentIndex === 109
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandCursorTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandGeneralLoader

            anchors.fill: parent
            active: root.currentIndex === 110
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandGeneralTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandSnapLoader

            anchors.fill: parent
            active: root.currentIndex === 111
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandSnapTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandGroupbarLoader

            anchors.fill: parent
            active: root.currentIndex === 112
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandGroupbarTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandDwindleLoader

            anchors.fill: parent
            active: root.currentIndex === 113
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandDwindleTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandMasterLoader

            anchors.fill: parent
            active: root.currentIndex === 117
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandMasterTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandScrollingLoader

            anchors.fill: parent
            active: root.currentIndex === 118
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandScrollingTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: hyprlandMonocleLoader

            anchors.fill: parent
            active: root.currentIndex === 119
            visible: active
            asynchronous: true

            sourceComponent: Component {
                HyprlandMonocleTab {
                    parentModal: root.parentModal
                }
            }
        }

        // Animations tab (index 122)
        Loader {
            id: hyprlandAnimationsLoader

            anchors.fill: parent
            active: root.currentIndex === 122
            visible: active
            asynchronous: false

            sourceComponent: Component {
                HyprlandAnimationsTab {
                    parentModal: root.parentModal
                }
            }
        }

        // Niri Theme sub-tabs (indices 120-121)
        Loader {
            id: niriBorderColorsLoader

            anchors.fill: parent
            active: root.currentIndex === 120
            visible: active
            asynchronous: true

            sourceComponent: Component {
                NiriBorderColorsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: niriLayoutLoader

            anchors.fill: parent
            active: root.currentIndex === 121
            visible: active
            asynchronous: true

            sourceComponent: Component {
                NiriLayoutTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoDecorationsLoader

            anchors.fill: parent
            active: root.currentIndex === 123
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoDecorationsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoAnimationsLoader

            anchors.fill: parent
            active: root.currentIndex === 124
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoAnimationsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: keybindsMangoWMLoader

            anchors.fill: parent
            active: root.currentIndex === 125
            visible: active
            asynchronous: true

            sourceComponent: Component {
                KeybindsMangoWMTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoLayoutLoader

            anchors.fill: parent
            active: root.currentIndex === 126
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoLayoutTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoInputLoader

            anchors.fill: parent
            active: root.currentIndex === 127
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoInputTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoColorsLoader

            anchors.fill: parent
            active: root.currentIndex === 128
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoColorsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: mangoMiscLoader

            anchors.fill: parent
            active: root.currentIndex === 130
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MangoMiscTab {
                    parentModal: root.parentModal
                }
            }
        }

        // Matugen tab (index 114)
        Loader {
            id: matugenLoader

            anchors.fill: parent
            active: root.currentIndex === 114
            visible: active
            asynchronous: true

            sourceComponent: Component {
                MatugenTab {
                    parentModal: root.parentModal
                }
            }
        }

        // Templates tab (index 116)
        Loader {
            id: templatesLoader

            anchors.fill: parent
            active: root.currentIndex === 116
            visible: active
            asynchronous: true

            sourceComponent: Component {
                TemplatesTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: wallpaperLoader

            anchors.fill: parent
            active: root.currentIndex === 3
            visible: active
            asynchronous: true

            sourceComponent: Component {
                WallpaperTab {
                    parentModal: root.parentModal
                }
            }

        }

        Loader {
            id: bingWallpaperLoader

            anchors.fill: parent
            active: root.currentIndex === 115
            visible: active
            asynchronous: true

            sourceComponent: Component {
                BingWallpaperTab {
                    parentModal: root.parentModal
                }
            }

        }

        Loader {
            id: taskBarLoader

            anchors.fill: parent
            active: root.currentIndex === 4
            visible: active
            asynchronous: true

            sourceComponent: TaskBarTab {
            }

        }

        Loader {
            id: topBarLoader

            anchors.fill: parent
            active: root.currentIndex === 5
            visible: active
            asynchronous: true

            sourceComponent: TopBarTab {
            }

        }

        Loader {
            id: dockLoader

            anchors.fill: parent
            active: root.currentIndex === 6
            visible: active
            asynchronous: true

            sourceComponent: Component {
                DockTab {
                }
            }

            onLoaded: {
                if (item) {
                    item.forceActiveFocus()
                }
            }
        }

        Loader {
            id: widgetsLoader

            anchors.fill: parent
            active: root.currentIndex === 7
            visible: active
            asynchronous: true

            source: "../../Modules/Settings/WidgetTweaksTab.qml"

        }

        Loader {
            id: desktopWidgetsLoader

            anchors.fill: parent
            active: root.currentIndex === 8
            visible: active
            asynchronous: true

            sourceComponent: Component {
                DesktopWidgetsTab {
                    parentModal: root.parentModal
                }
            }
        }

        Loader {
            id: launcherLoader

            anchors.fill: parent
            active: root.currentIndex === 10
            visible: active
            asynchronous: true

            sourceComponent: LauncherTab {
            }

        }

        Loader {
            id: defaultAppsLoader

            anchors.fill: parent
            active: root.currentIndex === 11
            visible: active
            asynchronous: true

            sourceComponent: DefaultAppsTab {
            }

        }

        Loader {
            id: notificationsLoader

            anchors.fill: parent
            active: root.currentIndex === 129
            visible: active
            asynchronous: true

            sourceComponent: NotificationsTab {
                parentModal: root.parentModal
            }
        }

        Loader {
            id: displayConfigLoader

            anchors.fill: parent
            active: root.currentIndex === 12
            visible: active
            asynchronous: true

            sourceComponent: Component {
                DisplayConfigTab {
                }
            }

            onLoaded: {
                if (item && typeof item.tabActivated !== 'undefined') {
                    item.tabActivated()
                }
            }

            onActiveChanged: {
                if (active && item && typeof item.tabActivated !== 'undefined') {
                    Qt.callLater(() => {
                        if (item) {
                            item.tabActivated()
                        }
                    })
                }
            }
        }

        Loader {
            id: soundLoader

            anchors.fill: parent
            active: root.currentIndex === 13
            visible: active
            asynchronous: true

            sourceComponent: SoundTab {
            }

        }

        Loader {
            id: networkLoader

            anchors.fill: parent
            active: root.currentIndex === 14
            visible: active
            asynchronous: true

            sourceComponent: NetworkTab {
                parentModal: root.parentModal
            }

        }

        Loader {
            id: bluetoothLoader

            anchors.fill: parent
            active: root.currentIndex === 15
            visible: active
            asynchronous: true

            sourceComponent: BluetoothTab {
            }

        }

        Loader {
            id: keyboardLangLoader

            anchors.fill: parent
            active: root.currentIndex === 16
            visible: active
            asynchronous: true

            sourceComponent: KeyboardLangTab {
            }

        }

        Loader {
            id: timeLoader

            anchors.fill: parent
            active: root.currentIndex === 17
            visible: active
            asynchronous: true

            sourceComponent: TimeTab {
            }

        }

        Loader {
            id: powerLoader

            anchors.fill: parent
            active: root.currentIndex === 18
            visible: active
            asynchronous: true

            sourceComponent: PowerTab {
            }

        }

        Loader {
            id: weatherLoader

            anchors.fill: parent
            active: root.currentIndex === 20
            visible: active
            asynchronous: true

            sourceComponent: WeatherTab {
            }

        }

        Loader {
            id: updateLoader

            anchors.fill: parent
            active: root.currentIndex === 26
            visible: active
            asynchronous: true

            sourceComponent: UpdateTab {
            }

        }

        Loader {
            id: systemUpdateLoader

            anchors.fill: parent
            active: root.currentIndex === 27
            visible: active
            asynchronous: true

            sourceComponent: SystemUpdateTab {
            }

        }

        Loader {
            id: keybindsLoader

            anchors.fill: parent
            active: root.currentIndex === 21
            visible: active
            asynchronous: true

            source: "../../Modules/Settings/KeybindsTab.qml"

            }
        }

        Loader {
            id: layoutManagerLoader

            anchors.fill: parent
            active: root.currentIndex === 22
            visible: active
            asynchronous: true

            sourceComponent: LayoutManagerTab {
                parentModal: root.parentModal
            }
        }

        Loader {
            id: miniPanelLoader

            anchors.fill: parent
            active: root.currentIndex === 23
            visible: active
            asynchronous: true

            sourceComponent: MiniPanelTab {
            }
        }

        Loader {
            id: workspaceOverviewLoader

            anchors.fill: parent
            active: root.currentIndex === 24
            visible: active
            asynchronous: true

            sourceComponent: WorkspaceOverviewTab {
            }
        }

        Loader {
            id: controlCenterLoader

            anchors.fill: parent
            active: root.currentIndex === 25
            visible: active
            asynchronous: true

            sourceComponent: Component {
                ControlCenterTab {
                }
            }
        }
    }

}
