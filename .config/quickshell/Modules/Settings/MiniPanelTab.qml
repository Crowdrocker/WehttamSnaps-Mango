import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Settings

Item {
    id: miniPanelTab

    // Default widget configurations
    property var defaultLeftWidgets: ["launcherButton", "workspaceSwitcher", "windowPreview"]
    property var defaultCenterWidgets: ["music"]
    property var defaultRightWidgets: ["systemTray", "clock", "notificationButton", "controlCenterButton"]

    // Widget definitions - IDs must match MiniPanelWidgets.qml widgetMap keys
    property var widgetDefinitions: [{
            "id": "launcherButton",
            "text": "App Launcher",
            "description": "Quick access to application launcher",
            "icon": "apps",
            "enabled": true
        }, {
            "id": "spacer",
            "text": "Spacer",
            "description": "Empty space widget with adjustable width",
            "icon": "space_bar",
            "enabled": true,
            "hasSettings": true
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
            "id": "music",
            "text": "Media Controls",
            "description": "Control currently playing media",
            "icon": "music_note",
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
            "id": "systemTray",
            "text": "System Tray",
            "description": "System tray icons and indicators",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "cpuUsage",
            "text": "CPU Usage",
            "description": "CPU usage indicator",
            "icon": "memory",
            "enabled": true
        }, {
            "id": "memUsage",
            "text": "Memory Usage",
            "description": "Memory usage indicator",
            "icon": "storage",
            "enabled": true
        }, {
            "id": "notificationButton",
            "text": "Notifications",
            "description": "Notification center button",
            "icon": "notifications",
            "enabled": true
        }, {
            "id": "battery",
            "text": "Battery",
            "description": "Battery status indicator",
            "icon": "battery_full",
            "enabled": true
        }, {
            "id": "controlCenterButton",
            "text": "Control Center",
            "description": "Quick settings panel button",
            "icon": "tune",
            "enabled": true
        }, {
            "id": "systemUpdate",
            "text": "System Update",
            "description": "System update indicator",
            "icon": "system_update",
            "enabled": true
        }, {
            "id": "volumeMixer",
            "text": "Volume Mixer",
            "description": "Quick access to volume controls",
            "icon": "volume_up",
            "enabled": true
        }, {
            "id": "vpn",
            "text": "VPN",
            "description": "VPN connection status",
            "icon": "vpn_lock",
            "enabled": true
        }, {
            "id": "gpuTemp",
            "text": "GPU Temperature",
            "description": "GPU temperature monitor",
            "icon": "device_thermostat",
            "enabled": true
        }, {
            "id": "cpuTemp",
            "text": "CPU Temperature",
            "description": "CPU temperature monitor",
            "icon": "thermostat",
            "enabled": true
        }, {
            "id": "networkSpeed",
            "text": "Network Speed",
            "description": "Network activity monitor",
            "icon": "network_check",
            "enabled": true
        }, {
            "id": "mediaDisplay",
            "text": "Media Display",
            "description": "Now playing display",
            "icon": "play_circle",
            "enabled": true
        }, {
            "id": "applications",
            "text": "Applications",
            "description": "Application grid button",
            "icon": "grid_view",
            "enabled": true
        }, {
            "id": "colorPicker",
            "text": "Color Picker",
            "description": "Screen color picker tool",
            "icon": "palette",
            "enabled": true
        }, {
            "id": "idleInhibitor",
            "text": "Idle Inhibitor",
            "description": "Prevent screen sleep",
            "icon": "bedtime_off",
            "enabled": true
        }, {
            "id": "keyboardLayout",
            "text": "Keyboard Layout",
            "description": "Keyboard layout indicator",
            "icon": "keyboard",
            "enabled": true
        }, {
            "id": "notepadButton",
            "text": "Notepad",
            "description": "Quick notes button",
            "icon": "note",
            "enabled": true
        }, {
            "id": "privacyIndicator",
            "text": "Privacy Indicator",
            "description": "Privacy indicator for camera/mic",
            "icon": "visibility",
            "enabled": true
        }, {
            "id": "runningApps",
            "text": "Running Apps",
            "description": "Running applications indicator",
            "icon": "view_carousel",
            "enabled": true
        }, {
            "id": "darkDash",
            "text": "Dark Dash",
            "description": "Dark mode toggle",
            "icon": "dark_mode",
            "enabled": true
        }, {
            "id": "audioVisualization",
            "text": "Audio Visualization",
            "description": "Audio visualizer",
            "icon": "graphic_eq",
            "enabled": true
        }, {
            "id": "pinnedApps",
            "text": "Pinned Apps",
            "description": "Pinned application shortcuts",
            "icon": "push_pin",
            "enabled": true
        }]

    // Initialization is handled in SettingsData.parseSettings() and shell.qml

    // ─── Helper functions ───────────────────────────────────────────────────

    function addWidgetToSection(widgetId, targetSection) {
        var widgetObj = { "id": widgetId, "enabled": true }
        var widgets = []
        if (targetSection === "miniPanelLeft") {
            widgets = SettingsData.miniPanelLeftWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.miniPanelLeftWidgets = widgets
        } else if (targetSection === "miniPanelCenter") {
            widgets = SettingsData.miniPanelCenterWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.miniPanelCenterWidgets = widgets
        } else if (targetSection === "miniPanelRight") {
            widgets = SettingsData.miniPanelRightWidgets.slice()
            widgets.push(widgetObj)
            SettingsData.miniPanelRightWidgets = widgets
        }
        SettingsData.saveSettings()
    }

    function removeWidgetFromSection(sectionId, widgetIndex) {
        var widgets = []
        if (sectionId === "miniPanelLeft") {
            widgets = SettingsData.miniPanelLeftWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.miniPanelLeftWidgets = widgets
            }
        } else if (sectionId === "miniPanelCenter") {
            widgets = SettingsData.miniPanelCenterWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.miniPanelCenterWidgets = widgets
            }
        } else if (sectionId === "miniPanelRight") {
            widgets = SettingsData.miniPanelRightWidgets.slice()
            if (widgetIndex >= 0 && widgetIndex < widgets.length) {
                widgets.splice(widgetIndex, 1)
                SettingsData.miniPanelRightWidgets = widgets
            }
        }
        SettingsData.saveSettings()
    }

    function handleItemEnabledChanged(sectionId, itemId, enabled) {
        var widgets = []
        if (sectionId === "miniPanelLeft")
            widgets = SettingsData.miniPanelLeftWidgets.slice()
        else if (sectionId === "miniPanelCenter")
            widgets = SettingsData.miniPanelCenterWidgets.slice()
        else if (sectionId === "miniPanelRight")
            widgets = SettingsData.miniPanelRightWidgets.slice()

        for (var i = 0; i < widgets.length; i++) {
            var widget = widgets[i]
            var widgetId = typeof widget === "string" ? widget : widget.id
            if (widgetId === itemId) {
                widgets[i] = { "id": widgetId, "enabled": enabled }
                break
            }
        }

        if (sectionId === "miniPanelLeft")
            SettingsData.miniPanelLeftWidgets = widgets
        else if (sectionId === "miniPanelCenter")
            SettingsData.miniPanelCenterWidgets = widgets
        else if (sectionId === "miniPanelRight")
            SettingsData.miniPanelRightWidgets = widgets
        SettingsData.saveSettings()
    }

    function handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value) {
        if (settingName === "showNetworkIcon") SettingsData.setControlCenterShowNetworkIcon(value)
        else if (settingName === "showBluetoothIcon") SettingsData.setControlCenterShowBluetoothIcon(value)
        else if (settingName === "showAudioIcon") SettingsData.setControlCenterShowAudioIcon(value)
        else if (settingName === "showMicIcon") SettingsData.setControlCenterShowMicIcon(value)
    }

    function handleItemOrderChanged(sectionId, newOrder) {
        if (sectionId === "miniPanelLeft")
            SettingsData.miniPanelLeftWidgets = newOrder
        else if (sectionId === "miniPanelCenter")
            SettingsData.miniPanelCenterWidgets = newOrder
        else if (sectionId === "miniPanelRight")
            SettingsData.miniPanelRightWidgets = newOrder
        SettingsData.saveSettings()
    }

    function getItemsForSection(sectionId) {
        var widgets = []
        var widgetData = []
        if (sectionId === "miniPanelLeft")
            widgetData = SettingsData.miniPanelLeftWidgets || []
        else if (sectionId === "miniPanelCenter")
            widgetData = SettingsData.miniPanelCenterWidgets || []
        else if (sectionId === "miniPanelRight")
            widgetData = SettingsData.miniPanelRightWidgets || []

        widgetData.forEach(widget => {
            var widgetId = typeof widget === "string" ? widget : widget.id
            var widgetDef = widgetDefinitions.find(def => def.id === widgetId)
            if (widgetDef) {
                widgets.push({
                    "id": widgetId,
                    "text": widgetDef.text,
                    "description": widgetDef.description,
                    "icon": widgetDef.icon,
                    "enabled": typeof widget === "string" ? true : widget.enabled
                })
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
                        text: "Show Mini Panel"
                        description: "Display a compact panel at the top of the screen"
                        checked: SettingsData.showMiniPanel
                        onToggled: checked => {
                            SettingsData.showMiniPanel = checked
                            SettingsData.saveSettings()
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Autohide"
                        description: "Automatically hide the panel when not in use"
                        checked: SettingsData.miniPanelAutohide
                        enabled: SettingsData.showMiniPanel
                        onToggled: checked => {
                            SettingsData.miniPanelAutohide = checked
                            SettingsData.saveSettings()
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
                visible: SettingsData.showMiniPanel
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
                                        SettingsData.miniPanelLeftWidgets = defaultLeftWidgets
                                        SettingsData.miniPanelCenterWidgets = defaultCenterWidgets
                                        SettingsData.miniPanelRightWidgets = defaultRightWidgets
                                        SettingsData.saveSettings()
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
                                        SettingsData.miniPanelLeftWidgets = []
                                        SettingsData.miniPanelCenterWidgets = []
                                        SettingsData.miniPanelRightWidgets = []
                                        SettingsData.saveSettings()
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
                visible: SettingsData.showMiniPanel
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
                        sectionId: "miniPanelLeft"
                        items: miniPanelTab.getItemsForSection("miniPanelLeft")
                        allWidgets: miniPanelTab.widgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => miniPanelTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => miniPanelTab.handleItemOrderChanged("miniPanelLeft", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = miniPanelTab.widgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => miniPanelTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => miniPanelTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
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
                        sectionId: "miniPanelCenter"
                        items: miniPanelTab.getItemsForSection("miniPanelCenter")
                        allWidgets: miniPanelTab.widgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => miniPanelTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => miniPanelTab.handleItemOrderChanged("miniPanelCenter", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = miniPanelTab.widgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => miniPanelTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => miniPanelTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
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
                        sectionId: "miniPanelRight"
                        items: miniPanelTab.getItemsForSection("miniPanelRight")
                        allWidgets: miniPanelTab.widgetDefinitions
                        onItemEnabledChanged: (sectionId, itemId, enabled) => miniPanelTab.handleItemEnabledChanged(sectionId, itemId, enabled)
                        onItemOrderChanged: newOrder => miniPanelTab.handleItemOrderChanged("miniPanelRight", newOrder)
                        onAddWidget: sectionId => {
                            widgetSelectionPopup.allWidgets = miniPanelTab.widgetDefinitions
                            widgetSelectionPopup.targetSection = sectionId
                            widgetSelectionPopup.safeOpen()
                        }
                        onRemoveWidget: (sectionId, widgetIndex) => miniPanelTab.removeWidgetFromSection(sectionId, widgetIndex)
                        onControlCenterSettingChanged: (sectionId, widgetIndex, settingName, value) => miniPanelTab.handleControlCenterSettingChanged(sectionId, widgetIndex, settingName, value)
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 3: Style (Opacity + Border)
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
                visible: SettingsData.showMiniPanel
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

                    // Panel Opacity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Panel Opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelOpacity * 100
                            minimum: 10
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelOpacity = newValue / 100
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Border Size
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border Size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Row {
                            width: parent.width
                            height: 24
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.max(0, SettingsData.miniPanelBorderWidth - 1)
                                        SettingsData.miniPanelBorderWidth = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "remove"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }

                            EHSlider {
                                width: parent.width - 56
                                height: 24
                                value: SettingsData.miniPanelBorderWidth
                                minimum: 0
                                maximum: 10
                                unit: "px"
                                showValue: true
                                wheelEnabled: true
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: newValue => {
                                    SettingsData.miniPanelBorderWidth = newValue
                                    SettingsData.saveSettings()
                                }
                            }

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.min(10, SettingsData.miniPanelBorderWidth + 1)
                                        SettingsData.miniPanelBorderWidth = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "add"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }
                        }
                    }

                    // Border Opacity
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Border Opacity"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelBorderOpacity * 100
                            minimum: 0
                            maximum: 100
                            unit: "%"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelBorderOpacity = newValue / 100
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Border toggle
                    EHToggle {
                        width: parent.width
                        text: "Enable Border"
                        description: "Add a customizable border around the mini panel"
                        checked: SettingsData.miniPanelBorderEnabled
                        onToggled: checked => SettingsData.setMiniPanelBorderEnabled(checked)
                    }

                    // Border sub-options — shown only when border is enabled
                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SettingsData.miniPanelBorderEnabled
                        opacity: visible ? 1 : 0

                        EHToggle {
                            width: parent.width
                            text: "Enable Dynamic Border Colors"
                            description: "Override user-set border colors with dynamic colors sourced from matugen"
                            checked: SettingsData.miniPanelDynamicBorderColors
                            onToggled: checked => SettingsData.setMiniPanelDynamicBorderColors(checked)
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
                                value: SettingsData.miniPanelBorderWidth
                                minimum: 1
                                maximum: 20
                                unit: "px"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderWidth(newValue)
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
                                value: Math.round(SettingsData.miniPanelBorderRadius)
                                minimum: 0
                                maximum: 50
                                unit: "px"
                                showValue: true
                                wheelEnabled: false
                                onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderRadius(newValue)
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

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                visible: !SettingsData.miniPanelDynamicBorderColors
                                opacity: visible ? 1 : 0

                                StyledText { text: "Hue"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                                EHSlider {
                                    width: parent.width; height: 24
                                    value: SettingsData.miniPanelBorderHue
                                    minimum: 0; maximum: 360; unit: "°"; showValue: true; wheelEnabled: false
                                    onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderHue(newValue)
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
                                        value: Math.round(SettingsData.miniPanelBorderRed * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderRed(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Green"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.miniPanelBorderGreen * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderGreen(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Blue"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.miniPanelBorderBlue * 255)
                                        minimum: 0; maximum: 255; unit: ""; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderBlue(newValue / 255)
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    spacing: Theme.spacingS
                                    StyledText { text: "Alpha"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    EHSlider {
                                        width: parent.width; height: 24
                                        value: Math.round(SettingsData.miniPanelBorderAlpha * 100)
                                        minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
                                        onSliderValueChanged: newValue => SettingsData.setMiniPanelBorderAlpha(newValue / 100)
                                    }
                                }
                            }
                        }

                        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                    }

                    // Pinned Apps Icon Size
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Pinned Apps Icon Size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelPinnedAppsIconSize
                            minimum: 16
                            maximum: 48
                            unit: "px"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelPinnedAppsIconSize = newValue
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Pinned Apps Icon Spacing
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Pinned Apps Icon Spacing"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelPinnedAppsIconSpacing
                            minimum: 0
                            maximum: 16
                            unit: "px"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelPinnedAppsIconSpacing = newValue
                                SettingsData.saveSettings()
                            }
                        }
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
                visible: SettingsData.showMiniPanel
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

                    // Panel Height
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Panel Height"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelHeight
                            minimum: 32
                            maximum: 80
                            unit: "px"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelHeight = newValue
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Panel Scale
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Panel Scale"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelScale * 100
                            minimum: 50
                            maximum: 200
                            unit: "%"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelScale = newValue / 100
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Spacer Width
                    Column {
                        id: spacerWidthSection
                        width: parent.width
                        spacing: Theme.spacingS

                        Component.onCompleted: updateSpacerVisibility()

                        function updateSpacerVisibility() {
                            spacerWidthSection.visible = true
                        }

                        Connections {
                            target: SettingsData
                            function onMiniPanelLeftWidgetsChanged()  { spacerWidthSection.updateSpacerVisibility() }
                            function onMiniPanelCenterWidgetsChanged(){ spacerWidthSection.updateSpacerVisibility() }
                            function onMiniPanelRightWidgetsChanged() { spacerWidthSection.updateSpacerVisibility() }
                        }

                        StyledText {
                            text: "Spacer Width"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Row {
                            width: parent.width
                            height: 24
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.max(0, SettingsData.miniPanelSpacerWidth - 4)
                                        SettingsData.miniPanelSpacerWidth = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "remove"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }

                            EHSlider {
                                width: parent.width - 56
                                height: 24
                                value: SettingsData.miniPanelSpacerWidth
                                minimum: 0
                                maximum: 1000
                                unit: "px"
                                showValue: true
                                wheelEnabled: true
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: newValue => {
                                    SettingsData.miniPanelSpacerWidth = newValue
                                    SettingsData.saveSettings()
                                }
                            }

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.min(100, SettingsData.miniPanelSpacerWidth + 4)
                                        SettingsData.miniPanelSpacerWidth = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "add"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }
                        }
                    }
                }

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            }

            // ─────────────────────────────────────────────────────────────
            // CATEGORY 5: Advanced
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
                visible: SettingsData.showMiniPanel
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

                    // Exclusive Gap
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Exclusive Gap"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "Space between panel and screen edge"
                            font.pixelSize: Theme.fontSizeXSmall || Math.max(10, Theme.fontSizeSmall - 2)
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.miniPanelExclusiveGap
                            minimum: 0
                            maximum: 50
                            unit: "px"
                            showValue: true
                            wheelEnabled: true
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.miniPanelExclusiveGap = newValue
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Exclusive Zone Bottom
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Exclusive Zone Bottom"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: "Reserved space below the panel"
                            font.pixelSize: Theme.fontSizeXSmall || Math.max(10, Theme.fontSizeSmall - 2)
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            width: parent.width
                            height: 24
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.max(0, SettingsData.miniPanelExclusiveZone - 4)
                                        SettingsData.miniPanelExclusiveZone = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "remove"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }

                            EHSlider {
                                width: parent.width - 56
                                height: 24
                                value: SettingsData.miniPanelExclusiveZone
                                minimum: 0
                                maximum: 200
                                unit: "px"
                                showValue: true
                                wheelEnabled: true
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: newValue => {
                                    SettingsData.miniPanelExclusiveZone = newValue
                                    SettingsData.saveSettings()
                                }
                            }

                            Rectangle {
                                width: 24; height: 24; radius: 4
                                color: Theme.surfaceVariant
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var newVal = Math.min(200, SettingsData.miniPanelExclusiveZone + 4)
                                        SettingsData.miniPanelExclusiveZone = newVal
                                        SettingsData.saveSettings()
                                    }
                                }
                                EHIcon { name: "add"; size: 16; color: Theme.surfaceText; anchors.centerIn: parent }
                            }
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
            miniPanelTab.addWidgetToSection(widgetId, targetSection)
        }
    }
}