import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules
import qs.Modules.TopBar
import qs.Modules.TopBar.Widgets
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:bar:blur"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: {
        if (!SettingsData.topBarVisible) {
            return 0
        }
        if (SettingsData.topBarAutoHide && !topBarCore.reveal) {
            return 8
        }
        // Return implicitHeight plus bottom gap for exclusive zone
        return implicitHeight + SettingsData.topBarBottomGap
    }

    // Override property for calculated exclusive zone (like Dock.qml)
    property real calculatedTopBarExclusiveZone: {
        if (!SettingsData.topBarVisible) return 0
        if (SettingsData.topBarAutoHide && !topBarCore.reveal) return 8
        return implicitHeight + SettingsData.topBarBottomGap
    }
    exclusiveZone: calculatedTopBarExclusiveZone
    WlrLayershell.exclusionMode: (root.shouldBeExclusive && !root.reloadingAnchor) ? ExclusionMode.Auto : ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: SettingsData.topBarVisible

    // Set anchors for proper positioning
    anchors {
        top:    barPosition === "top"    || barIsVertical
        bottom: barPosition === "bottom" || barIsVertical
        left:   barPosition === "left"   || !barIsVertical
        right:  barPosition === "right"  || !barIsVertical
    }

    margins {
        top: (barPosition === "top" || barIsVertical) ? SettingsData.topBarTopMargin : 0
        bottom: barIsVertical ? 0 : (barPosition === "bottom" ? SettingsData.topBarTopMargin : 0)
        left: (barPosition === "left" || !barIsVertical) ? SettingsData.topBarLeftMargin : 0
        right: (barPosition === "right" || !barIsVertical) ? SettingsData.topBarRightMargin : 0
    }

    property var modelData
    property var notepadVariants: null
    property bool gothCornersEnabled: SettingsData.topBarGothCornersEnabled
    property bool reloadingAnchor: false
    property real wingtipsRadius: Theme.cornerRadius
    readonly property real _wingR: Math.max(0, wingtipsRadius || 0)
    readonly property color _bgColor: {
        var baseColor = Theme.surfaceContainer
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, topBarCore.backgroundTransparency)
    }
    readonly property color _tintColor: {
        var baseColor = Theme.surfaceTint
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.04 * topBarCore.backgroundTransparency)
    }

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

    function getDarkDashWidget() {
        var sections = [topBarContent.leftSection, topBarContent.centerSection, topBarContent.rightSection]
        for (var s = 0; s < sections.length; s++) {
            var section = sections[s]
            if (!section) continue
            var repeater = section.children[0]
            if (repeater && repeater.count !== undefined) {
                for (var i = 0; i < repeater.count; i++) {
                    var loader = repeater.itemAt(i)
                    if (loader && loader.widgetId === "darkDash" && loader.item) {
                        return loader.item
                    }
                }
            }
        }
        return null
    }
    property string screenName: modelData.name
    readonly property int notificationCount: NotificationService.notifications.length
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData?.topbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    readonly property real effectiveBarHeight: Math.max(spx(32), spx(SettingsData?.topBarHeight || 32))
    readonly property real widgetHeight: Math.max(spx(20), spx(26 + (SettingsData?.topBarInnerPadding || 0) * 0.6))
    readonly property real barWidth: barIsVertical ? Math.max(80, Number((effectiveBarHeight || 32) + (SettingsData?.topBarSpacing || 0) + ((SettingsData?.topBarGothCornersEnabled && (_wingR || 0)) ? (_wingR || 0) : 0)) || 80) : widgetHeight
    
    readonly property string barPosition: {
        const pos = SettingsData?.topBarPosition;
        return (pos === "top" || pos === "bottom" || pos === "left" || pos === "right") ? pos : "top";
    }
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

    screen: modelData
    color: "transparent"
    
    // Calculate total widget width for auto-fit mode
    readonly property real totalWidgetsWidth: {
        if (barIsVertical) return 0
        
        // Calculate the actual span of all widgets
        const leftMargin = Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
        const rightMargin = Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
        
        // Get left section width (actual content width)
        const leftWidth = leftSection.width > 0 ? leftSection.width : 0
        
        // Get right section width (actual content width)
        const rightWidth = rightSection.width > 0 ? rightSection.width : 0
        
        // For center section, calculate actual widget span
        let centerWidgetSpan = 0
        if (centerSection && centerSection.totalWidth > 0) {
            centerWidgetSpan = centerSection.totalWidth
        }
        
        // Calculate total width: left + center widgets + right + margins
        const totalWidth = leftWidth + centerWidgetSpan + rightWidth + leftMargin + rightMargin
        
        return totalWidth > 0 ? totalWidth : 0
    }
    
    // Function to force recalculate auto-fit width
    function recalculateAutoFitWidth() {
        if (SettingsData.topBarAutoFit && leftSection.width > 0 && rightSection.width > 0) {
            // Trigger the animation to recalculate
            autoFitWidthAnimator.restart()
        }
    }
    
    // Auto-fit animation target width
    readonly property real autoFitTargetWidth: {
        if (!SettingsData.topBarAutoFit || barIsVertical) return 0
        return totalWidgetsWidth
    }
    
    // Animated width for smooth transitions
    property real animatedAutoFitWidth: 0
    
    implicitWidth: barIsVertical ? Math.max(80, Number((effectiveBarHeight || 32) + (SettingsData?.topBarSpacing || 0) + ((SettingsData?.topBarGothCornersEnabled && (_wingR || 0)) ? (_wingR || 0) : 0)) || 80) : (SettingsData.topBarAutoFit && autoFitTargetWidth > 0 ? (animatedAutoFitWidth > 0 ? animatedAutoFitWidth : autoFitTargetWidth) : 0)
    implicitHeight: barIsVertical ? 0 : Math.max(32, Number((effectiveBarHeight || 32) + (SettingsData?.topBarSpacing || 0) + ((SettingsData?.topBarGothCornersEnabled && (_wingR || 0)) ? (_wingR || 0) : 0)) || 32)
    
    // Update animated width when target changes
    onAutoFitTargetWidthChanged: {
        Qt.callLater(() => {
            if (autoFitTargetWidth > 0) {
                // Auto-fit enabled - animate to target width
                autoFitWidthAnimator.from = animatedAutoFitWidth
                autoFitWidthAnimator.to = autoFitTargetWidth
                autoFitWidthAnimator.restart()
            } else {
                // Auto-fit disabled - animate back to 0 (full width)
                autoFitWidthAnimator.from = animatedAutoFitWidth
                autoFitWidthAnimator.to = 0
                autoFitWidthAnimator.restart()
            }
        })
    }
    
    NumberAnimation {
        id: autoFitWidthAnimator
        target: root
        property: "animatedAutoFitWidth"
        duration: 0
        easing.type: Easing.OutCubic
    }
    
    // Handle auto-fit enabled/disabled transitions
    Binding on implicitWidth {
        when: !barIsVertical && SettingsData.topBarAutoFit && animatedAutoFitWidth > 0
        value: animatedAutoFitWidth
    }

    // Defer size binding until component is ready to avoid undefined property warnings
    Binding on implicitWidth {
        when: barIsVertical && typeof implicitWidth !== "undefined" && implicitWidth >= 0
        value: implicitWidth
    }
    Binding on implicitHeight {
        when: !barIsVertical && typeof implicitHeight !== "undefined" && implicitHeight >= 0
        value: implicitHeight
    }

    // Note: Don't set width/height explicitly for WlrLayershell components - use implicitWidth/implicitHeight
    // The Bindings above handle setting these properties when ready
    
    Component.onCompleted: {
        const fonts = Qt.fontFamilies()
        if (fonts.indexOf("Material Symbols Rounded") === -1) {
            ToastService.showError("Please install Material Symbols Rounded and Restart your Shell. See README.md for instructions")
        }

        // Initialize auto-fit width if enabled
        if (SettingsData.topBarAutoFit) {
            Qt.callLater(() => {
                Qt.callLater(() => {
                    if (totalWidgetsWidth > 0) {
                        animatedAutoFitWidth = totalWidgetsWidth
                    }
                })
            })
        }

        SettingsData.forceTopBarLayoutRefresh.connect(() => {
                                                          Qt.callLater(() => {
                                                                           leftSection.visible = false
                                                                           leftSectionVertical.visible = false
                                                                           centerSection.visible = false
                                                                           centerSectionVertical.visible = false
                                                                           rightSection.visible = false
                                                                           rightSectionVertical.visible = false
                                                                           Qt.callLater(() => {
                                                                                            leftSection.visible = !barIsVertical
                                                                                            leftSectionVertical.visible = barIsVertical
                                                                                            centerSection.visible = !barIsVertical
                                                                                            centerSectionVertical.visible = barIsVertical
                                                                                            rightSection.visible = !barIsVertical
                                                                                            rightSectionVertical.visible = barIsVertical
                                                                                        })
                                                                       })
                                                      })

        updateGpuTempConfig()
        Qt.callLater(() => Qt.callLater(forceWidgetRefresh))
    }
    
    Connections {
        target: SettingsData
        function onTopBarPositionChanged() {
            root.reloadingAnchor = true
            Qt.callLater(() => {
                root.reloadingAnchor = false
                leftSection.visible = !barIsVertical
                leftSectionVertical.visible = barIsVertical
                centerSection.visible = !barIsVertical
                centerSectionVertical.visible = barIsVertical
                rightSection.visible = !barIsVertical
                rightSectionVertical.visible = barIsVertical
            })
        }
        function onTopBarAutoFitChanged() {
            // Force a layout refresh when auto-fit is toggled
            Qt.callLater(() => {
                root.recalculateAutoFitWidth()
                root.forceWidgetRefresh()
            })
        }
    }

    function forceWidgetRefresh() {
        const sections = [leftSection, leftSectionVertical, centerSection, centerSectionVertical, rightSection, rightSectionVertical]
        sections.forEach(section => section && (section.visible = false))
        Qt.callLater(() => {
            leftSection.visible = !barIsVertical
            leftSectionVertical.visible = barIsVertical
            centerSection.visible = !barIsVertical
            centerSectionVertical.visible = barIsVertical
            rightSection.visible = !barIsVertical
            rightSectionVertical.visible = barIsVertical
        })
    }

    function updateGpuTempConfig() {
        const allWidgets = [...(SettingsData.topBarLeftWidgets || []), ...(SettingsData.topBarCenterWidgets || []), ...(SettingsData.topBarRightWidgets || [])]

        const hasGpuTempWidget = allWidgets.some(widget => {
                                                     const widgetId = typeof widget === "string" ? widget : widget.id
                                                     const widgetEnabled = typeof widget === "string" ? true : (widget.enabled !== false)
                                                     return widgetId === "gpuTemp" && widgetEnabled
                                                 })

        DgopService.gpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled || SessionData.nonNvidiaGpuTempEnabled
        DgopService.nvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled
        DgopService.nonNvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nonNvidiaGpuTempEnabled
    }

    Connections {
        function onTopBarLeftWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onTopBarCenterWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        function onTopBarRightWidgetsChanged() {
            root.updateGpuTempConfig()
        }

        target: SettingsData
    }

    Connections {
        function onNvidiaGpuTempEnabledChanged() {
            root.updateGpuTempConfig()
        }

        function onNonNvidiaGpuTempEnabledChanged() {
            root.updateGpuTempConfig()
        }

        target: SessionData
    }

    Connections {
        function onTopBarAutoFitChanged() {
            Qt.callLater(() => {
                if (SettingsData.topBarAutoFit && totalWidgetsWidth > 0) {
                    // Auto-fit enabled - animate to target width
                    autoFitWidthAnimator.from = animatedAutoFitWidth
                    autoFitWidthAnimator.to = totalWidgetsWidth
                    autoFitWidthAnimator.restart()
                } else {
                    // Auto-fit disabled - animate back to 0 (full width)
                    autoFitWidthAnimator.from = animatedAutoFitWidth
                    autoFitWidthAnimator.to = 0
                    autoFitWidthAnimator.restart()
                }
                // Force layout refresh to recalculate section positions
                SettingsData.forceTopBarLayoutRefresh()
            })
        }

        target: SettingsData
    }

    Connections {
        target: leftSection
        function onWidthChanged() {
            if (SettingsData.topBarAutoFit && leftSection.width > 0) {
                autoFitWidthAnimator.restart()
            }
        }
    }

    Connections {
        target: rightSection
        function onWidthChanged() {
            if (SettingsData.topBarAutoFit && rightSection.width > 0) {
                autoFitWidthAnimator.restart()
            }
        }
    }

    Connections {
        target: centerSection
        function onTotalWidthChanged() {
            if (SettingsData.topBarAutoFit && centerSection.totalWidth > 0) {
                autoFitWidthAnimator.restart()
            }
        }
        function onWidthChanged() {
            if (SettingsData.topBarAutoFit && centerSection.width > 0) {
                autoFitWidthAnimator.restart()
            }
        }
    }

    Connections {
        target: root.screen
        function onGeometryChanged() {
            if (centerSection?.width > 0) {
                Qt.callLater(centerSection.updateLayout)
            }
        }
    }

    Connections {
        target: Theme
        function onColorUpdateTriggerChanged() {
        }
    }

    anchors {
        top: barPosition === "top" || barIsVertical
        bottom: barPosition === "bottom" || barIsVertical
        left: barPosition === "left" || (!barIsVertical && !SettingsData.topBarAutoFit)
        right: barPosition === "right" || (!barIsVertical && !SettingsData.topBarAutoFit)
    }

    readonly property bool shouldBeExclusive: {
        if (!SettingsData.topBarVisible) {
            return false
        }
        if (barPosition === "top" && SettingsData.topBarAutoHide) {
            return false
        }
        if (barIsVertical) {
            return !SettingsData.topBarAutoHide || topBarCore.reveal
        }
        if (barPosition === "bottom") {
            return true
        }
        return true
    }

    Item {
        id: inputMask
        anchors {
            top: barPosition === "top" || barIsVertical ? parent.top : undefined
            bottom: barPosition === "bottom" || barIsVertical ? parent.bottom : undefined
            left: barPosition === "left" || !barIsVertical ? parent.left : undefined
            right: barPosition === "right" || !barIsVertical ? parent.right : undefined
        }
        width: barIsVertical ? inputMaskSize : undefined
        height: !barIsVertical ? inputMaskSize : undefined
        
        readonly property real inputMaskSize: {
            if (root.reloadingAnchor) return 0;
            return (SettingsData.topBarAutoHide && topBarCore && !topBarCore.reveal) ? 8 : ((CompositorService.isNiri && NiriService.inOverview && SettingsData.topBarOpenOnOverview) ? (root.effectiveBarHeight + SettingsData.topBarSpacing) : (SettingsData.topBarVisible ? (root.effectiveBarHeight + SettingsData.topBarSpacing) : 0))
        }
    }

    mask: Region {
        item: inputMask
    }


    Item {
        id: topBarCore
        anchors.fill: parent
        property bool autoHide: SettingsData.topBarAutoHide
        property bool revealSticky: false
        property real backgroundTransparency: SettingsData.topBarTransparency

        Timer {
            id: revealHold
            interval: 250
            repeat: false
            onTriggered: topBarCore.revealSticky = false
        }

        property bool reveal: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.topBarOpenOnOverview
            }
            return SettingsData.topBarVisible && (!autoHide || topBarMouseArea.containsMouse || hasActivePopout || revealSticky)
        }

        property var notepadInstance: null
        property bool notepadInstanceVisible: notepadInstance?.isVisible ?? false
        
        readonly property bool hasActivePopout: {
            const loaders = [{
                                 "loader": appDrawerLoader,
                                 "prop": "shouldBeVisible"
                             }, {
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
                             }]
            return notepadInstanceVisible || loaders.some(item => {
                if (item.loader) {
                    return item.loader?.item?.[item.prop]
                }
                return false
            })
        }

        Component.onCompleted: {
            notepadInstance = root.getNotepadInstanceForScreen()
        }


        Connections {
            target: topBarMouseArea
            function onContainsMouseChanged() {
                if (topBarMouseArea.containsMouse) {
                    topBarCore.revealSticky = true
                    revealHold.stop()
                } else {
                    if (topBarCore.autoHide && !topBarCore.hasActivePopout) {
                        revealHold.restart()
                    }
                }
            }
        }

        onHasActivePopoutChanged: {
            if (!hasActivePopout && autoHide && !topBarMouseArea.containsMouse) {
                revealSticky = true
                revealHold.restart()
            }
        }

        MouseArea {
            id: topBarMouseArea
            anchors {
                top: barPosition === "top" || barIsVertical ? parent.top : undefined
                bottom: barPosition === "bottom" || barIsVertical ? parent.bottom : undefined
                left: barPosition === "left" || !barIsVertical ? parent.left : undefined
                right: barPosition === "right" || !barIsVertical ? parent.right : undefined
            }
            width: barIsVertical ? (root.effectiveBarHeight + SettingsData.topBarSpacing) : undefined
            height: !barIsVertical ? (root.effectiveBarHeight + SettingsData.topBarSpacing) : undefined
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: true

            Item {
                id: topBarContainer
                anchors.fill: parent

                transform: Translate {
                    id: topBarSlide
                    x: barIsVertical ? Math.round(topBarCore.reveal ? 0 : (barPosition === "left" ? -(root.effectiveBarHeight + SettingsData.topBarSpacing) : (root.effectiveBarHeight + SettingsData.topBarSpacing))) : 0
                    y: !barIsVertical ? Math.round(topBarCore.reveal ? 0 : (barPosition === "top" ? -(root.effectiveBarHeight + SettingsData.topBarSpacing) : (root.effectiveBarHeight + SettingsData.topBarSpacing))) : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: SettingsData.topBarLeftMargin
                    anchors.rightMargin: SettingsData.topBarRightMargin
                    
                    Rectangle {
                        anchors.fill: parent
                        color: root._bgColor
                        radius: SettingsData.topBarSquareCorners ? 0 : (SettingsData.topBarAutoFit && SettingsData.topBarAutoFitRoundedCorners ? SettingsData.topBarAutoFitCornerRadius : (SettingsData.topBarRoundedCorners ? SettingsData.topBarCornerRadius : 0))
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: SettingsData.topBarSquareCorners ? 0 : (SettingsData.topBarAutoFit && SettingsData.topBarAutoFitRoundedCorners ? SettingsData.topBarAutoFitCornerRadius : (SettingsData.topBarRoundedCorners ? SettingsData.topBarCornerRadius : 0))
                        border.width: SettingsData.topBarBorderEnabled ? SettingsData.topBarBorderWidth : 0
                        border.color: {
                            if (!SettingsData.topBarBorderEnabled) return "transparent"
                            if (SettingsData.topBarDynamicBorderColors && Theme.currentTheme === Theme.dynamic) return Theme.primary
                            return Qt.rgba(SettingsData.topBarBorderRed, SettingsData.topBarBorderGreen, SettingsData.topBarBorderBlue, SettingsData.topBarBorderAlpha)
                        }
                    }
                    
                    Item {
                        id: topBarContent
                        anchors.fill: parent
                        anchors.leftMargin: barIsVertical ? (SettingsData.topBarInnerPadding / 2) : Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                        anchors.rightMargin: barIsVertical ? (SettingsData.topBarInnerPadding / 2) : Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8)
                        anchors.topMargin: barIsVertical ? Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8) : (SettingsData.topBarInnerPadding / 2) + 4
                        anchors.bottomMargin: barIsVertical ? Math.max(Theme.spacingXS, SettingsData.topBarInnerPadding * 0.8) : (SettingsData.topBarInnerPadding / 2) + 4
                        clip: true

                    readonly property int availableWidth: barIsVertical ? height : width
                    readonly property int availableHeight: barIsVertical ? width : height
                        readonly property int launcherButtonWidth: 40
                        readonly property int workspaceSwitcherWidth: 120
                        readonly property int focusedAppMaxWidth: 456
                        readonly property int estimatedLeftSectionWidth: launcherButtonWidth + workspaceSwitcherWidth + focusedAppMaxWidth + (Theme.spacingXS * 2)
                        readonly property int rightSectionWidth: rightSection.width
                        readonly property int clockWidth: 120
                        readonly property int mediaMaxWidth: 280
                        readonly property int weatherWidth: 80
                        readonly property bool validLayout: availableWidth > 100 && estimatedLeftSectionWidth > 0 && rightSectionWidth > 0
                        readonly property int clockLeftEdge: (availableWidth - clockWidth) / 2
                        readonly property int clockRightEdge: clockLeftEdge + clockWidth
                        readonly property int leftSectionRightEdge: estimatedLeftSectionWidth
                        readonly property int mediaLeftEdge: clockLeftEdge - mediaMaxWidth - Theme.spacingS
                        readonly property int rightSectionLeftEdge: availableWidth - rightSectionWidth
                        readonly property int leftToClockGap: Math.max(0, clockLeftEdge - leftSectionRightEdge)
                        readonly property int leftToMediaGap: mediaMaxWidth > 0 ? Math.max(0, mediaLeftEdge - leftSectionRightEdge) : leftToClockGap
                        readonly property int mediaToClockGap: mediaMaxWidth > 0 ? Theme.spacingS : 0
                        readonly property int clockToRightGap: validLayout ? Math.max(0, rightSectionLeftEdge - clockRightEdge) : 1000
                        readonly property bool spacingTight: validLayout && (leftToMediaGap < 150 || clockToRightGap < 100)
                        readonly property bool overlapping: validLayout && (leftToMediaGap < 100 || clockToRightGap < 50)

                        // Helper to scale or hide widgets if overlapping
                        function getWidgetScale() {
                            return overlapping ? 0.85 : 1.0
                        }

                        function getWidgetEnabled(enabled) {
                            return enabled !== false
                        }

                        function getWidgetSection(parentItem) {
                            if (!parentItem?.parent) {
                                return "left"
                            }
                            if (parentItem.parent === leftSection) {
                                return "left"
                            }
                            if (parentItem.parent === rightSection) {
                                return "right"
                            }
                            if (parentItem.parent === centerSection) {
                                return "center"
                            }
                            return "left"
                        }

                        readonly property var widgetVisibility: ({
                                                                     "cpuUsage": DgopService.dgopAvailable,
                                                                     "memUsage": DgopService.dgopAvailable,
                                                                     "cpuTemp": DgopService.dgopAvailable,
                                                                     "gpuTemp": DgopService.dgopAvailable,
                                                                     "network_speed_monitor": DgopService.dgopAvailable
                                                                 })

                        function getWidgetVisible(widgetId) {
                            // Don't hide widgets when auto-fit is enabled
                            if (SettingsData.topBarAutoFit) return true
                            
                            // Hide less important widgets if overlapping
                            if (overlapping) {
                                // Example: hide weather and media first
                                if (widgetId === "weather" || widgetId === "media") return false
                            }
                            return widgetVisibility[widgetId] ?? true
                        }

                        readonly property var componentMap: ({
                                                                 "launcherButton": launcherButtonComponent,
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
                                                                 "volumeMixerButton": volumeMixerButtonComponent
                                                             })

                        function getWidgetComponent(widgetId) {
                            return componentMap[widgetId] || null
                        }

                        Row {
                            id: leftSection
                            visible: !barIsVertical
                            height: parent.height
                            spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Repeater {
                                model: SettingsData.topBarLeftWidgetsModel

                                Connections {
                                    target: SettingsData.topBarLeftWidgetsModel
                                    function onCountChanged() {
                                        leftSection.visible = false
                                        Qt.callLater(() => { leftSection.visible = true })
                                    }
                                }

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: leftSection.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }
                        
                        Column {
                            id: leftSectionVertical
                            visible: barIsVertical
                            spacing: SettingsData.topBarNoBackground ? 4 : Theme.spacingS
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: Theme.spacingS
                            topPadding: Theme.spacingXS
                            bottomPadding: Theme.spacingXS
                            clip: true

                            Repeater {
                                model: SettingsData.topBarLeftWidgetsModel

                                Connections {
                                    target: SettingsData.topBarLeftWidgetsModel
                                    function onCountChanged() {
                                        leftSectionVertical.visible = false
                                        Qt.callLater(() => { leftSectionVertical.visible = true })
                                    }
                                }

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                    active: leftSectionVertical.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }

                        Row {
                            id: centerSection
                            visible: !barIsVertical
                            property var centerWidgets: []
                            property int totalWidgets: 0
                            property int totalWidth: 0
                            property real spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: SettingsData.topBarAutoFit ? leftSection.right : undefined
                            anchors.horizontalCenter: SettingsData.topBarAutoFit ? undefined : parent.horizontalCenter
                            width: SettingsData.topBarAutoFit ? implicitWidth : undefined
                            clip: true

                            function updateLayout() {
                                if (width <= 0 || height <= 0 || !visible) {
                                    Qt.callLater(updateLayout)
                                    return
                                }

                                centerWidgets = []
                                totalWidgets = 0
                                totalWidth = 0

                                let configuredWidgets = 0
                                for (var i = 0; i < centerRepeater.count; i++) {
                                    const item = centerRepeater.itemAt(i)
                                    if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                        configuredWidgets++
                                        if (item.active && item.item) {
                                            centerWidgets.push(item.item)
                                            totalWidgets++
                                            totalWidth += item.item.width
                                        }
                                    }
                                }

                                if (totalWidgets > 1) {
                                    totalWidth += spacing * (totalWidgets - 1)
                                }
                                positionWidgets(configuredWidgets)
                            }

                            function positionWidgets(configuredWidgets) {
                                if (totalWidgets === 0 || width <= 0) {
                                    return
                                }

                                const globalCenter = SettingsData.topBarAutoFit ? (width / 2) : (parent.width / 2)
                                const parentCenterX = SettingsData.topBarAutoFit ? globalCenter : (globalCenter - x)
                                const isOdd = configuredWidgets % 2 === 1

                                centerWidgets.forEach(widget => widget.anchors.horizontalCenter = undefined)

                                if (isOdd) {
                                    const middleIndex = Math.floor(configuredWidgets / 2)
                                    let currentActiveIndex = 0
                                    let middleWidget = null

                                    for (var i = 0; i < centerRepeater.count; i++) {
                                        const item = centerRepeater.itemAt(i)
                                        if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                            if (currentActiveIndex === middleIndex && item.active && item.item) {
                                                middleWidget = item.item
                                                break
                                            }
                                            currentActiveIndex++
                                        }
                                    }

                                    if (middleWidget) {
                                        middleWidget.x = parentCenterX - (middleWidget.width / 2)

                                        let leftWidgets = []
                                        let rightWidgets = []
                                        let foundMiddle = false

                                        for (var i = 0; i < centerWidgets.length; i++) {
                                            if (centerWidgets[i] === middleWidget) {
                                                foundMiddle = true
                                                continue
                                            }
                                            if (!foundMiddle) {
                                                leftWidgets.push(centerWidgets[i])
                                            } else {
                                                rightWidgets.push(centerWidgets[i])
                                            }
                                        }

                                        let currentX = middleWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = middleWidget.x + middleWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    }
                                } else {
                                    let configuredLeftIndex = (configuredWidgets / 2) - 1
                                    let configuredRightIndex = configuredWidgets / 2
                                    const halfSpacing = spacing / 2

                                    let leftWidget = null
                                    let rightWidget = null
                                    let leftWidgets = []
                                    let rightWidgets = []

                                    let currentConfigIndex = 0
                                    for (var i = 0; i < centerRepeater.count; i++) {
                                        const item = centerRepeater.itemAt(i)
                                        if (item && topBarContent.getWidgetVisible(item.widgetId)) {
                                            if (item.active && item.item) {
                                                if (currentConfigIndex < configuredLeftIndex) {
                                                    leftWidgets.push(item.item)
                                                } else if (currentConfigIndex === configuredLeftIndex) {
                                                    leftWidget = item.item
                                                } else if (currentConfigIndex === configuredRightIndex) {
                                                    rightWidget = item.item
                                                } else {
                                                    rightWidgets.push(item.item)
                                                }
                                            }
                                            currentConfigIndex++
                                        }
                                    }

                                    if (leftWidget && rightWidget) {
                                        leftWidget.x = parentCenterX - halfSpacing - leftWidget.width
                                        rightWidget.x = parentCenterX + halfSpacing

                                        let currentX = leftWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = rightWidget.x + rightWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (leftWidget && !rightWidget) {
                                        leftWidget.x = parentCenterX - halfSpacing - leftWidget.width

                                        let currentX = leftWidget.x
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= (spacing + leftWidgets[i].width)
                                            leftWidgets[i].x = currentX
                                        }

                                        currentX = leftWidget.x + leftWidget.width + spacing
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (!leftWidget && rightWidget) {
                                        rightWidget.x = parentCenterX + halfSpacing

                                        let currentX = rightWidget.x - spacing
                                        for (var i = leftWidgets.length - 1; i >= 0; i--) {
                                            currentX -= leftWidgets[i].width
                                            leftWidgets[i].x = currentX
                                            currentX -= spacing
                                        }

                                        currentX = rightWidget.x + rightWidget.width
                                        for (var i = 0; i < rightWidgets.length; i++) {
                                            currentX += spacing
                                            rightWidgets[i].x = currentX
                                            currentX += rightWidgets[i].width
                                        }
                                    } else if (totalWidgets === 1 && centerWidgets[0]) {
                                        centerWidgets[0].x = parentCenterX - (centerWidgets[0].width / 2)
                                    }
                                }
                            }

                            Component.onCompleted: {
                                Qt.callLater(() => {
                                                 Qt.callLater(updateLayout)
                                             })
                            }

                            onWidthChanged: {
                                if (width > 0) {
                                    Qt.callLater(updateLayout)
                                }
                            }

                            onVisibleChanged: {
                                if (visible && width > 0) {
                                    Qt.callLater(updateLayout)
                                }
                            }

                            Repeater {
                                id: centerRepeater

                                model: SettingsData.topBarCenterWidgetsModel

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: centerSection.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false

                                    onLoaded: {
                                        if (!item) {
                                            return
                                        }
                                        item.onWidthChanged.connect(centerSection.updateLayout)
                                        if (model.widgetId === "spacer") {
                                            item.spacerSize = Qt.binding(() => model.size || 20)
                                        }
                                        Qt.callLater(centerSection.updateLayout)
                                    }
                                    onActiveChanged: {
                                        Qt.callLater(centerSection.updateLayout)
                                    }
                                }
                            }

                            Connections {
                                function onCountChanged() {
                                    Qt.callLater(centerSection.updateLayout)
                                }

                                target: SettingsData.topBarCenterWidgetsModel
                            }
                        }
                        
                        Item {
                            id: centerSectionVertical
                            visible: barIsVertical
                            anchors.top: leftSectionVertical.bottom
                            anchors.bottom: rightSectionVertical.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            clip: true
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                                
                                Repeater {
                                    model: SettingsData.topBarCenterWidgetsModel

                                    Connections {
                                        target: SettingsData.topBarCenterWidgetsModel
                                        function onCountChanged() {
                                            centerSectionVertical.visible = false
                                            Qt.callLater(() => { centerSectionVertical.visible = true })
                                        }
                                    }

                                    Loader {
                                        property string widgetId: model.widgetId
                                        property var widgetData: model
                                        property int spacerSize: model.size || 20

                                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                        active: centerSectionVertical.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                        sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                        opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                        asynchronous: false
                                    }
                                }
                            }
                        }

                        Row {
                            id: rightSection
                            visible: !barIsVertical
                            height: parent.height
                            width: childrenRect.width
                            spacing: SettingsData.topBarNoBackground ? 2 : Theme.spacingXS
                            anchors.right: SettingsData.topBarAutoFit ? undefined : parent.right
                            anchors.left: SettingsData.topBarAutoFit ? centerSection.right : undefined
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Repeater {
                                model: SettingsData.topBarRightWidgetsModel

                                Connections {
                                    target: SettingsData.topBarRightWidgetsModel
                                    function onCountChanged() {
                                        rightSection.visible = false
                                        Qt.callLater(() => { rightSection.visible = true })
                                    }
                                }

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    active: rightSection.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }
                        
                        Column {
                            id: rightSectionVertical
                            visible: barIsVertical
                            spacing: SettingsData.topBarNoBackground ? 4 : Theme.spacingS
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: Theme.spacingS
                            topPadding: Theme.spacingXS
                            bottomPadding: Theme.spacingXS
                            clip: true

                            Repeater {
                                model: SettingsData.topBarRightWidgetsModel

                                Connections {
                                    target: SettingsData.topBarRightWidgetsModel
                                    function onCountChanged() {
                                        rightSectionVertical.visible = false
                                        Qt.callLater(() => { rightSectionVertical.visible = true })
                                    }
                                }

                                Loader {
                                    property string widgetId: model.widgetId
                                    property var widgetData: model
                                    property int spacerSize: model.size || 20

                                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                    active: rightSectionVertical.visible && topBarContent.getWidgetVisible(model.widgetId) && (model.widgetId !== "music" || MprisController.activePlayer !== null)
                                    sourceComponent: topBarContent.getWidgetComponent(model.widgetId)
                                    opacity: topBarContent.getWidgetEnabled(model.enabled) ? 1 : 0
                                    asynchronous: false
                                }
                            }
                        }

                        Component {
                            id: clipboardComponent

                            Rectangle {
                                readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (root.widgetHeight / 30))
                                width: clipboardIcon.width + horizontalPadding * 2
                                height: root.widgetHeight
                                radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
                                color: {
                                    if (SettingsData.topBarNoBackground) {
                                        return "transparent"
                                    }
                                    const baseColor = clipboardArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
                                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
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
                            id: launcherButtonComponent

                            TopBarLauncherButton {
                                isActive: false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent)
                                popupTarget: appDrawerLoader.item
                                parentScreen: root.screen
                                onClicked: {
                                    const wasActive = appDrawerLoader.active
                                    appDrawerLoader.active = true
                                    
                                    const item = appDrawerLoader.item
                                    if (item) {
                                        if (_pendingTriggerPosition) {
                                            item.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, _pendingTriggerScreen)
                                            _pendingTriggerPosition = false
                                        }
                                        if (!wasActive) {
                                            item.show()
                                        } else {
                                            item.toggle()
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: workspaceSwitcherComponent

                            TopBarWorkspaceSwitcher {
                                screenName: root.screenName
                                widgetHeight: root.widgetHeight
                            }
                        }

                        Component {
                            id: focusedWindowComponent

                            TopBarFocusedApp {
                                availableWidth: topBarContent.leftToMediaGap
                                widgetHeight: root.widgetHeight
                            }
                        }

                        Component {
                            id: runningAppsComponent

                            TopBarRunningApps {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent)
                                parentScreen: root.screen
                                topBar: topBarContent
                            }
                        }

                        Component {
                            id: clockComponent

                            TopBarClock {
                                compactMode: topBarContent.overlapping
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: mediaComponent

                            TopBarMedia {
                                compactMode: topBarContent.spacingTight || topBarContent.overlapping
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: mediaDisplayComponent

                            TopBarMediaDisplay {
                                compactMode: topBarContent.spacingTight || topBarContent.overlapping
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: weatherComponent

                            TopBarWeather {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: darkDashComponent

                            TopBarDarkDash {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: applicationsComponent

                            TopBarApplications {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "center"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: systemTrayComponent

                            TopBarSystemTrayBar {
                                parentWindow: root
                                parentScreen: root.screen
                                widgetHeight: root.widgetHeight
                                visible: SettingsData.getFilteredScreens("systemTray").includes(root.screen)
                            }
                        }

                        Component {
                            id: privacyIndicatorComponent

                            TopBarPrivacyIndicator {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: cpuUsageComponent

                            TopBarCpuMonitor {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: memUsageComponent

                            TopBarRamMonitor {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: cpuTempComponent

                            TopBarCpuTemperature {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    processListPopoutLoader.active = true
                                    return processListPopoutLoader.item
                                }
                                parentScreen: root.screen
                                toggleProcessList: () => {
                                                       processListPopoutLoader.active = true
                                                       return processListPopoutLoader.item?.toggle()
                                                   }
                            }
                        }

                        Component {
                            id: gpuTempComponent

                            TopBarGpuTemperature {
                                barHeight: root.effectiveBarHeight
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
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
                            }
                        }

                        Component {
                            id: networkComponent

                            TopBarNetworkMonitor {}
                        }

                        Component {
                            id: notificationButtonComponent

                            TopBarNotificationCenterButton {
                                hasUnread: root.notificationCount > 0
                                isActive: notificationCenterLoader.item ? notificationCenterLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    notificationCenterLoader.active = true
                                    return notificationCenterLoader.item
                                }
                                parentScreen: root.screen
                                onClicked: {
                                    notificationCenterLoader.active = true
                                    notificationCenterLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: batteryComponent

                            TopBarBattery {
                                batteryPopupVisible: batteryPopoutLoader.item ? batteryPopoutLoader.item.shouldBeVisible : false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    batteryPopoutLoader.active = true
                                    return batteryPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onToggleBatteryPopup: {
                                    batteryPopoutLoader.active = true
                                    batteryPopoutLoader.item?.toggle()
                                }
                            }
                        }

                        Component {
                            id: vpnComponent

                            TopBarVpn {
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    vpnPopoutLoader.active = true
                                    return vpnPopoutLoader.item
                                }
                                parentScreen: root.screen
                                onToggleVpnPopup: {
                                    vpnPopoutLoader.active = true
                                    vpnPopoutLoader.item?.toggle()
                                }
                            }
                        }

                         Component {
                             id: controlCenterButtonComponent

                             TopBarControlCenterButton {
                                  isActive: Boolean(controlCenterLoader.item?.shouldBeVisible)
                                 widgetHeight: root.widgetHeight
                                 barHeight: root.effectiveBarHeight
                                                                  section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    controlCenterLoader.active = true
                                    return controlCenterLoader.item
                                }
                                parentScreen: root.screen
                                widgetData: parent.widgetData
                                onClicked: {
                                    controlCenterLoader.active = true
                                    // Wait for the loader to be ready before toggling
                                    Qt.callLater(() => {
                                        if (controlCenterLoader.item) {
                                            controlCenterLoader.item.toggle()
                                            if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
                                                NetworkService.scanWifi()
                                            }
                                        }
                                    })
                                }
                            }
                        }

                        Component {
                            id: idleInhibitorComponent

                            TopBarIdleInhibitor {
                                widgetHeight: root.widgetHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: spacerComponent

                            Item {
                                width: parent.spacerSize || 20
                                height: root.widgetHeight

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                    border.width: 1
                                    radius: 2
                                    visible: false

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.visible = true
                                        onExited: parent.visible = false
                                    }
                                }
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

                            TopBarKeyboardLayoutName {}
                        }

                        Component {
                            id: notepadButtonComponent

                            TopBarNotepadButton {
                                property var notepadInstance: topBarCore.notepadInstance
                                isActive: notepadInstance?.isVisible ?? false
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: notepadInstance
                                parentScreen: root.screen
                                onClicked: {
                                    if (notepadInstance) {
                                        notepadInstance.toggle()
                                    }
                                }
                            }
                        }

                        Component {
                            id: colorPickerComponent

                            TopBarColorPicker {
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                                onColorPickerRequested: {
                                    root.colorPickerRequested()
                                }
                            }
                        }

                        Component {
                            id: systemUpdateComponent

                            TopBarSystemUpdate {
                                isActive: false // TODO: connect to popup visibility if needed
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                parentScreen: root.screen
                            }
                        }

                        Component {
                            id: volumeMixerButtonComponent

                            TopBarVolumeMixerButton {
                                widgetHeight: root.widgetHeight
                                barHeight: root.effectiveBarHeight
                                section: topBarContent.getWidgetSection(parent) || "right"
                                popupTarget: {
                                    volumeMixerPopoutLoader.active = true
                                    return volumeMixerPopoutLoader.item
                                }
                                parentScreen: root.screen
                            }
                        }
                    }
                }
            }

            Loader {
                id: appDrawerLoader
                active: false
                source: "TopBarAppDrawer/AppDrawerPopout.qml"
            }

            Loader {
                id: darkDashLoader
                active: false
                source: "../DarkDash/DarkDashPopout.qml"
            }

            Loader {
                id: processListPopoutLoader
                active: false
                source: "../../Modals/ProcessListModal.qml"
            }

            Loader {
                id: notificationCenterLoader
                active: false
                source: "../Notifications/Center/NotificationCenterPopout.qml"
            }

            Loader {
                id: batteryPopoutLoader
                active: false
                source: "Widgets/TopBarBatteryPopout.qml"
            }

            Loader {
                id: vpnPopoutLoader
                active: false
                source: "Widgets/TopBarVpnPopout.qml"
            }

            Loader {
                id: controlCenterLoader
                active: false
                source: "TopBarControlCenter/TopBarControlCenterPopout.qml"
            }

            Loader {
                id: volumeMixerPopoutLoader
                active: false
                source: "Widgets/TopBarVolumeMixerPopout.qml"
            }
        }
    }
}