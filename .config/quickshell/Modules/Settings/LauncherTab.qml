import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modals.FileBrowser
import qs.Services

Item {
    id: recentAppsTab

    Component.onCompleted: {
        if (SettingsData.launcherLogoAutoSync) {
            SettingsData.syncLauncherLogoWithWallpaper()
        }
    }

    Connections {
        target: Theme
        function onColorUpdateTriggerChanged() {
            if (SettingsData.launcherLogoAutoSync) {
                Qt.callLater(() => { SettingsData.syncLauncherLogoWithWallpaper() })
            }
        }
    }

    Connections {
        target: SettingsData
        function onLauncherLogoAutoSyncChanged() {
            if (SettingsData.launcherLogoAutoSync) {
                SettingsData.syncLauncherLogoWithWallpaper()
            }
        }
    }

    Connections {
        target: ColorPaletteService
        function onColorsExtracted() {
            if (SettingsData.launcherLogoAutoSync) {
                Qt.callLater(() => { SettingsData.syncLauncherLogoWithWallpaper() })
            }
        }
    }

    Connections {
        target: typeof SessionData !== "undefined" ? SessionData : null
        function onWallpaperPathChanged() {
            if (SettingsData.launcherLogoAutoSync) {
                Qt.callLater(() => { Qt.callLater(() => { SettingsData.syncLauncherLogoWithWallpaper() }) })
            }
        }
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
            // LAUNCH PREFIX
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: launchPrefixSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: launchPrefixSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "terminal"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Launch Prefix"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        width: parent.width
                        text: "Add a custom prefix to all application launches. Useful for wrappers like 'uwsm-app' or 'systemd-run'."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    EHTextField {
                        width: parent.width
                        text: SessionData.launchPrefix
                        placeholderText: "Enter launch prefix (e.g., 'uwsm-app')"
                        onTextEdited: SessionData.setLaunchPrefix(text)
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // LAUNCHER BUTTON
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: launcherButtonSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: launcherButtonSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "apps"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Launcher Button"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Logo Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value: SettingsData.launcherLogoSize
                            minimum: 0; maximum: 64; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setLauncherLogoSize(newValue)
                        }
                    }

                    // Logo Color — hue slider + auto sync toggle
                    Column {
                        width: parent.width; spacing: Theme.spacingS

                        Row {
                            width: parent.width; spacing: Theme.spacingM

                            Column {
                                width: parent.width - autoSyncToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText { text: "Logo Color"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText {
                                    text: SettingsData.launcherLogoAutoSync ? "Automatically syncing with wallpaper colors" : "Manual hue control"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            EHToggle {
                                id: autoSyncToggle
                                anchors.verticalCenter: parent.verticalCenter
                                checked: SettingsData.launcherLogoAutoSync
                                onToggled: checked => {
                                    SettingsData.setLauncherLogoAutoSync(checked)
                                    if (checked) SettingsData.syncLauncherLogoWithWallpaper()
                                }
                            }
                        }

                        // Hue wheel strip
                        Rectangle {
                            width: parent.width; height: 10; radius: 5
                            opacity: SettingsData.launcherLogoAutoSync ? 0.25 : 0.5
                            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.000; color: "#ff0000" }
                                GradientStop { position: 0.167; color: "#ffff00" }
                                GradientStop { position: 0.333; color: "#00ff00" }
                                GradientStop { position: 0.500; color: "#00ffff" }
                                GradientStop { position: 0.667; color: "#0000ff" }
                                GradientStop { position: 0.833; color: "#ff00ff" }
                                GradientStop { position: 1.000; color: "#ff0000" }
                            }
                        }

                        EHSlider {
                            width: parent.width; height: 24
                            enabled: !SettingsData.launcherLogoAutoSync
                            opacity: enabled ? 1 : 0.4
                            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                            // Map RGB → hue (0–360) for display; write back as RGB
                            value: {
                                var r = SettingsData.launcherLogoRed
                                var g = SettingsData.launcherLogoGreen
                                var b = SettingsData.launcherLogoBlue
                                var max = Math.max(r, g, b), min = Math.min(r, g, b)
                                if (max === min) return 0
                                var d = max - min, h
                                if      (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
                                else if (max === g) h = ((b - r) / d + 2) / 6
                                else                h = ((r - g) / d + 4) / 6
                                return Math.round(h * 360)
                            }
                            minimum: 0; maximum: 360; unit: "°"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                if (SettingsData.launcherLogoAutoSync) return
                                // Convert hue → RGB (full saturation & value)
                                var h = newValue / 360
                                var i = Math.floor(h * 6)
                                var f = h * 6 - i
                                var q = 1 - f
                                var r, g, b
                                switch (i % 6) {
                                    case 0: r=1; g=f; b=0; break
                                    case 1: r=q; g=1; b=0; break
                                    case 2: r=0; g=1; b=f; break
                                    case 3: r=0; g=q; b=1; break
                                    case 4: r=f; g=0; b=1; break
                                    case 5: r=1; g=0; b=q; break
                                }
                                SettingsData.setLauncherLogoRed(r)
                                SettingsData.setLauncherLogoGreen(g)
                                SettingsData.setLauncherLogoBlue(b)
                            }
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Use OS Logo"
                        description: "Display operating system logo instead of apps icon"
                        checked: SettingsData.useOSLogo && !SettingsData.useCustomLauncherImage
                        onToggled: checked => {
                            if (checked) SettingsData.setUseCustomLauncherImage(false)
                            SettingsData.setUseOSLogo(checked)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SettingsData.useOSLogo
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

                        EHToggle {
                            width: parent.width
                            text: "Sync with Wallpaper"
                            description: "Automatically apply wallpaper color to the OS logo"
                            checked: SettingsData.osLogoAutoSync
                            onToggled: checked => {
                                SettingsData.setOSLogoAutoSync(checked)
                                // Clear color override when disabling sync to prevent stale colors
                                if (!checked) {
                                    SettingsData.setOSLogoColorOverride("")
                                }
                            }
                        }

                        Column { width: 200; spacing: Theme.spacingS
                            StyledText { text: "Color Override"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHTextField {
                                width: parent.width
                                text: SettingsData.osLogoColorOverride
                                placeholderText: "#FFFFFF"
                                onTextEdited: SettingsData.setOSLogoColorOverride(text)
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CUSTOM LAUNCHER IMAGE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: customLauncherSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: customLauncherSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "image"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Custom Launcher Image"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Use Custom Image"
                        description: "Use a custom PNG image instead of the default apps icon"
                        checked: SettingsData.useCustomLauncherImage
                        onToggled: checked => {
                            if (checked) SettingsData.setUseOSLogo(false)
                            SettingsData.setUseCustomLauncherImage(checked)
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: SettingsData.useCustomLauncherImage
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
                                    id: previewImage
                                    anchors.fill: parent
                                    source: SettingsData.customLauncherImagePath ? "file://" + SettingsData.customLauncherImagePath : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: false
                                }

                                MultiEffect {
                                    anchors.fill: previewImage
                                    source: previewImage
                                    visible: SettingsData.launcherLogoRed !== 1.0 || SettingsData.launcherLogoGreen !== 1.0 || SettingsData.launcherLogoBlue !== 1.0
                                    colorizationColor: Qt.rgba(SettingsData.launcherLogoRed, SettingsData.launcherLogoGreen, SettingsData.launcherLogoBlue, 0.8)
                                    colorization: 1.0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    visible: launcherImageMouseArea.containsMouse

                                    Row {
                                        anchors.centerIn: parent; spacing: Theme.spacingS
                                        EHIcon { name: "edit"; size: 16; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                        StyledText { text: "Click to change"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }

                                MouseArea {
                                    id: launcherImageMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: launcherImageBrowser.open()
                                }
                            }
                        }

                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText {
                                text: SettingsData.customLauncherImagePath ? SettingsData.customLauncherImagePath.split('/').pop() : "No image selected"
                                font.pixelSize: Theme.fontSizeSmall
                                color: SettingsData.customLauncherImagePath ? Theme.surfaceVariantText : Theme.outline
                                elide: Text.ElideMiddle
                                width: parent.width
                            }
                            StyledText {
                                text: "Click the preview or browse to select a PNG image file for the launcher button"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // VIEW MODE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: viewModeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: viewModeSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "view_list"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "View Mode"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "App Launcher Display Mode"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHButtonGroup {
                            width: parent.width
                            model: ["List", "Grid"]
                            currentIndex: SettingsData.appLauncherViewMode === "list" ? 0 : 1
                            selectionMode: "single"
                            onSelectionChanged: (index, selected) => {
                                if (selected) SettingsData.setAppLauncherViewMode(index === 0 ? "list" : "grid")
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // APP DRAWER SCALE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: appDrawerScaleSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: appDrawerScaleSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "zoom_in"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "App Drawer Scale"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText {
                            text: "Scale (" + Math.round(SettingsData.appDrawerScale * 100) + "%)"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value: Math.round(SettingsData.appDrawerScale * 100)
                            minimum: 50; maximum: 200; unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setAppDrawerScale(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // RECENTLY USED APPS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: recentlyUsedSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: recentlyUsedSection

                    property var rankedAppsModel: {
                        var apps = []
                        for (var appId in (AppUsageHistoryData.appUsageRanking || {})) {
                            var appData = (AppUsageHistoryData.appUsageRanking || {})[appId]
                            apps.push({ "id": appId, "name": appData.name, "exec": appData.exec,
                                        "icon": appData.icon, "comment": appData.comment,
                                        "usageCount": appData.usageCount, "lastUsed": appData.lastUsed })
                        }
                        apps.sort(function(a, b) {
                            if (a.usageCount !== b.usageCount) return b.usageCount - a.usageCount
                            return a.name.localeCompare(b.name)
                        })
                        return apps.slice(0, 20)
                    }

                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM

                        EHIcon { name: "history"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }

                        StyledText { text: "Recently Used Apps"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }

                        Item { width: parent.width - parent.children[0].width - parent.children[1].width - clearAllButton.width - Theme.spacingM * 3; height: 1 }

                        EHActionButton {
                            id: clearAllButton
                            iconName: "delete_sweep"; iconSize: Theme.iconSize - 2; iconColor: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                AppUsageHistoryData.appUsageRanking = {}
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: "Apps are ordered by usage frequency, then alphabetically."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        id: rankedAppsList
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: recentlyUsedSection.rankedAppsModel

                            delegate: Rectangle {
                                width: rankedAppsList.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                border.width: 1

                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: (index + 1).toString()
                                        font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                                        color: Theme.primary; width: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Image {
                                        width: 24; height: 24
                                        source: modelData.icon ? "image://icon/" + modelData.icon : "image://icon/application-x-executable"
                                        sourceSize.width: 24; sourceSize.height: 24
                                        fillMode: Image.PreserveAspectFit
                                        anchors.verticalCenter: parent.verticalCenter
                                        onStatusChanged: { if (status === Image.Error) source = "image://icon/application-x-executable" }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        StyledText {
                                            text: modelData.name || "Unknown App"
                                            font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText
                                        }
                                        StyledText {
                                            text: {
                                                if (!modelData.lastUsed) return "Never used"
                                                var date = new Date(modelData.lastUsed), now = new Date()
                                                var diffMs = now - date
                                                var diffMins  = Math.floor(diffMs / 60000)
                                                var diffHours = Math.floor(diffMs / 3600000)
                                                var diffDays  = Math.floor(diffMs / 86400000)
                                                if (diffMins < 1)  return "Last launched just now"
                                                if (diffMins < 60) return "Last launched " + diffMins  + " minute"  + (diffMins  === 1 ? "" : "s") + " ago"
                                                if (diffHours < 24)return "Last launched " + diffHours + " hour"    + (diffHours === 1 ? "" : "s") + " ago"
                                                if (diffDays  < 7) return "Last launched " + diffDays  + " day"     + (diffDays  === 1 ? "" : "s") + " ago"
                                                return "Last launched " + date.toLocaleDateString()
                                            }
                                            font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                EHActionButton {
                                    anchors.right: parent.right; anchors.rightMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    circular: true; iconName: "close"; iconSize: 16; iconColor: Theme.error
                                    onClicked: {
                                        var currentRanking = Object.assign({}, AppUsageHistoryData.appUsageRanking || {})
                                        delete currentRanking[modelData.id]
                                        AppUsageHistoryData.appUsageRanking = currentRanking
                                        SettingsData.saveSettings()
                                    }
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: "No apps have been launched yet."
                            font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            visible: recentlyUsedSection.rankedAppsModel.length === 0
                        }
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: launcherImageBrowser
        browserTitle: "Select Launcher Image"
        browserIcon: "image"
        browserType: "generic"
        fileExtensions: ["*.png"]
        onFileSelected: path => {
            SettingsData.setCustomLauncherImagePath(path)
            close()
        }
    }
}
