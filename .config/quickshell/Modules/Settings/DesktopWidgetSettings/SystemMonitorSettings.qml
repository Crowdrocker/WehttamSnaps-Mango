import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null

    readonly property var cfg: instanceData?.config ?? {}

    function updateConfig(key, value) {
        if (!instanceId) return
        var updates = {}
        updates[key] = value
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates)
    }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Custom CPU Name"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        StyledText { text: "Override auto-detected CPU name"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
        EHTextField {
            width: parent.width; height: 40
            placeholderText: "Leave empty for auto-detection"
            text: SettingsData.desktopSystemMonitorCustomCpuName || ""
            onTextChanged: SettingsData.setDesktopSystemMonitorCustomCpuName(text)
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Custom GPU Name"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        StyledText { text: "Override auto-detected GPU name"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
        EHTextField {
            width: parent.width; height: 40
            placeholderText: "Leave empty for auto-detection"
            text: SettingsData.desktopSystemMonitorCustomGpuName || ""
            onTextChanged: SettingsData.setDesktopSystemMonitorCustomGpuName(text)
        }
    }
}
