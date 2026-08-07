import QtQuick
import QtCore
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules
import qs.Modules.Plugins

PluginComponent {
    id: root
    
    property int bingDownloadInterval: 3 * 60 * 60 * 1000
    
    property string systemLocale: Qt.locale().name
    
    property string cachePath: pluginData.GnomeExtensionBingWallpaperCompatibility
                               ? StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/BingWallpaper/"
                               : Paths.cache + "/bingwall/"
    property string currentMetadatapath: Paths.cache + "/bingwall/metadata.json"
    property string fullImageUrl: ""
    
    property string currentImageSavePath: ""
    property string currentTitle: ""
    property string currentDescription: ""
    
    property bool isStarting: false
    property bool isLoading: false
    property bool isForcing: false
    property bool isDownloading: false

    Component.onCompleted: {
        root.isStarting = true
        startDelayTimer.start()
    }
    
    Component.onDestruction: {}
    
    signal wallpaperDataUpdated()

    Timer {
        id: startDelayTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            checkForEnvironmentAndStart()
        }
    }
    
    Timer {
        id: bingwallTimer
        interval: root.bingDownloadInterval
        running: false
        repeat: true
        onTriggered: {
            wallpaperCheck()
        }
    }

    Timer {
        id: dailyRefreshTimer
        running: false
        repeat: false
        onTriggered: {
            console.log("Wallpaper of the day: Daily refresh triggered at scheduled time")
            ToastService.showInfo("Daily wallpaper refresh triggered")
            wallpaperCheck()
            scheduleDailyRefresh()
        }
    }
    
    Connections {
        target: SessionData

        function onWallpaperCyclingEnabledChanged() {
            updateTimerState()
        }

        function onWallpaperCyclingModeChanged() {
            updateTimerState()
        }

        function onPerMonitorWallpaperChanged() {
            updateTimerState()
        }

        function onMonitorCyclingSettingsChanged() {
            updateTimerState()
        }

        function onPerModeWallpaperChanged() {
            updateTimerState()
        }
    }

    property var lastEnableDailyRefresh: pluginData.enableDailyRefresh
    property var lastDailyRefreshTime: pluginData.dailyRefreshTime

    onLastEnableDailyRefreshChanged: {
        updateDailyRefreshTimer()
    }

    onLastDailyRefreshTimeChanged: {
        updateDailyRefreshTimer()
    }
    
    function checkForEnvironmentAndStart() {
        pathExists(root.cachePath, function(exists) {
            if (!exists) {
                Paths.mkdir(root.cachePath)
            }
            pathExists(root.currentMetadatapath, function(exists) {
                if (!exists) {
                    saveMetadata()
                }
                readMetadata(bingMetadataFile.text())
                wallpaperCheck()
                updateDailyRefreshTimer()
                bingwallTimer.start()
            })
        })
    }

    function updateDailyRefreshTimer() {
        if (pluginData.enableDailyRefresh) {
            scheduleDailyRefresh()
        } else {
            dailyRefreshTimer.stop()
        }
    }

    function scheduleDailyRefresh() {
        if (!pluginData.enableDailyRefresh) {
            return
        }

        const timeString = pluginData.dailyRefreshTime || "09:00"
        const timeParts = timeString.split(":")

        if (timeParts.length !== 2) {
            console.error("Wallpaper of the day: Invalid time format:", timeString)
            return
        }

        const targetHour = parseInt(timeParts[0])
        const targetMinute = parseInt(timeParts[1])

        if (isNaN(targetHour) || isNaN(targetMinute) || targetHour < 0 || targetHour > 23 || targetMinute < 0 || targetMinute > 59) {
            console.error("Wallpaper of the day: Invalid time values:", timeString)
            return
        }

        const now = new Date()
        const target = new Date()
        target.setHours(targetHour)
        target.setMinutes(targetMinute)
        target.setSeconds(0)
        target.setMilliseconds(0)

        // If target time has already passed today, schedule for tomorrow
        if (target <= now) {
            target.setDate(target.getDate() + 1)
        }

        const msUntilTarget = target - now
        dailyRefreshTimer.interval = msUntilTarget
        dailyRefreshTimer.start()

        console.log("Wallpaper of the day: Daily refresh scheduled for", target.toLocaleString(), "(in", Math.round(msUntilTarget / 1000 / 60), "minutes)")
    }
    
    function forceWallpaperCheck() {
        if (root.isDownloading) {
            return
        }
        root.isForcing = true
        wallpaperCheck()
    }

    function wallpaperCheck() {
        if (root.isDownloading) {
            return
        }
        const command = ["ping", "-c", "1", "1.1.1.1"]
        Proc.runCommand(null, command, 
            (output, exitCode) => {
                if (exitCode === 0) {
                    root.isDownloading = true
                    console.log("Wallpaper of the day: Checking for a new wallpaper...")
                    downloadWallpaper()
                }
            }
        , 0)
    }
    
    function downloadWallpaper() {
        const curlCmd = `curl -s 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${root.systemLocale}'`
        const command = ["sh", "-c", curlCmd]
        Proc.runCommand(null, command, (output, exitCode) => {
            if (exitCode === 0) {
                try {
                    const response = JSON.parse(output.trim())
                    const responseData = response.images[0]
                    
                    if (root.currentTitle !== responseData.title || SessionData.wallpaperPath === "" || root.isForcing) {
                        root.currentTitle = responseData.title
                        root.currentDescription = responseData.copyright
                        const lastImagePath = root.currentImageSavePath
    
                        var imageUrl = responseData.url.split('&')[0]
                        imageUrl = imageUrl.replace("1920x1080", "UHD")
                        root.fullImageUrl = "https://www.bing.com" + imageUrl

                        const namePart = imageUrl.split('OHR.')[1];
                        const lastDot = namePart.lastIndexOf('.');
                        const fileName = namePart.substring(0, lastDot)
                        const extension = namePart.substring(lastDot + 1)
                        
                        if (pluginData.GnomeExtensionBingWallpaperCompatibility) {
                            // Add date prefix in YYYYMMDD format to match gnome extension
                            const datePrefix = responseData.startdate
                            root.currentImageSavePath = Paths.strip(root.cachePath + `${datePrefix}-${fileName}.${extension}`)
                        } else {
                            // Default behavior
                            root.currentImageSavePath = Paths.strip(root.cachePath + `${fileName}.${extension}`)
                        }
                        
                        if (pluginData.deleteOld) {
                            pathExists(lastImagePath, function(exists) {
                                if (exists) {
                                    Quickshell.execDetached(["rm", "-f", lastImagePath])
                                }
                            })
                        }
                        
                        saveMetadata()
                        
                        const curlCmd = `curl -s -o '${root.currentImageSavePath}' '${root.fullImageUrl}'`
                        const command = ["sh", "-c", curlCmd]
                        Proc.runCommand(null, command, (output, exitCode) => {
                            if (exitCode === 0) {
                                if (!root.isForcing) {
                                    bingNotification()
                                } else {
                                    ToastService.showInfo(`Check finished`)
                                }
                                SessionData.setWallpaper(root.currentImageSavePath)
                                root.wallpaperDataUpdated()
                                // Trigger real-time dynamic theming
                                if (typeof ColorPaletteService !== 'undefined') {
                                    ColorPaletteService.onWallpaperChanged(root.currentImageSavePath)
                                }
                            } else {
                                console.error("Wallpaper of the day: Failed to download image.")
                                ToastService.showError(`Wallpaper download failed`)
                            }
                            root.isForcing = false
                        }, 0)
                    } else {
                        console.log("Wallpaper of the day: No new wallpaper found")
                        if (root.isStarting === 0) {
                            SessionData.setWallpaper(root.currentImageSavePath)
                            root.wallpaperDataUpdated()
                            // Trigger real-time dynamic theming
                            if (typeof ColorPaletteService !== 'undefined') {
                                ColorPaletteService.onWallpaperChanged(root.currentImageSavePath)
                            }
                        }
                    }
                    root.isDownloading = false
                } catch (e) {
                    console.error("Error parsing Bing API response: ", e)
                } finally {
                    root.isStarting = false
                    console.log("Wallpaper of the day: Check finished")
                }
            } else {
                console.error("Wallpaper of the day: Failed to retrieve metadata.")
                ToastService.showError(`Wallpaper download failed`)
                root.isForcing = false
                root.isDownloading = false
                root.isStarting = false
            }
        }, 0)
    }
      
    function bingNotification() {
        if (pluginData.notifications) {
            var command = ["notify-send", "-a", "EH", "-i", "preferences-wallpaper", root.currentTitle, root.currentDescription]
            Quickshell.execDetached(command)
        }
    }
    
    function updateTimerState() {
        if (SessionData.perMonitorWallpaper || SessionData.wallpaperCyclingEnabled || SessionData.perModeWallpaper) {
            bingwallTimer.stop()
            ToastService.showInfo(`Wallpaper of the Day: update timer stopped`)
        }
    }
   
    function readMetadata(content) {
        root.isLoading = true
        try {
            if (content && content.trim()) {
                var metadata = JSON.parse(content)
                
                root.currentImageSavePath = metadata.currentImageSavePath !== undefined ? metadata.currentImageSavePath : ""
                root.currentTitle = metadata.currentTitle !== undefined ? metadata.currentTitle : ""
                root.currentDescription = metadata.currentDescription !== undefined ? metadata.currentDescription : ""
            }
        } catch (e) {
            console.error("Wallpaper of the day: Error loading metadata: ", e)
        } finally {
            root.isLoading = false
        }
    }

    function saveMetadata() {
        if (root.isLoading) {
            return
        }
        bingMetadataFile.setText(JSON.stringify({
            "currentImageSavePath": root.currentImageSavePath,
            "currentTitle": root.currentTitle,
            "currentDescription": root.currentDescription
        }, null, 2))
    }
    
    function pathExists(path: url, callback) {
        var stripped = Paths.strip(path)
        var command = ["sh", "-c", `test -e '${stripped}'`]
        Proc.runCommand(null, command, (output, exitCode) => {
            if (callback) {
                callback(exitCode === 0)
            }
        }, 0)
    }
    
    FileView {
        id: bingMetadataFile

        path: root.currentMetadatapath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        onFileChanged: {
            // nothing
        }
        onLoadFailed: error => {
            console.error("Wallpaper of the day: Error with metadata file => ", error)
            bingwallTimer.stop()
        }
    }

    popoutWidth: 380
    popoutHeight: 420
    popoutContent: Component {
        id: popoutContent

        Item {
            anchors.fill: parent

            Connections {
                target: root
                function onWallpaperDataUpdated() {
                    bingwallImage.imagePath = "file://" + root.currentImageSavePath
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // ── Header row ──────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 32

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Wallpaper of the Day")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        // Refresh button
                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: refreshHover.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            eventIcon {
                                id: refreshIcon
                                anchors.centerIn: parent
                                name: "refresh"
                                size: 16
                                color: refreshHover.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RotationAnimation {
                                    target: refreshIcon
                                    property: "rotation"
                                    from: 0; to: 360
                                    duration: 900
                                    running: root.isDownloading
                                    loops: Animation.Infinite
                                    onRunningChanged: { if (!running) refreshIcon.rotation = 0 }
                                }
                            }

                            MouseArea {
                                id: refreshHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.isDownloading
                                onClicked: forceWallpaperCheck()
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: closeHover.containsMouse
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            eventIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 16
                                color: closeHover.containsMouse ? Theme.error : Theme.surfaceVariantText
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: closeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: closePopout()
                            }
                        }
                    }
                }

                // ── Wallpaper image card ─────────────────────────────────────
                StyledRect {
                    id: imageCard
                    width: parent.width
                    height: width * 9 / 16
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                    border.width: 1
                    clip: true

                    CachingImage {
                        id: bingwallImage
                        anchors.fill: parent
                        imagePath: "file://" + root.currentImageSavePath
                        fillMode: Image.PreserveAspectCrop
                        maxCacheSize: 160
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: wallpaperMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }

                    Rectangle {
                        id: wallpaperMask
                        anchors.fill: parent
                        radius: Theme.cornerRadius - 1
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }

                    // Loading shimmer overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.6)
                        visible: root.isDownloading
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        StyledText {
                            anchors.centerIn: parent
                            text: "Downloading…"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                // ── Title + description ──────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        id: bingwallTitle
                        width: parent.width
                        text: root.currentTitle || "—"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: bingwallDescription
                        width: parent.width
                        text: root.currentDescription
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            id: emojiRow
            spacing: Theme.spacingXS

            eventIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "wallpaper"
                size: Theme.iconSize - 7
                color: Theme.surfaceText
            }
        }
    }

    verticalBarPill: Component {
        Column {
            id: emojiColumn
            spacing: Theme.spacingXS

            eventIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wallpaper"
                size: Theme.iconSize - 7
                color: Theme.surfaceText
            }
        }
    }
}
