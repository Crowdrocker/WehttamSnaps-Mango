import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Modals
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Modals.Settings
import qs.Modals.Spotlight
import qs.Modules
import qs.Modules.AppDrawer
import qs.Modules.DarkDash
import qs.Modules.PackageManager
import qs.Modules.Calendar
import qs.Modules.Weather
import qs.Modules.Applications
import qs.Modules.Dock
import qs.Modules.Lock
import qs.Modules.Notifications.Center
import qs.Widgets
import "./Modules/Notepad"
import qs.Modules.Notifications.Popup
import qs.Modules.OSD
import qs.Modules.ProcessList
import qs.Modules.Settings
import qs.Modules.TopBar
import qs.Modules.TopBar.TopBarControlCenter
import qs.Modules.TaskBar
import qs.Modules.TaskBar.TaskBarControlCenter
import qs.Modules.TaskBar.TaskBarAppDrawer
import qs.Modules.TaskBar.Widgets
import qs.Modules.Desktop
import qs.Modules.MiniPanel
import qs.Modules.WorkspaceOverview
import qs.Modules.Spotlight
import qs.Services
import "./Common/PowerActionUtils.js" as PowerActionUtils

ShellRoot {
    id: root

    // LazyLoader / Loader often populates `item` one event tick after `active=true`.
    // IPC calls were returning *_OPEN_FAILED because they checked `item` synchronously.
    function _ipcWithLazyItem(loader, whenReady) {
        loader.active = true
        if (loader.item) {
            whenReady(loader.item)
            return
        }
        var n = 0
        function step() {
            if (loader.item) {
                whenReady(loader.item)
                return
            }
            n++
            if (n < 40)
                Qt.callLater(step)
        }
        Qt.callLater(step)
    }

    Component.onCompleted: {
        PortalService.init()
        // Removed property accesses that were causing premature initialization
        // and triggering Qt.callLater before QCoreApplication was ready
        SettingsData.bootstrapSystemdUserServiceIfNeeded()
        // Force PolkitService singleton initialization (agent registers on load)
        PolkitService.polkitAvailable
        // Hook screenshot capture hosts (per screen)
        ScreenshotService.screencopyCaptures = screencopyCaptureHosts.captureMap
    }

    Connections {
        target: ColorPaletteService
        function onCustomThemeCreated(themeData) {
            if (themeData) {
            }
        }
    }

    Connections {
        target: ModalManager
        function onOpenSettingsRequested() {
            root._ipcWithLazyItem(settingsModalLoader, function (item) {
                item.show()
            })
        }
    }

    WallpaperBackground {}

    DesktopWidgetLayer {}

    // Desktop icons controller - scans Desktop folder and creates icon widgets
    DesktopIconsController {
        id: desktopIconsController
    }

    Lock {
        id: lock

        anchors.fill: parent
    }

    Loader {
        id: topBarVariantsLoader
        active: true
        sourceComponent: Component {
            Variants {
                id: topBarVariants
                model: SettingsData.getFilteredScreens("topBar")

                delegate: TopBar {
                    modelData: item
                    notepadVariants: notepadSlideoutVariants
                    onColorPickerRequested: colorPickerModal.show()
                }
            }
        }
    }

    Connections {
        target: SettingsData
        function onTopBarPositionChanged() {
            Qt.callLater(() => {
                topBarVariantsLoader.active = false
                Qt.callLater(() => {
                    topBarVariantsLoader.active = true
                })
            })
        }
    }




    Loader {
        id: miniPanelVariantsLoader
        active: SettingsData.showMiniPanel
        sourceComponent: Component {
            Variants {
                model: SettingsData.getFilteredScreens("miniPanel")
                delegate: MiniPanel {
                    modelData: item
                }
            }
        }
    }

    Connections {
        target: SettingsData
        function onShowMiniPanelChanged() {
            miniPanelVariantsLoader.active = SettingsData.showMiniPanel
            // Apply default widgets when enabling mini panel for the first time
            if (SettingsData.showMiniPanel) {
                if (!SettingsData.miniPanelLeftWidgets || SettingsData.miniPanelLeftWidgets.length === 0)
                    SettingsData.miniPanelLeftWidgets = ["launcherButton", "workspaceSwitcher", "windowPreview"]
                if (!SettingsData.miniPanelCenterWidgets || SettingsData.miniPanelCenterWidgets.length === 0)
                    SettingsData.miniPanelCenterWidgets = ["music"]
                if (!SettingsData.miniPanelRightWidgets || SettingsData.miniPanelRightWidgets.length === 0)
                    SettingsData.miniPanelRightWidgets = ["systemTray", "clock", "notificationButton", "controlCenterButton"]
            }
        }
    }

    Loader {
        id: dockVariantsLoader
        active: true
        sourceComponent: Component {
            Variants {
                model: SettingsData.getFilteredScreens("dock")

                delegate: Dock {
                    modelData: item
                    contextMenu: dockContextMenuLoader.item ? dockContextMenuLoader.item : null
                }
            }
        }
    }

    Connections {
        target: SettingsData
        function onDockExpandToScreenChanged() {
            Qt.callLater(() => {
                dockVariantsLoader.active = false
                Qt.callLater(() => {
                    dockVariantsLoader.active = true
                })
            })
        }
        function onDockCenterAppsChanged() {
            Qt.callLater(() => {
                dockVariantsLoader.active = false
                Qt.callLater(() => {
                    dockVariantsLoader.active = true
                })
            })
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("taskBar")

        delegate: TaskBar {
            modelData: item
            appDrawerLoader: taskBarAppDrawerLoader
            notepadVariants: notepadSlideoutVariants
            onColorPickerRequested: colorPickerModal.show()
        }
    }

    LazyLoader {
        id: darkDashLoader

        active: false

        DarkDashPopout {
            id: darkDashPopout
        }
    }

    LazyLoader {
        id: applicationsLoader

        active: false

        ApplicationsPopout {
            id: applicationsPopout
        }
    }

    LazyLoader {
        id: launchpadLoader

        active: false

        LaunchpadModal {
            id: launchpadModal
        }
    }

    Loader {
        id: dockContextMenuLoader

        active: true

        sourceComponent: DockContextMenu {
            id: dockContextMenu
        }
    }


    LazyLoader {
        id: notificationCenterLoader

        active: false

        NotificationCenterPopout {
            id: notificationCenter
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("notifications")

        delegate: NotificationPopupManager {
            modelData: item
        }
    }

    LazyLoader {
        id: controlCenterLoader

        active: false

        TopBarControlCenterPopout {
            id: controlCenterPopout

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
                    root._ipcWithLazyItem(powerConfirmModalLoader, function (item) {
                        item.showConfirmation(action, selected.title, selected.message)
                    })
                }
            }
            onLockRequested: {
                lock.activate()
            }
        }
    }

    LazyLoader {
        id: wifiPasswordModalLoader

        active: false

        WifiPasswordModal {
            id: wifiPasswordModal
        }
    }

    QtObject {
        id: screencopyCaptureHosts
        property var captureMap: ({})
    }

    // Per-screen capture hosts. Must be attached to a Window so grabToImage works.
    // Keep these surfaces as minimal as possible to avoid impacting compositor
    // composition; they expand only while capturing.
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: host
            required property var modelData
            readonly property var screenObj: modelData
            screen: screenObj

            visible: true
            color: "transparent"

            implicitWidth: capture.busy ? Math.round((screenObj.width || 1) * (screenObj.scale || 1)) : 1
            implicitHeight: capture.busy ? Math.round((screenObj.height || 1) * (screenObj.scale || 1)) : 1

            WlrLayershell.namespace: "quickshell:screencopy-capture"
            WlrLayershell.layer: WlrLayershell.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // No input region.
            mask: Region { item: Item {} }

            anchors { top: true; left: true }

            ScreencopyFileCapture {
                id: capture
                anchors.fill: parent
                visible: true
                opacity: 1
            }

            Component.onCompleted: {
                const m = screencopyCaptureHosts.captureMap
                m[screenObj.name] = capture
                screencopyCaptureHosts.captureMap = m
            }
        }
    }

    ScreenshotAreaModal {
        id: screenshotAreaModal

        onFinished: (ok, path) => {
            if (ok)
                ScreenshotService.postProcess(path)
            // Clean up background capture file best-effort.
            if (screenshotAreaModal.backgroundPath)
                Quickshell.execDetached(["rm", "-f", screenshotAreaModal.backgroundPath])
        }
    }

    Connections {
        target: ScreenshotService
        function onAreaRequested(path, backgroundPath) {
            // Ensure modal appears on the focused screen.
            const focused = (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor)
                ? Hyprland.focusedWorkspace.monitor.name : ""
            if (focused && Quickshell.screens) {
                const sc = Quickshell.screens.find(s => s.name === focused)
                if (sc)
                    screenshotAreaModal.screen = sc
            }
            screenshotAreaModal.start(path, backgroundPath)
        }
    }

    LazyLoader {
        id: polkitAuthModalLoader

        active: false

        PolkitAuthModal {
            id: polkitAuthModal
        }
    }

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onAuthenticationRequestStarted() {
            polkitAuthModalLoader.active = true
            if (polkitAuthModalLoader.item)
                polkitAuthModalLoader.item.show()
        }
    }

    LazyLoader {
        id: networkInfoModalLoader

        active: false

        NetworkInfoModal {
            id: networkInfoModal
        }
    }

    LazyLoader {
        id: batteryPopoutLoader

        active: false

        TaskBarBatteryPopout {
            id: batteryPopout
        }
    }

    LazyLoader {
        id: vpnPopoutLoader

        active: false

        TaskBarVpnPopout {
            id: vpnPopout
        }
    }

    LazyLoader {
        id: volumeMixerPopoutLoader

        active: false

        TaskBarVolumeMixerPopout {
            id: volumeMixerPopout
        }
    }

    LazyLoader {
        id: systemUpdatePopoutLoader

        active: false

        TaskBarSystemUpdatePopout {
            id: systemUpdatePopout
        }
    }

    LazyLoader {
        id: powerMenuLoader

        active: false

        PowerMenu {
            id: powerMenu

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
                    root._ipcWithLazyItem(powerConfirmModalLoader, function (item) {
                        item.showConfirmation(action, selected.title, selected.message)
                    })
                }
            }
        }
    }

    LazyLoader {
        id: powerConfirmModalLoader

        active: false

        PowerConfirmationModal {
            id: powerConfirmModal
            
            onConfirmed: function(action) {
                switch(action) {
                    case "logout":
                        SessionService.logout()
                        break
                    case "reboot":
                        SessionService.reboot()
                        break
                    case "poweroff":
                        SessionService.poweroff()
                        break
                    case "suspend":
                        SessionService.suspend()
                        break
                    case "hibernate":
                        SessionService.hibernate()
                        break
                }
            }
        }
    }

    LazyLoader {
        id: processListPopoutLoader

        active: false

        ProcessListPopout {
            id: processListPopout
        }
    }

    LazyLoader {
        id: settingsModalLoader
        active: false

        SettingsModal {
            id: settingsModal
            objectName: "settingsModal"
        }
    }

    LazyLoader {
        id: taskBarAppDrawerLoader
        active: false
        
        TaskBarAppDrawerPopout {
            id: taskBarAppDrawerPopout
        }
    }

    LazyLoader {
        id: appDrawerLoader

        active: false

        AppDrawerPopout {
            id: appDrawerPopout
        }
    }

    SpotlightModal {
        id: spotlightModal
    }

    SpotlightWindow {
        id: spotlightWindowInstance
    }



    
    ClipboardHistoryModal {
        id: clipboardHistoryModalPopup
    }

    NotificationModal {
        id: notificationModal
    }
    ColorPickerModal {
        id: colorPickerModal
    }

    LazyLoader {
        id: processListModalLoader

        active: false

        ProcessListModal {
            id: processListModal
        }
    }


    Variants {
        id: notepadSlideoutVariants
        model: SettingsData.getFilteredScreens("notepad")

        delegate: EHSlideout {
            id: notepadSlideout
            modelData: item
            title: qsTr("Notepad")
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960
            customTransparency: SettingsData.notepadTransparencyOverride

            content: Component {
                Notepad {
                    onHideRequested: {
                        notepadSlideout.hide()
                    }
                }
            }

            function toggle() {
                if (isVisible) {
                    hide()
                } else {
                    show()
                }
            }
        }
    }

    LazyLoader {
        id: powerMenuModalLoader

        active: false

        PowerMenuModal {
            id: powerMenuModal

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
                    root._ipcWithLazyItem(powerConfirmModalLoader, function (item) {
                        item.showConfirmation(action, selected.title, selected.message)
                    })
                }
            }
        }
    }

    IpcHandler {
        function open() {
            root._ipcWithLazyItem(powerMenuModalLoader, function (item) {
                item.open()
            })
            return "POWERMENU_OPEN_SUCCESS"
        }

        function close() {
            if (powerMenuModalLoader.item)
                powerMenuModalLoader.item.close()

            return "POWERMENU_CLOSE_SUCCESS"
        }

        function toggle() {
            root._ipcWithLazyItem(powerMenuModalLoader, function (item) {
                item.toggle()
            })
            return "POWERMENU_TOGGLE_SUCCESS"
        }

        target: "powermenu"
    }

    IpcHandler {
        function open(): string {
            root._ipcWithLazyItem(processListModalLoader, function (item) {
                item.show()
            })
            return "PROCESSLIST_OPEN_SUCCESS"
        }

        function close(): string {
            if (processListModalLoader.item)
                processListModalLoader.item.hide()

            return "PROCESSLIST_CLOSE_SUCCESS"
        }

        function toggle(): string {
            root._ipcWithLazyItem(processListModalLoader, function (item) {
                item.toggle()
            })
            return "PROCESSLIST_TOGGLE_SUCCESS"
        }

        target: "processlist"
    }

    IpcHandler {
        function _focusedScreenName(): string {
            if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor)
                return Hyprland.focusedWorkspace.monitor.name
            if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput)
                return NiriService.currentOutput
            if (CompositorService.isMango && typeof MangoService !== "undefined" && MangoService.lastFocusedOutput)
                return MangoService.lastFocusedOutput
            return ""
        }

        function area(): string {
            ScreenshotService.areaOn(_focusedScreenName())
            return "SCREENSHOT_AREA_SUCCESS"
        }

        function screen(): string {
            ScreenshotService.screenOn(_focusedScreenName())
            return "SCREENSHOT_SCREEN_SUCCESS"
        }

        function fullscreen(): string {
            ScreenshotService.fullscreen()
            return "SCREENSHOT_FULLSCREEN_SUCCESS"
        }

        function window(): string {
            ScreenshotService.window()
            return "SCREENSHOT_WINDOW_SUCCESS"
        }

        target: "screenshot"
    }

    IpcHandler {
        function open(tab: string): string {
            var t = (tab && tab.length) ? tab : ""
            root._ipcWithLazyItem(darkDashLoader, function (item) {
                switch (t.toLowerCase()) {
                case "media":
                    item.currentTabIndex = 1
                    break
                case "weather":
                    item.currentTabIndex = SettingsData.weatherEnabled ? 2 : 0
                    break
                default:
                    item.currentTabIndex = 0
                    break
                }
                item.setTriggerPosition(Screen.width / 2, SettingsData.topBarHeight + SettingsData.topBarSpacing + Theme.spacingS, 100, "center", Screen)
                item.show()
            })
            return "DASH_OPEN_SUCCESS"
        }

        function close(): string {
            if (darkDashLoader.item) {
                darkDashLoader.item.close()
                return "DASH_CLOSE_SUCCESS"
            }
            return "DASH_CLOSE_FAILED"
        }

        function toggle(tab: string): string {
            var t = (tab && tab.length) ? tab : ""
            root._ipcWithLazyItem(darkDashLoader, function (item) {
                if (item.shouldBeVisible) {
                    item.close()
                } else {
                    switch (t.toLowerCase()) {
                    case "media":
                        item.currentTabIndex = 1
                        break
                    case "weather":
                        item.currentTabIndex = SettingsData.weatherEnabled ? 2 : 0
                        break
                    default:
                        item.currentTabIndex = 0
                        break
                    }
                    item.setTriggerPosition(Screen.width / 2, SettingsData.topBarHeight + SettingsData.topBarSpacing + Theme.spacingS, 100, "center", Screen)
                    item.show()
                }
            })
            return "DASH_TOGGLE_SUCCESS"
        }

        target: "darkDash"
    }

    // PikaPack Package Manager
    LazyLoader {
        id: packageManagerModalLoader

        active: false

        PackageManagerModal {
            id: packageManagerModal
        }
    }

    IpcHandler {
        function getFocusedScreenName() {
            if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
                return Hyprland.focusedWorkspace.monitor.name
            }
            if (CompositorService.isNiri && NiriService.currentOutput) {
                return NiriService.currentOutput
            }
            if (CompositorService.isMango && MangoService.lastFocusedOutput) {
                return MangoService.lastFocusedOutput
            }
            return ""
        }

        function getActiveNotepadInstance() {
            if (notepadSlideoutVariants.instances.length === 0) {
                return null
            }

            if (notepadSlideoutVariants.instances.length === 1) {
                return notepadSlideoutVariants.instances[0]
            }

            var focusedScreen = getFocusedScreenName()
            if (focusedScreen && notepadSlideoutVariants.instances.length > 0) {
                for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                    var slideout = notepadSlideoutVariants.instances[i]
                    if (slideout.modelData && slideout.modelData.name === focusedScreen) {
                        return slideout
                    }
                }
            }

            for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                var slideout = notepadSlideoutVariants.instances[i]
                if (slideout.isVisible) {
                    return slideout
                }
            }

            return notepadSlideoutVariants.instances[0]
        }

        function open(): string {
            var instance = getActiveNotepadInstance()
            if (instance) {
                instance.show()
                return "NOTEPAD_OPEN_SUCCESS"
            }
            return "NOTEPAD_OPEN_FAILED"
        }

        function close(): string {
            var instance = getActiveNotepadInstance()
            if (instance) {
                instance.hide()
                return "NOTEPAD_CLOSE_SUCCESS"
            }
            return "NOTEPAD_CLOSE_FAILED"
        }

        function toggle(): string {
            var instance = getActiveNotepadInstance()
            if (instance) {
                instance.toggle()
                return "NOTEPAD_TOGGLE_SUCCESS"
            }
            return "NOTEPAD_TOGGLE_FAILED"
        }

        target: "notepad"
    }

    IpcHandler {
        function _focusedScreen() {
            if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === Hyprland.focusedWorkspace.monitor.name)
                        return Quickshell.screens[i]
                }
            }
            if (CompositorService.isNiri && NiriService.currentOutput) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === NiriService.currentOutput)
                        return Quickshell.screens[i]
                }
            }
            if (CompositorService.isMango && MangoService.lastFocusedOutput) {
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === MangoService.lastFocusedOutput)
                        return Quickshell.screens[i]
                }
            }
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        }

        function open(): string {
            root._ipcWithLazyItem(appDrawerLoader, function (item) {
                const scr = _focusedScreen()
                item.setTriggerPosition((scr ? scr.width / 2 : Screen.width / 2), (scr ? scr.height / 2 : Screen.height / 2), 100, "center", scr)
                item.show()
            })
            return "APPDRAWER_OPEN_SUCCESS"
        }

        function close(): string {
            if (appDrawerLoader.item) {
                appDrawerLoader.item.close()
                return "APPDRAWER_CLOSE_SUCCESS"
            }
            return "APPDRAWER_CLOSE_FAILED"
        }

        function toggle(): string {
            root._ipcWithLazyItem(appDrawerLoader, function (item) {
                if (item.shouldBeVisible)
                    item.close()
                else {
                    const scr = _focusedScreen()
                    item.setTriggerPosition((scr ? scr.width / 2 : Screen.width / 2), (scr ? scr.height / 2 : Screen.height / 2), 100, "center", scr)
                    item.show()
                }
            })
            return "APPDRAWER_TOGGLE_SUCCESS"
        }

        target: "appDrawerPopout"
    }

    Variants {
        model: SettingsData.getFilteredScreens("toast")

        delegate: Toast {
            modelData: item
            visible: ToastService.toastVisible
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: VolumeOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: MicMuteOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: InputOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: BrightnessOSD {
            modelData: item
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("osd")

        delegate: IdleInhibitorOSD {
            modelData: item
        }
    }

    LazyLoader {
        id: workspaceOverviewLoader

        active: false

        WorkspaceOverviewWidget {
            id: workspaceOverviewWidget
        }
    }

    IpcHandler {
        function toggle(): string {
            root._ipcWithLazyItem(workspaceOverviewLoader, function (item) {
                item.toggle()
            })
            return "WORKSPACE_OVERVIEW_TOGGLE_SUCCESS"
        }

        function show(): string {
            root._ipcWithLazyItem(workspaceOverviewLoader, function (item) {
                item.show()
            })
            return "WORKSPACE_OVERVIEW_SHOWN"
        }

        function hide(): string {
            if (workspaceOverviewLoader.item) {
                workspaceOverviewLoader.item.hide()
                return "WORKSPACE_OVERVIEW_HIDDEN"
            }
            root._ipcWithLazyItem(workspaceOverviewLoader, function (item) {
                item.hide()
            })
            return "WORKSPACE_OVERVIEW_HIDDEN"
        }

        target: "workspaceoverview"
    }

    IpcHandler {
        function open(): string {
            root._ipcWithLazyItem(packageManagerModalLoader, function (item) {
                item.show()
            })
            return "PIKAPACK_OPEN_SUCCESS"
        }

        function close(): string {
            if (packageManagerModalLoader.item) {
                packageManagerModalLoader.item.hide()
                return "PIKAPACK_CLOSE_SUCCESS"
            }
            return "PIKAPACK_CLOSE_FAILED"
        }

        function toggle(): string {
            root._ipcWithLazyItem(packageManagerModalLoader, function (item) {
                item.toggle()
            })
            return "PIKAPACK_TOGGLE_SUCCESS"
        }

        target: "pikapack"
    }

    // Calendar App
    LazyLoader {
        id: calendarModalLoader

        active: false

        CalendarModal {
            id: calendarModal
        }
    }

    IpcHandler {
        function open(): string {
            root._ipcWithLazyItem(calendarModalLoader, function (item) {
                item.show()
            })
            return "CALENDAR_OPEN_SUCCESS"
        }

        function close(): string {
            if (calendarModalLoader.item) {
                calendarModalLoader.item.hide()
                return "CALENDAR_CLOSE_SUCCESS"
            }
            return "CALENDAR_CLOSE_FAILED"
        }

        function toggle(): string {
            root._ipcWithLazyItem(calendarModalLoader, function (item) {
                item.toggle()
            })
            return "CALENDAR_TOGGLE_SUCCESS"
        }

        target: "calendar"
    }

    // Media popup (MPRIS)
    LazyLoader {
        id: mediaPopupLoader

        active: false

        MediaPopup {
            id: mediaPopup
        }
    }

    IpcHandler {
        function _getFocusedScreenName(): string {
            if (CompositorService.isHyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
                return Hyprland.focusedWorkspace.monitor.name
            }
            if (CompositorService.isNiri && NiriService.currentOutput) {
                return NiriService.currentOutput
            }
            if (CompositorService.isMango && MangoService.lastFocusedOutput) {
                return MangoService.lastFocusedOutput
            }
            return ""
        }

        function _screenByName(name: string) {
            if (!name || name.length === 0) return null
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
            }
            return null
        }

        function open(): string {
            return openOn("")
        }

        function openOn(screenName: string): string {
            const focusedName = screenName && screenName.length ? screenName : _getFocusedScreenName()
            const scr = _screenByName(focusedName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

            root._ipcWithLazyItem(mediaPopupLoader, function (item) {
                if (scr) item.parentScreen = scr
                item.barPosition = "bottom"
                item.barThickness = SettingsData.dockHeight || 48
                item.triggerX = (scr ? (scr.x || 0) + scr.width / 2 : Screen.width / 2)
                item.triggerY = (scr ? (scr.y || 0) + scr.height / 2 : Screen.height / 2)
                item.triggerWidth = 80
                item.open()
            })
            return "MEDIA_OPEN_SUCCESS"
        }

        function close(): string {
            if (mediaPopupLoader.item) {
                mediaPopupLoader.item.close()
                return "MEDIA_CLOSE_SUCCESS"
            }
            return "MEDIA_CLOSE_FAILED"
        }

        function toggle(): string {
            return toggleOn("")
        }

        function toggleOn(screenName: string): string {
            const focusedName = screenName && screenName.length ? screenName : _getFocusedScreenName()
            const scr = _screenByName(focusedName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

            root._ipcWithLazyItem(mediaPopupLoader, function (item) {
                if (item.showPopup) {
                    item.close()
                } else {
                    if (scr) item.parentScreen = scr
                    item.barPosition = "bottom"
                    item.barThickness = SettingsData.dockHeight || 48
                    item.triggerX = (scr ? (scr.x || 0) + scr.width / 2 : Screen.width / 2)
                    item.triggerY = (scr ? (scr.y || 0) + scr.height / 2 : Screen.height / 2)
                    item.triggerWidth = 80
                    item.open()
                }
            })
            return "MEDIA_TOGGLE_SUCCESS"
        }

        target: "media"
    }

    // Weather App
    LazyLoader {
        id: weatherModalLoader

        active: false

        WeatherModal {
            id: weatherModal
        }
    }

    IpcHandler {
        function open(): string {
            root._ipcWithLazyItem(weatherModalLoader, function (item) {
                item.show()
            })
            return "WEATHER_OPEN_SUCCESS"
        }

        function close(): string {
            if (weatherModalLoader.item) {
                weatherModalLoader.item.hide()
                return "WEATHER_CLOSE_SUCCESS"
            }
            return "WEATHER_CLOSE_FAILED"
        }

        function toggle(): string {
            root._ipcWithLazyItem(weatherModalLoader, function (item) {
                item.toggle()
            })
            return "WEATHER_TOGGLE_SUCCESS"
        }

        target: "weather"
    }

    IpcHandler {
        function open(): string {
            root._ipcWithLazyItem(settingsModalLoader, function (item) {
                item.show()
            })
            return "SETTINGS_OPEN_SUCCESS"
        }

        function close(): string {
            if (settingsModalLoader.item) {
                settingsModalLoader.item.hide()
                return "SETTINGS_CLOSE_SUCCESS"
            }
            return "SETTINGS_CLOSE_FAILED"
        }

        function toggle(): string {
            root._ipcWithLazyItem(settingsModalLoader, function (item) {
                if (item.shouldBeVisible)
                    item.hide()
                else
                    item.show()
            })
            return "SETTINGS_TOGGLE_SUCCESS"
        }

        target: "settings"
    }
}
