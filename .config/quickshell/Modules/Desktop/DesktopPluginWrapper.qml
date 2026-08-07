import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string pluginId
    required property var screen

    property var builtinComponent: null
    property var pluginService: null
    property string instanceId: ""
    property var instanceData: null
    property bool widgetEnabled: true

    readonly property real uiScale: (Appearance.combinedScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    readonly property bool isBuiltin: pluginId === "desktopClock" || pluginId === "systemMonitorDetailed" ||
                                      pluginId === "desktopCpuTemp" || pluginId === "desktopGpuTemp" ||
                                      pluginId === "desktopTerminal" || pluginId === "desktopEventHorizon" || pluginId === "desktopDarkDash" ||
                                      pluginId === "desktopWeather" || pluginId === "macOSClock" ||
                                      pluginId === "desktopAnalogClock" ||
                                      pluginId === "desktopSystemMonitorCard" || pluginId === "desktopSystemMonitorCircle" ||
                                      pluginId === "desktopFastfetch" || pluginId === "desktopWallpaperGallery" ||
                                      pluginId === "desktopMediaPlayer" || pluginId === "desktopCava" ||
                                      pluginId === "desktopCalendar" ||
                                      pluginId === "desktopIcon"
                                      || pluginId === "desktopBattery"
    readonly property var activeComponent: isBuiltin ? builtinComponent : (typeof PluginService !== 'undefined' ? (PluginService.pluginDesktopComponents?.[pluginId] ?? null) : null)

    readonly property bool showOnOverlay: instanceData?.config?.showOnOverlay ?? false
    readonly property bool showOnOverview: instanceData?.config?.showOnOverview ?? false
    readonly property bool showOnOverviewOnly: instanceData?.config?.showOnOverviewOnly ?? false
    readonly property bool overviewActive: typeof CompositorService !== 'undefined' && CompositorService.isNiri && typeof NiriService !== 'undefined' && NiriService.inOverview

    // Get rotation for Cava widget
    readonly property int cavaRotation: pluginId === "desktopCava" ? 
        (isInstance ? (instanceData?.config?.rotation ?? 0) : SettingsData.desktopCavaRotation) : 0

    Connections {
        target: typeof PluginService !== 'undefined' ? PluginService : null
        enabled: !root.isBuiltin && typeof PluginService !== 'undefined'

        function onPluginLoaded(loadedPluginId) {
            if (loadedPluginId === root.pluginId)
                contentLoader.reloadComponent();
        }

        function onPluginUnloaded(unloadedPluginId) {
            if (unloadedPluginId === root.pluginId)
                contentLoader.reloadComponent();
        }
    }

    // Reposition widget when dock/bar settings change
    Connections {
        target: SettingsData
        enabled: root.needsDockBarAwareness

        function onTopBarVisibleChanged() {
            // Force repositioning by triggering widgetX/widgetY recalculation
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onTopBarPositionChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onTopBarHeightChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onShowDockChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onDockExclusiveZoneChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onDockTopPaddingChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }

        function onDockBottomPaddingChanged() {
            const currentX = root.widgetX;
            const currentY = root.widgetY;
            root.widgetX = currentX;
            root.widgetY = currentY;
        }
    }

    readonly property string settingsKey: instanceId ? instanceId : pluginId
    readonly property bool isInstance: instanceId !== "" && instanceData !== null
    readonly property bool usePluginService: pluginService !== null && !isInstance && typeof PluginService !== 'undefined'

    QtObject {
        id: instanceScopedPluginService

        readonly property var availablePlugins: typeof PluginService !== 'undefined' ? PluginService.availablePlugins : {}
        readonly property var loadedPlugins: typeof PluginService !== 'undefined' ? PluginService.loadedPlugins : {}
        readonly property var pluginDesktopComponents: typeof PluginService !== 'undefined' ? PluginService.pluginDesktopComponents : {}

        signal pluginDataChanged(string pluginId)
        signal pluginLoaded(string pluginId)
        signal pluginUnloaded(string pluginId)

        function loadPluginData(pluginId, key, defaultValue) {
            const cfg = root.instanceData?.config;
            if (cfg && key in cfg)
                return cfg[key];
            if (typeof PluginService !== 'undefined')
                return SettingsData.getPluginSetting(pluginId, key, defaultValue);
            return defaultValue;
        }

        function savePluginData(pluginId, key, value) {
            if (!root.instanceId)
                return false;
            var updates = {};
            updates[key] = value;
            SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, updates);
            Qt.callLater(() => pluginDataChanged(pluginId));
            return true;
        }

        function getPluginVariants(pluginId) {
            if (typeof PluginService !== 'undefined')
                return PluginService.getPluginVariants(pluginId);
            return [];
        }

        function isPluginLoaded(pluginId) {
            if (typeof PluginService !== 'undefined')
                return PluginService.isPluginLoaded(pluginId);
            return false;
        }
    }
    readonly property string screenKey: SettingsData.getScreenDisplayName(screen)

    readonly property int screenWidth: screen?.width ?? 1920
    readonly property int screenHeight: screen?.height ?? 1080

    readonly property bool useGhostPreview: typeof CompositorService !== 'undefined' && !CompositorService.isNiri

    property real previewX: widgetX
    property real previewY: widgetY
    property real previewWidth: widgetWidth
    property real previewHeight: widgetHeight

    readonly property bool hasSavedPosition: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.x !== undefined;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopX_" + screenKey, null) !== null;
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "x", null) !== null;
    }

    readonly property bool hasSavedSize: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.width !== undefined;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopWidth_" + screenKey, null) !== null;
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "width", null) !== null;
    }

    property real savedX: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.x ?? (screenWidth / 2 - savedWidth / 2);
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopX_" + screenKey, screenWidth / 2 - savedWidth / 2);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "x", screenWidth / 2 - savedWidth / 2);
    }
    property real savedY: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.y ?? (screenHeight / 2 - savedHeight / 2);
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopY_" + screenKey, screenHeight / 2 - savedHeight / 2);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "y", screenHeight / 2 - savedHeight / 2);
    }
    property real savedWidth: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.width ?? 280;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopWidth_" + screenKey, 200);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "width", 280);
    }
    property real savedHeight: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.height ?? 180;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopHeight_" + screenKey, 200);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "height", 180);
    }

    // Calculate dock/bar thickness for positioning (only when visible)
    readonly property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real barExclusiveSize: SettingsData.topBarVisible && !SettingsData.topBarFloat ? ((SettingsData.topBarHeight * SettingsData.topbarScale) + SettingsData.topBarSpacing + (SettingsData.topBarGothCornersEnabled ? Theme.cornerRadius : 0)) : 0
    readonly property real topBarThickness: SettingsData.topBarVisible && SettingsData.topBarPosition === "top" && !SettingsData.topBarFloat ? ((SettingsData.topBarHeight * SettingsData.topbarScale) + SettingsData.topBarSpacing + SettingsData.topBarBottomGap) : 0
    readonly property real bottomDockThickness: SettingsData.showDock ? (SettingsData.dockExclusiveZone || SettingsData.dockHeight || 48) + (SettingsData.dockBottomGap || 0) + ((SettingsData.dockTopPadding || 0) * 2) : 0
    readonly property real leftBarThickness: SettingsData.topBarVisible && SettingsData.topBarPosition === "left" && !SettingsData.topBarFloat ? barExclusiveSize : 0
    readonly property real rightBarThickness: SettingsData.topBarVisible && SettingsData.topBarPosition === "right" && !SettingsData.topBarFloat ? barExclusiveSize : 0
    
    // Check if widget needs dock/bar awareness (all desktop widgets except desktopCava which can go behind bars)
    readonly property bool needsDockBarAwareness: (isBuiltin && pluginId !== "desktopCava") || (typeof PluginService !== 'undefined' && PluginService.pluginDesktopComponents?.[pluginId] !== undefined)
    
    // Calculate safe positioning with dock/bar awareness
    function getSafeX(x) {
        if (!needsDockBarAwareness) return x
        
        var safeX = x
        var minLeftMargin = leftBarThickness > 0 ? leftBarThickness + 20 : 20
        var minRightMargin = rightBarThickness > 0 ? rightBarThickness + 20 : 20
        
        // Ensure widget doesn't overlap with left bar
        if (x < minLeftMargin) {
            safeX = minLeftMargin
        }
        
        // Ensure widget doesn't overlap with right bar
        if (x + widgetWidth > screenWidth - minRightMargin) {
            safeX = Math.min(safeX, screenWidth - widgetWidth - minRightMargin)
        }
        
        return safeX
    }
    
    function getSafeY(y) {
        if (!needsDockBarAwareness) return y
        
        var safeY = y
        var minTopMargin = topBarThickness > 0 ? topBarThickness + 20 : 20
        var minBottomMargin = bottomDockThickness > 0 ? bottomDockThickness + 20 : 20
        
        // Ensure widget doesn't overlap with top bar
        if (y < minTopMargin) {
            safeY = minTopMargin
        }
        
        // Ensure widget doesn't overlap with bottom dock
        if (y + widgetHeight > screenHeight - minBottomMargin) {
            safeY = Math.min(safeY, screenHeight - widgetHeight - minBottomMargin)
        }
        
        return safeY
    }

    property real widgetX: {
        var x = Math.max(0, Math.min(savedX, screenWidth - widgetWidth))
        return needsDockBarAwareness ? getSafeX(x) : x
    }
    property real widgetY: {
        var y = Math.max(0, Math.min(savedY, screenHeight - widgetHeight))
        return needsDockBarAwareness ? getSafeY(y) : y
    }
    property real widgetWidth: Math.max(minWidth, Math.min(savedWidth, screenWidth))
    property real widgetHeight: Math.max(minHeight, Math.min(savedHeight, screenHeight))

    property real minWidth: contentLoader.item?.minWidth ?? 100
    property real minHeight: contentLoader.item?.minHeight ?? 100
    property bool forceSquare: contentLoader.item?.forceSquare ?? false
    property bool isInteracting: dragArea.pressed || resizeArea.pressed

    property var _gridSettingsTrigger: SettingsData.desktopWidgetGridSettings
    readonly property int gridSize: {
        void _gridSettingsTrigger;
        return SettingsData.getDesktopWidgetGridSetting(screenKey, "size", 40);
    }
    readonly property bool gridEnabled: {
        void _gridSettingsTrigger;
        const enabled = SettingsData.getDesktopWidgetGridSetting(screenKey, "enabled", false);
        // Debug log removed to reduce console spam
        return enabled;
    }

    function snapToGrid(value) {
        return Math.round(value / gridSize) * gridSize;
    }

    function savePosition() {
        if (isInstance && instanceData) {
            SettingsData.updateDesktopWidgetInstancePosition(instanceId, screenKey, {
                x: root.widgetX,
                y: root.widgetY
            });
            return;
        }
        if (usePluginService) {
            pluginService.savePluginData(pluginId, "desktopX_" + screenKey, root.widgetX);
            pluginService.savePluginData(pluginId, "desktopY_" + screenKey, root.widgetY);
            return;
        }
        SettingsData.updateDesktopWidgetPosition(pluginId, screenKey, {
            x: root.widgetX,
            y: root.widgetY
        });
    }

    function saveSize() {
        if (isInstance && instanceData) {
            SettingsData.updateDesktopWidgetInstancePosition(instanceId, screenKey, {
                width: root.widgetWidth,
                height: root.widgetHeight
            });
            return;
        }
        if (usePluginService) {
            pluginService.savePluginData(pluginId, "desktopWidth_" + screenKey, root.widgetWidth);
            pluginService.savePluginData(pluginId, "desktopHeight_" + screenKey, root.widgetHeight);
            return;
        }
        SettingsData.updateDesktopWidgetPosition(pluginId, screenKey, {
            width: root.widgetWidth,
            height: root.widgetHeight
        });
    }

    PanelWindow {
        id: widgetWindow
        screen: root.screen
        visible: {
            if (!root.widgetEnabled || root.activeComponent === null)
                return false;
            if (root.showOnOverviewOnly)
                return root.overviewActive;
            return true;
        }
        color: "transparent"

        WlrLayershell.namespace: "quickshell:dock:blur"
        WlrLayershell.layer: {
            if (root.isInteracting && !CompositorService.useHyprlandFocusGrab)
                return WlrLayer.Overlay;
            if (root.showOnOverlay)
                return WlrLayer.Overlay;
            if (root.overviewActive && (root.showOnOverview || root.showOnOverviewOnly))
                return WlrLayer.Overlay;
            return WlrLayer.Bottom;
        }
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: {
            if (!root.isInteracting)
                return WlrKeyboardFocus.None;
            if (CompositorService.useHyprlandFocusGrab)
                return WlrKeyboardFocus.OnDemand;
            return WlrKeyboardFocus.Exclusive;
        }

        HyprlandFocusGrab {
            active: CompositorService.isHyprland && root.isInteracting
            windows: [widgetWindow]
        }

        Item {
            anchors.fill: parent
            focus: root.isInteracting

            Keys.onPressed: event => {
                if (!root.isInteracting) {
                    console.log("[DesktopPluginWrapper] Key pressed but not interacting:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        key: event.key,
                        isInteracting: root.isInteracting
                    });
                    return;
                }
                
                console.log("[DesktopPluginWrapper] Key pressed during interaction:", {
                    pluginId: root.pluginId,
                    instanceId: root.instanceId || "none",
                    key: event.key,
                    keyName: event.key === Qt.Key_G ? "G" : (event.key === Qt.Key_Z ? "Z" : (event.key === Qt.Key_X ? "X" : "Other"))
                });
                
                switch (event.key) {
                case Qt.Key_G:
                    const newGridEnabled = !root.gridEnabled;
                    console.log("[DesktopPluginWrapper] Toggling grid:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        screenKey: root.screenKey,
                        oldValue: root.gridEnabled,
                        newValue: newGridEnabled,
                        gridSize: root.gridSize
                    });
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "enabled", newGridEnabled);
                    event.accepted = true;
                    break;
                case Qt.Key_Z:
                    const newSizeZ = Math.max(10, root.gridSize - 10);
                    console.log("[DesktopPluginWrapper] Decreasing grid size:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        screenKey: root.screenKey,
                        oldSize: root.gridSize,
                        newSize: newSizeZ
                    });
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "size", newSizeZ);
                    event.accepted = true;
                    break;
                case Qt.Key_X:
                    const newSizeX = Math.min(200, root.gridSize + 10);
                    console.log("[DesktopPluginWrapper] Increasing grid size:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        screenKey: root.screenKey,
                        oldSize: root.gridSize,
                        newSize: newSizeX
                    });
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "size", newSizeX);
                    event.accepted = true;
                    break;
                default:
                    console.log("[DesktopPluginWrapper] Unhandled key:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        key: event.key
                    });
                }
            }
        }

        anchors {
            left: true
            top: true
        }

        WlrLayershell.margins {
            left: root.widgetX
            top: root.widgetY
        }

        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.activeComponent
            
            // Apply rotation transform for Cava widget
            transform: Rotation {
                origin.x: contentLoader.width / 2
                origin.y: contentLoader.height / 2
                angle: root.cavaRotation
            }

            function reloadComponent() {
                active = false;
                active = true;
            }

            function updateInstanceData() {
                if (!item)
                    return;
                var targetItem = item;
                // Handle Loader items
                if (item.sourceComponent !== undefined && item.item !== undefined && item.item) {
                    targetItem = item.item;
                }
                if (targetItem.instanceData === undefined)
                    return;
                targetItem.instanceData = root.instanceData;
            }

            Connections {
                target: root
                enabled: contentLoader.item !== null

                function onInstanceDataChanged() {
                    contentLoader.updateInstanceData();
                }
            }

            onLoaded: {
                if (!item)
                    return;

                // Handle Loader items - set properties on the Loader's item
                var targetItem = item;
                if (item.sourceComponent !== undefined && item.item !== undefined) {
                    // This is a Loader, wait for its item to load
                    if (item.item) {
                        targetItem = item.item;
                    } else {
                        // Wait for Loader's item to be ready
                        item.onItemChanged.connect(function() {
                            if (item.item) {
                                updateItemProperties(item.item);
                            }
                        });
                        return;
                    }
                }

                updateItemProperties(targetItem);
            }

            function updateItemProperties(targetItem) {
                if (!targetItem)
                    return;

                if (targetItem.pluginService !== undefined) {
                    targetItem.pluginService = root.isInstance ? instanceScopedPluginService : root.pluginService;
                }
                if (targetItem.pluginId !== undefined)
                    targetItem.pluginId = root.pluginId;
                if (targetItem.instanceId !== undefined)
                    targetItem.instanceId = root.instanceId;
                if (targetItem.instanceData !== undefined)
                    targetItem.instanceData = root.instanceData;
                if (!root.hasSavedSize) {
                    const defW = targetItem.defaultWidth ?? targetItem.widgetWidth ?? 280;
                    const defH = targetItem.defaultHeight ?? targetItem.widgetHeight ?? 180;
                    root.widgetWidth = Math.max(root.minWidth, Math.min(defW, root.screenWidth));
                    root.widgetHeight = Math.max(root.minHeight, Math.min(defH, root.screenHeight));
                }
                // CRITICAL: Break binding for widgetX/widgetY to make them writable during drag
                // This direct assignment breaks the computed property binding
                if (!root.hasSavedPosition) {
                    let centerX = Math.max(0, Math.min(root.screenWidth / 2 - root.widgetWidth / 2, root.screenWidth - root.widgetWidth));
                    let centerY = Math.max(0, Math.min(root.screenHeight / 2 - root.widgetHeight / 2, root.screenHeight - root.widgetHeight));
                    // Apply dock/bar awareness for specific widgets
                    if (root.needsDockBarAwareness) {
                        centerX = root.getSafeX(centerX);
                        centerY = root.getSafeY(centerY);
                    }
                    root.widgetX = centerX;
                    root.widgetY = centerY;
                } else {
                    // Even when position exists, we need to break the binding by direct assignment
                    // Store current values and reassign to break the computed property binding
                    const breakX = root.widgetX;
                    const breakY = root.widgetY;
                    root.widgetX = breakX;
                    root.widgetY = breakY;
                }
                if (targetItem.widgetWidth !== undefined)
                    targetItem.widgetWidth = Qt.binding(() => contentLoader.width);
                if (targetItem.widgetHeight !== undefined) {
                    if (pluginId === "desktopEventHorizon" || pluginId === "desktopDarkDash") {
                        targetItem.widgetHeight = Qt.binding(() => {
                            const item = contentLoader.item
                            const ih = item && item.implicitHeight > 0 ? item.implicitHeight : (item?.defaultHeight ?? root.widgetHeight)
                            return Math.max(root.minHeight, Math.min(ih, root.screenHeight))
                        })
                    } else {
                        targetItem.widgetHeight = Qt.binding(() => contentLoader.height)
                    }
                }
            }
        }

        Rectangle {
            id: interactionBorder
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.primary
            border.width: 2
            radius: Theme.cornerRadius
            visible: root.isInteracting && !root.useGhostPreview
            opacity: 0.8

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: root.spx(48)
                height: root.spx(48)
                topLeftRadius: Theme.cornerRadius
                bottomRightRadius: Theme.cornerRadius
                color: Theme.primary
                opacity: resizeArea.pressed ? 1 : 0.6
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

            property point startPos
            property real startX
            property real startY

            onPressed: mouse => {
                startPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                startX = root.widgetX;
                startY = root.widgetY;
                root.previewX = root.widgetX;
                root.previewY = root.widgetY;
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const currentPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                let newX = Math.max(0, Math.min(startX + currentPos.x - startPos.x, root.screenWidth - root.widgetWidth));
                let newY = Math.max(0, Math.min(startY + currentPos.y - startPos.y, root.screenHeight - root.widgetHeight));
                if (root.gridEnabled) {
                    newX = Math.max(0, Math.min(root.snapToGrid(newX), root.screenWidth - root.widgetWidth));
                    newY = Math.max(0, Math.min(root.snapToGrid(newY), root.screenHeight - root.widgetHeight));
                }
                // Apply dock/bar awareness for specific widgets
                if (root.needsDockBarAwareness) {
                    newX = root.getSafeX(newX)
                    newY = root.getSafeY(newY)
                }
                if (root.useGhostPreview) {
                    root.previewX = newX;
                    root.previewY = newY;
                    return;
                }
                root.widgetX = newX;
                root.widgetY = newY;
            }

            onReleased: {
                if (root.useGhostPreview) {
                    root.widgetX = root.previewX;
                    root.widgetY = root.previewY;
                }
                root.savePosition();
            }
        }

        MouseArea {
            id: resizeArea
            width: root.spx(48)
            height: root.spx(48)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            acceptedButtons: Qt.RightButton
            cursorShape: pressed ? Qt.SizeFDiagCursor : Qt.ArrowCursor

            property point startPos
            property real startWidth
            property real startHeight

            onPressed: mouse => {
                startPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                startWidth = root.widgetWidth;
                startHeight = root.widgetHeight;
                root.previewWidth = root.widgetWidth;
                root.previewHeight = root.widgetHeight;
                
                console.log("[DesktopPluginWrapper] Resize started:", {
                    pluginId: root.pluginId,
                    instanceId: root.instanceId || "none",
                    screenKey: root.screenKey,
                    startPos: startPos.x + "," + startPos.y,
                    startWidth: startWidth,
                    startHeight: startHeight,
                    minWidth: root.minWidth,
                    minHeight: root.minHeight,
                    gridEnabled: root.gridEnabled,
                    gridSize: root.gridSize,
                    useGhostPreview: root.useGhostPreview
                });
            }

            onPositionChanged: mouse => {
                if (!pressed) {
                    console.log("[DesktopPluginWrapper] Resize position changed but not pressed");
                    return;
                }
                
                const currentPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                const deltaX = currentPos.x - startPos.x;
                const deltaY = currentPos.y - startPos.y;
                let newW = startWidth + deltaX;
                let newH = startHeight + deltaY;
                
                console.log("[DesktopPluginWrapper] Resize position changed (before clamping):", {
                    pluginId: root.pluginId,
                    instanceId: root.instanceId || "none",
                    deltaX: deltaX,
                    deltaY: deltaY,
                    newW: newW,
                    newH: newH,
                    startWidth: startWidth,
                    startHeight: startHeight
                });
                
                // Clamp to screen bounds and min size
                const beforeClampW = newW;
                const beforeClampH = newH;
                newW = Math.max(root.minWidth, Math.min(newW, root.screenWidth - root.widgetX));
                newH = Math.max(root.minHeight, Math.min(newH, root.screenHeight - root.widgetY));
                
                if (beforeClampW !== newW || beforeClampH !== newH) {
                    console.log("[DesktopPluginWrapper] Resize clamped:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        beforeW: beforeClampW,
                        beforeH: beforeClampH,
                        afterW: newW,
                        afterH: newH,
                        minWidth: root.minWidth,
                        minHeight: root.minHeight,
                        maxWidth: root.screenWidth - root.widgetX,
                        maxHeight: root.screenHeight - root.widgetY
                    });
                }
                
                // Apply grid snapping
                if (root.gridEnabled) {
                    const beforeGridW = newW;
                    const beforeGridH = newH;
                    newW = Math.max(root.minWidth, root.snapToGrid(newW));
                    newH = Math.max(root.minHeight, root.snapToGrid(newH));
                    
                    if (beforeGridW !== newW || beforeGridH !== newH) {
                        console.log("[DesktopPluginWrapper] Resize grid snapping applied:", {
                            pluginId: root.pluginId,
                            instanceId: root.instanceId || "none",
                            beforeGridW: beforeGridW,
                            beforeGridH: beforeGridH,
                            afterGridW: newW,
                            afterGridH: newH,
                            gridSize: root.gridSize
                        });
                    }
                }
                
                // Apply force square if enabled
                if (root.forceSquare) {
                    const beforeSquareW = newW;
                    const beforeSquareH = newH;
                    const size = Math.max(newW, newH);
                    newW = Math.min(size, root.screenWidth - root.widgetX);
                    newH = Math.min(size, root.screenHeight - root.widgetY);
                    
                    if (beforeSquareW !== newW || beforeSquareH !== newH) {
                        console.log("[DesktopPluginWrapper] Force square applied:", {
                            pluginId: root.pluginId,
                            instanceId: root.instanceId || "none",
                            beforeW: beforeSquareW,
                            beforeH: beforeSquareH,
                            afterW: newW,
                            afterH: newH
                        });
                    }
                }
                
                if (root.useGhostPreview) {
                    root.previewWidth = newW;
                    root.previewHeight = newH;
                    console.log("[DesktopPluginWrapper] Preview size updated:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        previewWidth: root.previewWidth,
                        previewHeight: root.previewHeight
                    });
                    return;
                }
                
                root.widgetWidth = newW;
                root.widgetHeight = newH;
                
                console.log("[DesktopPluginWrapper] Final widget size set:", {
                    pluginId: root.pluginId,
                    instanceId: root.instanceId || "none",
                    widgetWidth: root.widgetWidth,
                    widgetHeight: root.widgetHeight
                });
            }

            onReleased: {
                console.log("[DesktopPluginWrapper] Resize released:", {
                    pluginId: root.pluginId,
                    instanceId: root.instanceId || "none",
                    finalWidth: root.widgetWidth,
                    finalHeight: root.widgetHeight,
                    previewWidth: root.previewWidth,
                    previewHeight: root.previewHeight,
                    startWidth: startWidth,
                    startHeight: startHeight,
                    totalDeltaW: root.widgetWidth - startWidth,
                    totalDeltaH: root.widgetHeight - startHeight,
                    useGhostPreview: root.useGhostPreview
                });
                
                if (root.useGhostPreview) {
                    console.log("[DesktopPluginWrapper] Applying preview size to widget:", {
                        pluginId: root.pluginId,
                        instanceId: root.instanceId || "none",
                        oldWidth: root.widgetWidth,
                        oldHeight: root.widgetHeight,
                        newWidth: root.previewWidth,
                        newHeight: root.previewHeight
                    });
                    root.widgetWidth = root.previewWidth;
                    root.widgetHeight = root.previewHeight;
                }
                
                console.log("[DesktopPluginWrapper] Saving size after resize...");
                root.saveSize();
            }
        }
    }

    Loader {
        active: root.isInteracting && root.useGhostPreview

        sourceComponent: PanelWindow {
            id: ghostPreviewWindow
            screen: root.screen
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            mask: Region {}

            WlrLayershell.namespace: "quickshell:desktop-widget-preview"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: gridOverlay
                anchors.fill: parent
                visible: root.gridEnabled
                opacity: 0.3

                Repeater {
                    model: Math.ceil(root.screenWidth / root.gridSize)

                    Rectangle {
                        required property int index
                        x: index * root.gridSize
                        y: 0
                        width: 1
                        height: root.screenHeight
                        color: Theme.primary
                    }
                }

                Repeater {
                    model: Math.ceil(root.screenHeight / root.gridSize)

                    Rectangle {
                        required property int index
                        x: 0
                        y: index * root.gridSize
                        width: root.screenWidth
                        height: 1
                        color: Theme.primary
                    }
                }
            }

            Rectangle {
                x: root.previewX
                y: root.previewY
                width: root.previewWidth
                height: root.previewHeight
                color: "transparent"
                border.color: Theme.primary
                border.width: 2
                radius: Theme.cornerRadius

                Rectangle {
                    width: 48
                    height: 48
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    topLeftRadius: Theme.cornerRadius
                    bottomRightRadius: Theme.cornerRadius
                    color: Theme.primary
                    opacity: resizeArea.pressed ? 1 : 0.6
                }
            }
        }
    }

    Loader {
        active: root.isInteracting && root.gridEnabled && !root.useGhostPreview

        sourceComponent: PanelWindow {
            screen: root.screen
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            mask: Region {}

            WlrLayershell.namespace: "quickshell:desktop-widget-grid"
            WlrLayershell.layer: root.overviewActive && (root.showOnOverview || root.showOnOverviewOnly) ? WlrLayer.Overlay : WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                opacity: 0.3

                Repeater {
                    model: Math.ceil(root.screenWidth / root.gridSize)

                    Rectangle {
                        required property int index
                        x: index * root.gridSize
                        y: 0
                        width: 1
                        height: root.screenHeight
                        color: Theme.primary
                    }
                }

                Repeater {
                    model: Math.ceil(root.screenHeight / root.gridSize)

                    Rectangle {
                        required property int index
                        x: 0
                        y: index * root.gridSize
                        width: root.screenWidth
                        height: 1
                        color: Theme.primary
                    }
                }
            }
        }
    }

    Loader {
        active: root.isInteracting

        sourceComponent: PanelWindow {
            id: helperWindow
            screen: root.screen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:desktop-widget-helper"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: 60

            Rectangle {
                id: helperContent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                width: helperRow.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: Theme.cornerRadius
                color: Theme.surface

                Row {
                    id: helperRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    height: parent.height

                    EHIcon {
                        name: "grid_on"
                        size: 16
                        color: root.gridEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.gridEnabled ? "Grid: ON" : "Grid: OFF"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.gridEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.gridSize + "px"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "G: grid • Z/X: size"
                        font.pixelSize: Theme.fontSizeSmall
                        font.italic: true
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
