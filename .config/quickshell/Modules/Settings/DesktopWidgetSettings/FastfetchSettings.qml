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

    width: parent?.width ?? 400
    spacing: Theme.spacingM

    // ── Transparency ───────────────────────────────────────────────────
    Column { width: parent.width; spacing: Theme.spacingS
        StyledText { text: "Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
        EHSlider {
            width: parent.width; height: 24
            value: Math.round((root.getToggleValue("transparency", 0.92)) * 100)
            minimum: 0; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false
            thumbOutlineColor: Theme.surfaceContainer
            onSliderValueChanged: newValue => root.updateConfig("transparency", newValue / 100)
        }
    }

    // ── Wallpaper Colors ───────────────────────────────────────────────────────
    EHToggle {
        width: parent.width
        text: "Use Wallpaper Colors"
        description: "Color the background using colors extracted from the current wallpaper"
        checked: root.getToggleValue("wallpaperColors", false)
        onToggled: checked => root.updateConfig("wallpaperColors", checked)
    }

    // ── Display Fields ────────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "list"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Display Fields"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    StyledText {
        text: "Toggle which information fields to show in the Fastfetch widget"
        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
        width: parent.width; wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width; spacing: Theme.spacingS

        EHToggle { width: parent.width; text: "OS";                   description: "Show operating system name";       checked: root.getToggleValue("showOs",       true); onToggled: checked => root.updateConfig("showOs",       checked) }
        EHToggle { width: parent.width; text: "Host";                 description: "Show hostname";                    checked: root.getToggleValue("showHost",     true); onToggled: checked => root.updateConfig("showHost",     checked) }
        EHToggle { width: parent.width; text: "Kernel";               description: "Show kernel version";              checked: root.getToggleValue("showKernel",   true); onToggled: checked => root.updateConfig("showKernel",   checked) }
        EHToggle { width: parent.width; text: "Uptime";               description: "Show system uptime";               checked: root.getToggleValue("showUptime",   true); onToggled: checked => root.updateConfig("showUptime",   checked) }
        EHToggle { width: parent.width; text: "Packages";             description: "Show installed package count";     checked: root.getToggleValue("showPackages", true); onToggled: checked => root.updateConfig("showPackages", checked) }
        EHToggle { width: parent.width; text: "Shell";                description: "Show shell name and version";      checked: root.getToggleValue("showShell",    true); onToggled: checked => root.updateConfig("showShell",    checked) }
        EHToggle { width: parent.width; text: "Resolution";           description: "Show display resolution";          checked: root.getToggleValue("showRes",      true); onToggled: checked => root.updateConfig("showRes",      checked) }
        EHToggle { width: parent.width; text: "Desktop Environment";  description: "Show desktop environment name";    checked: root.getToggleValue("showDe",       true); onToggled: checked => root.updateConfig("showDe",       checked) }
        EHToggle { width: parent.width; text: "Window Manager";       description: "Show window manager name";         checked: root.getToggleValue("showWm",       true); onToggled: checked => root.updateConfig("showWm",       checked) }
        EHToggle { width: parent.width; text: "Theme";                description: "Show GTK theme name";              checked: root.getToggleValue("showTheme",    true); onToggled: checked => root.updateConfig("showTheme",    checked) }
        EHToggle { width: parent.width; text: "Icons";                description: "Show icon theme name";             checked: root.getToggleValue("showIcons",    true); onToggled: checked => root.updateConfig("showIcons",    checked) }
        EHToggle { width: parent.width; text: "Fonts";                description: "Show font name";                   checked: root.getToggleValue("showFonts",    true); onToggled: checked => root.updateConfig("showFonts",    checked) }
        EHToggle { width: parent.width; text: "CPU";                  description: "Show CPU model";                   checked: root.getToggleValue("showCpu",      true); onToggled: checked => root.updateConfig("showCpu",      checked) }
        EHToggle { width: parent.width; text: "GPU";                  description: "Show GPU model";                   checked: root.getToggleValue("showGpu",      true); onToggled: checked => root.updateConfig("showGpu",      checked) }
        EHToggle { width: parent.width; text: "Memory";               description: "Show memory usage";                checked: root.getToggleValue("showMemory",   true); onToggled: checked => root.updateConfig("showMemory",   checked) }
        EHToggle { width: parent.width; text: "Disk";                 description: "Show disk usage";                  checked: root.getToggleValue("showDisk",     true); onToggled: checked => root.updateConfig("showDisk",     checked) }
        EHToggle { width: parent.width; text: "Local IP";             description: "Show local IP address";            checked: root.getToggleValue("showLocalIp",  true); onToggled: checked => root.updateConfig("showLocalIp",  checked) }
    }

    // ── Custom Logo ───────────────────────────────────────────────────────
    Row {
        width: parent.width; spacing: Theme.spacingM
        EHIcon { name: "image"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: "Custom Logo"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
    }

    EHToggle {
        width: parent.width
        text: "Use Custom Logo"
        description: "Use a custom PNG image instead of the default OS logo"
        checked: root.getToggleValue("useCustomLogo", false)
        onToggled: checked => root.updateConfig("useCustomLogo", checked)
    }

    Column {
        width: parent.width; spacing: Theme.spacingM
        visible: root.getToggleValue("useCustomLogo", false)
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

        Rectangle {
            width: 120; height: 120
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            border.width: 1

            Item {
                anchors.fill: parent; anchors.margins: 1

                Image {
                    anchors.fill: parent
                    source: root.getToggleValue("customLogoPath", "") ? "file://" + root.getToggleValue("customLogoPath", "") : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                }

                Rectangle {
                    anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.3)
                    visible: logoImageMouseArea.containsMouse
                    Row {
                        anchors.centerIn: parent; spacing: Theme.spacingS
                        EHIcon { name: "edit"; size: 16; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Click to change"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                MouseArea { id: logoImageMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: logoBrowser.open() }
            }
        }

        Column { width: parent.width; spacing: Theme.spacingS
            StyledText {
                text: root.getToggleValue("customLogoPath", "") ? root.getToggleValue("customLogoPath", "").split('/').pop() : "No image selected"
                font.pixelSize: Theme.fontSizeSmall
                color: root.getToggleValue("customLogoPath", "") ? Theme.surfaceVariantText : Theme.outline
                elide: Text.ElideMiddle; width: parent.width
            }
            StyledText {
                text: "Click the preview or browse to select a PNG image file"
                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap; width: parent.width
            }
        }
    }

    FileBrowserModal {
        id: logoBrowser
        browserTitle: "Select Custom Logo"; browserIcon: "image"; browserType: "generic"
        fileExtensions: ["*.png"]
        onFileSelected: path => { root.updateConfig("customLogoPath", path); close() }
    }
}
