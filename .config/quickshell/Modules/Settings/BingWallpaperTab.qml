import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: bingWallpaperTab

    property var parentModal: null

    // ── Paths ────────────────────────────────────────────────────────────────
    readonly property string homeDir: Paths.home.toString().replace("file://", "")
    readonly property string pythonScript: homeDir + "/.config/quickshell/scripts/BingWallpaper.py"
    property string downloadPath: homeDir + "/Pictures/BingWallpaper"

    // ── Year / Month pickers ─────────────────────────────────────────────────
    property int selectedYear:  new Date().getFullYear()
    property int selectedMonth: new Date().getMonth() + 1

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    readonly property var availableYears: {
        var arr = []
        var cur = new Date().getFullYear()
        for (var y = cur; y >= 2014; y--) arr.push(y)
        return arr
    }

    // ── State ────────────────────────────────────────────────────────────────
    property bool isDownloading:      false
    property bool isCheckingUpdates:  false
    property bool isFetchingDaily:    false

    property int  progressCurrent:    0
    property int  progressTotal:      0
    property int  updateCount:        0
    property int  downloadedCount:    0
    property int  failedCount:        0
    property int  skippedCount:       0
    property int  foundInArchive:     -1
    property string statusText:       ""
    property string statusType:       "idle"

    readonly property real progressFraction: progressTotal > 0
        ? Math.min(1.0, progressCurrent / progressTotal)
        : (isDownloading ? -1 : 0)

    // ── Daily wallpaper ──────────────────────────────────────────────────────
    property string dailyWallpaperPath: ""
    property string newestAvailableDate: ""

    // ── Archive UI state ─────────────────────────────────────────────────────
    property bool downloadEntireArchive: false

    Timer {
        id: dailyCheckTimer
        interval: 3600000
        repeat: true
        running: SessionData.bingDailyWallpaperEnabled || false
        onTriggered: fetchDailyWallpaper()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Processes
    // ─────────────────────────────────────────────────────────────────────────

    Process {
        id: checkUpdatesProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                bingWallpaperTab.isCheckingUpdates = false
                var lines = text.trim().split('\n')
                var count = 0
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.startsWith("UPDATE_COUNT:")) {
                        count = parseInt(line.split(":")[1]) || 0
                    }
                }
                bingWallpaperTab.updateCount = count
                if (count > 0) {
                    bingWallpaperTab.statusText = count + " new wallpaper" + (count > 1 ? "s" : "") + " available to download"
                    bingWallpaperTab.statusType = "info"
                    ToastService.showInfo(count + " new Bing wallpaper" + (count > 1 ? "s" : "") + " available!")
                } else {
                    bingWallpaperTab.statusText = "Already up to date — no new wallpapers"
                    bingWallpaperTab.statusType = "success"
                    ToastService.showInfo("Already up to date")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) console.warn("checkUpdatesProc stderr:", text.trim())
            }
        }
    }

    Process {
        id: downloadProc
        running: false

        onExited: function(exitCode, exitStatus) {
            console.log("[BingWallpaper] downloadProc exited code=" + exitCode + " status=" + exitStatus)
            if (exitCode !== 0 && bingWallpaperTab.isDownloading) {
                bingWallpaperTab.isDownloading = false
                bingWallpaperTab.statusText = "Script failed (exit code " + exitCode + ") — check logs"
                bingWallpaperTab.statusType = "error"
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                bingWallpaperTab.isDownloading = false
                console.log("[BingWallpaper] stdout:", text)
                var lines = text.trim().split('\n')
                var dl = 0, skip = 0, fail = 0

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue

                    if (line.startsWith("DONE:")) {
                        var m = line.match(/downloaded=(\d+).*?skipped=(\d+).*?failed=(\d+)/)
                        if (m) {
                            dl   = parseInt(m[1])
                            skip = parseInt(m[2])
                            fail = parseInt(m[3])
                        }
                    } else if (line.startsWith("NEWEST:")) {
                        bingWallpaperTab.newestAvailableDate = line.substring(7).trim()
                    } else if (line.startsWith("FOUND:")) {
                        bingWallpaperTab.foundInArchive = parseInt(line.substring(6)) || 0
                    } else if (line.startsWith("TOTAL:")) {
                        bingWallpaperTab.progressTotal = parseInt(line.substring(6)) || 0
                    } else if (line.startsWith("PROGRESS:")) {
                        var parts = line.substring(9).split("/")
                        bingWallpaperTab.progressCurrent = parseInt(parts[0]) || 0
                        if (!bingWallpaperTab.progressTotal)
                            bingWallpaperTab.progressTotal = parseInt(parts[1]) || 0
                    }
                }

                bingWallpaperTab.downloadedCount = dl
                bingWallpaperTab.skippedCount    = skip
                bingWallpaperTab.failedCount     = fail
                bingWallpaperTab.progressCurrent = bingWallpaperTab.progressTotal
                bingWallpaperTab.updateCount     = 0

                var found = bingWallpaperTab.foundInArchive
                if (dl > 0) {
                    bingWallpaperTab.statusText = "Downloaded " + dl + " wallpaper" + (dl !== 1 ? "s" : "")
                                                + (fail > 0 ? " · " + fail + " failed" : "")
                    bingWallpaperTab.statusType = fail > 0 ? "error" : "success"
                    ToastService.showInfo("Downloaded " + dl + " wallpaper" + (dl !== 1 ? "s" : ""))
                } else if (fail > 0) {
                    bingWallpaperTab.statusText = fail + " download" + (fail !== 1 ? "s" : "") + " failed"
                    bingWallpaperTab.statusType = "error"
                } else if (found === 0) {
                    var newest = bingWallpaperTab.newestAvailableDate
                    bingWallpaperTab.statusText = newest
                        ? "Not in archive yet — newest available is " + newest
                        : "No wallpapers found in the archive for this period"
                    bingWallpaperTab.statusType = "info"
                } else if (skip > 0) {
                    bingWallpaperTab.statusText = "All " + skip + " wallpaper" + (skip !== 1 ? "s" : "") + " already downloaded"
                    bingWallpaperTab.statusType = "success"
                } else {
                    bingWallpaperTab.statusText = "Nothing to download"
                    bingWallpaperTab.statusType = "info"
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    console.warn("downloadProc stderr:", text.trim())
                    bingWallpaperTab.isDownloading = false
                    bingWallpaperTab.statusText = "Error: " + text.trim().split("\n")[0]
                    bingWallpaperTab.statusType = "error"
                }
            }
        }
    }

    Process {
        id: dailyProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                bingWallpaperTab.isFetchingDaily = false
                var lines = text.trim().split('\n')
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.startsWith("DAILY:")) {
                        var path = line.substring(6).trim()
                        if (path !== "") {
                            bingWallpaperTab.dailyWallpaperPath = path
                            if (SessionData.perMonitorWallpaper) {
                                var screens = Quickshell.screens
                                var mon = screens.length > 0 ? screens[0].name : ""
                                SessionData.setMonitorWallpaper(mon, path)
                            } else {
                                SessionData.setWallpaper(path)
                            }
                            ToastService.showInfo("Daily wallpaper: " + path.split('/').pop())
                        }
                        return
                    } else if (line.startsWith("DAILY_ERROR:")) {
                        var errMsg = line.substring(12)
                        console.warn("Daily wallpaper error:", errMsg)
                        ToastService.showError("Daily wallpaper failed: " + errMsg)
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                bingWallpaperTab.isFetchingDaily = false
                if (text.trim()) console.warn("dailyProc stderr:", text.trim())
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    Component.onCompleted: {
        loadDownloadPath()
        if (SessionData.bingDailyWallpaperEnabled) {
            fetchDailyWallpaper()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Functions
    // ─────────────────────────────────────────────────────────────────────────

    function loadDownloadPath() {
        if (SessionData.bingWallpaperGalleryPath && SessionData.bingWallpaperGalleryPath !== "") {
            downloadPath = SessionData.bingWallpaperGalleryPath.replace('file://', '').replace(/\/$/, '')
        } else {
            downloadPath = homeDir + "/Pictures/BingWallpaper"
        }
    }

    function saveDownloadPath(path) {
        downloadPath = path.replace(/\/$/, '')
        SessionData.bingWallpaperGalleryPath = downloadPath + "/"
        SessionData.saveSettings()
    }

    function checkForUpdates() {
        if (isCheckingUpdates || isDownloading) return
        isCheckingUpdates = true
        updateCount       = 0
        statusText        = "Fetching remote wallpaper list…"
        statusType        = "idle"

        checkUpdatesProc.running = false
        checkUpdatesProc.command = [
            "python3", pythonScript,
            "--check-updates",
            "--path", downloadPath
        ]
        checkUpdatesProc.running = true
    }

    function downloadWallpapers(filterType, customMonth) {
        if (isDownloading) return
        isDownloading    = true
        downloadedCount  = 0
        failedCount      = 0
        skippedCount     = 0
        progressCurrent  = 0
        progressTotal    = 0
        foundInArchive   = -1
        newestAvailableDate = ""

        var label = filterType === "custom" && customMonth ? customMonth
                  : filterType === "current" ? "this month"
                  : filterType === "last"    ? "last month"
                  : "entire archive"
        statusText = "Fetching wallpaper list for " + label + "…"
        statusType = "idle"

        var cmd = ["python3", pythonScript, "--download", "--filter", filterType, "--path", downloadPath]
        if (filterType === "custom" && customMonth) {
            cmd.push("--month")
            cmd.push(customMonth)
        }
        console.log("[BingWallpaper] command:", JSON.stringify(cmd))
        downloadProc.running = false
        downloadProc.command = cmd
        downloadProc.running = true
    }

    function fetchDailyWallpaper() {
        if (isFetchingDaily) return
        isFetchingDaily = true
        dailyProc.running = false
        dailyProc.command = [
            "python3", pythonScript,
            "--daily",
            "--use-cache",
            "--path", downloadPath
        ]
        dailyProc.running = true
    }

    function applyWallpaperPath(path) {
        var cleanPath = Paths.strip(path)
        if (SessionData.perMonitorWallpaper) {
            SessionData.setMonitorWallpaper("", path)
        } else {
            SessionData.setWallpaper(path)
        }
        ToastService.showInfo("Applied: " + path.split('/').pop())
    }

    function selectedMonthString() {
        return selectedYear + "-" + (selectedMonth < 10 ? "0" + selectedMonth : "" + selectedMonth)
    }

    component ActionButton: Item {
        id: btn
        property string label: ""
        property string iconName: ""
        property bool enabled: true
        signal clicked

        width: btnRow.implicitWidth + Theme.spacingL * 2
        height: 34

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: btnArea.containsMouse
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                  btnArea.containsMouse ? 0.45 : 0.22)

            Behavior on color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
            Behavior on border.color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
        }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            EHIcon {
                name: btn.iconName
                size: 14
                color: Theme.primary
                visible: btn.iconName !== ""
            }

            StyledText {
                text: btn.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
            }
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
            enabled: btn.enabled
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────────────────

    component StyledCombo: ComboBox {
        id: styledCombo

        height: 32
        leftPadding: 10
        rightPadding: 10

        background: Rectangle {
            radius: 6
            color: styledCombo.hovered
                ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.38)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, styledCombo.hovered ? 0.28 : 0.16)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 100 } }
        }

        contentItem: Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 28
            spacing: 6

            StyledText {
                text: styledCombo.displayText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - 6
            }
        }

        indicator: EHIcon {
            name: "expand_more"
            size: 16
            color: Theme.surfaceVariantText
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }

        popup: Popup {
            y: styledCombo.height + 2
            width: styledCombo.width
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
            padding: 4
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
                radius: 8
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.96)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                border.width: 1
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: styledCombo.popup.visible ? styledCombo.delegateModel : null
                currentIndex: styledCombo.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
        }

        delegate: ItemDelegate {
            width: styledCombo.width - 8
            height: 32

            background: Rectangle {
                radius: 6
                color: highlighted
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                    : "transparent"
            }

            contentItem: StyledText {
                text: modelData
                font.pixelSize: Theme.fontSizeSmall
                font.weight: styledCombo.currentIndex === index ? Font.Medium : Font.Normal
                color: styledCombo.currentIndex === index ? Theme.primary : Theme.surfaceText
                leftPadding: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────────────────

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            leftPadding: Theme.spacingL
            rightPadding: Theme.spacingL
            spacing: Theme.spacingL

            // ══════════════════════════════════════════════════════════════════
            // SECTION 1 — Download Directory
            // ══════════════════════════════════════════════════════════════════

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                height: downloadSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: downloadSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "folder_open"
                            size: Theme.iconSize
                            color: Theme.primary
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true

                            StyledText {
                                text: "Download Directory"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Where to save downloaded Bing wallpapers"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: text.length > 0
                            }
                        }
                    }

                    // Browse row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Save location"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            Layout.preferredWidth: 140
                        }

                        EHTextField {
                            id: pathField
                            Layout.fillWidth: true
                            text: bingWallpaperTab.downloadPath
                            readOnly: true
                            placeholderText: "Select a folder..."
                            showClearButton: false
                            backgroundColor: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                        }

                        ActionButton {
                            label: "Browse"
                            iconName: "folder_open"
                            onClicked: folderBrowser.open()
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // SECTION 2 — Daily Wallpaper
            // ══════════════════════════════════════════════════════════════════

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                height: dailySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dailySection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "today"
                            size: Theme.iconSize
                            color: Theme.primary
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true

                            StyledText {
                                text: "Daily Wallpaper"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically fetch and apply today's newest Bing wallpaper"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: text.length > 0
                            }
                        }

                        EHToggle {
                            id: dailyToggle
                            checked: SessionData.bingDailyWallpaperEnabled || false
                            onToggled: function(toggled) {
                                SessionData.bingDailyWallpaperEnabled = toggled
                                SessionData.saveSettings()
                                if (toggled) {
                                    fetchDailyWallpaper()
                                    dailyCheckTimer.restart()
                                } else {
                                    dailyCheckTimer.stop()
                                }
                            }
                        }
                    }

                    // Status row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: dailyWallpaperPath !== "" || isFetchingDaily

                        EHIcon {
                            name: isFetchingDaily ? "hourglass_empty" : "check_circle"
                            size: 20
                            color: Theme.primary
                        }

                        StyledText {
                            text: isFetchingDaily ? "Fetching daily wallpaper…"
                                  : dailyWallpaperPath.split('/').pop()
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }

                        ActionButton {
                            label: isFetchingDaily ? "Fetching…" : "Fetch Now"
                            iconName: isFetchingDaily ? "hourglass_empty" : "refresh"
                            enabled: !isFetchingDaily
                            onClicked: fetchDailyWallpaper()
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // SECTION 3 — Updates
            // ══════════════════════════════════════════════════════════════════

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                height: updatesSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: updatesSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "sync"
                            size: Theme.iconSize
                            color: Theme.primary
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true

                            StyledText {
                                text: "Updates"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Check for new wallpapers and download them"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: text.length > 0
                            }
                        }
                    }

                    // Status message when updates available or checking
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: updateCount > 0 || isCheckingUpdates

                        EHIcon {
                            name: isCheckingUpdates ? "hourglass_empty" : "new_releases"
                            size: 20
                            color: Theme.primary
                        }

                        StyledText {
                            text: isCheckingUpdates ? "Checking for updates…"
                                  : updateCount + " new wallpaper" + (updateCount > 1 ? "s" : "") + " available"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }
                    }

                    // Action buttons
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        ActionButton {
                            id: downloadUpdatesBtn
                            label: "Download " + updateCount + " New"
                            iconName: "download"
                            visible: updateCount > 0
                            enabled: !isDownloading && !isCheckingUpdates
                            onClicked: downloadWallpapers("all", null)
                        }

                        ActionButton {
                            id: checkNowBtn
                            label: isCheckingUpdates ? "Checking…" : "Check Now"
                            iconName: isCheckingUpdates ? "hourglass_empty" : "sync"
                            enabled: !isCheckingUpdates && !isDownloading
                            onClicked: checkForUpdates()
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // SECTION 4 — Archive Download
            // ══════════════════════════════════════════════════════════════════

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                height: archiveSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: archiveSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "download"
                            size: Theme.iconSize
                            color: Theme.primary
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true

                            StyledText {
                                text: "Archive Download"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Choose a time range. Already-downloaded wallpapers are skipped automatically."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    // Quick selection buttons
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        ActionButton {
                            label: "This Month"
                            iconName: "calendar_month"
                            enabled: !isDownloading && !isCheckingUpdates
                            onClicked: downloadWallpapers("current", null)
                        }

                        ActionButton {
                            label: "Last Month"
                            iconName: "calendar_month"
                            enabled: !isDownloading && !isCheckingUpdates
                            onClicked: downloadWallpapers("last", null)
                        }
                    }

                    // Year / Month selectors
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        enabled: !downloadEntireArchive

                        Column {
                            spacing: Theme.spacingS
                            width: (parent.width - Theme.spacingM) / 2
                            opacity: downloadEntireArchive ? 0.4 : 1.0

                            StyledText {
                                text: "Year"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }

                            StyledCombo {
                                width: parent.width
                                model: bingWallpaperTab.availableYears
                                currentIndex: {
                                    var idx = bingWallpaperTab.availableYears.indexOf(bingWallpaperTab.selectedYear)
                                    return idx >= 0 ? idx : 0
                                }
                                enabled: !downloadEntireArchive && !isDownloading && !isCheckingUpdates
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < bingWallpaperTab.availableYears.length) {
                                        bingWallpaperTab.selectedYear = bingWallpaperTab.availableYears[currentIndex]
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingS
                            width: (parent.width - Theme.spacingM) / 2
                            opacity: downloadEntireArchive ? 0.4 : 1.0

                            StyledText {
                                text: "Month"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }

                            StyledCombo {
                                id: monthCombo
                                width: parent.width
                                model: bingWallpaperTab.monthNames
                                currentIndex: bingWallpaperTab.selectedMonth - 1
                                enabled: !downloadEntireArchive && !isDownloading && !isCheckingUpdates
                                onCurrentIndexChanged: {
                                    bingWallpaperTab.selectedMonth = currentIndex + 1
                                }
                            }
                        }
                    }

                    // Entire archive checkbox
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            id: archiveCheckbox
                            width: 20
                            height: 20
                            radius: 4
                            color: downloadEntireArchive
                                ? Theme.primary
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            border.color: downloadEntireArchive
                                ? Theme.primary
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 100 } }

                            EHIcon {
                                name: "check"
                                size: 14
                                color: Theme.primaryContainerText || Theme.surfaceTextInvert || "white"
                                anchors.centerIn: parent
                                visible: downloadEntireArchive
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bingWallpaperTab.downloadEntireArchive = !bingWallpaperTab.downloadEntireArchive
                            }
                        }

                        StyledText {
                            text: "Download Entire Archive"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: archiveCheckbox.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bingWallpaperTab.downloadEntireArchive = !bingWallpaperTab.downloadEntireArchive
                            }
                        }
                    }

                    // Download button
                    ActionButton {
                        label: downloadEntireArchive
                            ? "Download Entire Archive"
                            : "Download " + bingWallpaperTab.monthNames[bingWallpaperTab.selectedMonth - 1] + " " + bingWallpaperTab.selectedYear
                        iconName: "download"
                        width: parent.width
                        enabled: !isDownloading && !isCheckingUpdates
                        onClicked: {
                            if (downloadEntireArchive) {
                                downloadWallpapers("all", null)
                            } else {
                                downloadWallpapers("custom", selectedMonthString())
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // SECTION 5 — Progress & Status
            // ══════════════════════════════════════════════════════════════════

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                height: progressSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isDownloading || isCheckingUpdates || statusText !== ""

                Column {
                    id: progressSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM
                    visible: parent.visible

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: (isDownloading || isCheckingUpdates) ? "hourglass_empty" : "info"
                            size: Theme.iconSize
                            color: Theme.primary
                        }

                        StyledText {
                            text: "Status"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    // Status message
                    StyledText {
                        width: parent.width
                        text: statusText !== "" ? statusText : (isCheckingUpdates ? "Checking for updates…" : "Downloading…")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    // Progress bar (only when downloading)
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: isDownloading

                        // Label row
                        RowLayout {
                            width: parent.width

                            StyledText {
                                text: progressTotal > 0
                                    ? progressCurrent + " / " + progressTotal + " wallpapers"
                                    : "Fetching list…"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: progressTotal > 0 ? Math.round(progressFraction * 100) + "%" : "…"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.primary
                            }
                        }

                        // Track
                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            clip: true
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                            // Indeterminate shimmer
                            Rectangle {
                                id: indeterminateBar
                                width: parent.width * 0.35
                                height: parent.height
                                radius: 2
                                color: Theme.primary
                                visible: progressTotal <= 0

                                NumberAnimation on x {
                                    running: progressTotal <= 0 && isDownloading
                                    loops: Animation.Infinite
                                    from: -indeterminateBar.width
                                    to: parent.width
                                    duration: 1200
                                    easing.type: Easing.InOutSine
                                }
                            }

                            // Progress fill
                            Rectangle {
                                width: progressTotal > 0 ? Math.max(0, Math.min(parent.width, parent.width * progressFraction)) : 0
                                height: parent.height
                                radius: 2
                                color: Theme.primary
                                visible: progressTotal > 0
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // File browser modal
    // ─────────────────────────────────────────────────────────────────────────

    FileBrowserModal {
        id: folderBrowser
        browserTitle: "Select Download Folder"
        browserIcon: "folder_open"
        browserType: "generic"
        onFileSelected: path => {
            saveDownloadPath(path)
            bingWallpaperTab.downloadPath = path
        }
    }
}
