function getWidgetForId(baseWidgetDefinitions, widgetId) {
    return baseWidgetDefinitions.find(w => w.id === widgetId)
}

function addWidget(widgetId) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    // Volume mixer and media should always take full width (100 = full row = both left and right spots)
    var defaultWidth = (widgetId === "volumeMixer" || widgetId === "media") ? 100 : 50
    var widget = {
        "id": widgetId,
        "enabled": true,
        "width": defaultWidth
    }
    widgets.push(widget)
    SettingsData.setControlCenterWidgets(widgets)
}

function removeWidget(index) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    if (index >= 0 && index < widgets.length) {
        widgets.splice(index, 1)
        SettingsData.setControlCenterWidgets(widgets)
    }
}

function toggleWidgetSize(index) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    if (index >= 0 && index < widgets.length) {
        const currentWidth = widgets[index].width || 50
        const id = widgets[index].id || ""

        // Volume mixer and media always stay at full width (100 = both left and right spots)
        if (id === "volumeMixer" || id === "media") {
            widgets[index].width = 100
        } else if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput") {
            widgets[index].width = currentWidth <= 50 ? 100 : 50
        } else {
            if (currentWidth <= 25) {
                widgets[index].width = 50
            } else if (currentWidth <= 50) {
                widgets[index].width = 100
            } else {
                widgets[index].width = 25
            }
        }

        SettingsData.setControlCenterWidgets(widgets)
    }
}

function reorderWidgets(newOrder) {
    SettingsData.setControlCenterWidgets(newOrder)
}

function moveWidget(fromIndex, toIndex) {
    let widgets = [...(SettingsData.controlCenterWidgets || [])]
    if (fromIndex >= 0 && fromIndex < widgets.length && toIndex >= 0 && toIndex < widgets.length) {
        const movedWidget = widgets.splice(fromIndex, 1)[0]
        widgets.splice(toIndex, 0, movedWidget)
        SettingsData.setControlCenterWidgets(widgets)
    }
}

function resetToDefault() {
    const defaultWidgets = [
        {"id": "wifi", "enabled": true, "width": 50},
        {"id": "bluetooth", "enabled": true, "width": 50},
        {"id": "audioOutput", "enabled": true, "width": 50},
        {"id": "audioInput", "enabled": true, "width": 50},
        {"id": "volumeMixer", "enabled": true, "width": 100},
        {"id": "performance", "enabled": true, "width": 50},
        {"id": "darkMode", "enabled": true, "width": 50}
    ]
    SettingsData.setControlCenterWidgets(defaultWidgets)
}

function clearAll() {
    SettingsData.setControlCenterWidgets([])
}

function ensureVolumeMixerWidth() {
    var widgets = SettingsData.controlCenterWidgets.slice()
    var updated = false
    for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id === "volumeMixer" && widgets[i].width !== 100) {
            widgets[i].width = 100
            updated = true
        }
    }
    if (updated) {
        SettingsData.setControlCenterWidgets(widgets)
    }
}