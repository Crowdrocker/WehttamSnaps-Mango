import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.TaskBar.Widgets
import qs.Modules.Dock

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:bar:blur"
    WlrLayershell.layer: WlrLayershell.Top

    // ── Scaling (single effective scale) ──────────────────────────────────────
    // One effective scale factor for the whole TaskBar: global UI × taskbar.
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    WlrLayershell.exclusiveZone: {
        if (!SettingsData.taskBarVisible) {
            return 0
        }
        if (SettingsData.taskBarAutoHide && !taskBarCore.reveal) {
            return spx(8)
        }
        return SettingsData.taskBarExclusiveZone > 0 ? SettingsData.taskBarExclusiveZone * uiScale : implicitHeight
    }
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var modelData
    property var appDrawerLoader: null
    property var notepadVariants: null
    property real panelHeight: SettingsData.taskBarHeight * uiScale
    property real backgroundTransparency: SettingsData.taskBarTransparency
    readonly property real widgetHeight: Math.max(spx(20), SettingsData.taskbarIconSize * uiScale)
    readonly property string screenName: modelData.name
    readonly property int notificationCount: NotificationService.notifications.length

    signal colorPickerRequested()

    function getNotepadInstanceForScreen() {
        if (!notepadVariants || !notepadVariants.instances) return null

        for (var i = 0; i < notepadVariants.instances.length; i++) {
            var slideout = notepadVariants.instances[i]
            if (slideout.modelData && slideout.modelData.name === root.screen?.name) {
                return slideout
            }
        }
        return null
    }

    screen: modelData
    color: "transparent"
    visible: SettingsData.taskBarVisible

    property var contextMenu: taskBarContextMenuLoader.item

    Connections {
        target: taskBarContextMenuLoader
        function onItemChanged() {
            if (taskBarContextMenuLoader.item) {
            }
        }
    }

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        left: SettingsData.taskBarFloat ? SettingsData.taskBarBottomMargin : 0
        right: SettingsData.taskBarFloat ? SettingsData.taskBarBottomMargin : 0
        bottom: SettingsData.taskBarFloat ? SettingsData.taskBarBottomMargin : 0
        top: 0
    }

    implicitHeight: panelHeight

    Item {
        id: taskBarCore
        anchors.fill: parent
        property bool autoHide: SettingsData.taskBarAutoHide === true
        property bool revealSticky: false
        property bool intentToShow: false

        // When autohide is disabled mid-session, immediately clear any
        // lingering hidden state so the bar snaps back into view.
        onAutoHideChanged: {
            if (!autoHide) {
                revealSticky = false
                intentToShow = false
                hideTimer.stop()
                graceTimer.stop()
                showIntentTimer.stop()
            }
        }

        Timer {
            id: hideTimer
            interval: 500
            repeat: false
            onTriggered: {
                if (!taskBarMouseArea.containsMouse && !taskBarCore.intentToShow) {
                    taskBarCore.revealSticky = false
                }
            }
        }

        Timer {
            id: graceTimer
            interval: 1500
            repeat: false
            onTriggered: {
                if (!taskBarMouseArea.containsMouse && !taskBarCore.hasActivePopout) {
                    taskBarCore.revealSticky = false
                }
            }
        }

        Timer {
            id: showIntentTimer
            interval: 200
            repeat: false
            onTriggered: {
                taskBarCore.intentToShow = true
            }
        }

        property bool reveal: {
            if (!SettingsData.taskBarVisible) {
                return false
            }
            return !autoHide || taskBarMouseArea.containsMouse || revealSticky
        }

        readonly property bool hasActivePopout: {
            const loaders = [{
                                 "loader": darkDashLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": processListPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": notificationCenterLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": batteryPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": vpnPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": controlCenterLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": clipboardHistoryModalPopup,
                                 "prop": "visible"
                             }, {
                                 "loader": volumeMixerPopoutLoader,
                                 "prop": "shouldBeVisible"
                             }, {
                                 "loader": systemUpdatePopoutLoader,
                                 "prop": "shouldBeVisible"
                             }]
            return loaders.some(item => {
                if (item.loader) {
                    return item.loader?.item?.[item.prop]
                }
                return false
            })
        }

        Connections {
            target: taskBarMouseArea
            function onContainsMouseChanged() {
                if (taskBarMouseArea.containsMouse) {
                    taskBarCore.revealSticky = true
                    hideTimer.stop()
                    graceTimer.stop()
                } else {
                    if (taskBarCore.autoHide && !graceTimer.running) {
                        graceTimer.restart()
                    }
                }
            }
        }

        MouseArea {
            id: taskBarMouseArea
            anchors.fill: parent
            hoverEnabled: taskBarCore.autoHide
            acceptedButtons: Qt.NoButton
            enabled: taskBarCore.autoHide
        }
    }

    Item {
        id: panelContainer
        anchors.fill: parent
        readonly property string barPosition: "bottom"
        readonly property bool barIsVertical: false
        
        // ── Framerate-aware slide duration ──────────────────────────────
        // Target ~200 ms at 60 Hz.  Scale wall-clock duration proportionally
        // so the animation spans the same frame count on any refresh rate.
        // Clamped to [80, 350] ms so 240 Hz panels feel snappy and
        // 30 Hz panels don't look choppy.
        readonly property int slideMs: Math.max(80, Math.min(350,
            Math.round(200 * 60 / Math.max(30, modelData.refreshRate || 60))))

        transform: Translate {
            id: panelSlide
            y: Math.round(taskBarCore.reveal ? 0 : panelHeight)

            Behavior on y {
                NumberAnimation {
                    duration: panelContainer.slideMs
                    easing.type: Easing.OutQuint
                }
            }
        }

        Rectangle {
            id: panelBackground
            anchors.fill: parent
            color: {
                var baseColor = Theme.surfaceContainer
                return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, backgroundTransparency)
            }
            radius: SettingsData.taskBarRoundedCorners ? SettingsData.taskBarCornerRadius : 0
            border.width: SettingsData.taskBarBorderEnabled ? SettingsData.taskBarBorderWidth : 0
            border.color: {
                if (!SettingsData.taskBarBorderEnabled) return "transparent"
                if (SettingsData.taskBarDynamicBorderColors && Theme.currentTheme === Theme.dynamic) return Theme.primary
                return Qt.rgba(SettingsData.taskBarBorderRed, SettingsData.taskBarBorderGreen, SettingsData.taskBarBorderBlue, SettingsData.taskBarBorderAlpha)
            }
        }

        Item {
            id: panelContent
            anchors.fill: parent
            anchors.leftMargin: spx(4)
            anchors.rightMargin: spx(4)
            anchors.topMargin: spx(SettingsData.taskBarTopPadding || 0)
            anchors.bottomMargin: spx(SettingsData.taskBarBottomPadding || 0)
            clip: true

            function getWidgetEnabled(enabled) {
                return enabled !== false
            }

            readonly property var widgetVisibility: ({
                                                         "cpuUsage": DgopService.dgopAvailable,
                                                         "memUsage": DgopService.dgopAvailable,
                                                         "cpuTemp": DgopService.dgopAvailable,
                                                         "gpuTemp": DgopService.dgopAvailable,
                                                         "network_speed_monitor": DgopService.dgopAvailable
                                                     })

            function getWidgetVisible(widgetId) {
                return widgetVisibility[widgetId] ?? true
            }

            readonly property var componentMap: ({
                                                     "launcherButton": launcherButtonComponent,
                                                     "launchpad": launchpadComponent,
                                                     "workspaceSwitcher": workspaceSwitcherComponent,
                                                     "focusedWindow": focusedWindowComponent,
                                                     "runningApps": runningAppsComponent,
                                                    "clock": clockComponent,
                                                    "music": mediaComponent,
                                                    "mediaDisplay": mediaDisplayComponent,
                                                    "weather": weatherComponent,
                                                     "darkDash": darkDashComponent,
                                                     "applications": applicationsComponent,
                                                     "systemTray": systemTrayComponent,
                                                     "privacyIndicator": privacyIndicatorComponent,
                                                     "clipboard": clipboardComponent,
                                                     "trash": trashComponent,
                                                     "cpuUsage": cpuUsageComponent,
                                                     "memUsage": memUsageComponent,
                                                     "cpuTemp": cpuTempComponent,
                                                     "gpuTemp": gpuTempComponent,
                                                     "notificationButton": notificationButtonComponent,
                                                     "battery": batteryComponent,
                                                     "controlCenterButton": controlCenterButtonComponent,
                                                     "idleInhibitor": idleInhibitorComponent,
                                                     "spacer": spacerComponent,
                                                     "separator": separatorComponent,
                                                     "network_speed_monitor": networkComponent,
                                                     "keyboard_layout_name": keyboardLayoutNameComponent,
                                                     "vpn": vpnComponent,
                                                     "notepadButton": notepadButtonComponent,
                                                     "colorPicker": colorPickerComponent,
                                                     "systemUpdate": systemUpdateComponent,
"volumeMixerButton": volumeMixerButtonComponent,
                                                     "pinnedApps": pinnedAppsComponent,
                                                     "settingsButton": settingsButtonComponent
                                                  })

            function getWidgetComponent(widgetId) {
                return componentMap[widgetId] || null
            }

            Item {
                id: contentRow
                anchors.fill: parent

                // Left section
                Row {
                    id: leftSection
                    height: parent.height
                    spacing: (SettingsData.taskbarIconSpacing || 0) * uiScale
                    anchors.left: parent.left
                    anchors.leftMargin: spx(8)
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: SettingsData.taskBarLeftWidgetsModel

                        Connections {
                            target: SettingsData.taskBarLeftWidgetsModel
                            function onCountChanged() {
                                leftSection.visible = false
                                Qt.callLater(() => { leftSection.visible = true })
                            }
                        }

                        Loader {
                            property string widgetId: model.widgetId
                            property var widgetData: model
                            property int spacerSize: model.size || 20
                            property bool isBarVertical: panelContainer.barIsVertical
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            active: leftSection.visible && panelContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                            sourceComponent: panelContent.getWidgetComponent(model.widgetId)
                            opacity: panelContent.getWidgetEnabled(model.enabled) ? 1 : 0
                            asynchronous: false
                        }
                    }
                }

                // Center section
                Item {
                    id: centerSection
                    width: centerRow.width
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        id: centerRow
                        height: parent.height
                        spacing: (SettingsData.taskbarIconSpacing || 0) * uiScale
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: SettingsData.taskBarCenterWidgetsModel

                            Connections {
                                target: SettingsData.taskBarCenterWidgetsModel
                                function onCountChanged() {
                                    centerRow.visible = false
                                    Qt.callLater(() => { centerRow.visible = true })
                                }
                            }

                            Loader {
                                property string widgetId: model.widgetId
                                property var widgetData: model
                                property int spacerSize: model.size || 20
                                property bool isBarVertical: panelContainer.barIsVertical
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                active: centerSection.visible && panelContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                sourceComponent: panelContent.getWidgetComponent(model.widgetId)
                                opacity: panelContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                asynchronous: false
                            }
                        }
                    }
                }

                // Right section
                Row {
                    id: rightSection
                    height: parent.height
                    spacing: (SettingsData.taskbarIconSpacing || 0) * uiScale
                    anchors.right: parent.right
                    anchors.rightMargin: spx(8)
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: SettingsData.taskBarRightWidgetsModel

                        Connections {
                            target: SettingsData.taskBarRightWidgetsModel
                            function onCountChanged() {
                                rightSection.visible = false
                                Qt.callLater(() => { rightSection.visible = true })
                            }
                        }

                        Loader {
                            property string widgetId: model.widgetId
                            property var widgetData: model
                            property int spacerSize: model.size || 20
                            property bool isBarVertical: panelContainer.barIsVertical
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            active: rightSection.visible && panelContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                            sourceComponent: panelContent.getWidgetComponent(model.widgetId)
                            opacity: panelContent.getWidgetEnabled(model.enabled) ? 1 : 0
                            asynchronous: false
                        }
                    }
                }
            }

            // Widget Components
            Component {
                id: launcherButtonComponent
                TaskBarLauncherButton {
                    isActive: false
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "left"
                    popupTarget: appDrawerLoader ? appDrawerLoader.item : null
                    parentScreen: root.screen
                    onClicked: {
                        if (appDrawerLoader) {
                            appDrawerLoader.active = true
                            const item = appDrawerLoader.item
                            if (item) {
                                if (_pendingTriggerPosition) {
                                    item.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, _pendingTriggerScreen)
                                    _pendingTriggerPosition = false
                                }
                                item.toggle()
                            }
                        }
                    }
                }
            }

            Component {
                id: launchpadComponent
                TaskBarLaunchpad {
                    widgetHeight: root.widgetHeight
                    parentScreen: root.screen
                }
            }

            Component {
                id: workspaceSwitcherComponent
                TaskBarWorkspaceSwitcher {
                    screenName: root.screenName
                    widgetHeight: root.widgetHeight
                    isBarVertical: false
                }
            }

            Component {
                id: focusedWindowComponent
                TaskBarFocusedApp {
                    availableWidth: 456
                    widgetHeight: root.widgetHeight
                }
            }

            Component {
                id: runningAppsComponent
                TaskBarRunningApps {
                    widgetHeight: root.widgetHeight
                    section: "left"
                    parentScreen: root.screen
                    topBar: panelContent
                    contextMenu: root.contextMenu
                }
            }

            Component {
                id: clockComponent
                TaskBarClock {
                    compactMode: false
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                    onOpenCalendarPopup: {
                        calendarPopupLoader.active = true
                        if (calendarPopupLoader.item) {
                            const pos = mapToItem(null, 0, 0)
                            calendarPopupLoader.item.parentScreen = root.screen
                            calendarPopupLoader.item.panelScale = (SettingsData.taskbarScale || 1)
                            calendarPopupLoader.item.barPosition = "bottom"
                            calendarPopupLoader.item.barThickness = root.panelHeight
                            calendarPopupLoader.item.triggerX = pos.x
                            calendarPopupLoader.item.triggerY = pos.y
                            calendarPopupLoader.item.triggerWidth = width
                            calendarPopupLoader.item.open()
                        }
                    }
                }
            }

            Component {
                id: mediaComponent
                TaskBarMedia {
                    compactMode: false
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: mediaDisplayComponent
                TaskBarMediaDisplay {
                    compactMode: false
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: weatherComponent
                TaskBarWeather {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                    onOpenWeatherPopup: {
                        if (weatherPopupLoader) {
                            weatherPopupLoader.active = true
                            if (weatherPopupLoader.item) {
                                const pos = mapToItem(null, 0, 0)

                                weatherPopupLoader.item.parentScreen = root.screen
                                weatherPopupLoader.item.barPosition = "bottom"
                                weatherPopupLoader.item.barThickness = root.panelHeight
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
                id: darkDashComponent
                TaskBarDarkDash {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: applicationsComponent
                TaskBarApplications {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "center"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: systemTrayComponent
                TaskBarSystemTrayBar {
                    parentWindow: root
                    parentScreen: root.screen
                    widgetHeight: root.widgetHeight
                    isAtBottom: true
                    isVertical: false
                    isBarVertical: false
                    axis: null
                    visible: true
                }
            }

            Component {
                id: privacyIndicatorComponent
                TaskBarPrivacyIndicator {
                    widgetHeight: root.widgetHeight
                    section: "right"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: cpuUsageComponent
                TaskBarCpuMonitor {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "right"
                    popupTarget: {
                        processListPopoutLoader.active = true
                        return processListPopoutLoader.item
                    }
                    parentScreen: root.screen
                    toggleProcessList: () => {
                                           processListPopoutLoader.active = true
                                           return processListPopoutLoader.item?.toggle()
                                       }
                    isBarVertical: false
                }
            }

            Component {
                id: memUsageComponent
                TaskBarRamMonitor {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "right"
                    popupTarget: {
                        processListPopoutLoader.active = true
                        return processListPopoutLoader.item
                    }
                    parentScreen: root.screen
                    toggleProcessList: () => {
                                           processListPopoutLoader.active = true
                                           return processListPopoutLoader.item?.toggle()
                                       }
                    isBarVertical: false
                }
            }

            Component {
                id: cpuTempComponent
                TaskBarCpuTemperature {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "right"
                    popupTarget: {
                        processListPopoutLoader.active = true
                        return processListPopoutLoader.item
                    }
                    parentScreen: root.screen
                    toggleProcessList: () => {
                                           processListPopoutLoader.active = true
                                           return processListPopoutLoader.item?.toggle()
                                       }
                    isBarVertical: false
                }
            }

            Component {
                id: gpuTempComponent
                TaskBarGpuTemperature {
                    barHeight: root.panelHeight
                    widgetHeight: root.widgetHeight
                    section: "right"
                    popupTarget: {
                        processListPopoutLoader.active = true
                        return processListPopoutLoader.item
                    }
                    parentScreen: root.screen
                    widgetData: parent.widgetData
                    toggleProcessList: () => {
                                           processListPopoutLoader.active = true
                                           return processListPopoutLoader.item?.toggle()
                                       }
                    isBarVertical: false
                }
            }

            Component {
                id: networkComponent
                TaskBarNetworkMonitor {
                    isBarVertical: false
                }
            }

            Component {
                id: notificationButtonComponent
                TaskBarNotificationCenterButton {
                    hasUnread: root.notificationCount > 0
                    isActive: notificationCenterLoader.item ? notificationCenterLoader.item.shouldBeVisible : false
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    popupTarget: {
                        notificationCenterLoader.active = true
                        return notificationCenterLoader.item
                    }
                    parentScreen: root.screen
                    onClicked: {
                        notificationCenterLoader.active = true
                        notificationCenterLoader.item?.toggle()
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: batteryComponent
                TaskBarBattery {
                    batteryPopupVisible: batteryPopoutLoader.item ? batteryPopoutLoader.item.shouldBeVisible : false
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    popupTarget: {
                        batteryPopoutLoader.active = true
                        return batteryPopoutLoader.item
                    }
                    parentScreen: root.screen
                    onToggleBatteryPopup: {
                        batteryPopoutLoader.active = true
                        batteryPopoutLoader.item?.toggle()
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: vpnComponent
                TaskBarVpn {
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    popupTarget: {
                        vpnPopoutLoader.active = true
                        return vpnPopoutLoader.item
                    }
                    parentScreen: root.screen
                    onToggleVpnPopup: {
                        vpnPopoutLoader.active = true
                        vpnPopoutLoader.item?.toggle()
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: controlCenterButtonComponent
                TaskBarControlCenterButton {
                    isActive: Boolean(controlCenterLoader.item?.showMenu)
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    barPosition: "bottom"
                    section: "right"
                    popupTarget: {
                        controlCenterLoader.active = true
                        return controlCenterLoader.item
                    }
                    parentScreen: root.screen
                    widgetData: parent.widgetData
                    onClicked: {
                        const pos = mapToItem(null, 0, 0)
                        controlCenterLoader.active = true
                        Qt.callLater(() => {
                            if (controlCenterLoader.item) {
                                controlCenterLoader.item.triggerX = pos.x
                                controlCenterLoader.item.triggerY = pos.y
                                controlCenterLoader.item.triggerWidth = width
                                controlCenterLoader.item.barPosition = "bottom"
                                controlCenterLoader.item.barThickness = SettingsData.taskBarHeight
                                controlCenterLoader.item.parentScreen = root.screen
                                controlCenterLoader.item.toggle()
                                if (controlCenterLoader.item.showMenu && NetworkService.wifiEnabled) {
                                    NetworkService.scanWifi()
                                }
                            }
                        })
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: idleInhibitorComponent
                TaskBarIdleInhibitor {
                    widgetHeight: root.widgetHeight
                    section: "right"
                    parentScreen: root.screen
                    isBarVertical: false
                }
            }

            Component {
                id: spacerComponent
                Item {
                    width: parent.spacerSize || 20
                    height: root.widgetHeight
                }
            }

            Component {
                id: separatorComponent
                Rectangle {
                    width: 1
                    height: root.widgetHeight * 0.67
                    color: Theme.outline
                    opacity: 0.3
                }
            }

            Component {
                id: keyboardLayoutNameComponent
                TaskBarKeyboardLayoutName {
                    isBarVertical: false
                }
            }

            Component {
                id: notepadButtonComponent
                TaskBarNotepadButton {
                    property var notepadInstance: root.getNotepadInstanceForScreen()
                    isActive: notepadInstance?.isVisible ?? false
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    popupTarget: notepadInstance
                    parentScreen: root.screen
                    onClicked: {
                        if (notepadInstance) {
                            notepadInstance.toggle()
                        }
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: colorPickerComponent
                TaskBarColorPicker {
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    parentScreen: root.screen
                    onColorPickerRequested: {
                        root.colorPickerRequested()
                    }
                    isBarVertical: false
                }
            }

            Component {
                id: systemUpdateComponent
                TaskBarSystemUpdate {
                    id: systemUpdateButton
                    isActive: false
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    parentScreen: root.screen
                    isBarVertical: false
                    onClicked: {
                        console.log("[TaskBar] SystemUpdate clicked, activating loader")
                        systemUpdatePopoutLoader.active = true
                        Qt.callLater(() => {
                            console.log("[TaskBar] Checking loader item: " + !!systemUpdatePopoutLoader.item)
                            if (systemUpdatePopoutLoader.item) {
                                console.log("[TaskBar] Calling openForItem on popup")
                                systemUpdatePopoutLoader.item.openForItem(systemUpdateButton, root.screen, "bottom", false, root.panelHeight)
                            }
                        })
                    }
                }
            }

            Component {
                id: volumeMixerButtonComponent
                TaskBarVolumeMixerButton {
                    id: volumeMixerButton
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    parentScreen: root.screen
                    isBarVertical: false
                    onClicked: {
                        volumeMixerPopoutLoader.active = true
                        Qt.callLater(() => {
                            if (volumeMixerPopoutLoader.item) {
                                volumeMixerPopoutLoader.item.openForItem(volumeMixerButton, root.screen, "bottom", false, root.panelHeight)
                            }
                        })
                    }
                }
            }

            Component {
                id: pinnedAppsComponent
                TaskBarPinnedApps {
                    widgetHeight: root.widgetHeight
                    section: "left"
                    parentScreen: root.screen
                    contextMenu: root.contextMenu
                }
            }

            Component {
                id: settingsButtonComponent
                TaskBarSettingsButton {
                    widgetHeight: root.widgetHeight
                    barHeight: root.panelHeight
                    section: "right"
                    parentScreen: root.screen
                }
            }

            Component {
                id: clipboardComponent
                Rectangle {
                    readonly property real horizontalPadding: Math.max(Theme.spacingXS, Theme.spacingS * (root.widgetHeight / 30))
                    width: clipboardIcon.width + horizontalPadding * 2
                    height: root.widgetHeight
                    radius: Theme.cornerRadius
                    color: {
                        const baseColor = clipboardArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
                        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * 0.85)
                    }

                    EHIcon {
                        id: clipboardIcon
                        anchors.centerIn: parent
                        name: "content_paste"
                        size: Theme.iconSize - 10
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: clipboardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboardHistoryModalPopup.toggle()
                        }
                    }
                }
            }

            Component {
                id: trashComponent
                TaskBarTrashBin {
                    widgetHeight: root.widgetHeight
                    section: "right"
                    parentScreen: root.screen
                }
            }
        }
    }

    Loader {
        id: taskBarContextMenuLoader
        active: SettingsData.taskBarVisible
        asynchronous: false
        sourceComponent: Component {
            TaskBarContextMenu {
                id: taskBarContextMenu
                screen: root.screen
            }
        }
    }

    Loader {
        id: weatherPopupLoader
        active: false
        sourceComponent: Component {
            WeatherPopup {
                parentScreen: root.screen
            }
        }
    }

    Loader {
        id: calendarPopupLoader
        active: false
        sourceComponent: Component {
            CalendarPopup {
                parentScreen: root.screen
            }
        }
    }
}