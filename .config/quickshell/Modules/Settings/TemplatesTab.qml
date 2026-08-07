import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals
import qs.Widgets

Item {
    id: templatesTab

    property var    parentModal: null
    property string searchText:  ""

    // ── Template definitions ──────────────────────────────────────────────────

    readonly property var appTemplates: [
        { id: "hyprland",    name: "Hyprland",        description: "hypr-colors.lua — border and accent colors",       icon: "window",   settingsKey: "matugenTemplateHyprland"    },
        { id: "mango",       name: "MangoWM (colors)", description: "colors.matugen.conf — Mango border colors (template-way)", icon: "window", settingsKey: "matugenTemplateMango" },
        { id: "gtk",         name: "GTK Theme",        description: "gtk-4.0/gtk.css and gtk-3.0/gtk-dark.css colors",  icon: "palette",  settingsKey: "matugenTemplateGtk"         },
        { id: "kcolorscheme",name: "KDE Color Scheme", description: "KDE Plasma color scheme",                          icon: "palette",  settingsKey: "matugenTemplateKcolorscheme"},
        { id: "qt5ct",       name: "Qt5 Settings",     description: "Qt5 application color scheme",                     icon: "tune",     settingsKey: "matugenTemplateQt5ct"       },
        { id: "qt6ct",       name: "Qt6 Settings",     description: "Qt6 application color scheme",                     icon: "tune",     settingsKey: "matugenTemplateQt6ct"       },
        { id: "kitty",       name: "Kitty",            description: "Terminal color scheme",                            icon: "terminal", settingsKey: "matugenTemplateKitty"       },
        { id: "ghostty",     name: "Ghostty",          description: "Terminal color scheme",                            icon: "terminal", settingsKey: "matugenTemplateGhostty"     },
        { id: "wezterm",     name: "WezTerm",          description: "Terminal color scheme",                            icon: "terminal", settingsKey: "matugenTemplateWezterm"     },
        { id: "alacritty",   name: "Alacritty",        description: "Terminal color scheme",                            icon: "terminal", settingsKey: "matugenTemplateAlacritty"   },
        { id: "foot",        name: "Foot",             description: "Terminal color scheme",                            icon: "terminal", settingsKey: "matugenTemplateFoot"        },
        { id: "otter",       name: "Otter / otter-term", description: "otter-term-matugen.conf (import from otter-term.conf)", icon: "terminal", settingsKey: "matugenTemplateOtterTerm" },
        { id: "btop",        name: "btop",             description: "~/.config/btop/themes/eh-matugen.theme",          icon: "memory",   settingsKey: "matugenTemplateBtop"        },
        { id: "neovim",      name: "Neovim",           description: "Editor color scheme",                              icon: "code",     settingsKey: "matugenTemplateNeovim"      },
        { id: "vscode",      name: "VS Code",          description: "material-code.colors in settings.json",            icon: "code",     settingsKey: "matugenTemplateVscode"      },
        { id: "zed",         name: "Zed",              description: "event-zed-theme.json under ~/.config/zed/themes/", icon: "code",     settingsKey: "matugenTemplateZed"         },
        { id: "firefox",     name: "Firefox",          description: "Browser userChrome colors",                        icon: "web",      settingsKey: "matugenTemplateFirefox"     },
        { id: "zenbrowser",  name: "Zen Browser",      description: "userChrome.css and userContent.css colors",        icon: "web",      settingsKey: "matugenTemplateZenbrowser"  },
        { id: "vesktop",     name: "Vesktop",          description: "Discord/Vesktop color overrides",                  icon: "chat",     settingsKey: "matugenTemplateVesktop"     },
        { id: "equibop",     name: "Equibop",          description: "Equibop Discord theme CSS (~/.config/equibop/themes/)", icon: "chat",  settingsKey: "matugenTemplateEquibop"     },
        { id: "pywalfox",    name: "PyWalFox",         description: "Firefox color theming via PyWal",                  icon: "web",      settingsKey: "matugenTemplatePywalfox"    },
        { id: "steam",       name: "Steam",            description: "MD3 CSS variables for Steam skin theming",         icon: "sports_esports", settingsKey: "matugenTemplateSteam" },
        { id: "dgop",        name: "dop (dgop)",       description: "App launcher color scheme",                        icon: "terminal", settingsKey: "matugenTemplateDgop"        },
        { id: "emacs",       name: "Emacs",            description: "Emacs color theme",                                icon: "code",     settingsKey: "matugenTemplateEmacs"       }
    ]

    // ── Filtered template list ────────────────────────────────────────────────

    property var filteredTemplates: {
        var s = searchText.toLowerCase().trim()
        if (s === "") return appTemplates
        return appTemplates.filter(function (t) {
            return t.name.toLowerCase().includes(s)
                || t.description.toLowerCase().includes(s)
                || t.id.toLowerCase().includes(s)
        })
    }

    // ── Template toggle helpers ───────────────────────────────────────────────

    function getTemplateEnabled(settingsKey) {
        switch (settingsKey) {
            case "matugenTemplateHyprland":    return SettingsData.matugenTemplateHyprland
            case "matugenTemplateMango":       return SettingsData.matugenTemplateMango
            case "matugenTemplateGtk":         return SettingsData.matugenTemplateGtk
            case "matugenTemplateKcolorscheme":return SettingsData.matugenTemplateKcolorscheme
            case "matugenTemplateQt5ct":       return SettingsData.matugenTemplateQt5ct
            case "matugenTemplateQt6ct":       return SettingsData.matugenTemplateQt6ct
            case "matugenTemplateKitty":       return SettingsData.matugenTemplateKitty
            case "matugenTemplateGhostty":     return SettingsData.matugenTemplateGhostty
            case "matugenTemplateWezterm":     return SettingsData.matugenTemplateWezterm
            case "matugenTemplateAlacritty":   return SettingsData.matugenTemplateAlacritty
            case "matugenTemplateFoot":        return SettingsData.matugenTemplateFoot
            case "matugenTemplateOtterTerm":   return SettingsData.matugenTemplateOtterTerm
            case "matugenTemplateBtop":        return SettingsData.matugenTemplateBtop
            case "matugenTemplateNeovim":      return SettingsData.matugenTemplateNeovim
            case "matugenTemplateVscode":      return SettingsData.matugenTemplateVscode
            case "matugenTemplateZed":         return SettingsData.matugenTemplateZed
            case "matugenTemplateFirefox":     return SettingsData.matugenTemplateFirefox
            case "matugenTemplateZenbrowser":  return SettingsData.matugenTemplateZenbrowser
            case "matugenTemplateVesktop":     return SettingsData.matugenTemplateVesktop
            case "matugenTemplateEquibop":      return SettingsData.matugenTemplateEquibop
            case "matugenTemplatePywalfox":    return SettingsData.matugenTemplatePywalfox
            case "matugenTemplateSteam":       return SettingsData.matugenTemplateSteam
            case "matugenTemplateDgop":        return SettingsData.matugenTemplateDgop
            case "matugenTemplateEmacs":       return SettingsData.matugenTemplateEmacs
            default:                           return true
        }
    }

    function setTemplateEnabled(settingsKey, enabled) {
        switch (settingsKey) {
            case "matugenTemplateHyprland":    SettingsData.setMatugenTemplateHyprland(enabled);    break
            case "matugenTemplateMango":       SettingsData.setMatugenTemplateMango(enabled);       break
            case "matugenTemplateGtk":         SettingsData.setMatugenTemplateGtk(enabled);         break
            case "matugenTemplateKcolorscheme":SettingsData.setMatugenTemplateKcolorscheme(enabled); break
            case "matugenTemplateQt5ct":       SettingsData.setMatugenTemplateQt5ct(enabled);       break
            case "matugenTemplateQt6ct":       SettingsData.setMatugenTemplateQt6ct(enabled);       break
            case "matugenTemplateKitty":       SettingsData.setMatugenTemplateKitty(enabled);       break
            case "matugenTemplateGhostty":     SettingsData.setMatugenTemplateGhostty(enabled);     break
            case "matugenTemplateWezterm":     SettingsData.setMatugenTemplateWezterm(enabled);     break
            case "matugenTemplateAlacritty":   SettingsData.setMatugenTemplateAlacritty(enabled);   break
            case "matugenTemplateFoot":        SettingsData.setMatugenTemplateFoot(enabled);        break
            case "matugenTemplateOtterTerm":  SettingsData.setMatugenTemplateOtterTerm(enabled);   break
            case "matugenTemplateBtop":        SettingsData.setMatugenTemplateBtop(enabled);        break
            case "matugenTemplateNeovim":      SettingsData.setMatugenTemplateNeovim(enabled);      break
            case "matugenTemplateVscode":      SettingsData.setMatugenTemplateVscode(enabled);      break
            case "matugenTemplateZed":         SettingsData.setMatugenTemplateZed(enabled);         break
            case "matugenTemplateFirefox":     SettingsData.setMatugenTemplateFirefox(enabled);     break
            case "matugenTemplateZenbrowser":  SettingsData.setMatugenTemplateZenbrowser(enabled);  break
            case "matugenTemplateVesktop":     SettingsData.setMatugenTemplateVesktop(enabled);     break
            case "matugenTemplateEquibop":     SettingsData.setMatugenTemplateEquibop(enabled);     break
            case "matugenTemplatePywalfox":    SettingsData.setMatugenTemplatePywalfox(enabled);    break
            case "matugenTemplateSteam":       SettingsData.setMatugenTemplateSteam(enabled);       break
            case "matugenTemplateDgop":        SettingsData.setMatugenTemplateDgop(enabled);        break
            case "matugenTemplateEmacs":       SettingsData.setMatugenTemplateEmacs(enabled);       break
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height
        contentWidth:  width

        Column {
            id: mainColumn
            width:   parent.width
            spacing: Theme.spacingXL

            // ── Header ────────────────────────────────────────────────────────
            StyledRect {
                width:  parent.width
                height: headerContent.childrenRect.height + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                                Theme.surfaceContainer.b, 0.6)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1

                Column {
                    id: headerContent
                    width: parent.width - Theme.spacingXL * 2
                    x: Theme.spacingXL
                    y: Theme.spacingXL
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingM
                        width:   parent.width

                        EHIcon {
                            name:  "description"
                            size:  Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text:            "Matugen Templates"
                            font.pixelSize:  Theme.fontSizeLarge
                            font.weight:     Font.Medium
                            color:           Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: "Select which application templates to apply when generating colors from your wallpaper."
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }

                    Row {
                        spacing: Theme.spacingS
                        visible: !Theme.matugenAvailable

                        EHIcon {
                            name:  "warning"
                            size:  Theme.fontSizeSmall
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text:           "matugen not found — template generation unavailable"
                            font.pixelSize: Theme.fontSizeSmall
                            color:          Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── Search ────────────────────────────────────────────────────────
            StyledRect {
                width:  parent.width
                height: searchContent.childrenRect.height + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                                Theme.surfaceContainer.b, 0.6)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1

                Column {
                    id: searchContent
                    width: parent.width - Theme.spacingXL * 2
                    x: Theme.spacingXL
                    y: Theme.spacingXL
                    spacing: Theme.spacingM

                    StyledText {
                        text:           "Search Templates"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    EHTextField {
                        width:           parent.width
                        placeholderText: "Search by name or description…"
                        text:            searchText
                        onTextChanged:   templatesTab.searchText = text
                    }
                }
            }

            // ── Event Horizon internal templates ──────────────────────────────
            StyledRect {
                width:   parent.width
                height:  ehContent.childrenRect.height + Theme.spacingL * 2
                radius:  Theme.cornerRadius
                color:   Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                                 Theme.surfaceContainer.b, 0.6)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: ehContent
                    width: parent.width - Theme.spacingXL * 2
                    x: Theme.spacingXL
                    y: Theme.spacingXL
                    spacing: Theme.spacingL

                    StyledText {
                        text:           "Event Horizon Templates"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    StyledText {
                        text:           "Internal templates that apply colors to Event Horizon components and features."
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingM

                        Row {
                            width:   parent.width
                            spacing: Theme.spacingM

                            EHToggle {
                                checked: SettingsData.runEHMatugenTemplates !== false
                                onToggled: toggled => {
                                    SettingsData.setRunEHMatugenTemplates(toggled)
                                }
                            }

                            Column {
                                width:   parent.width - 48 - Theme.spacingM
                                spacing: 2

                                StyledText {
                                    text:           "Event Horizon Templates"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color:          Theme.surfaceText
                                    font.weight:    Font.Medium
                                }

                                StyledText {
                                    text:           "Apply colors to Event Horizon configuration files"
                                    font.pixelSize: Theme.fontSizeXS
                                    color:          Theme.surfaceVariantText
                                }
                            }
                        }

                        Row {
                            width:   parent.width
                            spacing: Theme.spacingM

                            EHToggle {
                                checked: SettingsData.matugenTemplateNiri
                                onToggled: toggled => {
                                    SettingsData.setMatugenTemplateNiri(toggled)
                                }
                            }

                            Column {
                                width:   parent.width - 48 - Theme.spacingM
                                spacing: 2

                                StyledText {
                                    text:           "Niri Colors"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color:          Theme.surfaceText
                                    font.weight:    Font.Medium
                                }

                                StyledText {
                                    text:           "Apply colors to Niri window borders"
                                    font.pixelSize: Theme.fontSizeXS
                                    color:          Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }
            }

            // ── Application templates ─────────────────────────────────────────
            StyledRect {
                width:   parent.width
                height:  appContent.childrenRect.height + Theme.spacingL * 2
                radius:  Theme.cornerRadius
                color:   Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                                 Theme.surfaceContainer.b, 0.6)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                enabled: Theme.matugenAvailable
                opacity: enabled ? 1 : 0.4

                Column {
                    id: appContent
                    width: parent.width - Theme.spacingXL * 2
                    x: Theme.spacingXL
                    y: Theme.spacingXL
                    spacing: Theme.spacingL

                    StyledText {
                        text:           "Application Templates"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    StyledText {
                        text:           "Toggle templates on or off to control which applications receive color updates."
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            model: templatesTab.filteredTemplates

                            delegate: TemplateToggleRow {
                                required property var modelData
                                templateData: modelData
                            }
                        }

                        StyledText {
                            text:           "No templates match your search."
                            font.pixelSize: Theme.fontSizeSmall
                            color:          Theme.surfaceVariantText
                            visible:        templatesTab.filteredTemplates.length === 0
                                         && templatesTab.searchText !== ""
                        }
                    }
                }
            }

            // ── Info ──────────────────────────────────────────────────────────
            StyledRect {
                width:   parent.width
                height:  infoContent.childrenRect.height + Theme.spacingL * 2
                radius:  Theme.cornerRadius
                color:   Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                                 Theme.surfaceContainer.b, 0.4)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                border.width: 1

                Column {
                    id: infoContent
                    width: parent.width - Theme.spacingXL * 2
                    x: Theme.spacingXL
                    y: Theme.spacingXL
                    spacing: Theme.spacingM

                    Row {
                        spacing: Theme.spacingS

                        EHIcon {
                            name:  "info"
                            size:  Theme.fontSizeSmall
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text:           "How Templates Work"
                            font.pixelSize: Theme.fontSizeSmall
                            color:          Theme.surfaceText
                            font.weight:    Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: "When matugen generates colors from your wallpaper it reads template files from "
                            + "~/.config/quickshell/matugen/templates/ and writes colorized configs to each "
                            + "application's config directory. Toggle templates on or off to control which "
                            + "applications receive color updates."
                        font.pixelSize: Theme.fontSizeXS
                        color:          Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }

                    StyledText {
                        text:           "Template files: ~/.config/quickshell/matugen/templates/"
                        font.pixelSize: Theme.fontSizeXS
                        color:          Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }
                }
            }

            Item { width: parent.width; height: Theme.spacingXL }
        }
    }

    // ── TemplateToggleRow inline component ────────────────────────────────────

    component TemplateToggleRow: Rectangle {
        id: toggleRow

        property var templateData: null

        width:  parent.width
        height: 70
        radius: Theme.cornerRadius
        color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g,
                        Theme.surfaceContainer.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        Row {
            anchors {
                fill:    parent
                margins: Theme.spacingM
            }
            spacing: Theme.spacingM

            EHToggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: templatesTab.getTemplateEnabled(toggleRow.templateData?.settingsKey ?? "")
                onToggled: toggled => {
                    templatesTab.setTemplateEnabled(toggleRow.templateData?.settingsKey ?? "", toggled)
                }
            }

            Column {
                width:   parent.width - 48 - Theme.spacingM
                spacing: 2

                Row {
                    spacing: Theme.spacingS

                    EHIcon {
                        name:  toggleRow.templateData?.icon ?? "app"
                        size:  Theme.fontSizeSmall
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text:           toggleRow.templateData?.name ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceText
                        font.weight:    Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text:           toggleRow.templateData?.description ?? ""
                    font.pixelSize: Theme.fontSizeXS
                    color:          Theme.surfaceVariantText
                    wrapMode:       Text.WordWrap
                    width:          parent.width
                }
            }
        }
    }
}
