import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: wallpaperTab

    property var parentModal: null
    property string selectedMonitorName: {
        var screens = Quickshell.screens
        return screens.length > 0 ? screens[0].name : ""
    }
    property var monitors: []
    property var monitorCapabilities: ({})
    property bool loading: false
    property string wallpaperGalleryDir: ""
    property int galleryCurrentPage: 0
    readonly property int galleryItemsPerPage: SessionData.galleryColumns * SessionData.galleryRows
    property int galleryTotalPages: Math.max(1, Math.ceil(filteredCount / galleryItemsPerPage))
    property int galleryGridIndex: 0

    // Sort mode: "name" | "oldest" | "newest"
    property string gallerySortMode: "name"

    // Total count after sort/filter (equals model count because FolderListModel handles filtering)
    property int filteredCount: wallpaperGalleryModel.count

    readonly property string defaultWallpaperPath: {
        var shellDir = Paths.strip(Qt.resolvedUrl("../../").toString())
        return shellDir + "/assets/Default-Wallpaper.jpg"
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function resolveWallpaper() {
        return SessionData.perMonitorWallpaper
            ? SessionData.getMonitorWallpaper(selectedMonitorName)
            : SessionData.wallpaperPath
    }

    function isImageWallpaper(wp) {
        return wp && wp !== "" && !wp.startsWith("#") && !wp.startsWith("we:")
    }

    function setDefaultWallpaper() {
        if (SessionData.perMonitorWallpaper) {
            SessionData.setMonitorWallpaper(selectedMonitorName, defaultWallpaperPath)
        } else {
            if (Theme.currentTheme === Theme.dynamic) Theme.switchTheme("blue")
            SessionData.setWallpaper(defaultWallpaperPath)
        }
    }

    function applyWallpaper(path) {
        if (!path) return
        if (SessionData.perMonitorWallpaper) {
            SessionData.setMonitorWallpaper(selectedMonitorName, path)
        } else {
            SessionData.setWallpaper(path)
        }
        if (typeof ColorPaletteService !== 'undefined') {
            ColorPaletteService.onWallpaperChanged(path)
        }
    }

    onGalleryCurrentPageChanged: saveGalleryPage()
    onGallerySortModeChanged: {
        saveSortMode()
        // Apply sort to FolderListModel
        if (gallerySortMode === "oldest") {
            wallpaperGalleryModel.sortField = FolderListModel.Time
            wallpaperGalleryModel.sortReversed = true
        } else if (gallerySortMode === "newest") {
            wallpaperGalleryModel.sortField = FolderListModel.Time
            wallpaperGalleryModel.sortReversed = false
        } else {
            wallpaperGalleryModel.sortField = FolderListModel.Name
            wallpaperGalleryModel.sortReversed = false
        }
        galleryCurrentPage = 0
    }

    Component.onCompleted: {
        loadMonitors()
        Qt.callLater(() => { loadWallpaperGalleryDir() })
    }

    function loadWallpaperGalleryDir() {
        if (SessionData.wallpaperLastPath && SessionData.wallpaperLastPath !== "") {
            wallpaperGalleryDir = SessionData.wallpaperLastPath
        } else {
            var wp = resolveWallpaper()
            if (isImageWallpaper(wp)) {
                var lastSlash = wp.lastIndexOf('/')
                if (lastSlash > 0) {
                    wallpaperGalleryDir = wp.substring(0, lastSlash)
                    SessionData.wallpaperLastPath = wallpaperGalleryDir
                    SessionData.saveSettings()
                }
            }
        }
        // Restore last page
        if (SessionData.wallpaperLastPage !== undefined && SessionData.wallpaperLastPage > 0)
            galleryCurrentPage = SessionData.wallpaperLastPage
        // Restore sort mode
        if (SessionData.wallpaperSortMode && SessionData.wallpaperSortMode !== "")
            gallerySortMode = SessionData.wallpaperSortMode
    }

    function saveGalleryPage() {
        SessionData.wallpaperLastPage = galleryCurrentPage
        SessionData.saveSettings()
    }

    function saveSortMode() {
        SessionData.wallpaperSortMode = gallerySortMode
        SessionData.saveSettings()
    }

    function loadMonitors() {
        loading = true
        monitors = []
        monitorCapabilities = {}
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            var screen = screens[i]
            monitors.push({
                name: screen.name, width: screen.width, height: screen.height,
                scale: "1.0", position: "", disabled: false
            })
            monitorCapabilities[screen.name] = {
                width: screen.width, height: screen.height,
                make: screen.manufacturer || "", model: screen.model || "",
                description: screen.name
            }
        }
        loading = false
    }

    // =========================================================================
    // UI
    // =========================================================================
    // SUB-TAB SELECTION
    // =========================================================================
    property int currentSubTab: 0  // 0 = Wallpaper, 1 = Gallery Settings

    // Tab bar
    Row {
        id: subTabBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48
        z: 10

        // Wallpaper tab button
        Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: Theme.cornerRadius
            color: wallpaperTab.currentSubTab === 0 ? Theme.primary : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
            border.color: wallpaperTab.currentSubTab === 0 ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                EHIcon {
                    name: "wallpaper"
                    size: 20
                    color: wallpaperTab.currentSubTab === 0 ? "white" : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Wallpaper"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: wallpaperTab.currentSubTab === 0 ? "white" : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wallpaperTab.currentSubTab = 0
            }
        }

        // Gallery Settings tab button
        Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: Theme.cornerRadius
            color: wallpaperTab.currentSubTab === 1 ? Theme.primary : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
            border.color: wallpaperTab.currentSubTab === 1 ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                EHIcon {
                    name: "tune"
                    size: 20
                    color: wallpaperTab.currentSubTab === 1 ? "white" : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Gallery Settings"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: wallpaperTab.currentSubTab === 1 ? "white" : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wallpaperTab.currentSubTab = 1
            }
        }
    }

    // =========================================================================

    EHFlickable {
        anchors.topMargin: 48  // Space for tab bar
        anchors.fill: parent
        clip: true
        contentHeight: rootColumn.implicitHeight
        contentWidth: width

        visible: wallpaperTab.currentSubTab === 0

        Column {
            id: rootColumn
            width: parent.width
            spacing: 0  // We handle spacing manually for full control

            // =================================================================
            // HERO BANNER — rounded card, matches the rest of the UI
            // =================================================================
            Item {
                id: heroBannerOuter
                width: parent.width
                height: 260 + Theme.spacingL * 2

                // Mask source for rounded corners — mirrors heroBanner's size
                Rectangle {
                    id: heroBannerMask
                    width: heroBanner.width
                    height: heroBanner.height
                    radius: heroBanner.radius
                    color: "black"
                    visible: false
                }

                // Rounded clipping container
                Rectangle {
                    id: heroBanner
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingL
                    anchors.bottomMargin: Theme.spacingL
                    radius: 8  // Fixed 8px radius for banner
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 1.0)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                    border.width: 1

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.0
                        maskSpreadAtMin: 1.0
                        maskSource: ShaderEffectSource {
                            sourceItem: heroBannerMask
                            hideSource: false
                            live: true
                        }
                    }

                // Full bleed background image
                CachingImage {
                    id: heroImage
                    anchors.fill: parent
                    imagePath: {
                        var wp = wallpaperTab.resolveWallpaper()
                        return wallpaperTab.isImageWallpaper(wp) ? wp : ""
                    }
                    fillMode: Image.PreserveAspectCrop
                    maxCacheSize: 2048
                    visible: imagePath !== ""
                }

                // Solid color fill when wallpaper is a colour hex
                Rectangle {
                    anchors.fill: parent
                    color: {
                        var wp = wallpaperTab.resolveWallpaper()
                        return (wp && wp.startsWith("#")) ? wp : "transparent"
                    }
                    visible: {
                        var wp = wallpaperTab.resolveWallpaper()
                        return wp && wp.startsWith("#")
                    }
                }

                // Placeholder when nothing is set
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    visible: heroImage.imagePath === "" && !colorFillRect.visible

                    EHIcon {
                        name: "wallpaper"
                        size: 52
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: "No wallpaper selected"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Invisible rect just used to check color fill visibility (avoids forward reference)
                Rectangle {
                    id: colorFillRect
                    visible: {
                        var wp = wallpaperTab.resolveWallpaper()
                        return wp && wp.startsWith("#")
                    }
                    width: 0; height: 0  // not rendered, just a visibility flag
                }

                // Bottom gradient scrim so text stays readable
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 140
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                    }
                }

                // Top gradient scrim
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 80
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.38) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Top-right: action buttons overlay
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    // Browse folder
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.5)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1

                        EHIcon { name: "folder_open"; size: 18; color: "white"; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parentModal) {
                                    parentModal.allowFocusOverride = true
                                    parentModal.shouldHaveFocus = false
                                }
                                wallpaperBrowser.open()
                            }
                        }
                    }

                    // Colour picker
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.5)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1

                        EHIcon { name: "palette"; size: 18; color: "white"; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: colorPicker.open()
                        }
                    }

                    // Clear / reset
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Qt.rgba(0, 0, 0, 0.5)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1
                        visible: wallpaperTab.resolveWallpaper() !== ""

                        EHIcon { name: "clear"; size: 18; color: "white"; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallpaperTab.setDefaultWallpaper()
                        }
                    }
                }

                // Bottom-left: wallpaper name + cycle controls
                Column {
                    anchors.left: parent.left
                    anchors.right: heroControls.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingL
                    spacing: 4

                    StyledText {
                        text: "Current Wallpaper"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.weight: Font.Medium
                        visible: wallpaperTab.resolveWallpaper() !== ""
                    }

                    StyledText {
                        property string wp: wallpaperTab.resolveWallpaper()
                        text: {
                            if (!wp || wp === "") return "No wallpaper"
                            if (wp.startsWith("#")) return wp + " (solid colour)"
                            if (wp.startsWith("we:")) return "Wallpaper Engine scene"
                            return wp.split('/').pop()
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: "white"
                        elide: Text.ElideMiddle
                        width: parent.width
                    }
                }

                // Bottom-right: prev/next cycle buttons
                Row {
                    id: heroControls
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Theme.spacingL
                    anchors.bottomMargin: Theme.spacingM
                    spacing: Theme.spacingS
                    visible: {
                        var wp = wallpaperTab.resolveWallpaper()
                        return wp && wp !== "" && !wp.startsWith("#") && !wp.startsWith("we:")
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.cornerRadius
                        color: Qt.rgba(0, 0, 0, 0.55)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1

                        EHIcon { name: "skip_previous"; size: 18; color: "white"; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (SessionData.perMonitorWallpaper)
                                    WallpaperCyclingService.cyclePrevForMonitor(wallpaperTab.selectedMonitorName)
                                else
                                    WallpaperCyclingService.cyclePrevManually()
                            }
                        }
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.cornerRadius
                        color: Qt.rgba(0, 0, 0, 0.55)
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        border.width: 1

                        EHIcon { name: "skip_next"; size: 18; color: "white"; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (SessionData.perMonitorWallpaper)
                                    WallpaperCyclingService.cycleNextForMonitor(wallpaperTab.selectedMonitorName)
                                else
                                    WallpaperCyclingService.cycleNextManually()
                            }
                        }
                    }
                }
                } // Rectangle (clip + radius)
            }   // Item (outer padding)

            // =================================================================
            // SETTINGS STRIP — per-monitor toggle + monitor arrangement
            // =================================================================
            Column {
                width: parent.width
                spacing: Theme.spacingM
                topPadding: Theme.spacingL
                bottomPadding: Theme.spacingL
                leftPadding: Theme.spacingL
                rightPadding: Theme.spacingL

                // Per-monitor toggle
                StyledRect {
                    width: parent.width - Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: toggleRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    Row {
                        id: toggleRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM

                        EHIcon {
                            name: SessionData.perMonitorWallpaper ? "monitor" : "desktop_windows"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - perMonitorSwitch.width - Theme.spacingM
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Per-Monitor Wallpapers"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: SessionData.perMonitorWallpaper
                                    ? "Each monitor has its own wallpaper"
                                    : "Same wallpaper on all monitors"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        EHToggle {
                            id: perMonitorSwitch
                            anchors.verticalCenter: parent.verticalCenter
                            checked: SessionData.perMonitorWallpaper
                            onToggled: toggled => SessionData.setPerMonitorWallpaper(toggled)
                        }
                    }
                }

                // Monitor arrangement (only when per-monitor is on)
                MonitorArrangementWidget {
                    width: parent.width - Theme.spacingL * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    monitors: wallpaperTab.monitors
                    monitorCapabilities: wallpaperTab.monitorCapabilities
                    selectedMonitor: SessionData.perMonitorWallpaper ? selectedMonitorName : ""
                    visible: SessionData.perMonitorWallpaper && wallpaperTab.monitors.length > 0 && !wallpaperTab.loading
                    onMonitorSelected: function(monitorName) { selectedMonitorName = monitorName }
                }
            }

            // Transition effect selector
            StyledRect {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: transitionRow.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1

                Row {
                    id: transitionRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "animation"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - Theme.spacingM - transitionDropdown.width - Theme.spacingM
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: "Transition Effect"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Wallpaper transition animation"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    EHDropdown {
                        id: transitionDropdown
                        width: 140
                        text: "Effect"
                        options: ["none", "fade", "crossfade", "wipe", "radial"]
                        currentValue: SessionData.wallpaperTransition
                        onValueChanged: v => SessionData.setWallpaperTransition(v)
                    }
                }
            }

            // Transition FPS selector
            StyledRect {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: fpsRow.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1

                Row {
                    id: fpsRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "speed"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - Theme.spacingM - fpsDropdown.width - Theme.spacingM
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: "Transition FPS"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Frames per second during transition"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    EHDropdown {
                        id: fpsDropdown
                        width: 140
                        text: "FPS"
                        options: [24, 30, 60, 90, 120, 144, 180, 240, 380]
                        currentValue: SessionData.wallpaperTransitionFps
                        onValueChanged: v => SessionData.setWallpaperTransitionFps(v)
                    }
                }
            }

            // Per-monitor preview cards
            Repeater {
                model: SessionData.perMonitorWallpaper ? wallpaperTab.monitors : []

                delegate: Item {
                    width: rootColumn.width
                    height: monitorCard.height + Theme.spacingS
                    // Only show if per-monitor is enabled
                    visible: SessionData.perMonitorWallpaper

                    StyledRect {
                        id: monitorCard
                        width: parent.width - Theme.spacingL * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: monitorCardRow.implicitHeight + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.45)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1

                        Row {
                            id: monitorCardRow
                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingL

                            // Thumbnail
                            StyledRect {
                                width: 160
                                height: 90
                                radius: Theme.cornerRadius
                                color: Theme.surfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true

                                property string monWp: SessionData.getMonitorWallpaper(modelData.name)

                                CachingImage {
                                    anchors.fill: parent
                                    imagePath: {
                                        var wp = parent.monWp
                                        return (wp && !wp.startsWith("#") && !wp.startsWith("we:")) ? wp : ""
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    maxCacheSize: 2048
                                    visible: imagePath !== ""
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: 160; height: 90
                                                radius: Theme.cornerRadius
                                                color: "black"
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: {
                                        var wp = parent.monWp
                                        return (wp && wp.startsWith("#")) ? wp : "transparent"
                                    }
                                    visible: { var wp = parent.monWp; return wp && wp.startsWith("#") }
                                    radius: Theme.cornerRadius
                                }

                                EHIcon {
                                    anchors.centerIn: parent
                                    name: "monitor"
                                    size: 28
                                    color: Theme.surfaceVariantText
                                    visible: parent.monWp === "" || parent.monWp === undefined
                                }

                                // Hover overlay
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    radius: Theme.cornerRadius
                                    visible: monTileHover.containsMouse

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingS

                                        Rectangle {
                                            width: 34; height: 34; radius: 17
                                            color: Qt.rgba(1, 1, 1, 0.9)
                                            EHIcon { name: "folder_open"; size: 16; color: "black"; anchors.centerIn: parent }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (parentModal) {
                                                        parentModal.allowFocusOverride = true
                                                        parentModal.shouldHaveFocus = false
                                                    }
                                                    wallpaperBrowser.open()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 34; height: 34; radius: 17
                                            color: Qt.rgba(1, 1, 1, 0.9)
                                            EHIcon { name: "palette"; size: 16; color: "black"; anchors.centerIn: parent }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: colorPicker.open()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: monTileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            // Info + cycle controls
                            Column {
                                width: parent.width - 160 - Theme.spacingL
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    spacing: Theme.spacingS

                                    EHIcon {
                                        name: "monitor"
                                        size: Theme.iconSizeSmall
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        property var caps: wallpaperTab.monitorCapabilities[modelData.name] || {}
                                        text: (caps.width || modelData.width) + "×" + (caps.height || modelData.height)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                StyledText {
                                    property string monWp: SessionData.getMonitorWallpaper(modelData.name)
                                    text: monWp ? monWp.split('/').pop() : "No wallpaper"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }

                                Row {
                                    spacing: Theme.spacingS
                                    visible: {
                                        var wp = SessionData.getMonitorWallpaper(modelData.name)
                                        return wp && !wp.startsWith("#") && !wp.startsWith("we:")
                                    }

                                    EHActionButton {
                                        buttonSize: 32; iconName: "skip_previous"; iconSize: Theme.iconSizeSmall
                                        backgroundColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                        iconColor: Theme.surfaceText
                                        onClicked: WallpaperCyclingService.cyclePrevForMonitor(modelData.name)
                                    }

                                    EHActionButton {
                                        buttonSize: 32; iconName: "skip_next"; iconSize: Theme.iconSizeSmall
                                        backgroundColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                        iconColor: Theme.surfaceText
                                        onClicked: WallpaperCyclingService.cycleNextForMonitor(modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Spacing before gallery
            Item { width: parent.width; height: Theme.spacingL }

            // =================================================================
            // GALLERY SECTION
            // Uses an Item wrapper so left/right margins + centering work
            // correctly inside a Column parent.
            // =================================================================
            Item {
                id: gallerySectionOuter
                width: parent.width
                height: {
                    var cols = SessionData.galleryColumns
                    var gap  = 6
                    // inner width = full width minus the L margins on each side
                    var innerW = width - Theme.spacingL * 2
                    var tileW = Math.ceil((innerW - gap * (cols - 1)) / cols * SessionData.galleryScale)
                    var tileH = Math.round(tileW * 9 / 16)
                    var rows  = SessionData.galleryRows
                    var gridH = rows * (tileH + gap) + Theme.spacingS
                    return 52 + 40 + 1 + gridH + Theme.spacingM  // header + filter bar + divider + grid + bottom pad
                }

                // ── centred inner container ──────────────────────────────────
                Item {
                    id: gallerySectionInner
                    x: Theme.spacingL
                    width: parent.width - Theme.spacingL * 2
                    height: parent.height

                    // Gallery header bar
                    Item {
                        id: galleryHeaderBar
                        width: parent.width
                        height: 52

                        // Left: folder info
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: wallpaperGalleryDir !== ""
                                    ? wallpaperGalleryDir.replace(/^file:\/\//, '').split('/').pop()
                                    : "No folder selected"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: wallpaperGalleryDir !== ""
                                    ? (wallpaperGalleryModel.count > 0
                                        ? wallpaperGalleryModel.count + " wallpapers"
                                        : "Empty folder")
                                    : "Pick a folder to browse wallpapers"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        // Right: controls
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            // Page info chip
                            StyledRect {
                                visible: wallpaperGalleryModel.count > 0
                                width: pageChipText.implicitWidth + Theme.spacingM * 2
                                height: 30
                                radius: 15
                                color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.8)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    id: pageChipText
                                    anchors.centerIn: parent
                                    text: (galleryCurrentPage + 1) + " / " + galleryTotalPages
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }

                            EHActionButton {
                                iconName: "chevron_left"
                                iconSize: Theme.iconSizeSmall
                                buttonSize: 34
                                enabled: galleryCurrentPage > 0
                                opacity: enabled ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: if (galleryCurrentPage > 0) galleryCurrentPage--
                            }

                            EHActionButton {
                                iconName: "chevron_right"
                                iconSize: Theme.iconSizeSmall
                                buttonSize: 34
                                enabled: galleryCurrentPage < galleryTotalPages - 1
                                opacity: enabled ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: if (galleryCurrentPage < galleryTotalPages - 1) galleryCurrentPage++
                            }

                            Rectangle {
                                width: 34
                                height: 34
                                radius: Theme.cornerRadius
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter

                                EHIcon { name: "folder_open"; size: 16; color: "white"; anchors.centerIn: parent }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parentModal) {
                                            parentModal.allowFocusOverride = true
                                            parentModal.shouldHaveFocus = false
                                        }
                                        wallpaperBrowser.open()
                                    }
                                }
                            }
                        }
                    }

                    // Sort filter bar
                    Item {
                        id: galleryFilterBar
                        anchors.top: galleryHeaderBar.bottom
                        width: parent.width
                        height: 40

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Sort:"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Name (default)
                            Rectangle {
                                height: 28
                                width: sortNameLabel.implicitWidth + 20
                                radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: gallerySortMode === "name"
                                    ? Theme.primary
                                    : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.7)
                                border.color: gallerySortMode === "name"
                                    ? "transparent"
                                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                StyledText {
                                    id: sortNameLabel
                                    anchors.centerIn: parent
                                    text: "Name"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: gallerySortMode === "name" ? Font.Medium : Font.Normal
                                    color: gallerySortMode === "name" ? "white" : Theme.surfaceVariantText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: gallerySortMode = "name"
                                }
                            }

                            // Oldest first
                            Rectangle {
                                height: 28
                                width: sortOldLabel.implicitWidth + 20
                                radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: gallerySortMode === "oldest"
                                    ? Theme.primary
                                    : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.7)
                                border.color: gallerySortMode === "oldest"
                                    ? "transparent"
                                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                StyledText {
                                    id: sortOldLabel
                                    anchors.centerIn: parent
                                    text: "First Modified"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: gallerySortMode === "oldest" ? Font.Medium : Font.Normal
                                    color: gallerySortMode === "oldest" ? "white" : Theme.surfaceVariantText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: gallerySortMode = "oldest"
                                }
                            }

                            // Newest first
                            Rectangle {
                                height: 28
                                width: sortNewLabel.implicitWidth + 20
                                radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: gallerySortMode === "newest"
                                    ? Theme.primary
                                    : Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.7)
                                border.color: gallerySortMode === "newest"
                                    ? "transparent"
                                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                StyledText {
                                    id: sortNewLabel
                                    anchors.centerIn: parent
                                    text: "Last Modified"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: gallerySortMode === "newest" ? Font.Medium : Font.Normal
                                    color: gallerySortMode === "newest" ? "white" : Theme.surfaceVariantText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: gallerySortMode = "newest"
                                }
                            }
                        }
                    }

                    // Thin divider
                    Rectangle {
                        id: galleryDivider
                        anchors.top: galleryFilterBar.bottom
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                    }

                    Item {
                        id: galleryGridArea
                        anchors.top: galleryDivider.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: {
                            var cols = SessionData.galleryColumns
                            var gap  = 6
                            var tileW = Math.ceil((gallerySectionInner.width - gap * (cols - 1)) / cols * SessionData.galleryScale)
                            var tileH = Math.round(tileW * 9 / 16)
                            // Show up to 5 rows visible at a time, but allow scrolling for more
                            var visibleRows = Math.min(SessionData.galleryRows, 5)
                            return visibleRows * (tileH + gap) + Theme.spacingS
                        }
                        clip: true

                    // Empty state — no folder
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        visible: wallpaperGalleryDir === ""

                        EHIcon {
                            name: "folder_open"
                            size: 52
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: "Select a wallpaper folder"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: "Click the folder button above to browse your wallpapers"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            width: 300
                        }
                    }

                    // Empty state — folder has no images
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        visible: wallpaperGalleryDir !== "" && wallpaperGalleryModel.count === 0

                        EHIcon {
                            name: "image_not_supported"
                            size: 52
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: "No wallpapers found"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: "This folder has no supported image files.\nTry selecting a different folder."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            width: 300
                        }
                    }

                    // Gallery grid
                    GridView {
                        id: galleryGrid
                        anchors.fill: parent
                        anchors.topMargin: Theme.spacingS
                        visible: wallpaperGalleryModel.count > 0

                        property int cols: SessionData.galleryColumns
                        property int gap: 6
                        property real scale: SessionData.galleryScale
                        property int thumbnailRadius: SessionData.galleryThumbnailRadius
                        property int cellW: Math.ceil(((width - gap * (cols - 1)) / cols) * scale)
                        property int cellH: Math.round(cellW * 9 / 16)

                        cellWidth:  cellW + gap
                        cellHeight: cellH + gap
                        clip: true
                        interactive: SessionData.galleryRows > 5

                        property var galleryItems: []

                        function updateModel() {
                            var start = galleryCurrentPage * galleryItemsPerPage
                            var end   = Math.min(start + galleryItemsPerPage, wallpaperGalleryModel.count)
                            var items = []
                            for (var i = start; i < end; i++) {
                                var fp = wallpaperGalleryModel.get(i, "filePath")
                                if (fp) items.push(fp.toString().replace(/^file:\/\//, ''))
                            }
                            galleryItems = items
                        }

                        Component.onCompleted: Qt.callLater(() => updateModel())

                        Connections {
                            target: wallpaperTab
                            function onGalleryCurrentPageChanged() { galleryGrid.updateModel() }
                            function onWallpaperGalleryDirChanged() { Qt.callLater(() => galleryGrid.updateModel()) }
                            function onGallerySortModeChanged() { Qt.callLater(() => galleryGrid.updateModel()) }
                        }

                        Connections {
                            target: SessionData
                            function onGalleryColumnsChanged() { galleryGrid.updateModel() }
                            function onGalleryRowsChanged() { galleryGrid.updateModel() }
                            function onGalleryScaleChanged() { galleryGrid.updateModel() }
                        }

                        Connections {
                            target: wallpaperGalleryModel
                            function onCountChanged() { Qt.callLater(() => galleryGrid.updateModel()) }
                            function onStatusChanged() {
                                if (wallpaperGalleryModel.status === FolderListModel.Ready)
                                    Qt.callLater(() => galleryGrid.updateModel())
                            }
                        }

                        model: galleryItems

                        delegate: Item {
                            id: tileRoot
                            width:  galleryGrid.cellW
                            height: galleryGrid.cellH

                            property string currentWp: {
                                var wp = SessionData.perMonitorWallpaper
                                    ? SessionData.getMonitorWallpaper(wallpaperTab.selectedMonitorName)
                                    : SessionData.wallpaperPath
                                if (!wp || wp.startsWith("#") || wp.startsWith("we:")) return ""
                                return wp
                            }

                            property bool isSelected: currentWp !== "" && currentWp === modelData

                            property string fileName: {
                                if (!modelData) return ""
                                var parts = modelData.split('/')
                                return parts[parts.length - 1]
                            }

                            // Outer glow ring when this is the active wallpaper
                            Rectangle {
                                visible: tileRoot.isSelected
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: Theme.cornerRadius + 3
                                color: "transparent"
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                                border.width: 3
                                opacity: 0.85
                            }

                            Rectangle {
                                id: tileCard
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: Theme.surfaceVariant
                                clip: true

                                // Selection ring border
                                border.color: tileRoot.isSelected
                                    ? Theme.primary
                                    : (tileHover.containsMouse
                                        ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
                                        : "transparent")
                                border.width: tileRoot.isSelected ? 2 : (tileHover.containsMouse ? 1 : 0)

                                Behavior on border.color { ColorAnimation { duration: 80 } }

                                // Thumbnail
                                CachingImage {
                                    id: tileImg
                                    anchors.fill: parent
                                    imagePath: modelData || ""
                                    fillMode: Image.PreserveAspectCrop
                                    maxCacheSize: 2048
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: tileImg.width
                                                height: tileImg.height
                                                radius: galleryGrid.thumbnailRadius
                                                color: "black"
                                            }
                                        }
                                    }
                                }

                                // Active wallpaper overlay — tinted veil + centred "In Use" badge
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                    visible: tileRoot.isSelected

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: inUseLbl.implicitWidth + 16
                                        height: 24
                                        radius: 12
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.88)

                                        StyledText {
                                            id: inUseLbl
                                            anchors.centerIn: parent
                                            text: "In Use"
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Medium
                                            color: "white"
                                        }
                                    }
                                }

                                // Check badge (top-right)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22; height: 22
                                    radius: 11
                                    color: Theme.primary
                                    visible: tileRoot.isSelected

                                    EHIcon {
                                        name: "check"
                                        size: 13
                                        color: "white"
                                        anchors.centerIn: parent
                                    }
                                }

                                // Filename tooltip on hover (only when not selected)
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 26
                                    color: Qt.rgba(0, 0, 0, 0.58)
                                    radius: Theme.cornerRadius
                                    visible: tileHover.containsMouse && !tileRoot.isSelected
                                    opacity: tileHover.containsMouse ? 1 : 0

                                    Behavior on opacity { NumberAnimation { duration: 70 } }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: tileRoot.fileName
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: "white"
                                        width: parent.width - 8
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    cornerRadius: parent.radius
                                    stateColor: Theme.primary
                                }

                                MouseArea {
                                    id: tileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wallpaperTab.applyWallpaper(modelData)
                                }
                            }
                        }
                    }           // GridView (galleryGrid)
                    }           // Item (galleryGridArea)
                }               // Item (gallerySectionInner)
            }                   // Item (gallerySectionOuter)

            // bottom padding
            Item { width: parent.width; height: Theme.spacingL }
        }
    }

    // Gallery Settings sub-tab content (when currentSubTab === 1)
    EHFlickable {
        anchors.topMargin: 48  // Space for tab bar
        anchors.fill: parent
        clip: true
        contentHeight: gallerySettingsColumn.implicitHeight
        contentWidth: width

        visible: wallpaperTab.currentSubTab === 1

        Column {
            id: gallerySettingsColumn
            width: parent.width
            spacing: 0

            // =================================================================
            // GALLERY SETTINGS HEADER
            // =================================================================
            Item {
                width: parent.width
                height: 80

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingL
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Gallery Settings"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: "Configure the wallpaper gallery grid layout and appearance"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            // Settings cards
            Column {
                width: parent.width
                spacing: Theme.spacingM
                leftPadding: Theme.spacingL
                rightPadding: Theme.spacingL
                bottomPadding: Theme.spacingL

                // Columns setting
                StyledRect {
                    width: parent.width - Theme.spacingL * 2
                    height: 90
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Columns"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: SessionData.galleryColumns + " columns in the grid"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SessionData.galleryColumns
                            minimum: 1
                            maximum: 10
                            unit: ""
                            showValue: false
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => {
                                SessionData.galleryColumns = v
                                SessionData.saveSettings()
                            }
                        }
                    }
                }

                // Rows setting
                StyledRect {
                    width: parent.width - Theme.spacingL * 2
                    height: 90
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Rows"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: SessionData.galleryRows + " rows in the grid"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SessionData.galleryRows
                            minimum: 1
                            maximum: 10
                            unit: ""
                            showValue: false
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => {
                                SessionData.galleryRows = v
                                SessionData.saveSettings()
                            }
                        }
                    }
                }

                // Scale setting
                StyledRect {
                    width: parent.width - Theme.spacingL * 2
                    height: 90
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Scale"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: Math.round(SessionData.galleryScale * 100) + "% thumbnail size"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SessionData.galleryScale
                            minimum: 0.5
                            maximum: 2.0
                            unit: ""
                            showValue: false
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => {
                                SessionData.galleryScale = v
                                SessionData.saveSettings()
                            }
                        }
                    }
                }

                // Radius setting
                StyledRect {
                    width: parent.width - Theme.spacingL * 2
                    height: 90
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Thumbnail Radius"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: SessionData.galleryThumbnailRadius + "px corner radius"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        EHSlider {
                            width: parent.width
                            height: 24
                            value: SessionData.galleryThumbnailRadius
                            minimum: 0
                            maximum: 20
                            unit: "px"
                            showValue: false
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => {
                                SessionData.galleryThumbnailRadius = v
                                SessionData.saveSettings()
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Non-visual infrastructure (unchanged behaviour, moved outside scroll)
    // =========================================================================

    FolderListModel {
        id: wallpaperGalleryModel
        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        showFiles: true
        showDirs: false
        sortField: FolderListModel.Name
        folder: wallpaperGalleryDir ? "file://" + wallpaperGalleryDir : ""
        onStatusChanged: {
            if (status === FolderListModel.Ready && count > 0) {
                Qt.callLater(() => { if (galleryGrid) galleryGrid.updateModel() })
            }
        }
    }

    Connections {
        target: SessionData
        function onWallpaperLastPathChanged() {
            if (SessionData.wallpaperLastPath && SessionData.wallpaperLastPath !== ""
                    && wallpaperGalleryDir !== SessionData.wallpaperLastPath) {
                wallpaperGalleryDir = SessionData.wallpaperLastPath
            }
        }
    }

    FileBrowserModal {
        id: wallpaperBrowser
        browserTitle: "Select Wallpaper Directory"
        browserIcon: "folder_open"
        browserType: "wallpaper"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        selectFolderMode: true
        onFileSelected: path => {
            wallpaperTab.applyWallpaper(path)
            close()
        }
        onFolderSelected: folderPath => {
            var cleanPath = folderPath.replace(/^file:\/\//, '')
            wallpaperGalleryDir = cleanPath
            SessionData.wallpaperLastPath = cleanPath
            SessionData.saveSettings()
            galleryCurrentPage = 0
            close()
        }
        onDialogClosed: {
            if (parentModal) {
                parentModal.allowFocusOverride = false
                parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible)
            }
        }
    }

    EHColorPicker {
        id: colorPicker
        pickerTitle: "Choose Wallpaper Colour"
        onColorSelected: selectedColor => {
            if (SessionData.perMonitorWallpaper) {
                SessionData.setMonitorWallpaper(selectedMonitorName, selectedColor)
            } else {
                SessionData.setWallpaperColor(selectedColor)
            }
            if (typeof ColorPaletteService !== 'undefined') {
                ColorPaletteService.onWallpaperChanged(selectedColor)
            }
        }
    }

}

