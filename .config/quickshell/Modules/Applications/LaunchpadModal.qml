import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.AppDrawer
import qs.Modals.Common
import qs.Services
import qs.Widgets

DarkModal {
    id: launchpad

    objectName: "launchpadModal"
    WlrLayershell.namespace: "quickshell:dock:blur"


    property bool launchpadOpen: false
    property string applicationName: ""
    property var targetScreen: null
    property int currentPage: 0

    // ── Folder overlay state ──────────────────────────────────────────────────
    property string openFolderId:   ""
    property string openFolderName: ""
    property var    openFolderApps: []

    function openFolder(folderId) {
        const f = LaunchpadFolderService.getFolderById(folderId)
        if (!f) return
        openFolderId   = f.id
        openFolderName = f.name
        openFolderApps = f.appIds.slice()
    }

    function closeFolder() {
        openFolderId   = ""
        openFolderName = ""
        openFolderApps = []
    }

    function resetAnyStuckDrag() {
        // Drag state lives inside each page's `iconGrid`. If the modal is closed
        // mid-drag, MouseArea cancel/release may never fire, leaving dragActive
        // stuck true and blocking future drags. Clear it defensively on close.
        if (!pageView || !pageView.contentItem) return
        const pages = pageView.contentItem.children || []
        for (var i = 0; i < pages.length; i++) {
            const p = pages[i]
            if (!p) continue
            const grids = p.children || []
            for (var j = 0; j < grids.length; j++) {
                const g = grids[j]
                if (!g) continue
                if (g.draggingAppId !== undefined) g.draggingAppId = ""
                if (g.draggingSlotIndex !== undefined) g.draggingSlotIndex = -1
                if (g.hoverSlotIndex !== undefined) g.hoverSlotIndex = -1
            }
        }
    }

    // Rebuild open folder apps when service data changes
    Connections {
        target: LaunchpadFolderService
        function onFoldersChanged() {
            if (launchpad.openFolderId !== "") {
                const f = LaunchpadFolderService.getFolderById(launchpad.openFolderId)
                if (f) {
                    launchpad.openFolderName = f.name
                    launchpad.openFolderApps = f.appIds.slice()
                } else {
                    launchpad.closeFolder()
                }
            }
        }
    }

    // ── Responsive layout engine ─────────────────────────────────────────────
    // Tiered by resolution so each breakpoint gets intentional values.
    readonly property real sw: activeScreen ? activeScreen.width  : 1920
    readonly property real sh: activeScreen ? activeScreen.height : 1080

    // Animation durations scaled to the screen's actual refresh rate.
    // At 60 Hz a "quick" transition is ~100 ms; at 240 Hz it should be ~25 ms
    // so motion resolves within the same number of frames regardless of display.
    readonly property real refreshRate: activeScreen ? activeScreen.refreshRate : 60
    readonly property int animQuick:  Math.round(100 * 60 / Math.max(60, refreshRate))  // hover colors, opacity
    readonly property int animMedium: Math.round(150 * 60 / Math.max(60, refreshRate))  // scale, border
    readonly property int animSlow:   Math.round(220 * 60 / Math.max(60, refreshRate))  // page indicators, context menu

    // uiScale still used for spacing/font/search bar sizing
    readonly property real uiScale: Math.min(sw / 1920, sh / 1080)

    // ── Resolution tiers ──────────────────────────────────────────────────────
    readonly property real gridIconSize: {
        if (sh >= 2160) return 192   // 4K
        if (sh >= 1440) return 128   // 1440p
        if (sh >= 1080) return 96    // 1080p
        if (sh >= 720)  return 72    // 720p
        return 52                    // <720p
    }
    readonly property int rows: {
        // Raw tier-based row count
        const tierRows =
            sh >= 2160 ? 9 :
            sh >= 1440 ? 7 :
            sh >= 1080 ? 5 :
            sh >= 720  ? 4 : 3
        // Safety clamp: never allocate more rows than actually fit
        const maxRows = Math.max(1, Math.floor(availableHeight / (cellH + gridSpacing)))
        return Math.min(tierRows, maxRows)
    }

    // Spacing: generous at high res, tighter at low res
    readonly property real gridSpacing: {
        if (sh >= 2160) return 32
        if (sh >= 1440) return 24
        if (sh >= 1080) return 20
        return 14
    }

    // Search bar height
    readonly property real searchBarHeight: Math.max(36, Math.min(64, Math.round(44 * uiScale)))

    // Header / footer / padding
    // headerAllowance = vPad + topSpacer + searchBar + spacing after search bar
    readonly property int headerAllowance: vPad + Math.round(Theme.spacingXL * uiScale) + searchBarHeight + Math.max(Theme.spacingS, Math.round(Theme.spacingL * uiScale))
    // footerAllowance = page indicators height + spacing + vPad
    readonly property int footerAllowance: Theme.iconSize + Math.max(Theme.spacingS, Math.round(Theme.spacingL * uiScale)) + vPad
    readonly property int hPad: Math.max(8,  Math.round(60  * uiScale))
    readonly property int vPad: Math.max(4,  Math.round(Theme.spacingS * uiScale))

    // Available grid area
    readonly property real availableWidth:  Math.max(1, sw - hPad * 2)
    readonly property real availableHeight: Math.max(1, sh - headerAllowance - footerAllowance - vPad * 2)

    // Label height (used for app names under icons)
    readonly property int labelHeight: Math.max(
        12,
        Math.round(((Theme.fontSizeSmall || 12) + 6) * Math.min(uiScale, 1.5))
    )

    // Cell = icon + padding + label
    readonly property real cellW: gridIconSize + Math.round(Theme.spacingM * 2 * Math.min(uiScale, 1.5))
    readonly property real cellH: gridIconSize + Math.round(Theme.spacingM * 2 * Math.min(uiScale, 1.5)) + labelHeight

    // Columns: fill available width with the fixed icon size
    readonly property int columns: Math.max(3, Math.min(20, Math.floor(availableWidth / (cellW + gridSpacing))))

    readonly property int itemsPerPage: columns * rows
    readonly property int pageCount: Math.max(1, Math.ceil(appLauncher.model.count / itemsPerPage))

    readonly property color surfaceBase: (Theme.surface && Theme.surface.r !== undefined) ? Theme.surface : Theme.background
    readonly property color surfaceContainerColor: (Theme.surfaceContainer && Theme.surfaceContainer.r !== undefined) ? Theme.surfaceContainer : surfaceBase
    readonly property color surfaceContainerHighColor: (Theme.surfaceContainerHigh && Theme.surfaceContainerHigh.r !== undefined) ? Theme.surfaceContainerHigh : surfaceContainerColor
    readonly property color surfaceContainerHighestColor: (Theme.surfaceContainerHigh && Theme.surfaceContainerHigh.r !== undefined) ? Theme.surfaceContainerHigh : surfaceContainerHighColor

    readonly property var allowedScreens: SettingsData.getFilteredScreens("launchpad")
    readonly property var activeScreen: (targetScreen && allowedScreens.includes(targetScreen))
                                        ? targetScreen
                                        : (allowedScreens.length > 0 ? allowedScreens[0] : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null))

    width: activeScreen ? activeScreen.width : (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920)
    height: activeScreen ? activeScreen.height : (Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080)
    screen: activeScreen
    cornerRadius: 0
    enableShadow: false
    showBackground: true
    backgroundOpacity: 0.30
    backgroundColor: Qt.rgba(surfaceContainerHighColor.r, surfaceContainerHighColor.g, surfaceContainerHighColor.b, 0.75)
    animationType: "fade"
    closeOnEscapeKey: true
    closeOnBackgroundClick: true
    allowStacking: false
    shouldBeVisible: launchpadOpen
    shouldHaveFocus: launchpadOpen
    onBackgroundClicked: hide()
    onDialogClosed: launchpadOpen = false

    function show() {
        launchpadOpen = true
        open()
        currentPage = 0
        appLauncher.searchQuery = ""
        appLauncher.selectedIndex = 0
        // Auto-organize into category folders on first ever open
        Qt.callLater(() => LaunchpadFolderService.autoOrganizeIfNeeded(appLauncher.model))
    }

    function hide() {
        launchpadOpen = false
        close()
    }

    function toggle() {
        if (launchpadOpen) {
            hide()
        } else {
            show()
        }
    }

    onPageCountChanged: {
        if (currentPage >= pageCount) {
            currentPage = Math.max(0, pageCount - 1)
        }
    }

    AppLauncher {
        id: appLauncher
        viewMode: "grid"
        gridColumns: launchpad.columns
        debounceSearch: true
        debounceInterval: 75
        maxResults: 800
        onAppLaunched: launchpad.hide()
    }

    content: Component {
        Rectangle {
            id: contentRoot

            anchors.fill: parent
            color: Qt.rgba(surfaceBase.r, surfaceBase.g, surfaceBase.b, 0.25)
            focus: true

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) {
                    launchpad.hide()
                    event.accepted = true
                } else if (event.key === Qt.Key_Left && pageCount > 1 && !searchField.activeFocus) {
                    pageView.currentIndex = Math.max(0, pageView.currentIndex - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right && pageCount > 1 && !searchField.activeFocus) {
                    pageView.currentIndex = Math.min(pageCount - 1, pageView.currentIndex + 1)
                    event.accepted = true
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin:   launchpad.hPad
                anchors.rightMargin:  launchpad.hPad
                anchors.topMargin:    launchpad.vPad
                anchors.bottomMargin: launchpad.vPad
                spacing: Math.max(Theme.spacingS, Math.round(Theme.spacingL * launchpad.uiScale))

                Item {
                    Layout.preferredHeight: Math.round(Theme.spacingXL * launchpad.uiScale)
                }

                Item {
                    id: searchRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: launchpad.searchBarHeight

                    Rectangle {
                        id: searchFieldBox

                        width: Math.min(Math.round(520 * launchpad.uiScale), launchpad.availableWidth * 0.55)
                        height: launchpad.searchBarHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter

                        radius: height / 2
                        color: Qt.rgba(surfaceContainerHighestColor.r, surfaceContainerHighestColor.g, surfaceContainerHighestColor.b, 0.85)
                        border.color: searchField.activeFocus
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                            : Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1
                        antialiasing: false

                        Behavior on border.color { ColorAnimation { duration: launchpad.animMedium } }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            EHIcon {
                                name: "search"
                                size: (Theme.iconSize ?? 24) - 2
                                color: searchField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: launchpad.animMedium } }
                            }

                            TextInput {
                                id: searchField

                                width: Math.max(180, searchFieldBox.width - Theme.iconSize - Theme.spacingM * 4)
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                onTextChanged: {
                                    appLauncher.searchQuery = text
                                    launchpad.currentPage = 0
                                    pageView.currentIndex = 0
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: ((Theme.iconSize ?? 24) - 2 + Theme.spacingS) / 2
                            text: "Search apps…"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            opacity: 0.65
                            visible: searchField.text.length === 0 && !searchField.activeFocus
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            onClicked: searchField.forceActiveFocus()
                        }
                    }
                }

                Item {
                    id: gridArea

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    SwipeView {
                        id: pageView

                        anchors.fill: parent
                        clip: true
                        interactive: pageCount > 1
                        currentIndex: launchpad.currentPage

                        onCurrentIndexChanged: launchpad.currentPage = currentIndex

                        Repeater {
                            model: launchpad.pageCount

                            Item {
                                property int pageIndex: index

                                width: pageView.width
                                height: pageView.height

                                Grid {
                                    id: iconGrid

                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    columns: launchpad.columns
                                    columnSpacing: launchpad.gridSpacing
                                    rowSpacing: launchpad.gridSpacing

                                    readonly property real cellWidth:  launchpad.cellW
                                    readonly property real cellHeight: launchpad.cellH
                                    readonly property real computedWidth:  columns * cellWidth  + launchpad.gridSpacing * (launchpad.columns - 1)
                                    readonly property real computedHeight: launchpad.rows * cellHeight + launchpad.gridSpacing * (launchpad.rows - 1)

                                    // ── Drag state (one dragging app at a time per page) ──
                                    property string draggingAppId: ""
                                    property int    draggingSlotIndex: -1
                                    property int    hoverSlotIndex: -1
                                    property real   dragProxyX: 0
                                    property real   dragProxyY: 0
                                    property bool   dragActive: draggingAppId !== ""

                                    function slotIndexAt(px, py) {
                                        // Find which appSlot the point (px,py) in grid coords is over
                                        for (var i = 0; i < slotRepeater.count; i++) {
                                            var it = slotRepeater.itemAt(i)
                                            if (!it || !it.visible) continue
                                            var local = iconGrid.mapToItem(it, px, py)
                                            if (local.x >= 0 && local.x < it.width &&
                                                local.y >= 0 && local.y < it.height)
                                                return i
                                        }
                                        return -1
                                    }

                                    Repeater {
                                        id: slotRepeater
                                        model: launchpad.itemsPerPage

                                        Item {
                                            id: appSlot
                                            property int globalIndex: (pageIndex * launchpad.itemsPerPage) + index
                                            property bool hasApp: globalIndex < appLauncher.model.count
                                            property var app: hasApp ? appLauncher.model.get(globalIndex) : null
                                            property bool inFolder: hasApp && app && LaunchpadFolderService.isFolderApp(app.appId || app.id || "")
                                            property var folderHere: {
                                                if (!hasApp || !app) return null
                                                const appId = app.appId || app.id || ""
                                                const f = LaunchpadFolderService.getFolderForApp(appId)
                                                if (!f) return null
                                                if (f.appIds[0] !== appId) return null
                                                return f
                                            }
                                            // Is a foreign app being dragged over this slot?
                                            readonly property bool isHoverTarget:
                                                iconGrid.dragActive &&
                                                iconGrid.hoverSlotIndex === index &&
                                                iconGrid.draggingSlotIndex !== index

                                            width:   iconGrid.cellWidth
                                            height:  iconGrid.cellHeight
                                            visible: (hasApp && !inFolder) || folderHere !== null

                                            // ── Folder tile ───────────────────────────────
                                            LaunchpadFolder {
                                                anchors.centerIn: parent
                                                visible: appSlot.folderHere !== null
                                                folderId:   appSlot.folderHere?.id   ?? ""
                                                folderName: appSlot.folderHere?.name ?? ""
                                                appIds:     appSlot.folderHere?.appIds ?? []
                                                tileSize:   launchpad.gridIconSize
                                                uiScale:    launchpad.uiScale
                                                // Folder tiles light up when hovered during drag
                                                isDropTarget: appSlot.isHoverTarget

                                                onClicked: folderId => launchpad.openFolder(folderId)
                                                // folder-on-folder drop handled in onReleased below
                                            }

                                            // ── Regular app tile ──────────────────────────
                                            Item {
                                                id: appTileItem
                                                visible: !appSlot.inFolder && appSlot.folderHere === null && appSlot.hasApp
                                                anchors.fill: parent
                                                property bool longPressing: false
                                                property point pressPos: Qt.point(0, 0)
                                                // Fade out the source slot while dragging
                                                opacity: (iconGrid.draggingSlotIndex === index && iconGrid.dragActive) ? 0.3 : 1.0
                                                Behavior on opacity { NumberAnimation { duration: launchpad.animQuick } }

                                                Timer {
                                                    id: appLongPressTimer
                                                    interval: 400
                                                    repeat: false
                                                    onTriggered: appTileItem.longPressing = true
                                                }

                                                Column {
                                                    id: appTileCol
                                                    anchors.centerIn: parent
                                                    width: parent.width
                                                    spacing: Math.max(2, Math.round(Theme.spacingXS * launchpad.uiScale))

                                                    Rectangle {
                                                        id: iconBg
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width:  launchpad.gridIconSize
                                                        height: launchpad.gridIconSize
                                                        radius: Math.max(8, Theme.cornerRadius * 1.5 * launchpad.uiScale)
                                                        // Highlight when another app hovers over this slot
                                                        color: appSlot.isHoverTarget
                                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                                                            : appDragArea.containsMouse && !iconGrid.dragActive
                                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                                : "transparent"
                                                        border.width: appSlot.isHoverTarget ? 2 : 0
                                                        border.color: Theme.primary
                                                        Behavior on color { ColorAnimation { duration: launchpad.animQuick; easing.type: Easing.OutQuad } }

                                                        scale: (appDragArea.containsMouse && !iconGrid.dragActive) ? 1.08 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: launchpad.animMedium; easing.type: Easing.OutQuad } }

                                                        Item {
                                                            anchors { fill: parent; margins: Theme.spacingS }
                                                            layer.enabled: SettingsData.systemIconTinting

                                                            Image {
                                                                id: appIconImg
                                                                anchors.fill: parent
                                                                sourceSize.width:  parent.width
                                                                sourceSize.height: parent.height
                                                                fillMode: Image.PreserveAspectFit
                                                                source: appSlot.hasApp && appSlot.app
                                                                    ? Quickshell.iconPath(appSlot.app.icon || "application-x-executable", true)
                                                                    : ""
                                                                smooth: false
                                                                asynchronous: true
                                                                visible: appSlot.hasApp && status === Image.Ready
                                                            }

                                                            layer.effect: MultiEffect {
                                                                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                                                colorizationColor: Theme.primary
                                                            }

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                visible: !(appSlot.hasApp && appIconImg.visible)
                                                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.8)
                                                                radius: Theme.cornerRadius
                                                                border.width: 1
                                                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                                                StyledText {
                                                                    anchors.centerIn: parent
                                                                    text: appSlot.app?.name?.charAt(0)?.toUpperCase() ?? "A"
                                                                    font.pixelSize: parent.width * 0.4
                                                                    color: Theme.primary
                                                                    font.weight: Font.Bold
                                                                }
                                                            }
                                                        }
                                                    }

                                                    StyledText {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: parent.width
                                                        text: appSlot.app?.name ?? ""
                                                        font.pixelSize: Math.max(10, Math.round((Theme.fontSizeSmall || 12) * Math.min(launchpad.uiScale, 1.5)))
                                                        font.weight: Font.Medium
                                                        color: Theme.surfaceText
                                                        opacity: 0.95
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                    }
                                                }

                                                MouseArea {
                                                    id: appDragArea
                                                    anchors.fill: parent
                                                    hoverEnabled: appSlot.hasApp
                                                    enabled:      appSlot.hasApp && !iconGrid.dragActive
                                                    cursorShape:  Qt.PointingHandCursor
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    // Don't let the surrounding SwipeView/Flickable steal the gesture,
                                                    // otherwise pressAndHold may never trigger (drag appears "broken").
                                                    preventStealing: true
                                                    onPressed: mouse => {
                                                        if (mouse.button !== Qt.LeftButton) return
                                                        appTileItem.pressPos = Qt.point(mouse.x, mouse.y)
                                                        appTileItem.longPressing = false
                                                        appLongPressTimer.restart()
                                                    }

                                                    onReleased: mouse => {
                                                        appLongPressTimer.stop()
                                                        appTileItem.longPressing = false
                                                    }

                                                    onPositionChanged: mouse => {
                                                        if (iconGrid.dragActive) return
                                                        if (!appTileItem.longPressing) return

                                                        const dx = mouse.x - appTileItem.pressPos.x
                                                        const dy = mouse.y - appTileItem.pressPos.y
                                                        const dist = Math.sqrt(dx * dx + dy * dy)
                                                        if (dist <= 5) return

                                                        // Begin drag (dock-style long-press + slight move)
                                                        const gridPos = appDragArea.mapToItem(iconGrid, 0, 0)
                                                        iconGrid.draggingAppId   = appSlot.app?.appId ?? ""
                                                        iconGrid.draggingSlotIndex = index
                                                        iconGrid.dragProxyX = gridPos.x + appDragArea.width  / 2 - launchpad.gridIconSize / 2
                                                        iconGrid.dragProxyY = gridPos.y + appDragArea.height / 2 - launchpad.gridIconSize / 2
                                                        appTileItem.longPressing = false
                                                        appLongPressTimer.stop()
                                                    }

                                                    onClicked: function(mouse) {
                                                        if (iconGrid.dragActive) return
                                                        if (appSlot.hasApp && appSlot.app) {
                                                            if (mouse.button === Qt.LeftButton) {
                                                                appLauncher.launchApp(appSlot.app)
                                                            } else if (mouse.button === Qt.RightButton) {
                                                                const gp = appDragArea.mapToItem(null, mouse.x, mouse.y)
                                                                launchpadContextMenu.show(gp.x, gp.y, appSlot.app)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // ── Full-grid drag handler (active once press-and-hold triggers) ──
                                    MouseArea {
                                        id: gridDragHandler
                                        anchors.fill: parent
                                        enabled:  iconGrid.dragActive
                                        visible:  iconGrid.dragActive
                                        cursorShape: Qt.ClosedHandCursor
                                        z: 20

                                        onPositionChanged: mouse => {
                                            iconGrid.dragProxyX = mouse.x - launchpad.gridIconSize / 2
                                            iconGrid.dragProxyY = mouse.y - launchpad.gridIconSize / 2
                                            iconGrid.hoverSlotIndex = iconGrid.slotIndexAt(mouse.x, mouse.y)
                                        }

                                        onReleased: mouse => {
                                            const fromId  = iconGrid.draggingAppId
                                            const toIndex = iconGrid.hoverSlotIndex
                                            const toSlot  = toIndex >= 0 ? slotRepeater.itemAt(toIndex) : null
                                            const toApp   = toSlot?.app ?? null
                                            const toId    = toApp?.appId ?? ""
                                            const toFolder = toSlot?.folderHere ?? null

                                            if (fromId && toId && fromId !== toId && toIndex !== iconGrid.draggingSlotIndex) {
                                                if (toFolder) {
                                                    // Dropped onto a folder tile → add to folder
                                                    LaunchpadFolderService.addAppToFolder(toFolder.id, fromId)
                                                } else if (!LaunchpadFolderService.isFolderApp(fromId) && !LaunchpadFolderService.isFolderApp(toId)) {
                                                    // Both regular apps → create new folder
                                                    LaunchpadFolderService.createFolder("New Folder", toId, fromId)
                                                } else if (LaunchpadFolderService.isFolderApp(toId)) {
                                                    const f = LaunchpadFolderService.getFolderForApp(toId)
                                                    if (f) LaunchpadFolderService.addAppToFolder(f.id, fromId)
                                                }
                                            }

                                            // Reset drag state
                                            iconGrid.draggingAppId    = ""
                                            iconGrid.draggingSlotIndex = -1
                                            iconGrid.hoverSlotIndex   = -1
                                        }

                                        onCanceled: {
                                            iconGrid.draggingAppId    = ""
                                            iconGrid.draggingSlotIndex = -1
                                            iconGrid.hoverSlotIndex   = -1
                                        }
                                    }

                                    // ── Floating drag proxy ───────────────────────────
                                    Rectangle {
                                        id: dragProxy
                                        visible:  iconGrid.dragActive
                                        x: iconGrid.dragProxyX
                                        y: iconGrid.dragProxyY
                                        width:  launchpad.gridIconSize
                                        height: launchpad.gridIconSize
                                        radius: Math.max(8, Theme.cornerRadius * 1.5 * launchpad.uiScale)
                                        color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                                        border.color: Theme.primary
                                        border.width: 2
                                        z: 50
                                        opacity: 0.92

                                        // Show the dragged app's icon inside the proxy
                                        Image {
                                            anchors { fill: parent; margins: Theme.spacingS }
                                            source: {
                                                if (!iconGrid.dragActive || iconGrid.draggingSlotIndex < 0) return ""
                                                const s = slotRepeater.itemAt(iconGrid.draggingSlotIndex)
                                                if (!s?.app) return ""
                                                return Quickshell.iconPath(s.app.icon || "application-x-executable", true)
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            smooth: false
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    radius: Theme.cornerRadius + 2
                                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.45)
                                    visible: appLauncher.model.count === 0
                                    width: Math.min(parent.width * 0.45, 300)
                                    height: emptyCol.implicitHeight + Theme.spacingL * 2
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                                    border.width: 1
                                    z: 5

                                    Column {
                                        id: emptyCol
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingS

                                        EHIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: "search_off"
                                            size: (Theme.iconSize ?? 24) + 8
                                            color: Theme.surfaceVariantText
                                            opacity: 0.6
                                        }

                                        StyledText {
                                            text: "No apps found"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: "Try a different search term"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignHCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            opacity: 0.75
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: pageIndicators

                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.iconSize
                    visible: launchpad.pageCount > 1

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingS

                        Repeater {
                            model: launchpad.pageCount

                            Rectangle {
                                width:  launchpad.currentPage === index ? 22 : 7
                                height: 7
                                radius: height / 2
                                color: launchpad.currentPage === index
                                    ? Theme.primary
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.30)
                                opacity: launchpad.currentPage === index ? 1.0 : 0.7

                                Behavior on width { NumberAnimation { duration: launchpad.animSlow; easing.type: Theme.emphasizedEasing } }
                                Behavior on color { ColorAnimation { duration: launchpad.animSlow } }
                            }
                        }
                    }
                }
            }

            // Retry focus until the Wayland surface has actually received
            // keyboard grant — a single callLater is too early on layer-shell.
            Timer {
                id: focusRetryTimer
                interval: 8   // one ~120Hz frame; fires repeatedly until focus lands
                repeat: true
                running: false
                property int attempts: 0
                onTriggered: {
                    searchField.forceActiveFocus()
                    attempts++
                    if (searchField.activeFocus || attempts > 40) {
                        running = false
                        attempts = 0
                    }
                }
            }

            Connections {
                target: launchpad
                function onShouldBeVisibleChanged() {
                    if (!launchpad.shouldBeVisible) {
                        searchField.text = ""
                        focusRetryTimer.running = false
                        launchpad.resetAnyStuckDrag()
                        launchpad.closeFolder()
                    } else {
                        focusRetryTimer.attempts = 0
                        focusRetryTimer.running = true
                    }
                }
            }

            // ── Folder overlay ────────────────────────────────────────────────
            LaunchpadFolderOverlay {
                anchors.fill: parent
                visible:      launchpad.openFolderId !== ""
                folderId:     launchpad.openFolderId
                folderName:   launchpad.openFolderName
                appIds:       launchpad.openFolderApps
                uiScale:      launchpad.uiScale
                appLauncher:  appLauncher
                z: 50

                onClosed:      launchpad.closeFolder()
                onAppLaunched: launchpad.hide()
                onAppRemoved:  appId => { /* grid updates reactively via LaunchpadFolderService */ }
            }
        }
    }

    // Context menu for right-clicking apps
    Rectangle {
        id: launchpadContextMenu

        property var currentApp: null

        readonly property string appId: (currentApp && currentApp.desktopEntry) ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""

        function show(x, y, app) {
            currentApp = app

            const menuWidth = 180
            const menuHeight = contextMenuColumn.implicitHeight + Theme.spacingS * 2

            let finalX = x + Theme.spacingS
            let finalY = y + Theme.spacingS

            if (finalX + menuWidth > launchpadModal.width) {
                finalX = x - menuWidth - Theme.spacingS
            }

            if (finalY + menuHeight > launchpadModal.height) {
                finalY = y - menuHeight - Theme.spacingS
            }

            finalX = Math.max(Theme.spacingS, Math.min(finalX, launchpadModal.width - menuWidth - Theme.spacingS))
            finalY = Math.max(Theme.spacingS, Math.min(finalY, launchpadModal.height - menuHeight - Theme.spacingS))

            launchpadContextMenu.x = finalX
            launchpadContextMenu.y = finalY
            launchpadContextMenu.visible = true
            launchpadContextMenu.opacity = 1.0
            launchpadContextMenu.scale = 1.0
        }

        function close() {
            launchpadContextMenu.opacity = 0.0
            launchpadContextMenu.scale = 0.85
            Qt.callLater(() => {
                launchpadContextMenu.visible = false
            })
        }

        visible: false
        width: 200
        height: contextMenuColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius + 2
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
        border.width: 1
        z: 1000
        opacity: 0.0
        scale: 0.92

        // Drop shadow
        Rectangle {
            anchors { fill: parent; topMargin: 4; leftMargin: 2; rightMargin: -2; bottomMargin: -4 }
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.18)
            z: -1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: launchpad.animSlow
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: launchpad.animSlow
                easing.type: Theme.emphasizedEasing
            }
        }

        Column {
            id: contextMenuColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingXXS

            // Launch option
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: launchMouseArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: launchpad.animQuick; easing.type: Easing.OutQuad } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    EHIcon {
                        name: "launch"
                        size: (Theme.iconSize ?? 24) - 2
                        color: Theme.surfaceText
                        opacity: 0.75
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Launch"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: launchMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (launchpadContextMenu.currentApp) appLauncher.launchApp(launchpadContextMenu.currentApp)
                        launchpadContextMenu.close()
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 5
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                }
            }

            // Pin to Dock option
            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: pinMouseArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: launchpad.animQuick; easing.type: Easing.OutQuad } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    EHIcon {
                        name: "push_pin"
                        size: (Theme.iconSize ?? 24) - 2
                        color: Theme.surfaceText
                        opacity: 0.75
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Pin to Dock & Taskbar"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: pinMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (launchpadContextMenu.currentApp && launchpadContextMenu.appId)
                            SessionData.addPinnedApp(launchpadContextMenu.appId)
                        launchpadContextMenu.close()
                    }
                }
            }
        }
    }

    // Click outside to close context menu
    MouseArea {
        anchors.fill: parent
        visible: launchpadContextMenu.visible
        z: 999
        onClicked: {
            launchpadContextMenu.close()
        }
    }
}

