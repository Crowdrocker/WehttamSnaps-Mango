import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals
import qs.Modules.Dock
import qs.Modules.Dock.DockControlCenter
import qs.Modules.Dock.DockAppDrawer
import qs.Modules.Dock.Widgets
import "../../Common/MonitorUtils.js" as MonitorUtils
import "../../Common/PowerActionUtils.js" as PowerActionUtils

PanelWindow {
    id: dock

    WlrLayershell.namespace: "quickshell:dock:blur"

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var modelData
    property var contextMenu
    property bool autoHide: SettingsData.dockAutoHide
    property real backgroundTransparency: SettingsData.dockTransparency
    readonly property bool isVertical: SettingsData.dockPosition === "left" || SettingsData.dockPosition === "right"

    // ── Scaling ───────────────────────────────────────────────────────────────
    // Use one effective scale factor (global UI scale × dock scale) so the Dock
    // scales consistently without mixing hard-coded px and per-module scaling.
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    property bool contextMenuOpen: (contextMenu && contextMenu.visible && contextMenu.screen === modelData)
    property bool windowIsFullscreen: {
        if (!SettingsData.dockHideOnGames || !ToplevelManager.activeToplevel) {
            return false
        }
        const activeWindow = ToplevelManager.activeToplevel
        const fullscreenApps = ["vlc", "mpv", "kodi", "steam", "lutris", "wine", "dosbox"]
        return fullscreenApps.some(app => activeWindow.appId && activeWindow.appId.toLowerCase().includes(app))
    }
    
    // Reveal sticky for smoother auto-hide (like TopBar)
    property bool revealSticky: false
    
    readonly property bool hasActivePopout: {
        return contextMenuOpen
            || !!appDrawerLoader.item?.shouldBeVisible
            || !!dockControlCenterLoader.item?.shouldBeVisible
    }
    
    onHasActivePopoutChanged: {
        if (!hasActivePopout && autoHide && !dockMouseArea.containsMouse) {
            revealSticky = true
            revealHold.restart()
        }
    }
    
    Timer {
        id: revealHold
        interval: 250
        repeat: false
        onTriggered: dock.revealSticky = false
    }
    
    property bool reveal: {
        if (windowIsFullscreen) {
            return false
        }
        return !autoHide || dockMouseArea.containsMouse || hasActivePopout || revealSticky
    }
    // Widgets only show when BOTH are true: (1) dockWidgetsEnabled in Settings, (2) corresponding model has count > 0
    readonly property bool hasLeftWidgets: SettingsData.dockWidgetsEnabled && SettingsData.dockLeftWidgetsModel && SettingsData.dockLeftWidgetsModel.count > 0
    readonly property bool hasRightWidgets: SettingsData.dockWidgetsEnabled && SettingsData.dockRightWidgetsModel && SettingsData.dockRightWidgetsModel.count > 0
    readonly property bool hasCenterWidgets: SettingsData.dockWidgetsEnabled && SettingsData.dockCenterWidgetsModel && SettingsData.dockCenterWidgetsModel.count > 0

    Connections {
        target: SettingsData
        function onDockTransparencyChanged() {
            dock.backgroundTransparency = SettingsData.dockTransparency
        }
        function onDockAutoHideChanged() {
            // Ensure autoHide property stays in sync with settings
            dock.autoHide = SettingsData.dockAutoHide
        }
    }

    screen: modelData
    visible: SettingsData.showDock
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        left: 0
        right: 0
        bottom: SettingsData.dockBottomGap
    }

    Loader {
        id: dockControlCenterLoader
        active: false
        sourceComponent: ControlCenterPopout {
            // Power actions are handled inside the popout (AppDrawer-style),
            // so they always have a live modal instance (no Loader.item races).
        }
    }

    Loader {
        id: appDrawerLoader
        active: false
        sourceComponent: AppDrawerPopout {
        }
    }

    Loader {
        id: volumeMixerLoader
        active: false
        sourceComponent: DockVolumeMixerPopout {
        }
    }

    Loader {
        id: systemUpdateLoader
        active: false
        sourceComponent: DockSystemUpdatePopout {
        }
    }

    readonly property var currentScreenInfo: {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === screen.name) {
                return Quickshell.screens[i]
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : {width: 1920, height: 1080}
    }

    readonly property real maxDockWidth: Math.min(currentScreenInfo.width * 0.8, 1200)
    implicitHeight: Math.min(spx(100), maxDockWidth * 0.5)
    
    readonly property var monitorInfo: {
        if (!currentScreenInfo) return null
        return {
            width: currentScreenInfo.width || 1920,
            height: currentScreenInfo.height || 1080,
            transform: 0
        }
    }
    readonly property real effectiveBarHeight: (SettingsData.dockIconSize * uiScale) + (SettingsData.dockIconSpacing * uiScale) * 2

    // Full visual extent of the dock bar from the screen edge (matches dockBackground layout).
    // This is what popups need as barThickness to position correctly above the dock.
    readonly property real dockVisualHeight: {
        var contentH = Math.max(spx(70), effectiveBarHeight)
        var topPad = spx(SettingsData.dockTopPadding)
        var bottomPad = spx(SettingsData.dockBottomPadding)
        var topMargin = spx(4)
        return SettingsData.dockBottomGap + topMargin + contentH + topPad * 2 + bottomPad
    }
    
    readonly property real calculatedExclusiveZone: {
        // When dock is revealed (shown), use calculated exclusive zone
        // When dock is hidden, exclusive zone is off (-1)
        if (reveal) {
            if (!monitorInfo || !SettingsData.dockUseDynamicZones) {
                return SettingsData.dockExclusiveZone * SettingsData.dockScale + SettingsData.dockBottomGap + (SettingsData.dockTopPadding * 2 * Math.sqrt(SettingsData.dockScale))
            }
            var optimalZone = MonitorUtils.calculateOptimalReservedZone(monitorInfo, "dock")
            return optimalZone * SettingsData.dockScale + SettingsData.dockBottomGap + (SettingsData.dockTopPadding * 2 * Math.sqrt(SettingsData.dockScale))
        }
        // Dock is hidden - no exclusive zone
        return -1
    }
    
    exclusiveZone: calculatedExclusiveZone

    // Input mask for auto-hide trigger area (similar to TopBar)
    Item {
        id: dockInputMask
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        readonly property real fullDockHeight: spx(65) + spx(SettingsData.dockTopPadding + SettingsData.dockBottomPadding) + spx(13)
        
        // Height based on autoHide and mouse hover - like TopBar's inputMaskSize
        readonly property real inputMaskSize: {
            if (!autoHide) return fullDockHeight
            // When autoHide is enabled and NOT revealed (no mouse hover), show only 8px trigger area
            if (!dockMouseArea.containsMouse && !hasActivePopout && !revealSticky) {
                return spx(8)
            }
            return fullDockHeight
        }
        
        height: inputMaskSize
    }
    
    // Mask follows the input mask which changes size based on reveal state (for auto-hide trigger area)
    mask: Region {
        item: dockInputMask
    }
    
    MouseArea {
        id: dockMouseArea

        // MouseArea stays at full height for hover detection, like TopBar
        // Height animation is handled by the mask/inputMask
        height: dockInputMask.fullDockHeight
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        
        x: SettingsData.dockExpandToScreen ? 0 : leftWidgetArea.width + spx(8)
        width: SettingsData.dockExpandToScreen ? parent.width : parent.width - leftWidgetArea.width - spx(8)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        preventStealing: false
        
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
        onClicked: mouse.accepted = false

        Connections {
            target: dockMouseArea
            function onContainsMouseChanged() {
                if (dockMouseArea.containsMouse) {
                    dock.revealSticky = true
                    revealHold.stop()
                } else {
                    if (autoHide && !hasActivePopout) {
                        revealHold.restart()
                    }
                }
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: SettingsData.dockAnimationDuration
                easing.type: Easing.OutCubic
            }
        }


        Item {
            id: dockContainer
            anchors.fill: parent

            // Calculate full slide distance based on dock height (like TopBar)
            readonly property real fullSlideDistance: {
                return dockInputMask.fullDockHeight + SettingsData.dockBottomGap
            }

            transform: Translate {
                id: dockSlide
                y: dock.reveal ? 0 : dockContainer.fullSlideDistance

                Behavior on y {
                    NumberAnimation {
                        duration: SettingsData.dockAnimationDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        
            Rectangle {
                id: dockBackground
                objectName: "dockBackground"
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }

                width: {
                    if (SettingsData.dockExpandToScreen) {
                        return parent.width - spx(16)
                    } else {
                        const appsWidth = centerWidgets.implicitWidth || 0
                        const leftWidgetAreaWidth = leftWidgetArea.width || 0
                        const rightWidgetAreaWidth = rightWidgetArea.width || 0
                        const spacing = spx(8) + spx(8) + spx(8) + spx(8)
                        const padding = spx(12)
                        const totalPadding = spx(SettingsData.dockLeftPadding) * 2
                        return appsWidth + leftWidgetAreaWidth + rightWidgetAreaWidth + spacing + padding + totalPadding
                    }
                }

                height: parent.height - spx(8) + (spx(SettingsData.dockTopPadding) * 2)

                anchors.topMargin: spx(4)
                anchors.bottomMargin: spx(1)

                color: {
                    var baseColor = Theme.surfaceContainer
                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, backgroundTransparency)
                }
                radius: SettingsData.dockRadius
                border.width: SettingsData.dockBorderEnabled ? SettingsData.dockBorderWidth : 0
                border.color: {
                    if (!SettingsData.dockBorderEnabled) {
                        return "transparent"
                    }
                    if (SettingsData.dockDynamicBorderColors && Theme.currentTheme === Theme.dynamic) {
                        return Theme.primary
                    }
                    return Qt.rgba(SettingsData.dockBorderRed, SettingsData.dockBorderGreen, SettingsData.dockBorderBlue, SettingsData.dockBorderAlpha)
                }
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    color: {
                        var baseColor = Theme.surfaceTint
                        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, SettingsData.dockBackgroundTintOpacity)
                    }
                    radius: parent.radius
                }

                // Background widget area - renders behind all other widgets (z: 0)
                Rectangle {
                    id: backgroundWidgetsArea
                    anchors.fill: parent
                    color: "transparent"
                    z: 0
                    visible: SettingsData.dockBackgroundWidgetsModel && SettingsData.dockBackgroundWidgetsModel.count > 0

                    DockWidgets {
                        width: parent.width
                        height: parent.height
                        widgetList: SettingsData.dockBackgroundWidgetsModel
                        side: "background"
                        contextMenu: dock.contextMenu
                        parentScreen: dock.screen
                        parentWindow: dock
                        controlCenterLoader: dockControlCenterLoader
                        appDrawerLoader: appDrawerLoader
                        volumeMixerLoader: volumeMixerLoader
                        systemUpdateLoader: systemUpdateLoader
                        dockBarHeight: dock.dockVisualHeight
                    }
                }

                Rectangle {
                    id: leftWidgetArea
                    anchors.left: parent.left
                    anchors.leftMargin: spx(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - spx(8)
                    width: hasLeftWidgets ? Math.max(spx(SettingsData.dockLeftWidgetAreaMinWidth), leftWidgets.implicitWidth + spx(16)) : 0
                    radius: 0
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"
                    z: 10
                    visible: !SettingsData.dockExpandToScreen && hasLeftWidgets
                    
                    Behavior on width {
                        NumberAnimation {
                            duration: SettingsData.dockAnimationDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Connections {
                        target: SettingsData
                        function onWidgetDataChanged() {
                            Qt.callLater(() => {
                                leftWidgets.visible = false
                                Qt.callLater(() => {
                                    leftWidgets.visible = true
                                })
                            })
                        }
                    }
                    
                    Connections {
                        target: MprisController
                        function onActivePlayerChanged() {
                            if (MprisController.activePlayer === null) {
                                Qt.callLater(() => {
                                    leftWidgets.visible = false
                                    Qt.callLater(() => {
                                        leftWidgets.visible = true
                                    })
                                })
                            }
                        }
                    }

                    DockWidgets {
                        id: leftWidgets
                        anchors.centerIn: parent
                        height: parent.height - spx(8)
                        widgetList: SettingsData.dockLeftWidgetsModel
                        side: "left"
                        contextMenu: dock.contextMenu
                        parentScreen: dock.screen
                        parentWindow: dock
                        controlCenterLoader: dockControlCenterLoader
                        appDrawerLoader: appDrawerLoader
                        volumeMixerLoader: volumeMixerLoader
                        systemUpdateLoader: systemUpdateLoader
                        dockBarHeight: dock.dockVisualHeight
                        z: 11
                    }
                }


                Rectangle {
                    id: rightWidgetArea
                    anchors.right: parent.right
                    anchors.rightMargin: spx(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - spx(8)
                    width: hasRightWidgets ? Math.max(spx(SettingsData.dockRightWidgetAreaMinWidth), rightWidgets.implicitWidth + spx(16)) : 0
                    radius: 0
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"
                    visible: !SettingsData.dockExpandToScreen && hasRightWidgets
                    
                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Connections {
                        target: SettingsData
                        function onWidgetDataChanged() {
                            Qt.callLater(() => {
                                rightWidgets.visible = false
                                Qt.callLater(() => {
                                    rightWidgets.visible = true
                                })
                            })
                        }
                    }
                    
                    Connections {
                        target: MprisController
                        function onActivePlayerChanged() {
                            if (MprisController.activePlayer === null) {
                                Qt.callLater(() => {
                                    rightWidgets.visible = false
                                    Qt.callLater(() => {
                                        rightWidgets.visible = true
                                    })
                                })
                            }
                        }
                    }

                    DockWidgets {
                        id: rightWidgets
                        anchors.centerIn: parent
                        height: parent.height - spx(8)
                        widgetList: SettingsData.dockRightWidgetsModel
                        side: "right"
                        contextMenu: dock.contextMenu
                        parentScreen: dock.screen
                        parentWindow: dock
                        controlCenterLoader: dockControlCenterLoader
                        appDrawerLoader: appDrawerLoader
                        volumeMixerLoader: volumeMixerLoader
                        systemUpdateLoader: systemUpdateLoader
                        dockBarHeight: dock.dockVisualHeight
                    }
                }

                Item {
                    id: mainDockContainer
                    anchors.left: SettingsData.dockExpandToScreen ? parent.left : leftWidgetArea.right
                    anchors.leftMargin: SettingsData.dockExpandToScreen ? spx(8) : spx(12)
                    anchors.right: SettingsData.dockExpandToScreen ? parent.right : rightWidgetArea.left
                    anchors.rightMargin: SettingsData.dockExpandToScreen ? spx(8) : spx(12)
                    anchors.top: parent.top
                    // Important: keep padding out of these margins.
                    // `dockBackground` already grows with dockTopPadding/dockBottomPadding; adding it here
                    // cancels out the extra space and makes widgets appear "stuck" vertically.
                    anchors.topMargin: spx(4)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: spx(4)
                    
                    clip: false
                    z: 5

                    Item {
                        anchors.fill: parent

                        Item {
                            id: centerArea
                            anchors.left: SettingsData.dockExpandToScreen ? (hasLeftWidgets ? expandedLeftWidgets.right : parent.left) : parent.left
                            anchors.right: SettingsData.dockExpandToScreen ? (hasRightWidgets ? expandedRightWidgets.left : parent.right) : parent.right
                            anchors.leftMargin: SettingsData.dockExpandToScreen ? spx(8) : 0
                            anchors.rightMargin: SettingsData.dockExpandToScreen ? spx(8) : 0
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            clip: SettingsData.dockExpandToScreen
                        }

                        DockWidgets {
                            id: centerWidgets
                            // Avoid anchoring to non-sibling items (dockBackground is not a sibling here).
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: centerArea.verticalCenter
                            height: centerArea.height - spx(8)
                            widgetList: SettingsData.dockCenterWidgetsModel
                            side: "center"
                            contextMenu: dock.contextMenu
                            parentScreen: dock.screen
                            parentWindow: dock
                            controlCenterLoader: dockControlCenterLoader
                            appDrawerLoader: appDrawerLoader
                            volumeMixerLoader: volumeMixerLoader
                            systemUpdateLoader: systemUpdateLoader
                            dockBarHeight: dock.dockVisualHeight
                            z: 1
                            visible: hasCenterWidgets
                        }



                        DockWidgets {
                            id: expandedLeftWidgets
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - spx(8)
                            widgetList: SettingsData.dockLeftWidgetsModel
                            side: "left"
                            allowEdgeAnchors: true
                            contextMenu: dock.contextMenu
                            parentScreen: dock.screen
                            parentWindow: dock
                            controlCenterLoader: dockControlCenterLoader
                            appDrawerLoader: appDrawerLoader
                            volumeMixerLoader: volumeMixerLoader
                            systemUpdateLoader: systemUpdateLoader
                            dockBarHeight: dock.dockVisualHeight
                            visible: SettingsData.dockExpandToScreen && hasLeftWidgets
                            z: 2
                        }

                        DockWidgets {
                            id: expandedRightWidgets
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - spx(8)
                            widgetList: SettingsData.dockRightWidgetsModel
                            side: "right"
                            allowEdgeAnchors: true
                            contextMenu: dock.contextMenu
                            parentScreen: dock.screen
                            parentWindow: dock
                            controlCenterLoader: dockControlCenterLoader
                            appDrawerLoader: appDrawerLoader
                            volumeMixerLoader: volumeMixerLoader
                            systemUpdateLoader: systemUpdateLoader
                            dockBarHeight: dock.dockVisualHeight
                            visible: SettingsData.dockExpandToScreen && hasRightWidgets
                            z: 2
                        }

                    }
                }

            }


        }
    }
}