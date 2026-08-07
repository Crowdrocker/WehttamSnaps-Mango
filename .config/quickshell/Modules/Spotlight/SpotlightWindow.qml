import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Modules.PackageManager

PanelWindow {
    id: spotlightWindow
    screen: targetScreen

    // ── State ────────────────────────────────────────────────────────────────
    property bool   spotlightOpen:  false
    property var    targetScreen:   null
    property string searchQuery:    ""
    property bool   hasQuery:       searchQuery.length > 0
    property int    selectedIndex:  0
    property var    combinedResults: []
    property string resultFilter: "all"  // "all" | "apps" | "images" | "text"
    property var    displayedResults: {
        if (resultFilter === "all")   return combinedResults
        if (resultFilter === "apps")  return combinedResults.filter(i => i.type === "app")
        if (resultFilter === "images") return combinedResults.filter(i => spotlightWindow.isImageFile(i))
        if (resultFilter === "text")   return combinedResults.filter(i => spotlightWindow.isTextFile(i))
        return combinedResults
    }

    readonly property var imageExts: [".png",".jpg",".jpeg",".gif",".bmp",".webp",".svg",".ico",".tiff",".tif",".avif",".heic",".heif",".raw",".cr2",".nef",".orf",".arw"]
    readonly property var textExts:  [".txt",".md",".markdown",".rst",".csv",".json",".yaml",".yml",".toml",".xml",".html",".htm",".css",".js",".ts",".py",".sh",".bash",".zsh",".fish",".conf",".cfg",".ini",".log",".diff",".patch",".tex",".org",".nfo",".rtf"]

    function fileExt(item) {
        if (!item || item.type !== "file") return ""
        const name = (item.data.name || item.data.path || "").toLowerCase()
        const dot = name.lastIndexOf('.')
        return dot >= 0 ? name.slice(dot) : ""
    }
    function isImageFile(item) { return imageExts.indexOf(fileExt(item)) >= 0 }
    function isTextFile(item)  { return textExts.indexOf(fileExt(item)) >= 0 }

    function getFileIcon(item) {
        if (item.type === "file") {
            if (isImageFile(item)) return "image"
            if (isTextFile(item)) return "article"
            return "description"
        }
        return "folder"
    }
    property Item    searchInputRef: null

    // ── Geometry ─────────────────────────────────────────────────────────────
    readonly property int barW:      620
    readonly property int barH:      56
    readonly property int barR:      28
    readonly property int pad:       16
    readonly property int maxListH:  420
    readonly property int itemH:     54

    readonly property int glassH: {
        if (!hasQuery || displayedResults.length === 0)
            return barH + pad
        const rh = Math.min(displayedResults.length * (itemH + 2) + 8, maxListH)
        return barH + pad + 1 + 10 + 36 + rh + 8
    }

    // Re-center when window width changes.
    // Height changes should expand in-place (no vertical drift).
    onBarWChanged: if (spotlightOpen) Qt.callLater(centerWindow)
    onPadChanged: if (spotlightOpen) Qt.callLater(centerWindow)

    // ── Window ───────────────────────────────────────────────────────────────
    color:   "transparent"
    visible: spotlightOpen
    anchors { top: true; left: true; right: true; bottom: true }

    // Centering offset for glassRect (computed in centerWindow)
    property real glassX: 0
    property real glassY: 0

    function centerWindow() {
        const scr = targetScreen ?? null
        const screenW = scr ? scr.width  : (Screen.width  || 1920)
        const screenH = scr ? scr.height : (Screen.height || 1080)
        glassX = Math.floor(screenW / 2 - barW / 2)
        glassY = Math.floor(screenH / 2 - barH / 2)
    }

    Component.onCompleted: centerWindow()
    onSpotlightOpenChanged: if (spotlightOpen) Qt.callLater(centerWindow)

    WlrLayershell.namespace: "quickshell:dock:blur"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: spotlightOpen
                                       ? WlrKeyboardFocus.OnDemand
                                       : WlrKeyboardFocus.None

    Timer {
        interval: 100
        running: spotlightOpen
        onTriggered: {
            if (spotlightOpen && !this.activeFocus && !searchInput.activeFocus) {
                hide()
            }
        }
    }

    // ── API ──────────────────────────────────────────────────────────────────
    function show() {
        searchQuery   = ""
        selectedIndex = 0
        combinedResults = []
        spotlightOpen = true
        Qt.callLater(() => {
            if (searchInputRef) {
                searchInputRef.text = ""
                searchInputRef.forceActiveFocus()
            }
        })
    }

    function hide() {
        spotlightOpen = false
        searchQuery   = ""
        selectedIndex = 0
        combinedResults = []
        if (searchInputRef)
            searchInputRef.text = ""
    }

    function toggle() {
        if (spotlightOpen) hide(); else show()
    }

    function launchSelected() {
        if (combinedResults.length === 0) return
        const idx = Math.max(0, Math.min(selectedIndex, combinedResults.length - 1))
        const item = combinedResults[idx]
        if (item) {
            if (item.type === "app") {
                SessionService.launchDesktopEntry(item.data)
            } else if (item.type === "file") {
                Qt.openUrlExternally("file://" + item.data.path)
            }
            hide()
        }
    }

    property var installPopupWindow: null

    function getInstallPopup() {
        if (!installPopupWindow) {
            console.log("[Spotlight] Creating InstallPopupWindow...")
            const url = Qt.resolvedUrl("Modules/PackageManager/InstallPopupWindow.qml")
            console.log("[Spotlight] Component URL:", url.toString())
            const component = Qt.createComponent(url)
            if (component.status === Component.Ready) {
                installPopupWindow = component.createObject(null)
                console.log("[Spotlight] InstallPopupWindow created:", !!installPopupWindow)
            } else {
                console.log("[Spotlight] Component ERROR:", component.errorString())
                console.log("[Spotlight] Trying file path...")
                const url2 = "file://Modules/PackageManager/InstallPopupWindow.qml"
                const component2 = Qt.createComponent(url2)
                if (component2.status === Component.Ready) {
                    installPopupWindow = component2.createObject(null)
                    console.log("[Spotlight] InstallPopupWindow created via file path")
                } else {
                    console.log("[Spotlight] File path also failed:", component2.errorString())
                }
            }
        }
        return installPopupWindow
    }

    function installSelected() {
        if (combinedResults.length === 0) return
        const idx = Math.max(0, Math.min(selectedIndex, combinedResults.length - 1))
        const item = combinedResults[idx]
        if (item && item.type === "app" && item.data) {
            const pkgInfo = {
                name: item.data.name || "",
                version: item.data.version || "",
                source: "pacman",
                description: item.data.comment || item.data.genericName || "",
                installed: false
            }
            const popup = getInstallPopup()
            if (popup) {
                popup.openPackage(pkgInfo)
            } else {
                console.log("[Spotlight] InstallPopup is null!")
            }
        }
    }

    onSearchQueryChanged: {
        if (searchQuery.length === 0) {
            combinedResults = []
            selectedIndex = 0
            resultFilter = "all"
        } else {
            const apps = AppSearchService.searchApplications(searchQuery)
            combinedResults = apps.map(app => ({ type: "app", data: app }))
            selectedIndex = 0
            FileSearchService.searchFiles(searchQuery, function(files) {
                combinedResults = apps.map(app => ({ type: "app", data: app }))
                                      .concat(files.map(f => ({ type: f.isDirectory ? "directory" : "file", data: f })))
            })
        }
    }

    onResultFilterChanged: {
        selectedIndex = 0
    }

    // Keep selectedIndex in bounds when results or filter change
    onDisplayedResultsChanged: {
        if (displayedResults.length > 0 && selectedIndex >= displayedResults.length) {
            selectedIndex = displayedResults.length - 1
        }
    }

    // ── IPC ──────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "Spotlight"
        function toggle(): string {
            spotlightWindow.toggle()
            return spotlightWindow.spotlightOpen ? "SPOTLIGHT_SHOWN" : "SPOTLIGHT_HIDDEN"
        }
        function open(): string {
            spotlightWindow.show()
            return "SPOTLIGHT_OPEN_SUCCESS"
        }
        function close(): string {
            spotlightWindow.hide()
            return "SPOTLIGHT_CLOSE_SUCCESS"
        }
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    Rectangle {
        id: glassRect
        x:      spotlightWindow.glassX
        y:      spotlightWindow.glassY
        width:  spotlightWindow.barW
        height: spotlightWindow.glassH
        radius: spotlightWindow.barR + 8
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        color: Qt.rgba(
                   Theme.surfaceContainer.r,
                   Theme.surfaceContainer.g,
                   Theme.surfaceContainer.b,
                   SettingsData.spotlightTransparency
               )
        border.color: Qt.rgba(1, 1, 1, 0.13)
        border.width: 1
        clip: true

        // Shadow layer
        Rectangle {
            id: shadowSource
            anchors {
                fill:         parent
                topMargin:    -4
                leftMargin:   -4
                rightMargin:  -4
                bottomMargin: -20
            }
            radius: parent.radius + 4
            color:  "transparent"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            Qt.rgba(0, 0, 0, 0.58)
                shadowBlur:             0.88
                shadowVerticalOffset:   16
                shadowHorizontalOffset: 0
                shadowScale:            1.0
            }
        }

        // ── Content area ────────────────────────────────────────────────────
        Item {
            id: contentArea
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                bottom: parent.bottom
                topMargin:    spotlightWindow.pad / 2
                leftMargin:  spotlightWindow.pad / 2
                rightMargin: spotlightWindow.pad / 2
                bottomMargin: spotlightWindow.pad / 2
            }
            focus: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    spotlightWindow.hide(); event.accepted = true; break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    spotlightWindow.launchSelected(); event.accepted = true; break
                case Qt.Key_Down:
                    if (spotlightWindow.selectedIndex < spotlightWindow.displayedResults.length - 1) spotlightWindow.selectedIndex++
                    event.accepted = true; break
                case Qt.Key_Up:
                    if (spotlightWindow.selectedIndex > 0) spotlightWindow.selectedIndex--
                    event.accepted = true; break
                case Qt.Key_I:
                    if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.AltModifier)) {
                        spotlightWindow.installSelected(); event.accepted = true; break
                    }
                    default:
                        if (!searchInput.activeFocus && event.text && event.text.match(/\S/))
                            searchInput.forceActiveFocus()
                }
            }

            // ── Search bar row ────────────────────────────────────────────────
            Item {
                id: searchBar
                anchors {
                    top:         parent.top
                    left:        parent.left
                    right:       parent.right
                    topMargin:   0
                    leftMargin:  0
                    rightMargin: 0
                }
                height: spotlightWindow.barH

                // Pill background
                Rectangle {
                    anchors.fill: parent
                    radius:       spotlightWindow.barR
                    color: Qt.rgba(
                               Theme.surfaceVariant.r,
                               Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b,
                               0.18
                           )
                    border.color: searchInput.activeFocus
                                      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.72)
                                      : Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1.5
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // 🔍 icon
                Text {
                    id: srchIcon
                    anchors {
                        left:           parent.left
                        leftMargin:     18
                        verticalCenter: parent.verticalCenter
                    }
                    text:           "search"
                    font.family:    "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: searchInput.activeFocus
                               ? Theme.primary
                               : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.38)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Placeholder
                Text {
                    anchors {
                        left:           srchIcon.right
                        leftMargin:     10
                        verticalCenter: parent.verticalCenter
                    }
                    text:    "Spotlight Search"
                    visible: searchInput.text.length === 0
                    font.pixelSize: 19
                    font.weight:    Font.Light
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.28)
                }

                // Input
                TextInput {
                    id: searchInput
                    anchors {
                        left:           srchIcon.right
                        leftMargin:     10
                        right:          clearBtn.visible ? clearBtn.left : parent.right
                        rightMargin:    clearBtn.visible ? 6 : 18
                        verticalCenter: parent.verticalCenter
                    }
                    font.pixelSize:   19
                    font.weight:      Font.Light
                    color:            Theme.surfaceText
                    selectionColor:   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.36)
                    selectedTextColor: Theme.surfaceText
                    clip:             true
                    focus:            true

                    onTextChanged: spotlightWindow.searchQuery = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down   || event.key === Qt.Key_Up     ||
                            event.key === Qt.Key_Return || event.key === Qt.Key_Enter  ||
                            event.key === Qt.Key_Escape)
                            event.accepted = false
                    }

                    Component.onCompleted: {
                        spotlightWindow.searchInputRef = searchInput
                    }
                }

                // Clear ✕
                Item {
                    id: clearBtn
                    anchors {
                        right:          parent.right
                        rightMargin:    12
                        verticalCenter: parent.verticalCenter
                    }
                    width:   26
                    height:  26
                    visible: spotlightWindow.searchQuery.length > 0

                    opacity: clearMouse.containsMouse ? 1.0 : 0.52
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    Rectangle {
                        anchors.fill: parent
                        radius:       13
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.14)
                    }
                    Text {
                        anchors.centerIn: parent
                        text:             "close"
                        font.family:      "Material Symbols Rounded"
                        font.pixelSize:   13
                        color:            Theme.surfaceText
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            spotlightWindow.searchQuery = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }

            // ── Separator ─────────────────────────────────────────────────────
            Rectangle {
                id: divider
                anchors {
                    top:         searchBar.bottom
                    topMargin:   5
                    left:        parent.left
                    right:       parent.right
                    leftMargin:  14
                    rightMargin: 14
                }
                height:  1
                color:   Qt.rgba(1, 1, 1, 0.09)
                visible: spotlightWindow.hasQuery && spotlightWindow.displayedResults.length > 0
            }

            // ── Results ───────────────────────────────────────────────────────
            Item {
                anchors {
                    top:         divider.bottom
                    topMargin:   5
                    left:        parent.left
                    right:       parent.right
                    bottom:      parent.bottom
                    bottomMargin: 6
                    leftMargin:  6
                    rightMargin: 6
                }
                visible: spotlightWindow.hasQuery

                // ── Filter chips ──────────────────────────────────────────────
                Row {
                    id: filterRow
                    anchors {
                        top:   parent.top
                        left:  parent.left
                        right: parent.right
                        leftMargin:  4
                        rightMargin: 4
                    }
                    height:  34
                    spacing: 6
                    visible: spotlightWindow.hasQuery

                    property string activeFilter: spotlightWindow.resultFilter
                    function setFilter(f) { spotlightWindow.resultFilter = f }

                    Repeater {
                        model: [
                            { key: "all",    label: "All",    icon: "apps"         },
                            { key: "apps",   label: "Apps",   icon: "widgets"      },
                            { key: "images", label: "Images", icon: "image"        },
                            { key: "text",   label: "Text",   icon: "description"  }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: filterRow.activeFilter === modelData.key
                            readonly property bool hasItems: {
                                const k = modelData.key
                                if (k === "all")    return spotlightWindow.combinedResults.length > 0
                                if (k === "apps")   return spotlightWindow.combinedResults.some(i => i.type === "app")
                                if (k === "images") return spotlightWindow.combinedResults.some(i => spotlightWindow.isImageFile(i))
                                if (k === "text")   return spotlightWindow.combinedResults.some(i => spotlightWindow.isTextFile(i))
                                return false
                            }

                            anchors.verticalCenter: parent.verticalCenter
                            height:  28
                            width:   chipLabel.implicitWidth + chipIcon.implicitWidth + 20
                            radius:  14
                            visible: hasItems || modelData.key === "all"
                            opacity: hasItems ? 1.0 : 0.35

                            color: active
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                            border.color: active
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            Behavior on color       { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    id: chipIcon
                                    text:           modelData.icon
                                    font.family:    "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: active ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                Text {
                                    id: chipLabel
                                    text:           modelData.label
                                    font.pixelSize: 12
                                    font.weight:    active ? Font.Medium : Font.Normal
                                    color: active ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                enabled:      parent.hasItems || modelData.key === "all"
                                onClicked:    filterRow.setFilter(modelData.key)
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: spotlightWindow.displayedResults.length === 0 && spotlightWindow.hasQuery
                    text:    "No results"
                    font.pixelSize: 13
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.33)
                }

                ListView {
                    id: resultsList
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    anchors.topMargin: spotlightWindow.hasQuery ? 40 : 0
                    model:                spotlightWindow.displayedResults
                    clip:                 true
                    spacing:              2
                    currentIndex:         spotlightWindow.selectedIndex
                    boundsBehavior:       Flickable.StopAtBounds
                    keyNavigationEnabled: false

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius:        2
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.20)
                        }
                        background: Rectangle { color: "transparent" }
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }

                    delegate: Item {
                        id: row

                        required property int index
                        required property var modelData  // { type: "app"|"file", data: app/file }

                        width:  resultsList.width
                        height: spotlightWindow.itemH

                        readonly property bool sel: row.index === spotlightWindow.selectedIndex
                        readonly property bool isApp: row.modelData.type === "app"
                        readonly property bool isFile: row.modelData.type === "file"
                        readonly property var itemData: row.modelData.data

                        Rectangle {
                            anchors {
                                fill:         parent
                                leftMargin:   2
                                rightMargin:  2
                                topMargin:    1
                                bottomMargin: 1
                            }
                            radius: 10
                            color: row.sel
                                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.19)
                                       : rowMouse.containsMouse
                                           ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                           : "transparent"
                            Behavior on color { ColorAnimation { duration: 75 } }

                            // Selection accent bar
                            Rectangle {
                                anchors {
                                    left:           parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                width:   3
                                height:  20
                                radius:  2
                                color:   Theme.primary
                                visible: row.sel
                                opacity: 0.82
                            }

                            // Icon
                            Item {
                                id: iconWrap
                                anchors {
                                    left:           parent.left
                                    leftMargin:     14
                                    verticalCenter: parent.verticalCenter
                                }
                                width:  34
                                height: 34

                                IconImage {
                                    id: ico
                                    anchors.fill: parent
                                    source: row.isApp
                                            ? Quickshell.iconPath(row.itemData.icon, true)
                                            : Quickshell.iconPath(getFileIcon(row.itemData), true)
                                    asynchronous: true
                                    smooth:       true
                                    visible:      status === Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible:      !ico.visible
                                    radius:       8
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.36)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: row.itemData && row.itemData.name
                                                  ? row.itemData.name.charAt(0).toUpperCase() : "?"
                                        font.pixelSize: 14
                                        font.weight:    Font.Medium
                                        color:          Theme.primary
                                    }
                                }
                            }

                            // Name + subtitle
                            Column {
                                anchors {
                                    left:           iconWrap.right
                                    leftMargin:     12
                                    right:          badge.visible ? badge.left : parent.right
                                    rightMargin:    badge.visible ? 8 : 12
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 2

                                Text {
                                    width:          parent.width
                                    text:           row.itemData ? (row.itemData.name || "") : ""
                                    font.pixelSize: 14
                                    font.weight:    Font.Medium
                                    color:          Theme.surfaceText
                                    elide:          Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: row.isApp
                                              ? (row.itemData.comment || row.itemData.genericName || "Application")
                                              : row.itemData.path || ""
                                    font.pixelSize: 12
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.46)
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }

                            // Category badge (apps only)
                            Rectangle {
                                id: badge
                                anchors {
                                    right:          parent.right
                                    rightMargin:    12
                                    verticalCenter: parent.verticalCenter
                                }
                                height:  20
                                width:   badgeText.implicitWidth + 14
                                radius:  10
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                visible: row.sel && badgeText.text.length > 0 && row.isApp

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: {
                                        if (!row.isApp || !row.itemData) return ""
                                        const c = AppSearchService.getCategoriesForApp(row.itemData)
                                        return (c && c.length > 0) ? c[0] : ""
                                    }
                                    font.pixelSize: 10
                                    font.weight:    Font.Medium
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.90)
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onEntered:    spotlightWindow.selectedIndex = row.index
                                onClicked: {
                                    if (row.modelData) {
                                        if (row.isApp) {
                                            SessionService.launchDesktopEntry(row.itemData)
                                        } else if (row.isFile) {
                                            Qt.openUrlExternally("file://" + row.itemData.path)
                                        }
                                        spotlightWindow.hide()
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
