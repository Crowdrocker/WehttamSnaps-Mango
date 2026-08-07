import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: fontsTab

    property var parentModal: null
    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false

    readonly property string fontWeightText: {
        switch (SettingsData.fontWeight) {
        case Font.Thin:       return "Thin"
        case Font.ExtraLight: return "Extra Light"
        case Font.Light:      return "Light"
        case Font.Normal:     return "Regular"
        case Font.Medium:     return "Medium"
        case Font.DemiBold:   return "Demi Bold"
        case Font.Bold:       return "Bold"
        case Font.ExtraBold:  return "Extra Bold"
        case Font.Black:      return "Black"
        default:              return "Regular"
        }
    }

    function enumerateFonts() {
        var fonts = ["Default"]
        var availableFonts = Qt.fontFamilies()
        var seenFamilies = new Set()
        var rootFamilies = []
        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i]
            if (fontName.startsWith(".")) continue
            if (fontName === SettingsData.defaultFontFamily) continue
            var rootName = fontName
                .replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "")
                .replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "")
                .replace(/ (UI|Display|Text|Mono|Sans|Serif)$/i, m => m)
                .trim()
            if (!seenFamilies.has(rootName) && rootName !== "") { seenFamilies.add(rootName); rootFamilies.push(rootName) }
        }
        cachedFontFamilies = fonts.concat(rootFamilies.sort())

        var monoFonts = ["Default"]
        var seenMonoFamilies = new Set()
        var monoFamilies = []
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j]
            if (fontName2.startsWith(".")) continue
            if (fontName2 === SettingsData.defaultMonoFontFamily) continue
            var lowerName = fontName2.toLowerCase()
            if (lowerName.includes("mono") || lowerName.includes("code") || lowerName.includes("console") ||
                lowerName.includes("terminal") || lowerName.includes("courier") || lowerName.includes("dejavu sans mono") ||
                lowerName.includes("jetbrains") || lowerName.includes("fira") || lowerName.includes("hack") ||
                lowerName.includes("source code") || lowerName.includes("ubuntu mono") || lowerName.includes("cascadia")) {
                var rootName2 = fontName2
                    .replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "")
                    .replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "")
                    .trim()
                if (!seenMonoFamilies.has(rootName2) && rootName2 !== "") { seenMonoFamilies.add(rootName2); monoFamilies.push(rootName2) }
            }
        }
        cachedMonoFamilies = monoFonts.concat(monoFamilies.sort())
    }

    Component.onCompleted: {
        if (!fontsEnumerated) { enumerateFonts(); fontsEnumerated = true }
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
            // FONT SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: fontSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: fontSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "font_download"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Font Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHDropdown {
                        width: parent.width; text: "Font Family"; description: "Select system font family"
                        currentValue: SettingsData.fontFamily === SettingsData.defaultFontFamily ? "Default" : (SettingsData.fontFamily || "Default")
                        enableFuzzySearch: true; popupWidthOffset: 100; maxPopupHeight: 400
                        options: cachedFontFamilies
                        onValueChanged: value => { if (value.startsWith("Default")) SettingsData.setFontFamily(SettingsData.defaultFontFamily); else SettingsData.setFontFamily(value) }
                    }

                    EHDropdown {
                        width: parent.width; text: "Font Weight"; description: "Select font weight"
                        currentValue: {
                            switch (SettingsData.fontWeight) {
                            case Font.Thin: return "Thin"; case Font.ExtraLight: return "Extra Light"; case Font.Light: return "Light"
                            case Font.Normal: return "Regular"; case Font.Medium: return "Medium"; case Font.DemiBold: return "Demi Bold"
                            case Font.Bold: return "Bold"; case Font.ExtraBold: return "Extra Bold"; case Font.Black: return "Black"
                            default: return "Regular"
                            }
                        }
                        options: ["Thin", "Extra Light", "Light", "Regular", "Medium", "Demi Bold", "Bold", "Extra Bold", "Black"]
                        onValueChanged: value => {
                            const map = { "Thin": Font.Thin, "Extra Light": Font.ExtraLight, "Light": Font.Light, "Regular": Font.Normal,
                                          "Medium": Font.Medium, "Demi Bold": Font.DemiBold, "Bold": Font.Bold, "Extra Bold": Font.ExtraBold, "Black": Font.Black }
                            SettingsData.setFontWeight(map[value] ?? Font.Normal)
                        }
                    }

                    EHDropdown {
                        width: parent.width; text: "Monospace Font"; description: "Select monospace font for process list and technical displays"
                        currentValue: SettingsData.monoFontFamily === SettingsData.defaultMonoFontFamily ? "Default" : (SettingsData.monoFontFamily || "Default")
                        enableFuzzySearch: true; popupWidthOffset: 100; maxPopupHeight: 400
                        options: cachedMonoFamilies
                        onValueChanged: value => { if (value === "Default") SettingsData.setMonoFontFamily(SettingsData.defaultMonoFontFamily); else SettingsData.setMonoFontFamily(value) }
                    }

                    // Font Scale
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        Row {
                            width: parent.width
                            Column {
                                width: parent.width - fontScaleControls.width; spacing: Theme.spacingXS
                                StyledText { text: "Font Scale"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Scale all font sizes"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }
                            Row {
                                id: fontScaleControls; spacing: Theme.spacingS
                                EHActionButton {
                                    buttonSize: 32; iconName: "remove"; iconSize: Theme.iconSizeSmall
                                    enabled: SettingsData.fontScale > 1.0
                                    backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                    iconColor: Theme.surfaceText
                                    onClicked: SettingsData.setFontScale(Math.max(1.0, SettingsData.fontScale - 0.05))
                                }
                                StyledRect {
                                    width: 60; height: 32; radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2); border.width: 1
                                    StyledText { anchors.centerIn: parent; text: (SettingsData.fontScale * 100).toFixed(0) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                }
                                EHActionButton {
                                    buttonSize: 32; iconName: "add"; iconSize: Theme.iconSizeSmall
                                    enabled: SettingsData.fontScale < 2.0
                                    backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                    iconColor: Theme.surfaceText
                                    onClicked: SettingsData.setFontScale(Math.min(2.0, SettingsData.fontScale + 0.05))
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // FONT PREVIEW
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: previewSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: previewSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "preview"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Font Preview"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    RowLayout {
                        width: parent.width; spacing: Theme.spacingM

                        Column {
                            spacing: Theme.spacingXS; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Preview"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                            Rectangle {
                                width: 295; height: 295; radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3); border.width: 2

                                Column {
                                    anchors.fill: parent; anchors.margins: Theme.spacingL; spacing: Theme.spacingS

                                    property var fontProps: ({
                                        family: SettingsData.fontFamily, weight: SettingsData.fontWeight,
                                        capitalization: SettingsData.fontCapitalization, italic: SettingsData.fontItalic,
                                        underline: SettingsData.fontUnderline, strikeout: SettingsData.fontStrikeout,
                                        hintingPreference: SettingsData.fontHintingPreference
                                    })

                                    Repeater {
                                        model: [
                                            { text: "The quick brown fox",  size: Theme.fontSizeLarge },
                                            { text: "jumps over the lazy dog", size: Theme.fontSizeMedium },
                                            { text: "ABCDEFGHIJKLM",       size: Theme.fontSizeLarge },
                                            { text: "NOPQRSTUVWXYZ",       size: Theme.fontSizeLarge },
                                        ]
                                        StyledText {
                                            text: modelData.text; width: parent.width
                                            font.pixelSize: modelData.size * SettingsData.fontScale
                                            font.family: SettingsData.fontFamily; font.weight: SettingsData.fontWeight
                                            font.capitalization: SettingsData.fontCapitalization; font.italic: SettingsData.fontItalic
                                            font.underline: SettingsData.fontUnderline; font.strikeout: SettingsData.fontStrikeout
                                            font.hintingPreference: SettingsData.fontHintingPreference
                                            renderType: SettingsData.fontRenderType; antialiasing: SettingsData.fontAntialiasing
                                            lineHeight: SettingsData.fontLineHeight; color: Theme.surfaceText
                                        }
                                    }

                                    Item { width: parent.width; height: Theme.spacingXS }

                                    Row {
                                        width: parent.width; spacing: Theme.spacingM
                                        Repeater {
                                            model: ["0123456789", "!@#$%^&*()"]
                                            StyledText {
                                                text: modelData
                                                font.pixelSize: Theme.fontSizeMedium * SettingsData.fontScale
                                                font.family: SettingsData.fontFamily; font.weight: SettingsData.fontWeight
                                                font.capitalization: SettingsData.fontCapitalization; font.italic: SettingsData.fontItalic
                                                font.underline: SettingsData.fontUnderline; font.strikeout: SettingsData.fontStrikeout
                                                font.hintingPreference: SettingsData.fontHintingPreference
                                                renderType: SettingsData.fontRenderType; antialiasing: SettingsData.fontAntialiasing
                                                lineHeight: SettingsData.fontLineHeight; color: Theme.surfaceText
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: "Aa Bb Cc Dd Ee"; width: parent.width
                                        font.pixelSize: Theme.fontSizeSmall * SettingsData.fontScale
                                        font.family: SettingsData.fontFamily; font.weight: SettingsData.fontWeight
                                        font.capitalization: SettingsData.fontCapitalization; font.italic: SettingsData.fontItalic
                                        font.underline: SettingsData.fontUnderline; font.strikeout: SettingsData.fontStrikeout
                                        font.hintingPreference: SettingsData.fontHintingPreference
                                        renderType: SettingsData.fontRenderType; antialiasing: SettingsData.fontAntialiasing
                                        lineHeight: SettingsData.fontLineHeight; color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingS; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            StyledText { text: "Sample Text"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText {
                                text: "This preview shows how your selected font settings will appear throughout the interface. Adjust the font family, weight, scale, hinting, and render type to see real-time changes."
                                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap; width: parent.width; lineHeight: 1.4
                            }
                            Item { width: parent.width; height: Theme.spacingM }
                            Column {
                                width: parent.width; spacing: Theme.spacingXS
                                StyledText { text: "Current Settings:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "• Family: " + (SettingsData.fontFamily || "Default"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width }
                                StyledText { text: "• Weight: " + fontsTab.fontWeightText; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width }
                                StyledText { text: "• Scale: " + (SettingsData.fontScale * 100).toFixed(0) + "%"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // NOTEPAD FONT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: notepadSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: notepadSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "description"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Notepad Font Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    EHToggle { width: parent.width; text: "Use Monospace Font"; description: "Use monospace font in notepad"; checked: SettingsData.notepadUseMonospace; onToggled: SettingsData.notepadUseMonospace = checked }
                    EHDropdown {
                        width: parent.width; text: "Notepad Font Family"; description: "Select font for notepad (empty = use system font)"
                        currentValue: SettingsData.notepadFontFamily || "System Default"
                        enableFuzzySearch: true; popupWidthOffset: 100; maxPopupHeight: 400
                        options: ["System Default"].concat(cachedFontFamilies.slice(1))
                        onValueChanged: value => { SettingsData.notepadFontFamily = (value === "System Default") ? "" : value }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Font Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Notepad font size in pixels"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24; minimum: 8; maximum: 32
                            value: SettingsData.notepadFontSize; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.notepadFontSize = newValue }
                        }
                    }

                    EHToggle { width: parent.width; text: "Show Line Numbers"; description: "Display line numbers in notepad"; checked: SettingsData.notepadShowLineNumbers; onToggled: SettingsData.notepadShowLineNumbers = checked }
                }
            }

            // ════════════════════════════════════════════════════════════
            // FONT RENDERING
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: renderingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: renderingSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Font Rendering"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Font Antialiasing"; description: "Enable smooth font rendering"; checked: SettingsData.fontAntialiasing; onToggled: SettingsData.fontAntialiasing = checked }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Line Height"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Spacing between lines of text"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24; minimum: 80; maximum: 250
                            value: Math.round(SettingsData.fontLineHeight * 100)
                            unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.fontLineHeight = newValue / 100.0 }
                        }
                    }

                    EHDropdown {
                        width: parent.width; text: "Text Capitalization"; description: "Transform text capitalization"
                        currentValue: {
                            switch (SettingsData.fontCapitalization) {
                            case Font.MixedCase: return "Mixed Case"; case Font.AllUppercase: return "All Uppercase"
                            case Font.AllLowercase: return "All Lowercase"; case Font.SmallCaps: return "Small Caps"
                            case Font.Capitalize: return "Capitalize"; default: return "Mixed Case"
                            }
                        }
                        options: ["Mixed Case", "All Uppercase", "All Lowercase", "Small Caps", "Capitalize"]
                        onValueChanged: value => {
                            const map = { "All Uppercase": Font.AllUppercase, "All Lowercase": Font.AllLowercase,
                                          "Small Caps": Font.SmallCaps, "Capitalize": Font.Capitalize, "Mixed Case": Font.MixedCase }
                            SettingsData.fontCapitalization = map[value] ?? Font.MixedCase
                        }
                    }

                    EHDropdown {
                        width: parent.width; text: "Font Stretch"; description: "Condensed or expanded font width (limited QML support)"
                        currentValue: {
                            switch (SettingsData.fontStretch) {
                            case Font.UltraCondensed: return "Ultra Condensed"; case Font.ExtraCondensed: return "Extra Condensed"
                            case Font.Condensed: return "Condensed"; case Font.SemiCondensed: return "Semi Condensed"
                            case Font.NormalStretch: return "Normal"; case Font.SemiExpanded: return "Semi Expanded"
                            case Font.Expanded: return "Expanded"; case Font.ExtraExpanded: return "Extra Expanded"
                            case Font.UltraExpanded: return "Ultra Expanded"; default: return "Normal"
                            }
                        }
                        options: ["Ultra Condensed", "Extra Condensed", "Condensed", "Semi Condensed", "Normal", "Semi Expanded", "Expanded", "Extra Expanded", "Ultra Expanded"]
                        onValueChanged: value => {
                            const map = { "Ultra Condensed": Font.UltraCondensed, "Extra Condensed": Font.ExtraCondensed,
                                          "Condensed": Font.Condensed, "Semi Condensed": Font.SemiCondensed,
                                          "Semi Expanded": Font.SemiExpanded, "Expanded": Font.Expanded,
                                          "Extra Expanded": Font.ExtraExpanded, "Ultra Expanded": Font.UltraExpanded }
                            SettingsData.fontStretch = map[value] ?? Font.NormalStretch
                        }
                    }

                    EHToggle { width: parent.width; text: "Italic Style"; description: "Apply italic style to text"; checked: SettingsData.fontItalic; onToggled: SettingsData.fontItalic = checked }
                    EHToggle { width: parent.width; text: "Underline"; description: "Add underline to text"; checked: SettingsData.fontUnderline; onToggled: SettingsData.fontUnderline = checked }
                    EHToggle { width: parent.width; text: "Strikeout"; description: "Add strikeout line to text"; checked: SettingsData.fontStrikeout; onToggled: SettingsData.fontStrikeout = checked }

                    EHDropdown {
                        width: parent.width; text: "Font Hinting"; description: "Control font rendering clarity"
                        currentValue: {
                            switch (SettingsData.fontHintingPreference) {
                            case Font.PreferDefaultHinting: return "Default"; case Font.PreferNoHinting: return "None"
                            case Font.PreferVerticalHinting: return "Vertical Only"; case Font.PreferFullHinting: return "Full"
                            default: return "Default"
                            }
                        }
                        options: ["Default", "None", "Vertical Only", "Full"]
                        onValueChanged: value => {
                            const map = { "None": Font.PreferNoHinting, "Vertical Only": Font.PreferVerticalHinting,
                                          "Full": Font.PreferFullHinting, "Default": Font.PreferDefaultHinting }
                            SettingsData.fontHintingPreference = map[value] ?? Font.PreferDefaultHinting
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Render Type"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Font rendering engine"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHButtonGroup {
                            width: parent.width
                            model: ["Qt Rendering", "Native Rendering", "Curve Rendering"]
                            currentIndex: { switch (SettingsData.fontRenderType) { case Text.QtRendering: return 0; case Text.NativeRendering: return 1; case Text.CurveRendering: return 2; default: return 0 } }
                            selectionMode: "single"; buttonHeight: 40; minButtonWidth: 100
                            buttonPadding: Theme.spacingM; textSize: Theme.fontSizeSmall; spacing: Theme.spacingS
                            onSelectionChanged: (index, selected) => {
                                if (selected) {
                                    const types = [Text.QtRendering, Text.NativeRendering, Text.CurveRendering]
                                    SettingsData.fontRenderType = types[index] ?? Text.QtRendering
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
