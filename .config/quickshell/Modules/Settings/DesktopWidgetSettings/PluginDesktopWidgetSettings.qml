import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property string widgetType: ""
    property var widgetDef: null

    readonly property var cfg: instanceData?.config ?? {}

    function updateConfig(key, value) {
        if (!instanceId) return
        var updates = {}
        updates[key] = value
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates)
    }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    EHToggle {
        width: parent.width
        text: "Enable Tint Animation"
        description: "Enable the animated tint effect on Event Horizon"
        checked: SettingsData.darkDashTintAnimateEnabled
        visible: root.widgetType === "desktopEventHorizon" || root.widgetType === "desktopDarkDash"
        onToggled: checked => SettingsData.setDarkDashTintAnimateEnabled(checked)
    }
}
