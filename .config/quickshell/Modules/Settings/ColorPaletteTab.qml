import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: colorPaletteTab

    property var parentModal: null
    property bool forceUpdate: false
    property bool stayOnGenericAfterCustom: false

    Component.onCompleted: {
        if (typeof ColorPaletteService !== 'undefined') {
            ColorPaletteService.colorsExtracted.connect(function() {
                forceUpdate = !forceUpdate
            })
            
            ColorPaletteService.customThemeCreated.connect(function(themeData) {
                if (typeof Theme !== 'undefined') {
                    Theme.customThemeData = themeData
                    Theme.switchTheme("custom", true, false)
                    Theme.generateSystemThemesFromCurrentTheme()
                }
            })

            ColorPaletteService.themesUpdated.connect(function() {
                forceUpdate = !forceUpdate
                customThemeTools.refreshCustomThemeOptions()
            })
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

            // Theme Selection Section
            StyledRect {
                width: parent.width
                height: themeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                               Theme.surfaceContainer.b, 0.6)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.12)
                border.width: 1

                Column {
                    id: themeSection

                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingXL

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Color Palette"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Choose a theme or extract colors from your wallpaper"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }

                    Column {
                        spacing: Theme.spacingL
                        width: parent.width

                        EHButtonGroup {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            buttonHeight: 48
                            minButtonWidth: (width - Theme.spacingXS * (model.length - 1)) / model.length
                            buttonPadding: Theme.spacingXL
                            textSize: Theme.fontSizeMedium
                            property int currentThemeIndex: {
                                if (Theme.currentTheme === Theme.dynamic) return 2
                                if (Theme.currentThemeName === "custom" && colorPaletteTab.stayOnGenericAfterCustom) return 0
                                if (Theme.currentThemeName === "custom") return 3
                                if (Theme.currentThemeCategory === "catppuccin") return 1
                                return 0
                            }

                            model: ["Generic", "Catppuccin", "Auto", "Custom"]
                            currentIndex: currentThemeIndex
                            selectionMode: "single"
                            onSelectionChanged: (index, selected) => {
                                colorPaletteTab.stayOnGenericAfterCustom = false
                                if (!selected) return
                                switch (index) {
                                    case 0: Theme.switchThemeCategory("generic", "blue"); break
                                    case 1: Theme.switchThemeCategory("catppuccin", "cat-mauve"); break
                                    case 2:
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            ToastService.showError("matugen not found - install matugen package for dynamic theming")
                                        else if (ToastService.wallpaperErrorStatus === "error")
                                            ToastService.showError("Wallpaper processing failed - check wallpaper path")
                                        else
                                            Theme.switchTheme(Theme.dynamic, true, false)
                                        break
                                    case 3:
                                        if (Theme.currentThemeName !== "custom") {
                                            Theme.switchTheme("custom", true, false)
                                        }
                                        break
                                }
                            }
                        }

                        // Matugen Palette Selection (visible when dynamic/auto theme is selected)
                        Column {
                            spacing: Theme.spacingM
                            width: parent.width
                            visible: Theme.currentTheme === Theme.dynamic

                            StyledText {
                                text: "Matugen Palette"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            EHDropdown {
                                width: parent.width
                                text: "Palette Algorithm"
                                description: "Select the palette algorithm used for wallpaper-based colors"
                                currentValue: Theme.getMatugenScheme(SettingsData.matugenScheme).label
                                options: Theme.availableMatugenSchemes.map(scheme => scheme.label)
                                enabled: Theme.matugenAvailable
                                opacity: enabled ? 1 : 0.4
                                onValueChanged: value => {
                                    for (var i = 0; i < Theme.availableMatugenSchemes.length; i++) {
                                        var scheme = Theme.availableMatugenSchemes[i]
                                        if (scheme.label === value) {
                                            SettingsData.setMatugenScheme(scheme.value)
                                            break
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: {
                                    var scheme = Theme.getMatugenScheme(SettingsData.matugenScheme)
                                    return scheme.description
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        // Extract Colors and Saved Themes (for Generic theme)
                        Column {
                            spacing: Theme.spacingL
                            width: parent.width
                            visible: (Theme.currentThemeCategory === "generic" || colorPaletteTab.stayOnGenericAfterCustom)
                                     && Theme.currentTheme !== Theme.dynamic
                                     && (Theme.currentThemeName !== "custom" || colorPaletteTab.stayOnGenericAfterCustom)

                            Rectangle {
                                id: extractButton
                                property bool isEnabled: !ColorPaletteService.isExtracting && Theme.wallpaperPath
                                property bool isHovered: extractMouseArea.containsMouse
                                property bool isPressed: extractMouseArea.pressed

                                width: 180
                                height: 44
                                radius: Theme.cornerRadius
                                color: isEnabled ? (isPressed ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : (isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1))) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                                opacity: isEnabled ? 1.0 : 0.5
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, isEnabled ? (isHovered ? 0.2 : 0.15) : 0.1)
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }

                                Rectangle {
                                    id: extractStateLayer
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Theme.surfaceTint
                                    opacity: extractButton.isEnabled && extractButton.isHovered ? 0.08 : 0
                                    visible: opacity > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.standardEasing
                                        }
                                    }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: extractContentRow.implicitWidth
                                    height: extractContentRow.implicitHeight

                                    Row {
                                        id: extractContentRow
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingS

                                        EHIcon {
                                            name: ColorPaletteService.isExtracting ? "hourglass_empty" : "palette"
                                            size: 20
                                            color: extractButton.isEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: true
                                        }

                                        StyledText {
                                            text: ColorPaletteService.isExtracting ? "Extracting..." : "Extract Colors"
                                            color: extractButton.isEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                MouseArea {
                                    id: extractMouseArea
                                    anchors.fill: parent
                                    enabled: extractButton.isEnabled
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (Theme.wallpaperPath && typeof ColorPaletteService !== 'undefined') {
                                            ColorPaletteService.extractColorsFromWallpaper(Theme.wallpaperPath)
                                        }
                                    }
                                }
                            }

                            Column {
                                spacing: Theme.spacingM
                                width: parent.width
                                visible: true

                                StyledText {
                                    text: "Saved Color Themes"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                Row {
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 220
                                        height: 40
                                        radius: Theme.cornerRadius
                                        color: Theme.contentBackground()
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: 1

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: Theme.spacingL
                                            anchors.rightMargin: Theme.spacingL
                                            spacing: Theme.spacingM

                                            StyledText {
                                                id: selectedThemeText
                                                text: {
                                                    if (SettingsData.currentColorTheme) {
                                                        return `#${SettingsData.currentColorTheme.toUpperCase()}`
                                                    } else if (ColorPaletteService.availableThemes.length > 0) {
                                                        return "Select Theme"
                                                    } else {
                                                        return "No themes saved"
                                                    }
                                                }
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                                font.pixelSize: Theme.fontSizeMedium
                                            }

                                            EHIcon {
                                                name: "keyboard_arrow_down"
                                                size: 20
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                                opacity: 0.7
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (themeDropdown.visible) {
                                                    themeDropdown.visible = false
                                                } else {
                                                    themeDropdown.visible = true
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: Theme.cornerRadius
                                        color: Theme.error || "#f44336"
                                        visible: SettingsData.currentColorTheme !== ""
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: 1

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.standardEasing
                                            }
                                        }

                                        EHIcon {
                                            name: "delete"
                                            size: 18
                                            color: Theme.errorText || "#ffffff"
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (SettingsData.currentColorTheme) {
                                                    ColorPaletteService.deleteTheme(SettingsData.currentColorTheme)
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: themeDropdown
                                    width: 220
                                    height: Math.min(240, ColorPaletteService.availableThemes.length * 40 + 8)
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainer
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                    border.width: 1
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true

                                    ListView {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingXS
                                        model: ColorPaletteService.availableThemes
                                        clip: true
                                        spacing: 2

                                        delegate: Rectangle {
                                            width: ListView.view.width - Theme.spacingXS * 2
                                            height: 40
                                            color: mouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                                            radius: Theme.cornerRadius
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: 1

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.shorterDuration
                                                    easing.type: Theme.standardEasing
                                                }
                                            }

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: Theme.spacingL
                                                spacing: Theme.spacingM

                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: modelData.primaryColor
                                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                                    border.width: 1
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: modelData.displayName
                                                    color: Theme.surfaceText
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: mouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ColorPaletteService.loadThemeByName(modelData.name)
                                                    themeDropdown.visible = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Color Palette Grid
                        Column {
                            spacing: Theme.spacingL
                            width: parent.width

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ColorPaletteService.extractedColors.length > 0 ? "Extracted Colors" : "Theme Colors"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignHCenter
                                visible: {
                                    if (ColorPaletteService.extractedColors.length > 0) {
                                        return ColorPaletteService.extractedColors.length > 0
                                    }
                                    return ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"].length > 0
                                }
                            }

                            Grid {
                                id: colorGrid
                                width: parent.width
                                anchors.horizontalCenter: parent.horizontalCenter
                                property int cellSize: 52
                                property int targetColumns: Math.max(1, Math.floor(width / (cellSize + Theme.spacingM)))
                                columns: targetColumns
                                rowSpacing: Theme.spacingM
                                columnSpacing: targetColumns > 1
                                                   ? Math.max(Theme.spacingM, Math.floor((width - targetColumns * cellSize) / (targetColumns - 1)))
                                                   : 0

                                Repeater {
                                    model: {
                                        forceUpdate
                                        return ColorPaletteService.extractedColors.length > 0 ?
                                               ColorPaletteService.extractedColors :
                                               ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]
                                    }

                                    Rectangle {
                                        property string colorValue: modelData
                                        property bool isExtractedColor: ColorPaletteService.extractedColors.length > 0
                                        property bool isSelected: isExtractedColor && ColorPaletteService.selectedColors.includes(colorValue)
                                        property string displayColor: isExtractedColor ? ColorPaletteService.applyHueAdjustments(colorValue) : Theme.getThemeColors(colorValue).primary
                                        property string textColor: {
                                            if (isExtractedColor && typeof SettingsData !== 'undefined') {
                                                const hexR = Math.max(0, Math.min(255, SettingsData.extractedColorTextR)).toString(16).padStart(2, '0')
                                                const hexG = Math.max(0, Math.min(255, SettingsData.extractedColorTextG)).toString(16).padStart(2, '0')
                                                const hexB = Math.max(0, Math.min(255, SettingsData.extractedColorTextB)).toString(16).padStart(2, '0')
                                                return "#" + hexR + hexG + hexB
                                            }
                                            return Theme.primary
                                        }
                                        width: colorGrid.cellSize
                                        height: colorGrid.cellSize
                                        radius: colorGrid.cellSize / 2
                                        color: displayColor
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: isSelected ? 3 : 1
                                        scale: isSelected ? 1.1 : 1

                                        EHIcon {
                                            name: "check"
                                            size: 20
                                            color: parent.textColor
                                            anchors.centerIn: parent
                                            visible: isSelected
                                            opacity: isSelected ? 1 : 0

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.standardEasing
                                                }
                                            }

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.standardEasing
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: nameText.contentWidth + Theme.spacingL
                                            height: nameText.contentHeight + Theme.spacingS
                                            color: Theme.surfaceContainer
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: 1
                                            radius: Theme.cornerRadius
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: Theme.spacingS
                                            visible: !isExtractedColor && colorMouseArea.containsMouse
                                            layer.enabled: true
                                            layer.smooth: true

                                            StyledText {
                                                id: nameText
                                                property string textColorValue: {
                                                    if (isExtractedColor && typeof SettingsData !== 'undefined') {
                                                        const hexR = Math.max(0, Math.min(255, SettingsData.extractedColorTextR)).toString(16).padStart(2, '0')
                                                        const hexG = Math.max(0, Math.min(255, SettingsData.extractedColorTextG)).toString(16).padStart(2, '0')
                                                        const hexB = Math.max(0, Math.min(255, SettingsData.extractedColorTextB)).toString(16).padStart(2, '0')
                                                        return "#" + hexR + hexG + hexB
                                                    }
                                                    return Theme.surfaceText
                                                }
                                                text: isExtractedColor ? "" : Theme.getThemeColors(colorValue).name
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: textColorValue
                                                anchors.centerIn: parent

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: Theme.shortDuration
                                                        easing.type: Theme.standardEasing
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: colorMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isExtractedColor) {
                                                    colorPaletteTab.stayOnGenericAfterCustom = true
                                                    ColorPaletteService.clearSelection()
                                                    ColorPaletteService.selectColor(colorValue, true)
                                                    ColorPaletteService.applySelectedColors()
                                                } else {
                                                    colorPaletteTab.stayOnGenericAfterCustom = false
                                                    Theme.switchTheme(colorValue)
                                                }
                                            }
                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.emphasizedEasing
                                            }
                                        }

                                        Behavior on border.width {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                                easing.type: Theme.emphasizedEasing
                                            }
                                        }
                                    }
                                }
                            }

                            // Catppuccin Colors
                            Column {
                                spacing: Theme.spacingS
                                visible: Theme.currentThemeCategory === "catppuccin" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"

                                Row {
                                    spacing: Theme.spacingM

                                    Repeater {
                                        model: [
                                            "cat-rosewater", "cat-flamingo", "cat-pink", "cat-mauve", "cat-red", "cat-maroon", "cat-peach",
                                            "cat-yellow", "cat-green", "cat-teal", "cat-sky", "cat-sapphire", "cat-blue", "cat-lavender"
                                        ]

                                        Rectangle {
                                            property string themeName: modelData
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: Theme.getCatppuccinColor(themeName)
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 3 : 1
                                            scale: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                            Rectangle {
                                                width: nameTextCatUnified.contentWidth + Theme.spacingL
                                                height: nameTextCatUnified.contentHeight + Theme.spacingS
                                                color: Theme.surfaceContainer
                                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                                border.width: 1
                                                radius: Theme.cornerRadius
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: Theme.spacingS
                                                visible: mouseAreaCatUnified.containsMouse
                                                layer.enabled: true
                                                layer.smooth: true

                                                StyledText {
                                                    id: nameTextCatUnified
                                                    text: Theme.getCatppuccinVariantName(themeName)
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceText
                                                    anchors.centerIn: parent
                                                }
                                            }

                                            MouseArea {
                                                id: mouseAreaCatUnified
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Theme.switchTheme(themeName)
                                                }
                                            }

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.emphasizedEasing
                                                }
                                            }

                                            Behavior on border.width {
                                                NumberAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.emphasizedEasing
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Custom Theme File Selection
                        Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: Theme.currentThemeName === "custom"

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                EHActionButton {
                                    buttonSize: 48
                                    iconName: "folder_open"
                                    iconSize: Theme.iconSize
                                    backgroundColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                    iconColor: Theme.primary
                                    onClicked: fileBrowserModal.open()
                                }

                                Column {
                                    width: parent.width - 48 - Theme.spacingM
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: SettingsData.customThemeFile ? SettingsData.customThemeFile.split('/').pop() : "No custom theme file"
                                        font.pixelSize: Theme.fontSizeLarge
                                        color: Theme.surfaceText
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: SettingsData.customThemeFile || "Click to select a custom theme JSON file"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1
                                        width: parent.width
                                    }
                                }
                            }
                        }

                        // Custom Theme Management Tools
                        Column {
                            id: customThemeTools
                            spacing: Theme.spacingM
                            width: parent.width
                            visible: Theme.currentThemeName === "custom"
                            property string selectedCustomThemeLabel: ""
                            property var customThemeOptions: []

                            function refreshCustomThemeOptions() {
                                const themes = ColorPaletteService.availableThemes || []
                                customThemeOptions = themes.map(t => ({ name: t.name, label: t.displayName || t.name }))
                                if (!customThemeOptions.some(o => o.label === selectedCustomThemeLabel)) {
                                    selectedCustomThemeLabel = customThemeOptions.length > 0 ? customThemeOptions[0].label : ""
                                }
                            }

                            Component.onCompleted: {
                                if (typeof ColorPaletteService !== 'undefined') {
                                    ColorPaletteService.initializeIfNeeded()
                                }
                                refreshCustomThemeOptions()
                            }

                            Connections {
                                target: ColorPaletteService
                                function onThemesUpdated() {
                                    customThemeTools.refreshCustomThemeOptions()
                                }
                            }

                            StyledRect {
                                width: parent.width
                                height: customThemeManager.implicitHeight + Theme.spacingL * 2
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                border.width: 1

                                Column {
                                    id: customThemeManager

                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingL
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: "Custom Themes"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "Create a new custom theme from the current colors, save it with a name, or load one of your saved themes to edit."
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        EHTextField {
                                            id: customThemeNameField
                                            width: parent.width - 150 - Theme.spacingM
                                            placeholderText: "Name your custom theme"
                                            autoExpandWidth: false
                                            autoExpandHeight: false
                                            minWidth: 200
                                            maxWidth: 600
                                            showClearButton: true
                                            text: customThemeTools.selectedCustomThemeLabel
                                        }

                                        StyledRect {
                                            id: saveCustomThemeButton
                                            width: 150
                                            height: 44
                                            radius: Theme.cornerRadius
                                            color: saveCustomThemeArea.containsMouse ? Theme.primary : Theme.primaryContainer
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingXS

                                                EHIcon {
                                                    name: "save"
                                                    size: 18
                                                    color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: "Save Theme"
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: saveCustomThemeArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const enteredName = customThemeNameField.text ? customThemeNameField.text.trim() : ""
                                                    if (!enteredName || enteredName.length === 0) {
                                                        if (typeof ToastService !== 'undefined') {
                                                            ToastService.showError("Enter a name to save the custom theme")
                                                        }
                                                        return
                                                    }

                                                    if (typeof ColorPaletteService !== 'undefined') {
                                                        const saved = ColorPaletteService.saveThemeWithName(enteredName)
                                                        if (saved && typeof ToastService !== 'undefined') {
                                                            ToastService.showInfo("Custom theme saved", `"${enteredName}" is now available to load and edit.`)
                                                        } else if (typeof ToastService !== 'undefined') {
                                                            ToastService.showError("Unable to save custom theme")
                                                        }
                                                        customThemeTools.refreshCustomThemeOptions()
                                                        customThemeTools.selectedCustomThemeLabel = enteredName
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        EHDropdown {
                                            id: customThemeDropdown
                                            width: parent.width - (150 * 2) - (Theme.spacingM * 2)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: customThemeTools.customThemeOptions.length > 0 ? "Saved Custom Themes" : ""
                                            description: customThemeTools.customThemeOptions.length > 0 ? "Pick a saved theme to load for editing" : ""
                                            currentValue: customThemeTools.selectedCustomThemeLabel
                                            options: customThemeTools.customThemeOptions.map(o => o.label)
                                            onValueChanged: value => {
                                                customThemeTools.selectedCustomThemeLabel = value
                                            }
                                        }

                                        StyledRect {
                                            id: loadCustomThemeButton
                                            width: 150
                                            height: 44
                                            radius: Theme.cornerRadius
                                            color: loadCustomThemeArea.containsMouse ? Theme.secondary : (Theme.secondaryContainer || Theme.surfaceVariant)
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingXS

                                                EHIcon {
                                                    name: "folder_open"
                                                    size: 18
                                                    color: ColorPaletteService.getTextColorForBackground(loadCustomThemeArea.containsMouse ? Theme.secondary : (Theme.secondaryContainer || Theme.surfaceVariant))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: "Load Theme"
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: ColorPaletteService.getTextColorForBackground(loadCustomThemeArea.containsMouse ? Theme.secondary : (Theme.secondaryContainer || Theme.surfaceVariant))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: loadCustomThemeArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const selected = customThemeTools.customThemeOptions.find(o => o.label === customThemeTools.selectedCustomThemeLabel)
                                                    if (!selected) {
                                                        if (typeof ToastService !== 'undefined') {
                                                            ToastService.showError("Select a saved theme to load")
                                                        }
                                                        return
                                                    }

                                                    const loaded = ColorPaletteService.loadThemeByName(selected.name)
                                                    if (loaded) {
                                                        customThemeNameField.text = selected.label
                                                        if (typeof ToastService !== 'undefined') {
                                                            ToastService.showInfo("Custom theme loaded", `"${selected.label}" is ready to edit and save again.`)
                                                        }
                                                    } else if (typeof ToastService !== 'undefined') {
                                                        ToastService.showError("Unable to load the selected theme")
                                                    }
                                                }
                                            }
                                        }

                                        StyledRect {
                                            id: deleteCustomThemeButton
                                            width: 150
                                            height: 44
                                            radius: Theme.cornerRadius
                                            color: deleteCustomThemeArea.containsMouse ? Theme.error : (Theme.errorContainer || Theme.error)
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingXS

                                                EHIcon {
                                                    name: "delete"
                                                    size: 18
                                                    color: ColorPaletteService.getTextColorForBackground(deleteCustomThemeArea.containsMouse ? Theme.error : (Theme.errorContainer || Theme.error))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: "Delete Theme"
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: ColorPaletteService.getTextColorForBackground(deleteCustomThemeArea.containsMouse ? Theme.error : (Theme.errorContainer || Theme.error))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: deleteCustomThemeArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const selected = customThemeTools.customThemeOptions.find(o => o.label === customThemeTools.selectedCustomThemeLabel)
                                                    if (!selected) {
                                                        if (typeof ToastService !== 'undefined') {
                                                            ToastService.showError("Select a saved theme to delete")
                                                        }
                                                        return
                                                    }

                                                    const deleted = ColorPaletteService.deleteTheme(selected.name)
                                                    if (deleted) {
                                                        customThemeTools.refreshCustomThemeOptions()
                                                        customThemeTools.selectedCustomThemeLabel = ""
                                                        if (typeof ToastService !== 'undefined') {
                                                            ToastService.showInfo("Custom theme deleted", `"${selected.label}" has been removed.`)
                                                        }
                                                    } else if (typeof ToastService !== 'undefined') {
                                                        ToastService.showError("Unable to delete the selected theme")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: "Select Custom Theme"
        filterExtensions: ["*.json"]
        showHiddenFiles: true

        function selectCustomTheme() {
            shouldBeVisible = true
        }

        onFileSelected: function(filePath) {
            if (filePath.endsWith(".json")) {
                SettingsData.setCustomThemeFile(filePath)
                Theme.switchTheme("custom")
                close()
            }
        }
    }
}
