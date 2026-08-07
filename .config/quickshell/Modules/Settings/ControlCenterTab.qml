import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.Settings
import qs.Services

Item {
    id: controlCenterTab

    property var activeWidgets: SettingsData.controlCenterWidgets || []
    property var availableWidgetsList: []

    Component.onCompleted: {
        updateAvailableWidgets()
    }

    Connections {
        target: SettingsData
        function onControlCenterWidgetsChanged() { updateAvailableWidgets() }
    }

    function updateAvailableWidgets() {
        var existingIds = (SettingsData.controlCenterWidgets || []).map(w => w.id)
        var baseWidgets = [
            {"id": "nightMode",       "text": "Night Mode",     "description": "Blue light filter",             "icon": "nightlight"},
            {"id": "darkMode",        "text": "Dark Mode",      "description": "System theme toggle",           "icon": "contrast"},
            {"id": "doNotDisturb",    "text": "Do Not Disturb", "description": "Block notifications",           "icon": "do_not_disturb_on"},
            {"id": "idleInhibitor",   "text": "Keep Awake",     "description": "Prevent screen timeout",        "icon": "motion_sensor_active"},
            {"id": "wifi",            "text": "Network",        "description": "Wi-Fi and Ethernet connection", "icon": "wifi"},
            {"id": "bluetooth",       "text": "Bluetooth",      "description": "Device connections",            "icon": "bluetooth"},
            {"id": "audioOutput",     "text": "Audio Output",   "description": "Speaker settings",              "icon": "volume_up"},
            {"id": "audioInput",      "text": "Audio Input",    "description": "Microphone settings",           "icon": "mic"},
            {"id": "brightnessSlider","text": "Brightness",     "description": "Display brightness control",    "icon": "brightness_6"},
            {"id": "battery",         "text": "Battery",        "description": "Battery and power management",  "icon": "battery_std"},
            {"id": "performance",     "text": "Performance",    "description": "Power and performance modes",   "icon": "speed"},
            {"id": "volumeMixer",     "text": "Volume Mixer",   "description": "Per-application audio control", "icon": "volume_up"},
            {"id": "media",           "text": "Media",          "description": "Now playing and controls",      "icon": "music_note"},
            {"id": "hdrToggle",       "text": "HDR Toggle",     "description": "Toggle HDR display settings",   "icon": "hdr_off"},
            {"id": "weather",         "text": "Weather",        "description": "Weather information and forecast", "icon": "cloud"},
            {"id": "worldClocks",     "text": "World Clocks",   "description": "Multiple time zones at a glance", "icon": "schedule"}
        ]
        availableWidgetsList = baseWidgets.filter(w => !existingIds.includes(w.id))
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // ACTIVE WIDGETS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: activeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: activeSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Active Widgets"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Drag to reorder \u2022 Click \u00d7 to remove"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    // Empty state
                    StyledRect {
                        width: parent.width
                        height: 52
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1
                        visible: controlCenterTab.activeWidgets.length === 0

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            EHIcon { name: "inbox"; size: Theme.iconSize - 2; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "No active widgets \u2014 add some below"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // Active list
                    Column {
                        id: activeWidgetsList
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: controlCenterTab.activeWidgets.length > 0

                        Repeater {
                            model: controlCenterTab.activeWidgets

                            delegate: Item {
                                id: delegateItem
                                property bool held: dragArea.pressed
                                property real originalY: y

                                width: parent.width
                                height: 48
                                z: held ? 2 : 1

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: held
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                    border.color: held
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: held ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    // Drag handle
                                    Item {
                                        width: 24; height: parent.height

                                        EHIcon {
                                            name: "drag_indicator"
                                            size: 18
                                            color: dragArea.containsMouse ? Theme.primary : Theme.outline
                                            anchors.centerIn: parent
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        MouseArea {
                                            id: dragArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.SizeVerCursor
                                            drag.target: held ? delegateItem : undefined
                                            drag.axis: Drag.YAxis
                                            drag.minimumY: -delegateItem.height
                                            drag.maximumY: activeWidgetsList.height
                                            preventStealing: true
                                            onPressed: {
                                                delegateItem.z = 2
                                                delegateItem.originalY = delegateItem.y
                                            }
                                            onReleased: {
                                                delegateItem.z = 1
                                                if (drag.active) {
                                                    var newIndex = Math.round(delegateItem.y / (delegateItem.height + Theme.spacingS))
                                                    newIndex = Math.max(0, Math.min(newIndex, controlCenterTab.activeWidgets.length - 1))
                                                    if (newIndex !== index) {
                                                        var newWidgets = controlCenterTab.activeWidgets.slice()
                                                        var draggedItem = newWidgets.splice(index, 1)[0]
                                                        newWidgets.splice(newIndex, 0, draggedItem)
                                                        SettingsData.setControlCenterWidgets(newWidgets)
                                                    }
                                                }
                                                delegateItem.y = delegateItem.originalY
                                            }
                                        }
                                    }

                                    EHIcon {
                                        name: getWidgetIcon(modelData.id)
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: getWidgetName(modelData.id)
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 24 - Theme.iconSize - 32 - Theme.spacingM * 3
                                        elide: Text.ElideRight
                                    }

                                    // Remove button
                                    Item {
                                        width: 32; height: parent.height

                                        EHIcon {
                                            name: "close"
                                            size: 16
                                            color: removeHover.containsMouse ? Theme.error : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
                                            anchors.centerIn: parent
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }

                                        MouseArea {
                                            id: removeHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var widgets = (SettingsData.controlCenterWidgets || []).slice()
                                                var widgetId = modelData.id
                                                for (var i = 0; i < widgets.length; i++) {
                                                    if (widgets[i].id === widgetId) {
                                                        widgets.splice(i, 1)
                                                        SettingsData.setControlCenterWidgets(widgets)
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Actions row
                    Row {
                        width: parent.width
                        spacing: Theme.spacingL
                        topPadding: Theme.spacingXS

                        MouseArea {
                            width: resetRow.implicitWidth; height: resetRow.implicitHeight
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const defaultWidgets = [
                                    {"id": "wifi",        "enabled": true, "width": 50},
                                    {"id": "bluetooth",   "enabled": true, "width": 50},
                                    {"id": "audioOutput", "enabled": true, "width": 50},
                                    {"id": "audioInput",  "enabled": true, "width": 50},
                                    {"id": "volumeMixer", "enabled": true, "width": 100},
                                    {"id": "performance", "enabled": true, "width": 50},
                                    {"id": "darkMode",    "enabled": true, "width": 50}
                                ]
                                SettingsData.setControlCenterWidgets(defaultWidgets)
                            }
                            Row {
                                id: resetRow
                                spacing: Theme.spacingS
                                EHIcon { name: "restore"; size: Theme.iconSize - 4; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Reset to Defaults"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        MouseArea {
                            width: clearRow.implicitWidth; height: clearRow.implicitHeight
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SettingsData.setControlCenterWidgets([])
                            }
                            Row {
                                id: clearRow
                                spacing: Theme.spacingS
                                EHIcon { name: "delete_sweep"; size: Theme.iconSize - 4; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Clear All"; font.pixelSize: Theme.fontSizeSmall; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // AVAILABLE WIDGETS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: availableSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: controlCenterTab.availableWidgetsList.length > 0

                Column {
                    id: availableSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "add_circle"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Available Widgets"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Click to add to Control Center"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: controlCenterTab.availableWidgetsList

                            delegate: Item {
                                width: parent.width
                                height: 52

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: addHover.containsMouse
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                    border.color: addHover.containsMouse
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Behavior on border.color { ColorAnimation { duration: 80 } }
                                }

                                MouseArea {
                                    id: addHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controlCenterTab.addWidget(modelData.id)
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    EHIcon {
                                        name: modelData.icon || "widgets"
                                        size: Theme.iconSize
                                        color: addHover.containsMouse ? Theme.primary : Theme.outline
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.iconSize - 24 - Theme.spacingM * 3
                                        spacing: 2

                                        StyledText {
                                            text: modelData.text || modelData.id
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                        }
                                        StyledText {
                                            text: modelData.description || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            visible: (modelData.description || "").length > 0
                                        }
                                    }

                                    EHIcon {
                                        name: "add"
                                        size: 18
                                        color: addHover.containsMouse
                                            ? Theme.primary
                                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function getWidgetName(widgetId) {
        var names = {
            "nightMode":       "Night Mode",
            "darkMode":        "Dark Mode",
            "doNotDisturb":    "Do Not Disturb",
            "idleInhibitor":   "Keep Awake",
            "wifi":            "Network",
            "bluetooth":       "Bluetooth",
            "audioOutput":     "Audio Output",
            "audioInput":      "Audio Input",
            "brightnessSlider":"Brightness",
            "battery":         "Battery",
            "performance":     "Performance",
            "volumeMixer":     "Volume Mixer",
            "media":           "Media",
            "hdrToggle":       "HDR Toggle",
            "weather":         "Weather",
            "worldClocks":     "World Clocks"
        }
        return names[widgetId] || widgetId
    }

    function getWidgetIcon(widgetId) {
        var icons = {
            "nightMode":       "nightlight",
            "darkMode":        "contrast",
            "doNotDisturb":    "do_not_disturb_on",
            "idleInhibitor":   "motion_sensor_active",
            "wifi":            "wifi",
            "bluetooth":       "bluetooth",
            "audioOutput":     "volume_up",
            "audioInput":      "mic",
            "brightnessSlider":"brightness_6",
            "battery":         "battery_std",
            "performance":     "speed",
            "volumeMixer":     "volume_up",
            "media":           "music_note",
            "hdrToggle":       "hdr_off",
            "weather":         "cloud",
            "worldClocks":     "schedule"
        }
        return icons[widgetId] || "widgets"
    }

    function addWidget(widgetId) {
        var widgets = (SettingsData.controlCenterWidgets || []).slice()
        var defaultWidth = (widgetId === "volumeMixer" || widgetId === "media" || widgetId === "weather" || widgetId === "worldClocks") ? 100 : 50
        widgets.push({"id": widgetId, "enabled": true, "width": defaultWidth})
        SettingsData.setControlCenterWidgets(widgets)
        updateAvailableWidgets()
    }

    function getAvailableWidgets() {
        return availableWidgetsList
    }
}
