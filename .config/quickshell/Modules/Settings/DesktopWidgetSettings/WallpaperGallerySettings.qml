import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.FileBrowser

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

    function getToggleValue(key, defaultValue) {
        if (cfg && cfg.hasOwnProperty(key)) return cfg[key]
        return defaultValue
    }

    function getValue(key, defaultValue) {
        if (cfg && cfg.hasOwnProperty(key)) return cfg[key]
        return defaultValue
    }

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    // ── Wallpaper Directory ───────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "folder_open"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Wallpaper Directory"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    Row {
        width: parent.width; spacing: Theme.spacingM

        StyledRect {
            width: 80; height: 80
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            border.width: 1

            Item {
                anchors.fill: parent; anchors.margins: 1
                EHIcon { anchors.centerIn: parent; name: "folder"; size: 32; color: Theme.surfaceVariantText }
                Rectangle {
                    anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.3)
                    visible: folderMouseArea.containsMouse
                    EHIcon { anchors.centerIn: parent; name: "edit"; size: 20; color: Theme.surfaceText }
                }
                MouseArea { id: folderMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperBrowser.open() }
            }
        }

        Column {
            width: parent.width - 80 - Theme.spacingM; spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: getValue("wallpaperDir", "") ? getValue("wallpaperDir", "").split('/').pop() : "No folder selected"
                font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium
                color: getValue("wallpaperDir", "") ? Theme.surfaceText : Theme.outline
                elide: Text.ElideMiddle; width: parent.width
            }
            StyledText {
                text: getValue("wallpaperDir", "") ? getValue("wallpaperDir", "") : "Click the folder icon to select a directory"
                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                elide: Text.ElideMiddle; width: parent.width; maximumLineCount: 1
            }
        }
    }

    // ── Display Options ───────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Display Options"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    EHToggle { width: parent.width; text: "Show Controls";       description: "Display folder browser and navigation controls";                                              checked: getToggleValue("showControls",  true);  onToggled: checked => root.updateConfig("showControls",  checked) }
    EHToggle { width: parent.width; text: "Show Filenames";      description: "Display wallpaper filenames on hover";                                                        checked: getToggleValue("showFileNames", true);  onToggled: checked => root.updateConfig("showFileNames", checked) }
    EHToggle { width: parent.width; text: "Use Wallpaper Colors"; description: "Tint the gallery border and selection using colors extracted from the current wallpaper";   checked: getToggleValue("wallpaperColors", false); onToggled: checked => root.updateConfig("wallpaperColors", checked) }

    // ── Grid Layout ───────────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "grid_view"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Grid Layout"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    Row {
        width: parent.width; spacing: Theme.spacingM

        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
            StyledText { text: "Columns"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
            EHDropdown { width: parent.width; model: [2, 3, 4, 5, 6, 7, 8]; currentValue: getValue("gridColumns", 4); onActivated: value => root.updateConfig("gridColumns", value) }
        }

        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
            StyledText { text: "Rows"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
            EHDropdown { width: parent.width; model: [2, 3, 4, 5, 6, 7, 8, 9, 10]; currentValue: getValue("gridRows", 3); onActivated: value => root.updateConfig("gridRows", value) }
        }
    }

    // ── Appearance ────────────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Appearance"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    Row {
        width: parent.width; spacing: Theme.spacingM

        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
            StyledText { text: "Font Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
            EHDropdown { width: parent.width; model: [8, 9, 10, 11, 12, 13, 14, 15, 16]; currentValue: getValue("fontSize", 12); onActivated: value => root.updateConfig("fontSize", value) }
        }

        Column { width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
            StyledText { text: "Padding"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
            EHDropdown { width: parent.width; model: [8, 12, 16, 20, 24, 28, 32]; currentValue: getValue("padding", 16); onActivated: value => root.updateConfig("padding", value) }
        }
    }

    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Spacing"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHDropdown { width: parent.width; model: [2, 3, 4, 5, 6, 7, 8, 9, 10]; currentValue: getValue("spacing", 4); onActivated: value => root.updateConfig("spacing", value) }
    }

    FileBrowserModal {
        id: wallpaperBrowser
        browserTitle: "Select Wallpaper Directory"; browserIcon: "folder_open"
        browserType: "wallpaper"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        selectFolderMode: true
        onFolderSelected: folderPath => {
            root.updateConfig("wallpaperDir", folderPath.replace(/^file:\/\//, ''))
            close()
        }
    }
}
