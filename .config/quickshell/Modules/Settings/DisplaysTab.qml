import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {
    id: displaysTab

    property var parentModal: null
    property bool nested: false

    readonly property real toggleColWidth: 80
    readonly property real rowHeight: 56
    readonly property real nameColWidth: 200

    property var variantComponents: [
        { "id": "topBar",         "name": "Top Bar",             "icon": "toolbar"            },
        { "id": "dock",           "name": "Application Dock",    "icon": "dock"               },
        { "id": "taskBar",        "name": "Task Bar",            "icon": "toolbar"            },
        { "id": "miniPanel",      "name": "Mini Panel",          "icon": "space_dashboard"    },
        { "id": "notifications",  "name": "Notification Popups", "icon": "notifications"      },
        { "id": "wallpaper",      "name": "Wallpaper",           "icon": "wallpaper"          },
        { "id": "osd",            "name": "On-Screen Displays",  "icon": "picture_in_picture" },
        { "id": "toast",          "name": "Toast Messages",      "icon": "campaign"           },
        { "id": "notepad",        "name": "Notepad Slideout",    "icon": "sticky_note_2"      },
        { "id": "systemTray",     "name": "System Tray",         "icon": "notifications"      },
        { "id": "desktopWidgets", "name": "Desktop Widgets",     "icon": "widgets"            },
        { "id": "launchpad",      "name": "Launchpad",           "icon": "apps"               },
        { "id": "appDrawer",      "name": "App Drawer",          "icon": "grid_view"          },
        { "id": "dockAppDrawer",      "name": "Dock App Drawer",      "icon": "grid_view"          },
        { "id": "taskBarAppDrawer",   "name": "TaskBar App Drawer",   "icon": "grid_view"          },
        { "id": "miniPanelAppDrawer", "name": "MiniPanel App Drawer", "icon": "grid_view"          },
        { "id": "alttab",         "name": "Alt+Tab Switcher",    "icon": "swap_horiz"         },
        { "id": "workspaceOverview", "name": "Workspace Overview",  "icon": "space_dashboard"    }
    ]

    function getScreenPreferences(componentId) {
        var prefs = SettingsData.screenPreferences && SettingsData.screenPreferences[componentId]
        if (!prefs || prefs.length === 0) return ["all"]
        return prefs
    }

    function setScreenPreferences(componentId, screenNames) {
        var prefs = SettingsData.screenPreferences ? Object.assign({}, SettingsData.screenPreferences) : {}
        prefs[componentId] = screenNames
        SettingsData.setScreenPreferences(prefs)
    }

    function isOnAll(componentId) {
        var prefs = getScreenPreferences(componentId)
        return !Array.isArray(prefs) || prefs.includes("all")
    }

    function isOnScreen(componentId, screenName) {
        var prefs = getScreenPreferences(componentId)
        if (!Array.isArray(prefs) || prefs.includes("all")) return false
        return prefs.some(p => typeof p === "string" ? p === screenName : p?.name === screenName)
    }

    function toggleScreen(componentId, screenName, currentlyActive) {
        var cur = getScreenPreferences(componentId)
        if (isOnAll(componentId)) {
            // Switch from All → just this screen
            setScreenPreferences(componentId, [screenName])
            return
        }
        var next = cur.slice()
        if (currentlyActive) {
            next = next.filter(p => typeof p === "string" ? p !== screenName : p?.name !== screenName)
            if (next.length === 0) next = ["all"]
        } else {
            if (!next.some(p => typeof p === "string" ? p === screenName : p?.name === screenName))
                next.push(screenName)
        }
        setScreenPreferences(componentId, next)
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        interactive: !displaysTab.nested
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ══════════════════════════════════════════════════════════════
            // SECTION 1: Connected Displays — big monitor cards
            // ══════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: connectedSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: connectedSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "monitor"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            StyledText {
                                text: "Connected Displays"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: Quickshell.screens.length + " screen" + (Quickshell.screens.length !== 1 ? "s" : "") + " detected"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // Monitor cards — same look as the arrangement widget
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            model: Quickshell.screens

                            delegate: Rectangle {
                                // Equal-width cards across the row
                                width: (parent.width - Theme.spacingM * (Quickshell.screens.length - 1)) / Math.max(1, Quickshell.screens.length)
                                height: 140
                                radius: Theme.cornerRadius * 1.5
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS
                                    width: parent.width * 0.85

                                    // Big bold name
                                    StyledText {
                                        width: parent.width
                                        text: modelData.name
                                        font.pixelSize: Math.max(28, Math.min(parent.width / 4, 48))
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    // Model name
                                    StyledText {
                                        width: parent.width
                                        text: modelData.model || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }

                                    // Resolution
                                    StyledText {
                                        width: parent.width
                                        text: modelData.width + "×" + modelData.height
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.6)
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // SECTION 2: Component Screen Assignment
            // ══════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: assignmentSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: assignmentSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        EHIcon { name: "settings_input_component"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            StyledText {
                                text: "Component Screen Assignment"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Choose which displays each shell component appears on"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // Column header row — "All" + one label per screen
                    Item {
                        width: parent.width
                        height: 32

                        Row {
                            anchors.right: parent.right

                            StyledText {
                                width: displaysTab.toggleColWidth
                                text: "All"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Repeater {
                                model: Quickshell.screens
                                delegate: StyledText {
                                    width: displaysTab.toggleColWidth
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceVariantText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Divider under header
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    // Component rows
                    Repeater {
                        model: displaysTab.variantComponents

                        delegate: Item {
                            id: compRow
                            width: parent.width
                            height: displaysTab.rowHeight

                            property string compId: modelData.id
                            property bool onAll: displaysTab.isOnAll(compId)

                            // Hover tint
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: rowHover.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                            // Icon + Name
                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                EHIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize - 2
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Dot columns pinned to the right
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                // "All" dot
                                Item {
                                    width: displaysTab.toggleColWidth
                                    height: displaysTab.rowHeight

                                    AssignDot {
                                        anchors.centerIn: parent
                                        active: compRow.onAll
                                        dimmed: false
                                        onClicked: {
                                            if (!compRow.onAll)
                                                displaysTab.setScreenPreferences(compRow.compId, ["all"])
                                        }
                                    }
                                }

                                // Per-screen dots
                                Repeater {
                                    model: Quickshell.screens

                                    delegate: Item {
                                        width: displaysTab.toggleColWidth
                                        height: displaysTab.rowHeight

                                        property string sn: modelData.name
                                        property bool screenActive: displaysTab.isOnScreen(compRow.compId, sn)

                                        AssignDot {
                                            anchors.centerIn: parent
                                            active: parent.screenActive
                                            dimmed: compRow.onAll
                                            onClicked: displaysTab.toggleScreen(compRow.compId, parent.sn, parent.screenActive)
                                        }
                                    }
                                }
                            }

                            // Row divider
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.outline
                                opacity: 0.1
                                visible: index < displaysTab.variantComponents.length - 1
                            }
                        }
                    }
                }
            }
        }
    }

    // Reusable radio-style dot
    component AssignDot: Item {
        id: adot
        width: 32
        height: 32
        property bool active: false
        property bool dimmed: false
        signal clicked()

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: 13
            color: adot.active
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
            border.color: adot.active
                ? Theme.primary
                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
            border.width: adot.active ? 2 : 1
            opacity: adot.dimmed ? 0.28 : 1.0

            Behavior on color        { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
            Behavior on opacity      { NumberAnimation { duration: 130 } }

            Rectangle {
                anchors.centerIn: parent
                width: 11; height: 11; radius: 5.5
                color: Theme.primary
                visible: adot.active && !adot.dimmed
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: adot.dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: adot.clicked()
        }
    }
}