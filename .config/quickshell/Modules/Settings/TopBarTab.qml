import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: topBarTab

    property var baseWidgetDefinitions: [{
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
            "id": "mediaDisplay",
            "text": "Media Display",
            "description": "Media controls with circular cava visualizer and album art",
            "icon": "album",
            "enabled": true
        }, {
            "id": "clipboard",
            "text": "Clipboard Manager",
            "description": "Access clipboard history",
            "icon": "content_paste",
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
            "description": "Control system and application audio levels",
            "icon": "volume_up",
            "enabled": true
        }]

    property var defaultLeftWidgets: ["launcherButton"]
    property var defaultCenterWidgets: ["workspaceSwitcher"]
    property var defaultRightWidgets: ["systemTray", "weather", "clock", "notificationButton", "controlCenterButton", "systemUpdate"]

    Component.onCompleted: {
        if (!SettingsData.topBarLeftWidgets)
            SettingsData.setTopBarLeftWidgets(defaultLeftWidgets)
        if (!SettingsData.topBarCenterWidgets)
            SettingsData.setTopBarCenterWidgets(defaultCenterWidgets)
        if (!SettingsData.topBarRightWidgets)
            SettingsData.setTopBarRightWidgets(defaultRightWidgets)

        const sections = ["left", "center", "right"]
        sections.forEach(sectionId => {
            var widgets = []
            if (sectionId === "left") widgets = SettingsData.topBarLeftWidgets.slice()
            else if (sectionId === "center") widgets = SettingsData.topBarCenterWidgets.slice()
            else if (sectionId === "right") widgets = SettingsData.topBarRightWidgets.slice()
            var updated = false
            for (var i = 0; i < widgets.length; i++) {
                var widget = widgets[i]
                if (typeof widget === "object" && widget.id === "spacer" && !widget.size) {
                    widgets[i] = Object.assign({}, widget, { "size": 20 })
                    updated = true
                }
            }
            if (updated) {
                if (sectionId === "left") SettingsData.setTopBarLeftWidgets(widgets)
                else if (sectionId === "center") SettingsData.setTopBarCenterWidgets(widgets)
                else if (sectionId === "right") SettingsData.setTopBarRightWidgets(widgets)
            }
        })
    }

    // ─── Helper functions ────────────────────────────────────────────────────

    function addWidgetToSection(widgetId, targetSection) {
        var widgetObj = { "id": widgetId, "enabled": true }
        if (widgetId === "spacer") widgetObj.size = 20
        if (widgetId === "gpuTemp") { widgetObj.selectedGpuIndex = 0; widgetObj.pciId = "" }
        if (widgetId === "controlCenterButton") {
            widgetObj.showNetworkIcon = true
            widgetObj.showBluetoothIcon = true
            widgetObj.showAudioIcon = true
        }
        var widgets = []
        if (targetSection === "left") {
            widgets = SettingsData.topBarLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarLeftWidgets(widgets)
        } else if (targetSection === "center") {
            widgets = SettingsData.topBarCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarCenterWidgets(widgets)
        } else if (targetSection === "right") {
            widgets = SettingsData.topBarRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.setTopBarRightWidgets(widgets)
        }
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "left") {
            widgets = SettingsData.topBarLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) widgets.splice(widgetIndex, 1)
            SettingsData.setTopBarLeftWidgets(widgets)
        } else if (sectionId === "center") {
            widgets = SettingsData.topBarCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) widgets.splice(widgetIndex, 1)
            SettingsData.setTopBarCenterWidgets(widgets)
        } else if (sectionId === "right") {
            widgets = SettingsData.topBarRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) widgets.splice(widgetIndex, 1)
            SettingsData.setTopBarRightWidgets(widgets)
        }
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "left") widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center") widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right") widgets = SettingsData.topBarRightWidgets.slice()

        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === itemId) {
                if (typeof widget === "string") {
                    widgets[i] = { "id": widget, "enabled": enabled }
                } else {
                    var newWidget = { "id": widget.id, "enabled": enabled }
                    if (widget.size !== undefined) newWidget.size = widget.size
                    if (widget.selectedGpuIndex !== undefined) newWidget.selectedGpuIndex = widget.selectedGpuIndex
                    else if (widget.id === "gpuTemp") newWidget.selectedGpuIndex = 0
                    if (widget.pciId !== undefined) newWidget.pciId = widget.pciId
                    else if (widget.id === "gpuTemp") newWidget.pciId = ""
                    if (widget.id === "controlCenterButton") {
                        newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                        newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                        newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                    }
                    widgets[i] = newWidget
                }
                break
            }
        }
        if (sectionId === "left") SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center") SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right") SettingsData.setTopBarRightWidgets(widgets)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "left") SettingsData.setTopBarLeftWidgets(newOrder)
        else if (sectionId === "center") SettingsData.setTopBarCenterWidgets(newOrder)
        else if (sectionId === "right") SettingsData.setTopBarRightWidgets(newOrder)
    }

    function handleSpacerSizeChanged(sectionId, widgetIndex, newSize) {
        var widgets = []
        if (sectionId === "left") widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center") widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right") widgets = SettingsData.topBarRightWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === "spacer") {
                if (typeof widget === "string") {
                    widgets[widgetIndex] = { "id": widget, "enabled": true, "size": newSize }
                } else {
                    var newWidget = { "id": widget.id, "enabled": widget.enabled, "size": newSize }
                    if (widget.selectedGpuIndex !== undefined) newWidget.selectedGpuIndex = widget.selectedGpuIndex
                    if (widget.pciId !== undefined) newWidget.pciId = widget.pciId
                    if (widget.id === "controlCenterButton") {
                        newWidget.showNetworkIcon = widget.showNetworkIcon !== undefined ? widget.showNetworkIcon : true
                        newWidget.showBluetoothIcon = widget.showBluetoothIcon !== undefined ? widget.showBluetoothIcon : true
                        newWidget.showAudioIcon = widget.showAudioIcon !== undefined ? widget.showAudioIcon : true
                    }
                    widgets[widgetIndex] = newWidget
                }
            }
        }
        if (sectionId === "left") SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center") SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right") SettingsData.setTopBarRightWidgets(widgets)
    }

    function handleGpuSelectionChanged(sectionId, widgetIndex, selectedGpuIndex) {
        var widgets = []
        if (sectionId === "left") widgets = SettingsData.topBarLeftWidgets.slice()
        else if (sectionId === "center") widgets = SettingsData.topBarCenterWidgets.slice()
        else if (sectionId === "right") widgets = SettingsData.topBarRightWidgets.slice()

        if (widgetIndex >= 0 && widgetIndex < widgets.length) {
            var widget = widgets[widgetIndex]
            var pciId = DgopService.availableGpus && DgopService.availableGpus.length > selectedGpuIndex
                        ? DgopService.availableGpus[selectedGpuIndex].pciId : ""
            if (typeof widget === "string") {
                widgets[widgetIndex] = { "id": widget, "enabled": true, "selectedGpuIndex": selectedGpuIndex, "pciId": pciId }
            } else {
                var newWidget = { "id": widget.id, "enabled": widget.enabled, "selectedGpuIndex": selectedGpuIndex, "pciId": pciId }
                if (widget.size !== undefined) newWidget.size = widget.size
                widgets[widgetIndex] = newWidget
            }
        }
        if (sectionId === "left") SettingsData.setTopBarLeftWidgets(widgets)
        else if (sectionId === "center") SettingsData.setTopBarCenterWidgets(widgets)
        else if (sectionId === "right") SettingsData.setTopBarRightWidgets(widgets)
    }

    function handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value) {
        if (settingName === "showNetworkIcon") SettingsData.setControlCenterShowNetworkIcon(value)
        else if (settingName === "showBluetoothIcon") SettingsData.setControlCenterShowBluetoothIcon(value)
        else if (settingName === "showAudioIcon") SettingsData.setControlCenterShowAudioIcon(value)
        else if (settingName === "showMicIcon") SettingsData.setControlCenterShowMicIcon(value)
    }

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "left") widgetData = SettingsData.topBarLeftWidgets || []
        else if (sectionId === "center") widgetData = SettingsData.topBarCenterWidgets || []
        else if (sectionId === "right") widgetData = SettingsData.topBarRightWidgets || []

        widgetData.forEach(widget => {
            var widgetId = typeof widget === "string" ? widget : widget.id
            var widgetEnabled = typeof widget === "string" ? true : widget.enabled
            var widgetSize = typeof widget === "string" ? undefined : widget.size
            var widgetSelectedGpuIndex = typeof widget === "string" ? undefined : widget.selectedGpuIndex
            var widgetPciId = typeof widget === "string" ? undefined : widget.pciId
            var widgetShowNetworkIcon = typeof widget === "string" ? undefined : widget.showNetworkIcon
            var widgetShowBluetoothIcon = typeof widget === "string" ? undefined : widget.showBluetoothIcon
            var widgetShowAudioIcon = typeof widget === "string" ? undefined : widget.showAudioIcon
            var widgetDef = baseWidgetDefinitions.find(w => w.id === widgetId)
            if (widgetDef) {
                var item = Object.assign({}, widgetDef)
                item.enabled = widgetEnabled
                if (widgetSize !== undefined) item.size = widgetSize
                if (widgetSelectedGpuIndex !== undefined) item.selectedGpuIndex = widgetSelectedGpuIndex
                if (widgetPciId !== undefined) item.pciId = widgetPciId
                if (widgetShowNetworkIcon !== undefined) item.showNetworkIcon = widgetShowNetworkIcon
                if (widgetShowBluetoothIcon !== undefined) item.showBluetoothIcon = widgetShowBluetoothIcon
                if (widgetShowAudioIcon !== undefined) item.showAudioIcon = widgetShowAudioIcon
                widgets.push(item)
            }
        })
        return widgets
    }

    // ─── UI ─────────────────────────────────────────────────────────────────

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        anchors.bottomMargin: Theme.spacingS
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
                        text: "Show Top Bar"
                        description: "Toggle top bar visibility manually (can be controlled via IPC)"
                        checked: SettingsData.topBarVisible
                        onToggled: toggled => SettingsData.setTopBarVisible(toggled)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Auto-hide"
                        description: "Automatically hide the top bar to expand screen real estate"
                        checked: SettingsData.topBarAutoHide
                        onToggled: toggled => SettingsData.setTopBarAutoHide(toggled)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Show on Overview"
                        description: "Always show the top bar when niri's overview is open"
                        visible: CompositorService.isNiri
                        checked: SettingsData.topBarOpenOnOverview
                        onToggled: toggled => SettingsData.setTopBarOpenOnOverview(toggled)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Float Top Bar"
                        description: "Make the topbar float above other windows"
                        checked: SettingsData.topBarFloat
                        onToggled: checked => SettingsData.setTopBarFloat(checked)
                    }

                    EHDropdown {
                        width: parent.width
                        height: Theme.scaledHeight(50)
                        text: "Bar Position"
                        description: "Current: " + SettingsData.topBarPosition
                        currentValue: SettingsData.topBarPosition
                        options: ["top", "bottom", "left", "right"]
                        onValueChanged: value => {
                            if (value && value !== SettingsData.topBarPosition)
                                SettingsData.topBarPosition = value
                        }
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
                                        SettingsData.setTopBarLeftWidgets(defaultLeftWidgets)
                                        SettingsData.setTopBarCenterWidgets(defaultCenterWidgets)
                                        SettingsData.setTopBarRightWidgets(defaultRightWidgets)
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
                                        SettingsData.setTopBarLeftWidgets([])
                                        SettingsData.setTopBarCenterWidgets([])
                                        SettingsData.setTopBarRightWidgets([])
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
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Left / Center / Right widget sections
            Column {
                width: parent.width
                spacing: Theme.spacingL

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
                        title: "Left Section"
                        titleIcon: "format_align_left"
                        sectionId: "left"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("left")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => topBarTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => topBarTab.handleItemOrderChanged("left", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = topBarTab.baseWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => topBarTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => topBarTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onCompactModeChanged: (widgetId, value) => {
                            if (widgetId === "clock") SettingsData.setClockCompactMode(value)
                            else if (widgetId === "music") SettingsData.setMediaSize(value)
                            else if (widgetId === "focusedWindow") SettingsData.setFocusedWindowCompactMode(value)
                            else if (widgetId === "runningApps") SettingsData.setRunningAppsCompactMode(value)
                        }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => topBarTab.handleGpuSelectionChanged(sectionId, widgetIndex, selectedIndex)
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
                        title: "Center Section"
                        titleIcon: "format_align_center"
                        sectionId: "center"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("center")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => topBarTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => topBarTab.handleItemOrderChanged("center", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = topBarTab.baseWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => topBarTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => topBarTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onCompactModeChanged: (widgetId, value) => {
                            if (widgetId === "clock") SettingsData.setClockCompactMode(value)
                            else if (widgetId === "music") SettingsData.setMediaSize(value)
                            else if (widgetId === "focusedWindow") SettingsData.setFocusedWindowCompactMode(value)
                            else if (widgetId === "runningApps") SettingsData.setRunningAppsCompactMode(value)
                        }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => topBarTab.handleGpuSelectionChanged(sectionId, widgetIndex, selectedIndex)
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
                        title: "Right Section"
                        titleIcon: "format_align_right"
                        sectionId: "right"
                        allWidgets: topBarTab.baseWidgetDefinitions
                        items: topBarTab.getItemsForSection("right")
                        onItemEnabledChanged: (sectionId, itemId, enabled) => topBarTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => topBarTab.handleItemOrderChanged("right", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = topBarTab.baseWidgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => topBarTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onSpacerSizeChanged: (sectionId, widgetIndex, newSize) => topBarTab.handleSpacerSizeChanged(sectionId, widgetIndex, newSize)
                        onCompactModeChanged: (widgetId, value) => {
                            if (widgetId === "clock") SettingsData.setClockCompactMode(value)
                            else if (widgetId === "music") SettingsData.setMediaSize(value)
                            else if (widgetId === "focusedWindow") SettingsData.setFocusedWindowCompactMode(value)
                            else if (widgetId === "runningApps") SettingsData.setRunningAppsCompactMode(value)
                        }
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                        onGpuSelectionChanged: (sectionId, widgetIndex, selectedIndex) => topBarTab.handleGpuSelectionChanged(sectionId, widgetIndex, selectedIndex)
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 3: Style (Opacity + Appearance toggles + Border)
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

                    // Background Opacity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Background Opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(SettingsData.topBarTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopBarTransparency(newValue / 100)
                        }
                    }

                    // Appearance toggles
                    EHToggle {
                        width: parent.width
                        text: "Rounded Corners"
                        description: "Enable rounded corners for the topbar"
                        checked: SettingsData.topBarRoundedCorners
                        onToggled: checked => SettingsData.setTopBarRoundedCorners(checked)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SettingsData.topBarRoundedCorners
                        opacity: visible ? 1 : 0

                        StyledText {
                            text: "Corner Radius"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.topBarCornerRadius
                            minimum: 0
                            maximum: 50
                            unit: "px"
                            showValue: true
                            wheelEnabled: false
                            onSliderValueChanged: newValue => SettingsData.setTopBarCornerRadius(newValue)
                        }

                        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Square Corners"
                        description: "Removes rounded corners from bar container"
                        checked: SettingsData.topBarSquareCorners
                        onToggled: checked => SettingsData.setTopBarSquareCorners(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "No Background"
                        description: "Remove widget backgrounds for a minimal look with tighter spacing"
                        checked: SettingsData.topBarNoBackground
                        onToggled: checked => SettingsData.setTopBarNoBackground(checked)
                    }

                    EHToggle {
                        width: parent.width
                        text: "Goth Corners"
                        description: "Add curved swooping tips at the bottom of the bar"
                        checked: SettingsData.topBarGothCornersEnabled
                        onToggled: checked => SettingsData.setTopBarGothCornersEnabled(checked)
                    }

                    // Border
                    EHToggle {
                        width: parent.width
                        text: "Enable Border"
                        description: "Add a customizable border around the topbar"
                        checked: SettingsData.topBarBorderEnabled
                        onToggled: checked => SettingsData.setTopBarBorderEnabled(checked)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SettingsData.topBarBorderEnabled
                        opacity: visible ? 1 : 0

                        EHToggle {
                            width: parent.width
                            text: "Enable Dynamic Border Colors"
                            description: "Override user-set border colors with dynamic colors sourced from matugen"
                            checked: SettingsData.topBarDynamicBorderColors
                            onToggled: checked => SettingsData.setTopBarDynamicBorderColors(checked)
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
                                value: SettingsData.topBarBorderWidth
                                minimum: 1
                                maximum: 20
                                unit: "px"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => SettingsData.setTopBarBorderWidth(newValue)
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

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Red"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.topBarBorderRed * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setTopBarBorderRed(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Green"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.topBarBorderGreen * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setTopBarBorderGreen(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Blue"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.topBarBorderBlue * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setTopBarBorderBlue(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Alpha"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.topBarBorderAlpha * 100)
                                        minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setTopBarBorderAlpha(newValue / 100)
                                    }
                                }
                            }
                        }

                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                    }
                }
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
                            text: "Height"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topBarHeight
                            minimum: 10; maximum: 100; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopBarHeight(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Scale"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(SettingsData.topbarScale * 100)
                            minimum: 50; maximum: 150; unit: "%"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopbarScale(newValue / 100)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Size (Inner Padding)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topBarInnerPadding
                            minimum: 0; maximum: 24; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopBarInnerPadding(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Launcher Logo Size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topbarLauncherLogoSize
                            minimum: 8; maximum: 64; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopbarLauncherLogoSize(newValue)
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 5: Margins & Gaps
            // ─────────────────────────────────────────────────────────────
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: marginsSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: marginsSection
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
                            text: "Margins & Gaps"
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
                            text: "Top/Left/Right Gaps"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "0 = edge-to-edge"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topBarSpacing
                            minimum: 0; maximum: 32; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopBarSpacing(newValue)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Bottom Gap (Exclusive Zone)"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topBarBottomGap
                            minimum: -100; maximum: 100; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.topBarBottomGap = newValue
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Top Margin"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.topBarTopMargin
                            minimum: 0; maximum: 200; unit: "px"
                            showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setTopBarTopMargin(newValue)
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: (parent.width - Theme.spacingS) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Left Margin"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.topBarLeftMargin
                                minimum: 0; maximum: 200; unit: "px"
                                showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: newValue => SettingsData.setTopBarLeftMargin(newValue)
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingS) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Right Margin"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.topBarRightMargin
                                minimum: 0; maximum: 200; unit: "px"
                                showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: newValue => SettingsData.setTopBarRightMargin(newValue)
                            }
                        }
                    }
                }
            }

        }
    }

    WidgetSelectionPopup {
        id: widgetSelectionPopup
        onWidgetSelected: (widgetId, targetSection) => {
            topBarTab.addWidgetToSection(widgetId, targetSection)
        }
    }
}