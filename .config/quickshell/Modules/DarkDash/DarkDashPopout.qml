import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Modules.DarkDash

EHPopout {
    id: root
    objectName: "darkDashPopout"

    property string triggerSection: "center"
    property var triggerScreen: null
    property int currentTabIndex: 0
    readonly property real uiScale: (Appearance.combinedScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    function show() {
        open()
    }

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    popupWidth: spx(700)
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : spx(500)
    triggerX: Screen.width - 620 - Theme.spacingL
    triggerY: {
        // Default positioning - adjust based on bar positions
        var baseY = SettingsData.topBarHeight + SettingsData.topBarSpacing + Theme.spacingS

        // If dock is visible at bottom, account for its height
        if (SettingsData.showDock && SettingsData.dockExclusiveZone > 0) {
            // Only adjust if we're positioning relative to top (not when triggered from dock itself)
            // The individual trigger buttons will set their own triggerY values
        }

        // If taskbar is visible, account for its height
        if (SettingsData.taskBarHeight > 0) {
            // Only adjust if we're positioning relative to top (not when triggered from taskbar itself)
        }

        return baseY
    }
    triggerWidth: 80
    screen: triggerScreen

    onBackgroundClicked: {
        close()
    }

    content: Component {
        Rectangle {
            id: mainContainer

            implicitHeight: contentColumn.height + Theme.spacingM * 2
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, SettingsData.darkDashContentBackgroundOpacity)
            radius: Theme.cornerRadius
            focus: true

            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus()
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function() {
                            mainContainer.forceActiveFocus()
                        })
                    }
                }
                target: root
            }

            Rectangle {
                id: animatedTintRect
                anchors.fill: parent
                color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 1.0)
                radius: parent.radius
                opacity: SettingsData.darkDashAnimatedTintOpacity

                SequentialAnimation on opacity {
                    running: root.shouldBeVisible && SettingsData.darkDashAnimatedTintOpacity > 0 && SettingsData.darkDashTintAnimateEnabled
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: Math.min(1.0, SettingsData.darkDashAnimatedTintOpacity * 2)
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
                    }

                    NumberAnimation {
                        to: Math.max(0.0, SettingsData.darkDashAnimatedTintOpacity * 0.5)
                        duration: Theme.extraLongDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                EHTabBar {
                    id: tabBar

                    width: parent.width
                    height: spx(48)
                    currentIndex: root.currentTabIndex
                    spacing: Theme.spacingS
                    equalWidthTabs: true
                    opacity: SettingsData.darkDashTabBarOpacity

                    model: {
                        let tabs = [
                            { icon: "dashboard", text: "Overview" },
                        ]
                        
                        if (SettingsData.weatherEnabled) {
                            tabs.push({ icon: "wb_sunny", text: "Weather" })
                        }
                        
                        tabs.push({ icon: "settings", text: "Settings", isAction: true })
                        return tabs
                    }

                    onTabClicked: function(index) {
                        root.currentTabIndex = index
                    }

                    onActionTriggered: function(index) {
                        let settingsIndex = SettingsData.weatherEnabled ? 2 : 1
                        if (index === settingsIndex) {
                            root.close()
                            settingsModal.show()
                        }
                    }

                }

                Item {
                    width: parent.width
                    height: Theme.spacingXS
                }

                StackLayout {
                    id: pages
                    width: parent.width
                    implicitHeight: {
                        if (currentIndex === 0) return overviewTab.implicitHeight
                        if (SettingsData.weatherEnabled && currentIndex === 1) return weatherTab.implicitHeight
                        return overviewTab.implicitHeight
                    }
                    currentIndex: root.currentTabIndex

                    OverviewTab {
                        id: overviewTab

                        onSwitchToWeatherTab: {
                            if (SettingsData.weatherEnabled) {
                                tabBar.currentIndex = 1
                                tabBar.tabClicked(1)
                            }
                        }
                    }

                    WeatherTab {
                        id: weatherTab
                        visible: SettingsData.weatherEnabled && root.currentTabIndex === 1
                    }
                }
            }
        }
    }
}