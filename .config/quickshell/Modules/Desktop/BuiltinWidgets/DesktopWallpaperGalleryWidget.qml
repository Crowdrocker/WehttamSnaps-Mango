import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.FileBrowser

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: defaultWidth
    property real widgetHeight: defaultHeight
    property real defaultWidth: 600
    property real defaultHeight: 550
    property real minWidth: 400
    property real minHeight: 300
    property real fontSize: isInstance ? (cfg.fontSize ?? 12) : (SettingsData.desktopWidgetFontSize || 12)
    property real spacing: isInstance ? (cfg.spacing ?? 4) : 4
    property real padding: isInstance ? (cfg.padding ?? 16) : 16
    property string wallpaperGalleryDir: isInstance ? (cfg.wallpaperDir ?? "") : ""
    property int galleryCurrentPage: 0
    property int galleryItemsPerPage: 20
    property int galleryTotalPages: Math.max(1, Math.ceil(wallpaperGalleryModel.count / galleryItemsPerPage))
    property bool showControls: isInstance ? (cfg.showControls ?? true) : true
    property bool showFileNames: isInstance ? (cfg.showFileNames ?? true) : true
    property int gridColumns: isInstance ? (cfg.gridColumns ?? 4) : 4
    property int gridRows: isInstance ? (cfg.gridRows ?? 3) : 3
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : false

    // Matugen color names for wallpaper-based colors
    readonly property var matugenColorNames: [
        "primary", "secondary", "tertiary", "surface_tint",
        "primary_container", "secondary_container", "tertiary_container"
    ]

    // Get color from matugen or fallback to null
    function getMatugenColor(index) {
        Theme.colorUpdateTrigger  // Trigger updates when theme changes

        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const colorName = matugenColorNames[index % matugenColorNames.length]
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            if (Theme.matugenColors.colors[colorName] && Theme.matugenColors.colors[colorName][colorMode]) {
                return Theme.matugenColors.colors[colorName][colorMode]
            }
        }
        return null
    }

    // Helper to get matugen color with alpha
    function getMatugenColorWithAlpha(index, alpha) {
        var color = getMatugenColor(index)
        if (color) {
            return Qt.hsla(color.hslHue, color.hslSaturation, color.hslLightness, alpha)
        }
        return null
    }

    // Dock/Topbar/Taskbar height awareness properties (like DesktopClockWidget)
    readonly property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real barExclusiveSize: SettingsData.topBarVisible && !SettingsData.topBarFloat ? ((SettingsData.topBarHeight * SettingsData.topbarScale) + SettingsData.topBarSpacing + (SettingsData.topBarGothCornersEnabled ? Theme.cornerRadius : 0)) : 0
    readonly property real dockExclusiveSize: SettingsData.showDock ? (SettingsData.dockExclusiveZone || SettingsData.dockHeight || 48) + (SettingsData.dockBottomGap || 0) + ((SettingsData.dockTopPadding || 0) * 2) : 0

    // Determine effective position based on current coordinates (for margin calculations)
    readonly property string effectivePosition: {
        if (!parent) return "center";
        var screenWidth = parent.width || Quickshell.screens[0]?.width || 1920;
        var screenHeight = parent.height || Quickshell.screens[0]?.height || 1080;
        var centerX = screenWidth / 2;
        var centerY = screenHeight / 2;
        var widgetCenterX = x + width / 2;
        var widgetCenterY = y + height / 2;

        var isLeft = widgetCenterX < centerX * 0.6;
        var isRight = widgetCenterX > centerX * 1.4;
        var isTop = widgetCenterY < centerY * 0.6;
        var isBottom = widgetCenterY > centerY * 1.4;

        if (isTop && isLeft) return "top-left";
        if (isTop && isRight) return "top-right";
        if (isBottom && isLeft) return "bottom-left";
        if (isBottom && isRight) return "bottom-right";
        if (isTop) return "top-center";
        if (isBottom) return "bottom-center";
        if (isLeft) return "middle-left";
        if (isRight) return "middle-right";
        return "middle-center";
    }

    function shouldShow(key) {
        if (!isInstance || !cfg) return true
        if (cfg.hasOwnProperty(key)) {
            return cfg[key] !== false
        }
        return true
    }

    function getConfigValue(key, defaultValue) {
        if (!isInstance || !cfg) return defaultValue
        if (cfg.hasOwnProperty(key)) {
            return cfg[key]
        }
        return defaultValue
    }

    width: widgetWidth
    height: widgetHeight

    Component.onCompleted: {
        loadWallpaperGalleryDir()
        Qt.callLater(() => {
            if (wallpaperGalleryGrid) {
                wallpaperGalleryGrid.updateModel()
            }
        })
    }

    function loadWallpaperGalleryDir() {
        if (isInstance && cfg.wallpaperDir && cfg.wallpaperDir !== "") {
            wallpaperGalleryDir = cfg.wallpaperDir
        } else {
            // Try to get directory from current wallpaper
            var currentWallpaper = SessionData.perMonitorWallpaper ?
                SessionData.getMonitorWallpaper("") :
                SessionData.wallpaperPath
            if (currentWallpaper && currentWallpaper !== "" && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we:")) {
                var lastSlash = currentWallpaper.lastIndexOf('/')
                if (lastSlash > 0) {
                    wallpaperGalleryDir = currentWallpaper.substring(0, lastSlash)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
        border.color: root.getMatugenColor(0) ? root.getMatugenColor(0) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: root.padding
            // Apply dock/topbar/taskbar awareness margins like DesktopClockWidget
            anchors.leftMargin: root.padding + (root.effectivePosition.includes("left") && SettingsData.topBarPosition === "left" && !SettingsData.topBarFloat ? root.barExclusiveSize : 0)
            anchors.rightMargin: root.padding + (root.effectivePosition.includes("right") && SettingsData.topBarPosition === "right" && !SettingsData.topBarFloat ? root.barExclusiveSize : 0)
            anchors.topMargin: root.padding + (root.effectivePosition.includes("top") && SettingsData.topBarPosition === "top" && !SettingsData.topBarFloat ? root.barExclusiveSize : 0)
            anchors.bottomMargin: root.padding + (root.effectivePosition.includes("bottom") && SettingsData.showDock && !SettingsData.dockFloating ? root.dockExclusiveSize : 0)
            spacing: root.spacing

            // Header with controls
            Row {
                width: parent.width
                spacing: Theme.spacingS
                height: showControls ? 32 : 0
                visible: showControls
                clip: true

                EHActionButton {
                    id: browseButton
                    iconName: "folder_open"
                    iconSize: Theme.iconSizeSmall
                    buttonSize: 32
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        wallpaperBrowser.open()
                    }
                }

                Column {
                    width: parent.width - browseButton.width - Theme.spacingS - pageInfo.width - Theme.spacingS - cycleControls.width - Theme.spacingS
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: wallpaperGalleryDir !== "" ? wallpaperGalleryDir.split('/').pop() : "No folder selected"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideMiddle
                        width: parent.width
                    }

                    StyledText {
                        text: wallpaperGalleryModel.count > 0 ? `${wallpaperGalleryModel.count} wallpapers` : "No wallpapers found"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceVariantText
                        visible: wallpaperGalleryDir !== ""
                    }
                }

                StyledText {
                    id: pageInfo
                    text: wallpaperGalleryModel.count > 0 ? `${galleryCurrentPage + 1} / ${galleryTotalPages}` : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wallpaperGalleryModel.count > 0
                }

                Row {
                    id: cycleControls
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    EHActionButton {
                        buttonSize: 28
                        iconName: "skip_previous"
                        iconSize: Theme.iconSizeSmall - 2
                        backgroundColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                        iconColor: Theme.surfaceText
                        onClicked: {
                            WallpaperCyclingService.cyclePrevManually()
                        }
                    }

                    EHActionButton {
                        buttonSize: 28
                        iconName: "skip_next"
                        iconSize: Theme.iconSizeSmall - 2
                        backgroundColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                        iconColor: Theme.surfaceText
                        onClicked: {
                            WallpaperCyclingService.cycleNextManually()
                        }
                    }
                }
            }

            // Gallery Grid
            Item {
                width: parent.width
                height: parent.height - (showControls ? 32 + root.spacing : 0) - (wallpaperGalleryModel.count > galleryItemsPerPage ? 28 + root.spacing : 0)

                GridView {
                    id: wallpaperGalleryGrid
                    anchors.fill: parent
                    anchors.margins: 2
                    property real availableWidth: width - 4
                    property real availableHeight: height - 4
                    property real cellSpacing: 3
                    cellWidth: Math.floor((availableWidth - (cellSpacing * (gridColumns - 1))) / gridColumns) + cellSpacing
                    cellHeight: Math.floor(cellWidth * 9 / 16) + cellSpacing
                    clip: true
                    interactive: false

                    property var galleryItems: []

                    function updateModel() {
                        const startIndex = galleryCurrentPage * galleryItemsPerPage;
                        const endIndex = Math.min(startIndex + galleryItemsPerPage, wallpaperGalleryModel.count);
                        const items = [];
                        for (var i = startIndex; i < endIndex; i++) {
                            const filePath = wallpaperGalleryModel.get(i, "filePath");
                            if (filePath) {
                                var cleanPath = filePath.toString().replace(/^file:\/\//, '');
                                items.push(cleanPath);
                            }
                        }
                        galleryItems = items;
                    }

                    Component.onCompleted: {
                        Qt.callLater(() => updateModel());
                    }

                    Connections {
                        target: root
                        function onGalleryCurrentPageChanged() {
                            wallpaperGalleryGrid.updateModel();
                        }
                        function onWallpaperGalleryDirChanged() {
                            Qt.callLater(() => wallpaperGalleryGrid.updateModel());
                        }
                    }

                    Connections {
                        target: wallpaperGalleryModel
                        function onCountChanged() {
                            Qt.callLater(() => wallpaperGalleryGrid.updateModel());
                        }
                        function onStatusChanged() {
                            if (wallpaperGalleryModel.status === FolderListModel.Ready) {
                                Qt.callLater(() => wallpaperGalleryGrid.updateModel());
                            }
                        }
                    }

                    model: galleryItems

                    delegate: Item {
                        width: wallpaperGalleryGrid.cellWidth - wallpaperGalleryGrid.cellSpacing
                        height: wallpaperGalleryGrid.cellHeight - wallpaperGalleryGrid.cellSpacing
                        x: (index % gridColumns) * wallpaperGalleryGrid.cellWidth
                        y: Math.floor(index / gridColumns) * wallpaperGalleryGrid.cellHeight

                        property string currentWallpaper: {
                            var wp = SessionData.perMonitorWallpaper ?
                                SessionData.getMonitorWallpaper("") :
                                SessionData.wallpaperPath
                            if (!wp || wp === "" || wp.startsWith("#") || wp.startsWith("we:")) {
                                return "";
                            }
                            return wp;
                        }

                        property bool isSelected: {
                            var current = currentWallpaper;
                            var model = modelData;
                            if (!current || current === "" || !model || model === "") {
                                return false;
                            }
                            return current === model;
                        }
                        property string fileName: {
                            if (!modelData) return "";
                            var parts = modelData.split('/');
                            return parts.length > 0 ? parts[parts.length - 1] : "";
                        }

                        StyledRect {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: thumbnailMouseArea.containsMouse ?
                                Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) :
                                Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            clip: true
                            border.color: isSelected ? (root.getMatugenColor(0) || Theme.primary) : (thumbnailMouseArea.containsMouse ? Theme.outline : "transparent")
                            border.width: (isSelected || thumbnailMouseArea.containsMouse) ? 2 : 0

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

                            CachingImage {
                                id: thumbnailImage
                                anchors.fill: parent
                                imagePath: modelData || ""
                                maxCacheSize: 1024
                                fillMode: Image.PreserveAspectCrop

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1.0
                                    maskSource: ShaderEffectSource {
                                        sourceItem: Rectangle {
                                            width: thumbnailImage.width
                                            height: thumbnailImage.height
                                            radius: Theme.cornerRadius
                                            color: "black"
                                        }
                                    }
                                }
                            }

                            // Hover overlay with filename
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 20
                                color: Qt.rgba(0, 0, 0, 0.7)
                                radius: Theme.cornerRadius
                                visible: thumbnailMouseArea.containsMouse && showFileNames && !isSelected
                                opacity: thumbnailMouseArea.containsMouse ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 80
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: parent.parent.parent.fileName
                                    font.pixelSize: Theme.fontSizeSmall - 4
                                    color: "white"
                                    width: parent.width - 4
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 1
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                stateColor: Theme.primary
                            }

                            MouseArea {
                                id: thumbnailMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData) {
                                        if (SessionData.perMonitorWallpaper) {
                                            var screens = Quickshell.screens
                                            var defaultMonitorName = screens.length > 0 ? screens[0].name : ""
                                            SessionData.setMonitorWallpaper(defaultMonitorName, modelData)
                                        } else {
                                            SessionData.setWallpaper(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty states
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: wallpaperGalleryModel.count === 0 && wallpaperGalleryDir !== ""

                    EHIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "image_not_supported"
                        size: 32
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "No wallpapers found"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: wallpaperGalleryDir === ""

                    EHIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "folder_open"
                        size: 32
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "Select wallpaper folder"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Pagination controls
            Row {
                width: parent.width
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                height: 28
                visible: wallpaperGalleryModel.count > galleryItemsPerPage

                EHActionButton {
                    iconName: "skip_previous"
                    iconSize: Theme.iconSizeSmall - 2
                    buttonSize: 28
                    enabled: galleryCurrentPage > 0
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (galleryCurrentPage > 0) {
                            galleryCurrentPage--;
                        }
                    }
                }

                StyledRect {
                    width: 80
                    height: 28
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.color: Theme.outline
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: wallpaperGalleryModel.count > 0 ? `${galleryCurrentPage + 1} / ${galleryTotalPages}` : "0 / 0"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceText
                    }
                }

                EHActionButton {
                    iconName: "skip_next"
                    iconSize: Theme.iconSizeSmall - 2
                    buttonSize: 28
                    enabled: galleryCurrentPage < galleryTotalPages - 1
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (galleryCurrentPage < galleryTotalPages - 1) {
                            galleryCurrentPage++;
                        }
                    }
                }
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
        onFolderSelected: folderPath => {
            var cleanPath = folderPath.replace(/^file:\/\//, '');
            wallpaperGalleryDir = cleanPath;
            if (isInstance && instanceData) {
                // Update instance config
                var newConfig = Object.assign({}, cfg);
                newConfig.wallpaperDir = cleanPath;
                instanceData.config = newConfig;
            }
            galleryCurrentPage = 0;
            close()
        }
    }

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
                Qt.callLater(() => {
                    if (wallpaperGalleryGrid) {
                        wallpaperGalleryGrid.updateModel()
                    }
                })
            }
        }
    }
}