import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.Settings
import qs.Services

Item {
    id: dockTab

    property var defaultLeftWidgets: []
    property var defaultCenterWidgets: [{"id": "launchpad", "enabled": true}, {"id": "pinnedApps", "enabled": true}, {"id": "trash", "enabled": true}]
    property var defaultRightWidgets: []

    property var dockWidgetDefinitions: [{
            "id": "launcherButton",
            "text": "App Launcher",
            "description": "Quick access to application launcher",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "workspaceSwitcher",
            "text": "Workspace Switcher",
            "description": "Shows current workspace and allows switching",
            "icon": "view_module",
            "enabled": true
        }, {
            "id": "focusedWindow",
            "text": "Focused Window",
            "description": "Display currently focused application title",
            "icon": "window",
            "enabled": true
        }, {
            "id": "runningApps",
            "text": "Running Apps",
            "description": "Shows all running applications with focus indication",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "pinnedApps",
            "text": "Pinned Apps",
            "description": "Shows pinned apps (and running indicators)",
            "icon": "push_pin",
            "enabled": true
        }, {
            "id": "clock",
            "text": "Clock",
            "description": "Current time and date display",
            "icon": "schedule",
            "enabled": true
        }, {
            "id": "weather",
            "text": "Weather Widget",
            "description": "Current weather conditions and temperature",
            "icon": "wb_sunny",
            "enabled": true
        }, {
            "id": "music",
            "text": "Media Controls",
            "description": "Control currently playing media",
            "icon": "music_note",
            "enabled": true
        }, {
            "id": "clipboard",
            "text": "Clipboard Manager",
            "description": "Access clipboard history",
            "icon": "content_paste",
            "enabled": true
        }, {
            "id": "trash",
            "text": "Trash",
            "description": "Show trash status and quick open",
            "icon": "delete",
            "enabled": true
        }, {
            "id": "cpuUsage",
            "text": "CPU Usage",
            "description": "CPU usage indicator",
            "icon": "memory",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "memUsage",
            "text": "Memory Usage",
            "description": "Memory usage indicator",
            "icon": "storage",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "cpuTemp",
            "text": "CPU Temperature",
            "description": "CPU temperature display",
            "icon": "device_thermostat",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        }, {
            "id": "gpuTemp",
            "text": "GPU Temperature",
            "description": "GPU temperature display",
            "icon": "auto_awesome_mosaic",
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : "This widget prevents GPU power off states, which can significantly impact battery life on laptops. It is not recommended to use this on laptops with hybrid graphics.",
            "enabled": DgopService.dgopAvailable
        }, {
            "id": "systemTray",
            "text": "System Tray",
            "description": "System notification area icons",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "privacyIndicator",
            "text": "Privacy Indicator",
            "description": "Shows when microphone, camera, or screen sharing is active",
            "icon": "privacy_tip",
            "enabled": true
        }, {
            "id": "controlCenterButton",
            "text": "Control Center",
            "description": "Access to system controls and settings",
            "icon": "settings",
            "enabled": true
        }, {
            "id": "notificationButton",
            "text": "Notification Center",
            "description": "Access to notifications and do not disturb",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "battery",
            "text": "Battery",
            "description": "Battery level and power management",
            "icon": "battery_std",
            "enabled": true
        }, {
            "id": "vpn",
            "text": "VPN",
            "description": "VPN status and quick connect",
            "icon": "vpn_lock",
            "enabled": true
        }, {
            "id": "idleInhibitor",
            "text": "Idle Inhibitor",
            "description": "Prevent screen timeout",
            "icon": "motion_sensor_active",
            "enabled": true
        }, {
            "id": "spacer",
            "text": "Spacer",
            "description": "Customizable empty space",
            "icon": "more_horiz",
            "enabled": true
        }, {
            "id": "separator",
            "text": "Separator",
            "description": "Visual divider between widgets",
            "icon": "remove",
            "enabled": true
        }, {
            "id": "network_speed_monitor",
            "text": "Network Speed Monitor",
            "description": "Network download and upload speed display",
            "icon": "network_check",
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined,
            "enabled": DgopService.dgopAvailable
        }, {
            "id": "keyboard_layout_name",
            "text": "Keyboard Layout Name",
            "description": "Displays the active keyboard layout and allows switching",
            "icon": "keyboard",
            "enabled": true
        }, {
            "id": "notepadButton",
            "text": "Notepad",
            "description": "Quick access to notepad",
            "icon": "assignment",
            "enabled": true
        }, {
            "id": "colorPicker",
            "text": "Color Picker",
            "description": "Quick access to color picker",
            "icon": "palette",
            "enabled": true
        }, {
            "id": "systemUpdate",
            "text": "System Update",
            "description": "Check for system updates",
            "icon": "update",
            "enabled": SystemUpdateService.distributionSupported
        }, {
            "id": "settingsButton",
            "text": "Settings Button",
            "description": "Quick access to settings modal",
            "icon": "settings",
            "enabled": true
        }, {
            "id": "darkDash",
            "text": "Dark Dash",
            "description": "Quick access dashboard with overview, media, and weather",
            "icon": "dashboard",
            "enabled": true
        }, {
            "id": "applications",
            "text": "Applications",
            "description": "macOS Tahoe-style application launcher with categorized apps",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "volumeMixerButton",
            "text": "Volume Mixer",
            "description": "Quick access to system and application volume controls",
            "icon": "volume_up",
            "enabled": true
        }, {
            "id": "launchpad",
            "text": "Launchpad",
            "description": "Full-screen, grid-first launcher styled after macOS/iOS",
            "icon": "grid_view",
            "enabled": true
        }, {
            "id": "cavaBackground",
            "text": "Cava Background",
            "description": "Audio visualizer background that appears behind other dock items",
            "icon": "equalizer",
            "enabled": true
        }]

    // ─── Helper functions ────────────────────────────────────────────────────

    function addWidgetToSection(widgetId, targetSection) {
        var widgetObj = { "id": widgetId, "enabled": true }
        if (widgetId === "spacer")
            widgetObj.size = 20
        var widgets = []
        if (targetSection === "dockLeft") {
            widgets = SettingsData.dockLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDockLeftWidgets(widgets)
        } else if (targetSection === "dockCenter") {
            widgets = SettingsData.dockCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDockCenterWidgets(widgets)
        } else if (targetSection === "dockRight") {
            widgets = SettingsData.dockRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDockRightWidgets(widgets)
        } else if (targetSection === "dockBackground") {
            widgets = SettingsData.dockBackgroundWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setDockBackgroundWidgets(widgets)
        }
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "dockLeft") {
            widgets = SettingsData.dockLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.setDockLeftWidgets(widgets)
            }
        } else if (sectionId === "dockCenter") {
            widgets = SettingsData.dockCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.setDockCenterWidgets(widgets)
            }
        } else if (sectionId === "dockRight") {
            widgets = SettingsData.dockRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.setDockRightWidgets(widgets)
            }
        } else if (sectionId === "dockBackground") {
            widgets = SettingsData.dockBackgroundWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.setDockBackgroundWidgets(widgets)
            }
        }
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "dockLeft")
            widgets = SettingsData.dockLeftWidgets.slice()
        else if (sectionId === "dockCenter")
            widgets = SettingsData.dockCenterWidgets.slice()
        else if (sectionId === "dockRight")
            widgets = SettingsData.dockRightWidgets.slice()
        else if (sectionId === "dockBackground")
            widgets = SettingsData.dockBackgroundWidgets.slice()

        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === itemId) {
                if (typeof widget === "string") {
                    widgets[i] = { "id": widget, "enabled": enabled }
                } else {
                    var newWidget = { "id": widget.id, "enabled": enabled }
                    if (widget.size !== undefined)
                        newWidget.size = widget.size
                    widgets[i] = newWidget
                }
                break
            }
        }

        if (sectionId === "dockLeft")
            SettingsData.setDockLeftWidgets(widgets)
        else if (sectionId === "dockCenter")
            SettingsData.setDockCenterWidgets(widgets)
        else if (sectionId === "dockRight")
            SettingsData.setDockRightWidgets(widgets)
        else if (sectionId === "dockBackground")
            SettingsData.setDockBackgroundWidgets(widgets)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "dockLeft")
            SettingsData.setDockLeftWidgets(newOrder)
        else if (sectionId === "dockCenter")
            SettingsData.setDockCenterWidgets(newOrder)
        else if (sectionId === "dockRight")
            SettingsData.setDockRightWidgets(newOrder)
        else if (sectionId === "dockBackground")
            SettingsData.setDockBackgroundWidgets(newOrder)
    }

    function handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value) {
        if (settingName === "showNetworkIcon") SettingsData.setControlCenterShowNetworkIcon(value)
        else if (settingName === "showBluetoothIcon") SettingsData.setControlCenterShowBluetoothIcon(value)
        else if (settingName === "showAudioIcon") SettingsData.setControlCenterShowAudioIcon(value)
        else if (settingName === "showMicIcon") SettingsData.setControlCenterShowMicIcon(value)
    }

    function handleSpacerSizeChanged(sectionId, widgetIndex, newSize) {
        var widgets = []
        if (sectionId === "dockLeft")
            widgets = SettingsData.dockLeftWidgets.slice()
        else if (sectionId === "dockCenter")
            widgets = SettingsData.dockCenterWidgets.slice()
        else if (sectionId === "dockRight")
            widgets = SettingsData.dockRightWidgets.slice()
        else if (sectionId === "dockBackground")
            widgets = SettingsData.dockBackgroundWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === "spacer") {
                if (typeof widget === "string") {
                    widgets[widgetIndex] = { "id": widget, "enabled": true, "size": newSize }
                } else {
                    widgets[widgetIndex] = { "id": widget.id, "enabled": widget.enabled, "size": newSize }
                }
            }
        }

        if (sectionId === "dockLeft")
            SettingsData.setDockLeftWidgets(widgets)
        else if (sectionId === "dockCenter")
            SettingsData.setDockCenterWidgets(widgets)
        else if (sectionId === "dockRight")
            SettingsData.setDockRightWidgets(widgets)
        else if (sectionId === "dockBackground")
            SettingsData.setDockBackgroundWidgets(widgets)
    }

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "dockLeft")
            widgetData = SettingsData.dockLeftWidgets || []
        else if (sectionId === "dockCenter")
            widgetData = SettingsData.dockCenterWidgets || []
        else if (sectionId === "dockRight")
            widgetData = SettingsData.dockRightWidgets || []
        else if (sectionId === "dockBackground")
            widgetData = SettingsData.dockBackgroundWidgets || []

        widgetData.forEach(widget => {
            var widgetId = typeof widget === "string" ? widget : widget.id
            var widgetDef = dockWidgetDefinitions.find(def => def.id === widgetId)
            if (widgetDef) {
                var item = {
                    "id": widgetId,
                    "text": widgetDef.text,
                    "description": widgetDef.description,
                    "icon": widgetDef.icon,
                    "enabled": typeof widget === "string" ? true : widget.enabled
                }
                if (widgetId === "spacer" && widget.size !== undefined)
                    item.size = widget.size
                widgets.push(item)
            }
        })
        return widgets
    }

    // ─── UI ─────────────────────────────────────────────────────────────────

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 1: Visibility & Behavior
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: visibilitySection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: visibilitySection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "visibility"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Visibility & Behavior"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Show Dock"
                        description: "Display a dock at the bottom of the screen with pinned and running applications"
                        checked: SettingsData.showDock
                        onToggled: checked => SettingsData.setShowDock(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Auto-hide Dock"
                        description: "Hide the dock when not in use and reveal it when hovering near the bottom of the screen"
                        checked: SettingsData.dockAutoHide
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockAutoHide(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Hide on Games/Apps"
                        description: "Automatically hide the dock when games or fullscreen applications are running"
                        checked: SettingsData.dockHideOnGames
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockHideOnGames(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Expand to Screen"
                        description: "Expand the dock to full screen width, hiding the left and right widget areas"
                        checked: SettingsData.dockExpandToScreen
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockExpandToScreen(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Enable Dock Widgets"
                        description: "Show widgets on the left and right sides of the dock"
                        checked: SettingsData.dockWidgetsEnabled
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockWidgetsEnabled(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Group Apps"
                        description: "Group multiple windows of the same application into a single dock entry"
                        checked: SettingsData.dockGroupApps
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockGroupApps(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Show Tooltips"
                        description: "Show application names and window titles when hovering over dock icons"
                        checked: SettingsData.dockTooltipsEnabled
                        enabled: SettingsData.showDock
                        onToggled: checked => SettingsData.setDockTooltipsEnabled(checked)
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 2: Widget Management
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: widgetManagementHeader.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                Column {
                    id: widgetManagementHeader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "widgets"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Widget Management"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { height: 1; Layout.fillWidth: true }

                        Row {
                            spacing: Theme.spacingS
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                id: defaultsButton
                                width: Theme.scaledWidth(90)
                                height: 28
                                radius: Theme.cornerRadius
                                color: defaultsArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                                border.width: 1
                                border.color: defaultsArea.containsMouse ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS
                                    EHIcon { name: "restore"; size: 14; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText { text: "Defaults"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: defaultsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsData.setDockLeftWidgets(defaultLeftWidgets)
                                        SettingsData.setDockCenterWidgets(defaultCenterWidgets)
                                        SettingsData.setDockRightWidgets(defaultRightWidgets)
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                            }

                            Rectangle {
                                id: resetButton
                                width: Theme.scaledWidth(80)
                                height: 28
                                radius: Theme.cornerRadius
                                color: resetArea.containsMouse ? Theme.surfacePressed : Theme.surfaceVariant
                                border.width: 1
                                border.color: resetArea.containsMouse ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS
                                    EHIcon { name: "refresh"; size: 14; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText { text: "Reset"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: resetArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsData.setDockLeftWidgets([])
                                        SettingsData.setDockCenterWidgets([])
                                        SettingsData.setDockRightWidgets([])
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: "Drag widgets to reorder within sections. Use the eye icon to hide/show widgets (maintains spacing), or X to remove them completely."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // Left / Center / Right widget sections
            Column {
                width: parent.width
                spacing: Theme.spacingL
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                StyledRect {
                    width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                    height: leftSection.implicitHeight + Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    WidgetsTabSection {
                        id: leftSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: "Left Side Widgets"
                        titleIcon: "format_align_left"
                        sectionId: "dockLeft"
                        items: dockTab.getItemsForSection("dockLeft")
                        allWidgets: dockTab.dockWidgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => dockTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => dockTab.handleItemOrderChanged("dockLeft", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = dockTab.dockWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => dockTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => dockTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => dockTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                    }
                }

                StyledRect {
                    width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                    height: centerSection.implicitHeight + Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    WidgetsTabSection {
                        id: centerSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: "Center Widgets"
                        titleIcon: "format_align_center"
                        sectionId: "dockCenter"
                        items: dockTab.getItemsForSection("dockCenter")
                        allWidgets: dockTab.dockWidgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => dockTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => dockTab.handleItemOrderChanged("dockCenter", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = dockTab.dockWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => dockTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => dockTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => dockTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                    }
                }

                StyledRect {
                    width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                    height: rightSection.implicitHeight + Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    WidgetsTabSection {
                        id: rightSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: "Right Side Widgets"
                        titleIcon: "format_align_right"
                        sectionId: "dockRight"
                        items: dockTab.getItemsForSection("dockRight")
                        allWidgets: dockTab.dockWidgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => dockTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => dockTab.handleItemOrderChanged("dockRight", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = dockTab.dockWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => dockTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => dockTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => dockTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                    }
                }

                StyledRect {
                    width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                    height: backgroundSection.implicitHeight + Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    WidgetsTabSection {
                        id: backgroundSection
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        title: "Background Widgets"
                        titleIcon: "layers"
                        sectionId: "dockBackground"
                        items: dockTab.getItemsForSection("dockBackground")
                        allWidgets: dockTab.dockWidgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => dockTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => dockTab.handleItemOrderChanged("dockBackground", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = dockTab.dockWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => dockTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => dockTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => dockTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 3: Style (Opacity + Border + Pill backgrounds)
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: styleSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                Column {
                    id: styleSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "palette"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Style"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Dock Opacity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Dock Opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.dockTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockTransparency(newValue / 100)
                        }
                    }

                    // Background Tint Opacity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Background Tint Opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.dockBackgroundTintOpacity * 100)
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockBackgroundTintOpacity(newValue / 100)
                        }
                    }

                    // Pill backgrounds
                    EHToggle {
                        width: parent.width
                        text: "Pill Background"
                        description: "Show a pill-shaped background behind pinned apps"
                        checked: SettingsData.dockPinnedAppsPillEnabled
                        onToggled: checked => SettingsData.setDockPinnedAppsPillEnabled(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Trash Pill Background"
                        description: "Show a pill-shaped background behind the trash bin"
                        checked: SettingsData.dockTrashPillEnabled
                        onToggled: checked => SettingsData.setDockTrashPillEnabled(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Launchpad Pill Background"
                        description: "Show a pill-shaped background behind the launchpad button"
                        checked: SettingsData.dockLaunchpadPillEnabled
                        onToggled: checked => SettingsData.setDockLaunchpadPillEnabled(checked)
                    }

                    // Border
                    EHToggle {
                        width: parent.width
                        text: "Enable Border"
                        description: "Add a customizable border around the dock"
                        checked: SettingsData.dockBorderEnabled
                        onToggled: checked => SettingsData.setDockBorderEnabled(checked)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SettingsData.dockBorderEnabled
                        opacity: visible ? 1 : 0

                        EHToggle {
                            width: parent.width
                            text: "Enable Dynamic Border Colors"
                            description: "Override user-set border colors with dynamic colors sourced from matugen"
                            checked: SettingsData.dockDynamicBorderColors
                            onToggled: checked => SettingsData.setDockDynamicBorderColors(checked)
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Border Width"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: SettingsData.dockBorderWidth
                                minimum: 1
                                maximum: 20
                                unit: "px"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => SettingsData.setDockBorderWidth(newValue)
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Border Radius"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 24
                                value: Math.round(SettingsData.dockBorderRadius)
                                minimum: 0
                                maximum: 50
                                unit: "px"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => SettingsData.setDockBorderRadius(newValue)
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Border Color"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            // Hue slider — quick hue sweep at full saturation
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: !SettingsData.dockDynamicBorderColors
                                opacity: visible ? 1 : 0

                                StyledText { text: "Hue"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                                EHSlider {
                                    width: parent.width; height: 24
                                    value: (SettingsData.dockBorderHue ?? 0)
                                    minimum: 0; maximum: 360; unit: "°"; showValue: true; wheelEnabled: false
                                    onSliderValueChanged: newValue => SettingsData.setDockBorderHue(newValue)
                                }

                                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Red"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.dockBorderRed * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setDockBorderRed(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Green"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.dockBorderGreen * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setDockBorderGreen(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Blue"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.dockBorderBlue * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setDockBorderBlue(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Alpha"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.dockBorderAlpha * 100)
                                        minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setDockBorderAlpha(newValue / 100)
                                    }
                                }
                            }
                        }

                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 4: Layout
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: layoutSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                Column {
                    id: layoutSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "straighten"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Layout"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Dock Scale"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.dockScale * 100)
                            minimum: 50
                            maximum: 150
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockScale(newValue / 100)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Icon Size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.dockIconSize)
                            minimum: 16
                            maximum: 96
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockIconSize(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Icon Spacing"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.dockIconSpacing)
                            minimum: 0
                            maximum: 32
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockIconSpacing(newValue)
                        }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 5: Padding
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: paddingSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                Column {
                    id: paddingSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "padding"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Padding"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Left Padding"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockLeftPadding
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockLeftPadding(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Right Padding (auto-synced with Left)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockLeftPadding
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            enabled: false
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Top Padding"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockTopPadding
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockTopPadding(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Bottom Padding (auto-synced with Top)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockTopPadding
                            minimum: 0
                            maximum: 100
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            enabled: false
                        }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 6: Advanced
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: advancedSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.showDock
                opacity: visible ? 1 : 0

                Column {
                    id: advancedSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "tune"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Advanced"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Bottom Gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "Space between the dock and the screen edge. 0 = edge-to-edge."
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockBottomGap
                            minimum: 0
                            maximum: 64
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockBottomGap(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Exclusive Zone"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "Controls reserved screen space. 0 = none, -1 = always exclusive."
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.dockExclusiveZone
                            minimum: -1
                            maximum: 200
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockExclusiveZone(newValue)
                        }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

        }
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup
        onWidgetSelected: (widgetId, targetSection) => {
            dockTab.addWidgetToSection(widgetId, targetSection)
        }
    }
}