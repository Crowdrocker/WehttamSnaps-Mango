import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules
import qs.Services

LazyLoader {
    active: true

    /**
     * Utility component for creating retry timers with proper cleanup
     * Ensures timers are properly destroyed to prevent resource leaks
     */
    Component {
        id: retryTimerComponent
        Timer {
            property int attempts: 0
            property int maxAttempts: 10
            property var checkCallback: null
            property var successCallback: null
            interval: 500
            repeat: true
            running: true
            onTriggered: {
                attempts++
                if (attempts >= maxAttempts) {
                    stop()
                    destroy()
                    return
                }
                if (checkCallback) {
                    const result = checkCallback(attempts)
                    if (result === true) {
                        if (successCallback) {
                            successCallback()
                        }
                        stop()
                        destroy()
                    }
                }
            }
            Component.onDestruction: {
                if (running) {
                    stop()
                }
            }
        }
    }

    Variants {
        model: SettingsData.getFilteredScreens("wallpaper")

        PanelWindow {
            id: wallpaperWindow

            required property var modelData

            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            color: "transparent"

            Item {
                id: root
                anchors.fill: parent

                readonly property string defaultWallpaperPath: {
                    var shellDir = Paths.strip(Qt.resolvedUrl("../").toString())
                    return shellDir + "/assets/Default-Wallpaper.jpg"
                }

                property string source: {
                    if (SessionData.perMonitorWallpaper) {
                        var monitorWallpaper = SessionData.monitorWallpapers[modelData.name] || SessionData.wallpaperPath || ""
                        return monitorWallpaper || defaultWallpaperPath
                    }
                    var wallpaper = SessionData.wallpaperPath || ""
                    return wallpaper || defaultWallpaperPath
                }
                property bool isColorSource: source.startsWith("#")
                property string transitionType: SessionData.wallpaperTransition || "fade"
                property int transitionDuration: SessionData.wallpaperTransitionDuration || 2000
                property int targetFps: SessionData.wallpaperTransitionFps || 60
                property real wipeDirection: 0.0
                property real wipeSoftness: 0.08
                property real radialCenterX: 0.5
                property real radialCenterY: 0.5
                property real radialSoftness: 0.12
                property real radialDirection: 0.0
                property real transitionProgress: 0
                property real fillMode: {
                    switch (SessionData.wallpaperFillMode) {
                    case "center": return 0.0
                    case "crop": return 1.0
                    case "fit": return 2.0
                    case "stretch": return 3.0
                    case "tile": return 4.0
                    default: return 1.0
                    }
                }
                property int imageFillMode: {
                    switch (SessionData.wallpaperFillMode) {
                    case "center": return Image.Pad
                    case "crop": return Image.PreserveAspectCrop
                    case "fit": return Image.PreserveAspectFit
                    case "stretch": return Image.Stretch
                    case "tile": return Image.Tile
                    default: return Image.PreserveAspectCrop
                    }
                }
                property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)

                readonly property bool transitioning: fadeAnimation.running

                property bool hasCurrent: currentWallpaper.status === Image.Ready && !!currentWallpaper.source
                property bool booting: !hasCurrent && nextWallpaper.status === Image.Ready
                property bool useAwww: SessionData.useAwwwBackend && AwwwService.awwwAvailable

                WallpaperEngineProc {
                    id: weProc
                    monitor: modelData.name
                }

                Connections {
                    target: SessionData
                    function onUseAwwwBackendChanged() {
                        if (SessionData.useAwwwBackend && AwwwService.awwwAvailable) {
                            root.applyWallpaperToAwww()
                        }
                    }
                    function onWallpaperPathChanged() {
                        Qt.callLater(() => {
                            if (root.useAwww && root.source && root.source !== "") {
                                root.applyWallpaperToAwww()
                            } else {
                                root.applyWallpaperOnStartup()
                            }
                        })
                    }
                    function onMonitorWallpapersChanged() {
                        Qt.callLater(() => {
                            if (root.useAwww && root.source && root.source !== "") {
                                root.applyWallpaperToAwww()
                            } else {
                                root.applyWallpaperOnStartup()
                            }
                        })
                    }
                    function onPerMonitorWallpaperChanged() {
                        Qt.callLater(() => {
                            if (root.useAwww && root.source && root.source !== "") {
                                root.applyWallpaperToAwww()
                            } else {
                                root.applyWallpaperOnStartup()
                            }
                        })
                    }
                }

                Connections {
                    target: AwwwService
                    function onDaemonRunningChanged() {
                        if (AwwwService.daemonRunning && root.useAwww && root.source && root.source !== "") {
                            Qt.callLater(() => {
                                root.applyWallpaperToAwww()
                            })
                        }
                    }
                }

                function applyWallpaperOnStartup() {
                    var currentSource = SessionData.getMonitorWallpaper(modelData.name) || ""
                    if (currentSource && currentSource !== "") {
                        if (useAwww) {
                            if (AwwwService.daemonRunning) {
                                applyWallpaperToAwww()
                            } else {
                                AwwwService.startDaemon()
                                const retryTimer = retryTimerComponent.createObject(root, {
                                    maxAttempts: 10,
                                    checkCallback: (attempts) => AwwwService.daemonRunning,
                                    successCallback: () => root.applyWallpaperToAwww()
                                })
                                if (!retryTimer) {
                                    if (typeof LoggingService !== 'undefined') {
                                        LoggingService.error("WallpaperBackground", "Failed to create retry timer", { screen: modelData.name })
                                    }
                                }
                            }
                        } else {
                            const isWE = currentSource.startsWith("we:")
                            const isColor = currentSource.startsWith("#")
                            if (isWE) {
                                setWallpaperImmediate("")
                                weProc.start(currentSource.substring(3))
                            } else if (isColor) {
                                setWallpaperImmediate("")
                            } else {
                                setWallpaperImmediate(currentSource)
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        Qt.callLater(() => {
                            var currentSource = root.source
                            if (currentSource && currentSource !== "") {
                                if (root.useAwww) {
                                    if (AwwwService.daemonRunning) {
                                        root.applyWallpaperToAwww()
                                    } else {
                                        AwwwService.startDaemon()
                                        const applyTimer = retryTimerComponent.createObject(root, {
                                            maxAttempts: 10,
                                            checkCallback: (attempts) => AwwwService.daemonRunning,
                                            successCallback: () => root.applyWallpaperToAwww()
                                        })
                                        if (!applyTimer) {
                                            if (typeof LoggingService !== 'undefined') {
                                                LoggingService.error("WallpaperBackground", "Failed to create apply timer", { screen: modelData.name })
                                            }
                                        }
                                    }
                                } else {
                                    root.applyWallpaperOnStartup()
                                }
                            }
                        })
                    })
                }

                Component.onDestruction: {
                    weProc.stop()
                }

                function applyWallpaperToAwww() {
                    const isWebP = source && source.toLowerCase().endsWith('.webp')
                    const shouldUseAwww = useAwww || (isWebP && AwwwService.awwwAvailable)
                    
                    if (!shouldUseAwww) {
                        return
                    }
                    
                    const screenName = SessionData.perMonitorWallpaper ? modelData.name : ""
                    
                    const isWE = source.startsWith("we:")
                    const isColor = source.startsWith("#")
                    
                    if (isWE) {
                        AwwwService.clearWallpaper(screenName)
                    } else if (isColor) {
                        AwwwService.setWallpaperColor(screenName, source)
                    } else if (source && source !== "") {
                        AwwwService.setWallpaper(screenName, source)
                    } else {
                        AwwwService.clearWallpaper(screenName)
                    }
                }

                onSourceChanged: {
                    const isWE = source.startsWith("we:")
                    const isColor = source.startsWith("#")
                    const isWebP = source.toLowerCase().endsWith('.webp')
                    
                    const shouldUseAwww = useAwww || (isWebP && AwwwService.awwwAvailable)
                    
                    if (shouldUseAwww) {
                        if (AwwwService.daemonRunning) {
                            root.applyWallpaperToAwww()
                        } else {
                            AwwwService.startDaemon()
                            Qt.callLater(() => {
                                const retryTimer = retryTimerComponent.createObject(root, {
                                    maxAttempts: 10,
                                    checkCallback: (attempts) => AwwwService.daemonRunning,
                                    successCallback: () => root.applyWallpaperToAwww()
                                })
                                if (!retryTimer) {
                                    if (typeof LoggingService !== 'undefined') {
                                        LoggingService.error("WallpaperBackground", "Failed to create retry timer in onSourceChanged", { screen: modelData.name })
                                    }
                                }
                            })
                        }
                        return
                    }

                    if (isWE) {
                        setWallpaperImmediate("")
                        weProc.start(source.substring(3))
                    } else {
                        weProc.stop()
                        if (!source) {
                            setWallpaperImmediate("")
                        } else if (isColor) {
                            setWallpaperImmediate("")
                        } else {
                            if (!currentWallpaper.source) {
                                setWallpaperImmediate(source)
                            } else {
                                changeWallpaper(source)
                            }
                        }
                    }
                }

                function setWallpaperImmediate(newSource) {
                    fadeAnimation.stop()
                    root.transitionProgress = 0.0
                    currentWallpaper.source = newSource
                    nextWallpaper.source = ""
                }

                function triggerWallpaperTransition(newPath) {
                    if (root.isColorSource) {
                        root.source = newPath
                    } else {
                        nextWallpaper.source = newPath
                    }
                }

                function changeWallpaper(newPath, force) {
                    if (!force && newPath === currentWallpaper.source) return
                    if (!newPath || newPath.startsWith("#")) return

                    if (root.transitioning) {
                        fadeAnimation.stop()
                        root.transitionProgress = 0.0
                        currentWallpaper.source = nextWallpaper.source
                        nextWallpaper.source = ""
                    }

                    if (!currentWallpaper.source || (root.transitionType !== "fade" && root.transitionType !== "crossfade" && root.transitionType !== "wipe" && root.transitionType !== "radial")) {
                        setWallpaperImmediate(newPath)
                        return
                    }

                    nextWallpaper.source = newPath
                    if (nextWallpaper.status === Image.Ready) {
                        root.transitionProgress = 0.0
                        fadeAnimation.start()
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: root.isColorSource && !root.useAwww
                    asynchronous: true

                    sourceComponent: EHBackdrop {
                        screenName: modelData.name
                    }
                }

                // Both images are always hidden — the ShaderEffect samples them
                // directly as variant properties (Qt creates implicit GPU textures).
                // This is the correct pattern: no ShaderEffectSource needed.
                Image {
                    id: currentWallpaper
                    anchors.fill: parent
                    fillMode: root.imageFillMode
                    visible: false
                    layer.enabled: true
                    asynchronous: true
                    smooth: true
                    cache: true
                }

                Image {
                    id: nextWallpaper
                    anchors.fill: parent
                    fillMode: root.imageFillMode
                    visible: false
                    layer.enabled: true
                    asynchronous: false  // synchronous so first frame is ready immediately
                    smooth: true
                    cache: true

                    onStatusChanged: {
                        if (status !== Image.Ready) return
                        if ((root.transitionType === "fade" || root.transitionType === "crossfade" || root.transitionType === "wipe" || root.transitionType === "radial") && root.hasCurrent) {
                            if (!root.transitioning) {
                                root.transitionProgress = 0.0
                                fadeAnimation.start()
                            }
                        } else {
                            currentWallpaper.source = source
                            nextWallpaper.source = ""
                        }
                    }
                }

                // The ShaderEffect renders both wallpapers and blends between them.
                // Passing Image items directly as variant properties is how Qt exposes
                // them as sampler2D uniforms — no ShaderEffectSource wrapper needed.
                ShaderEffect {
                    id: wallpaperShader
                    anchors.fill: parent
                    visible: root.transitioning

                    property variant currentTex: currentWallpaper
                    property variant nextTex: nextWallpaper
                    property real progress: root.transitionProgress
                    property real direction: root.wipeDirection
                    property real softness: root.wipeSoftness
                    property real centerX: root.radialCenterX
                    property real centerY: root.radialCenterY

                    fragmentShader: {
                        switch (root.transitionType) {
                        case "fade":       return Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb")
                        case "crossfade":  return Qt.resolvedUrl("../Shaders/qsb/wp_crossfade.frag.qsb")
                        case "wipe":       return Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb")
                        case "radial":     return Qt.resolvedUrl("../Shaders/qsb/wp_radial.frag.qsb")
                        default:           return Qt.resolvedUrl("../Shaders/qsb/wp_crossfade.frag.qsb")
                        }
                    }
                }

                // When not transitioning, render the current wallpaper directly.
                // Using a plain Image here is correct — the shader takes over during transitions.
                Image {
                    id: displayWallpaper
                    anchors.fill: parent
                    fillMode: root.imageFillMode
                    source: currentWallpaper.source
                    visible: !root.transitioning
                    asynchronous: true
                    smooth: true
                    cache: true
                }

                NumberAnimation {
                    id: fadeAnimation
                    target: root
                    property: "transitionProgress"
                    from: 0.0
                    to: 1.0
                    duration: root.transitionDuration
                    easing.type: Easing.InOutCubic
                    onFinished: {
                        currentWallpaper.source = nextWallpaper.source
                        nextWallpaper.source = ""
                        nextWallpaper.asynchronous = false
                        root.transitionProgress = 0.0
                    }
                }

                // X button overlay to clear wallpaper
                MouseArea {
                    id: wallpaperHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Rectangle {
                    id: clearWallpaperButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingM
                    width: 48
                    height: 48
                    radius: Theme.cornerRadius
                    color: Qt.rgba(0, 0, 0, wallpaperHoverArea.containsMouse ? 0.8 : 0.5)
                    border.color: Qt.rgba(255, 255, 255, 0.3)
                    border.width: 1
                    visible: false // Disabled to prevent X from appearing on desktop
                    opacity: wallpaperHoverArea.containsMouse ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 2
                        rotation: 45
                        color: "white"
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 2
                        rotation: -45
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (SessionData.perMonitorWallpaper) {
                                SessionData.setMonitorWallpaper(modelData.name, root.defaultWallpaperPath)
                            } else {
                                if (typeof Theme !== "undefined" && Theme.currentTheme === Theme.dynamic) {
                                    Theme.switchTheme("blue")
                                }
                                SessionData.setWallpaper(root.defaultWallpaperPath)
                            }
                        }
                    }
                }

                // Event Horizon logo overlay - shown on default wallpaper
                Item {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spacingXL * 2
                    anchors.bottomMargin: Theme.spacingXL * 2
                    opacity: 0.65
                    visible: root.source === root.defaultWallpaperPath && !root.useAwww

                    readonly property string logoPath: {
                        var shellDir = Paths.strip(Qt.resolvedUrl("../").toString())
                        return shellDir + "/assets/Event-Horizon-logo.png"
                    }

                    Image {
                        id: eventHorizonLogo
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        source: parent.logoPath
                        fillMode: Image.PreserveAspectFit
                        width: 800
                        height: implicitHeight * (800 / implicitWidth)
                        asynchronous: true
                        smooth: true
                    }
                }
            }
        }
    }
}
