import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Settings
import qs.Services
import qs.Widgets

Item {
    id: sidebarContainer

    property int currentIndex: 0
    property var parentModal: null
    property var expandedCategories: null

    // ── Collapsed / expanded state ────────────────────────────────────────────
    property bool collapsed: SettingsData.settingsSidebarCollapsed

    onCollapsedChanged: {
        SettingsData.setSettingsSidebarCollapsed(collapsed)
    }

    property int collapsedW: 64
    property int expandedW:  240

    // effectiveWidth tracks the animated panel so SettingsModal content reflows smoothly
    property int effectiveWidth: sidebarBg.width

    // ── Navigation data ───────────────────────────────────────────────────────
    readonly property var sidebarItems: [{
        "id": "user",
        "text": "User",
        "icon": "person",
        "tabIndex": 0
    }, {
        "id": "themeColors",
        "text": "Appearance",
        "icon": "palette",
        "children": [{
            "text": "Personalization",
            "icon": "person",
            "tabIndex": 98
        }, {
            "text": "Fonts",
            "icon": "font_download",
            "tabIndex": 99
        }, {
            "text": "Colors & Themes",
            "icon": "colorize",
            "tabIndex": 100
        }, {
            "text": "Appearance",
            "icon": "opacity",
            "tabIndex": 101
        }, {
            "text": "Components",
            "icon": "dashboard",
            "tabIndex": 102
        }, {
            "text": "System & Settings",
            "icon": "settings",
            "tabIndex": 103
        }, {
            "text": "Wallpaper",
            "icon": "wallpaper",
            "tabIndex": 3
        }, {
            "text": "BingWallpaper",
            "icon": "image",
            "tabIndex": 115
        }, {
            "text": "Matugen",
            "icon": "tune",
            "tabIndex": 114
        }, {
            "text": "Templates",
            "icon": "description",
            "tabIndex": 116
        }]
    }, {
        "id": "hyprlandTheme",
        "text": "Hyprland Theme",
        "icon": "window",
        "requireHyprland": true,
        "children": [{
            "text": "Border Colors",
            "icon": "palette",
            "tabIndex": 105
        }, {
            "text": "Window Rounding",
            "icon": "rounded_corner",
            "tabIndex": 106
        }, {
            "text": "Render",
            "icon": "settings",
            "tabIndex": 107
        }, {
            "text": "Input",
            "icon": "keyboard",
            "tabIndex": 108
        }, {
            "text": "Cursor",
            "icon": "mouse",
            "tabIndex": 109
        }, {
            "text": "General",
            "icon": "tune",
            "tabIndex": 110
        }, {
            "text": "Snap",
            "icon": "grid_view",
            "tabIndex": 111
        }, {
            "text": "Groupbar",
            "icon": "view_carousel",
            "tabIndex": 112
        }, {
            "text": "Dwindle",
            "icon": "splitscreen",
            "tabIndex": 113
        }, {
            "text": "Master",
            "icon": "view_agenda",
            "tabIndex": 117
        }, {
            "text": "Scrolling",
            "icon": "swap_vert",
            "tabIndex": 118
        }, {
            "text": "Monocle",
            "icon": "fullscreen",
            "tabIndex": 119
        }, {
            "text": "Animations",
            "icon": "animation",
            "tabIndex": 122
        }]
    }, {
        "id": "niriTheme",
        "text": "Niri Theme",
        "icon": "window",
        "requireNiri": true,
        "children": [{
            "text": "Border Colors",
            "icon": "palette",
            "tabIndex": 120
        }, {
            "text": "Layout",
            "icon": "grid_view",
            "tabIndex": 121
        }]
    }, {
        "id": "mangoTheme",
        "text": "MangoWM",
        "icon": "window",
        "requireMango": true,
        "children": [{
            "text": "Decorations",
            "icon": "blur_on",
            "tabIndex": 123
        }, {
            "text": "Colors",
            "icon": "palette",
            "tabIndex": 128
        }, {
            "text": "Animations",
            "icon": "animation",
            "tabIndex": 124
        }, {
            "text": "Keybinds",
            "icon": "keyboard",
            "tabIndex": 125
        }, {
            "text": "Layout",
            "icon": "grid_view",
            "tabIndex": 126
        }, {
            "text": "Input",
            "icon": "keyboard",
            "tabIndex": 127
        }, {
            "text": "Misc",
            "icon": "settings",
            "tabIndex": 130
        }]
    }, {
        "id": "panelsUi",
        "text": "Panels & UI",
        "icon": "view_quilt",
        "children": [{
            "text": "Task Bar",
            "icon": "view_agenda",
            "tabIndex": 4
        }, {
            "text": "Top Bar",
            "icon": "toolbar",
            "tabIndex": 5
        }, {
            "text": "Dock",
            "icon": "dock_to_bottom",
            "tabIndex": 6
        }, {
            "text": "Control Center",
            "icon": "settings_suggest",
            "tabIndex": 25
        }, {
            "text": "Mini Panel",
            "icon": "space_dashboard",
            "tabIndex": 23
        }, {
            "text": "Desktop Widgets",
            "icon": "widgets",
            "tabIndex": 8
        }, {
            "text": "Launcher",
            "icon": "apps",
            "tabIndex": 10
        }]
    }, {
        "id": "workspacesCategory",
        "text": "Workspaces",
        "icon": "view_carousel",
        "children": [{
            "text": "Workspaces",
            "icon": "view_week",
            "tabIndex": 7
        }, {
            "text": "Workspace Overview",
            "icon": "space_dashboard",
            "tabIndex": 24
        }, {
            "text": "Layout Manager",
            "icon": "dashboard_customize",
            "tabIndex": 22
        }, {
            "text": "Keybinds",
            "icon": "keyboard",
            "tabIndex": 21
        }]
    }, {
        "id": "systemCategory",
        "text": "System",
        "icon": "settings",
        "children": [{
            "text": "UI Layout",
            "icon": "monitor",
            "tabIndex": 104
        }, {
            "text": "Notifications",
            "icon": "notifications",
            "tabIndex": 129
        }, {
            "text": "Default Apps",
            "icon": "apps",
            "tabIndex": 11
        }, {
            "text": "Monitors",
            "icon": "settings",
            "tabIndex": 12
        }, {
            "text": "Sound",
            "icon": "volume_up",
            "tabIndex": 13
        }, {
            "text": "Network",
            "icon": "wifi",
            "tabIndex": 14
        }, {
            "text": "Bluetooth",
            "icon": "bluetooth",
            "tabIndex": 15
        }, {
            "text": "Keyboard & Language",
            "icon": "keyboard",
            "tabIndex": 16
        }, {
            "text": "Time & Date",
            "icon": "schedule",
            "tabIndex": 17
        }, {
            "text": "Power",
            "icon": "power_settings_new",
            "tabIndex": 18
        }, {
            "text": "Weather",
            "icon": "cloud",
            "tabIndex": 20
        }, {
            "text": "Updates",
            "icon": "system_update",
            "tabIndex": 26
        }, {
            "text": "System Updates",
            "icon": "computer",
            "tabIndex": 27
        }]
    }]

    // ── Flat list of every tab for collapsed icon-only view ───────────────────
    readonly property var flatItems: {
        var result = []
        for (var i = 0; i < sidebarItems.length; i++) {
            var item = sidebarItems[i]
            // compositor visibility filter
            var show = true
            if (item.requireHyprland && typeof CompositorService !== 'undefined')
                show = CompositorService.isHyprland
            if (item.requireNiri && typeof CompositorService !== 'undefined')
                show = CompositorService.isNiri
            if (item.requireMango && typeof CompositorService !== 'undefined')
                show = CompositorService.isMango
            if (!show) continue
            if (item.children && item.children.length > 0) {
                for (var j = 0; j < item.children.length; j++) {
                    result.push(item.children[j])
                }
            } else {
                result.push(item)
            }
        }
        return result
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function toggleCategory(categoryId) {
        var current = expandedCategories || {}
        var newExpanded = Object.assign({}, current)
        newExpanded[categoryId] = !isCategoryExpanded(categoryId)
        expandedCategories = newExpanded
    }

    function isCategoryExpanded(categoryId) {
        var ec = expandedCategories || {}
        if (ec[categoryId] !== undefined)
            return ec[categoryId]
        var category = sidebarItems.find(item => item.id === categoryId)
        if (category && category.children)
            return category.children.some(child => child.tabIndex === currentIndex)
        return false
    }

    function resolveTabIndex(tabName) {
        for (var i = 0; i < sidebarItems.length; i++) {
            var item = sidebarItems[i]
            if (item.text === tabName) return item.tabIndex !== undefined ? item.tabIndex : -1
            if (item.children) {
                for (var j = 0; j < item.children.length; j++) {
                    if (item.children[j].text === tabName) return item.children[j].tabIndex
                }
            }
        }
        return -1
    }

    function focusSearch() { /* no search in this design */ }

    // ── Sizing ────────────────────────────────────────────────────────────────
    height: parent.height

    // =========================================================================
    // SIDEBAR PANEL
    // =========================================================================
    Rectangle {
        id: sidebarBg
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        // Smoothly animate between collapsed and expanded
        width: collapsed ? collapsedW : expandedW
        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        color: Qt.rgba(Theme.surfaceContainer.r,
                       Theme.surfaceContainer.g,
                       Theme.surfaceContainer.b, 0.55)
        radius: Theme.cornerRadius
        clip: true
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        // ── User header ───────────────────────────────────────────────────────
        Item {
            id: topBar
            width: parent.width
            height: collapsed ? 68 : 118
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            clip: true

            // ── COLLAPSED: avatar circle + hover tooltip ──────────────────────
            Item {
                anchors.fill: parent
                visible: collapsed

                // Avatar circle
                Rectangle {
                    id: collapsedAvatar
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                    border.width: 1.5
                    clip: true

                    EHCircularImage {
                        anchors.fill: parent
                        imageSource: {
                            if (typeof PortalService === "undefined" || PortalService.profileImage === "") return ""
                            return PortalService.profileImage.startsWith("/")
                                ? "file://" + PortalService.profileImage
                                : PortalService.profileImage
                        }
                        fallbackIcon: "person"
                    }

                    MouseArea {
                        id: avatarHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebarContainer.currentIndex = 0
                    }
                }

                // Tooltip to the right of the sidebar
                Rectangle {
                    visible: avatarHover.containsMouse
                    anchors.left: parent.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: tooltipCol.implicitWidth + 20
                    height: tooltipCol.implicitHeight + 12
                    radius: 10
                    color: Qt.rgba(Theme.surfaceContainer.r,
                                   Theme.surfaceContainer.g,
                                   Theme.surfaceContainer.b, 0.97)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    z: 999

                    Column {
                        id: tooltipCol
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            text: (typeof UserInfoService !== "undefined" && UserInfoService.fullName)
                                ? UserInfoService.fullName : "User"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: (typeof DgopService !== "undefined" && DgopService.hostname)
                                ? DgopService.hostname : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                            visible: text !== ""
                        }
                    }
                }
            }

            // ── EXPANDED: full ProfileSection ─────────────────────────────────
            ProfileSection {
                id: profileSection
                parentModal: sidebarContainer.parentModal
                visible: !collapsed
                opacity: collapsed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 180 } }
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Divider under top bar
        Rectangle {
            anchors.top: topBar.bottom
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        // ── Scrollable nav list ───────────────────────────────────────────────
        EHFlickable {
            id: sidebarFlickable
            anchors.top: topBar.bottom
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            contentHeight: navColumn.implicitHeight
            contentWidth: width
            clip: true

            Column {
                id: navColumn
                width: parent.width
                spacing: 2
                topPadding: 8
                bottomPadding: 8

                // =============================================================
                // COLLAPSED — flat icon list, every tab visible, no categories
                // =============================================================
                Repeater {
                    model: collapsed ? sidebarContainer.flatItems : []

                    Item {
                        id: flatRow
                        required property int index
                        required property var modelData
                        property bool isActive: sidebarContainer.currentIndex === modelData.tabIndex

                        width: navColumn.width
                        height: 38

                        // Active pill
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            radius: 10
                            color: flatRow.isActive
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                : (flatHover.containsMouse
                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.07)
                                    : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                        }

                        // Active left accent
                        Rectangle {
                            visible: flatRow.isActive
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 18; radius: 2
                            color: Theme.primary
                        }

                        // Icon centred
                        EHIcon {
                            anchors.centerIn: parent
                            name: flatRow.modelData.icon || ""
                            size: 19
                            color: flatRow.isActive
                                ? Theme.primary
                                : (flatHover.containsMouse
                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.9)
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55))
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        // Tooltip on hover
                        Rectangle {
                            visible: flatHover.containsMouse
                            anchors.left: parent.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: flatTip.implicitWidth + 16
                            height: 28
                            radius: 8
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.97)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                            border.width: 1
                            z: 999

                            StyledText {
                                id: flatTip
                                anchors.centerIn: parent
                                text: flatRow.modelData.text || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }

                        MouseArea {
                            id: flatHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebarContainer.currentIndex = flatRow.modelData.tabIndex
                        }
                    }
                }

                // =============================================================
                // EXPANDED — grouped tree with categories + children
                // =============================================================
                Repeater {
                    model: collapsed ? [] : sidebarContainer.sidebarItems

                    Column {
                        id: navGroup
                        required property int index
                        required property var modelData

                        property bool hasChildren: !!(modelData.children && modelData.children.length > 0)
                        property bool isExpanded: hasChildren
                            ? sidebarContainer.isCategoryExpanded(modelData.id || "")
                            : false
                        property bool isCategoryActive: hasChildren
                            ? modelData.children.some(c => c.tabIndex === sidebarContainer.currentIndex)
                            : false
                        property bool isActive: !hasChildren
                            && sidebarContainer.currentIndex === (modelData.tabIndex !== undefined ? modelData.tabIndex : index)
                        property bool shouldShow: {
                            if (modelData.requireHyprland && typeof CompositorService !== 'undefined')
                                return CompositorService.isHyprland
                            if (modelData.requireNiri && typeof CompositorService !== 'undefined')
                                return CompositorService.isNiri
                            if (modelData.requireMango && typeof CompositorService !== 'undefined')
                                return CompositorService.isMango
                            return true
                        }

                        width: parent.width
                        spacing: 0
                        visible: shouldShow

                        // ── Category / top-level row ──────────────────────────
                        Item {
                            id: navRow
                            width: parent.width
                            height: 42

                            property bool isActive: navGroup.isActive || navGroup.isCategoryActive

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                radius: 10
                                color: {
                                    if (navRow.isActive)
                                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                    if (rowHover.containsMouse)
                                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.07)
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 10

                                Item {
                                    width: 22
                                    height: parent.height

                                    EHIcon {
                                        anchors.centerIn: parent
                                        name: navGroup.modelData.icon || ""
                                        size: 20
                                        color: navRow.isActive
                                            ? Theme.primary
                                            : (rowHover.containsMouse
                                                ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.9)
                                                : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6))
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }

                                Item {
                                    width: parent.width - 22 - 10
                                    height: parent.height

                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.right: chevronIcon.visible ? chevronIcon.left : parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: navGroup.modelData.text || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: navRow.isActive ? 600 : 400
                                        color: navRow.isActive
                                            ? Theme.primary
                                            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
                                        elide: Text.ElideRight
                                    }

                                    EHIcon {
                                        id: chevronIcon
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: navGroup.isExpanded ? "expand_less" : "expand_more"
                                        size: 16
                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                                        visible: navGroup.hasChildren
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (navGroup.hasChildren)
                                        sidebarContainer.toggleCategory(navGroup.modelData.id || "")
                                    else
                                        sidebarContainer.currentIndex = navGroup.modelData.tabIndex !== undefined
                                            ? navGroup.modelData.tabIndex : navGroup.index
                                }
                            }
                        }

                        // ── Children sub-items ────────────────────────────────
                        Column {
                            width: parent.width
                            spacing: 1
                            topPadding: 2
                            bottomPadding: 4
                            visible: navGroup.hasChildren && navGroup.isExpanded
                            clip: true
                            height: visible ? implicitHeight : 0
                            Behavior on height {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Repeater {
                                model: navGroup.modelData.children || []

                                Item {
                                    id: childRow
                                    required property int index
                                    required property var modelData
                                    property bool isActive: sidebarContainer.currentIndex === modelData.tabIndex

                                    width: parent.width
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        radius: 8
                                        color: {
                                            if (childRow.isActive)
                                                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                            if (childHover.containsMouse)
                                                return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                            return "transparent"
                                        }
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 36
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        EHIcon {
                                            name: childRow.modelData.icon || ""
                                            size: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: childRow.isActive
                                                ? Theme.primary
                                                : (childHover.containsMouse
                                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5))
                                        }

                                        StyledText {
                                            text: childRow.modelData.text || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: childRow.isActive ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: childRow.isActive
                                                ? Theme.primary
                                                : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.75)
                                            width: parent.width - 16 - 8
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: childHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sidebarContainer.currentIndex = childRow.modelData.tabIndex
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
