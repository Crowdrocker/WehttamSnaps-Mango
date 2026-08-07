import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: rootItem

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property string _logoColor: {
        if (typeof ColorPaletteService !== "undefined" && ColorPaletteService.extractedColors && ColorPaletteService.extractedColors.length > 0) {
            return ColorPaletteService.extractedColors[0]
        }
        return ""
    }

    property real widgetWidth: defaultWidth
    property real widgetHeight: defaultHeight
    // Stable surface scaling target (like terminal fastfetch "canvas")
    readonly property real designWidth: 750
    readonly property real designHeight: {
        const ch = (typeof contentColumn !== "undefined" && contentColumn) ? contentColumn.implicitHeight : defaultHeight
        return Math.max(defaultHeight, ch + padding * 2)
    }
    readonly property real minScale: 0.78  // keep text readable when resizing

    property real defaultWidth: 750
    property real defaultHeight: 550
    property real minWidth: Math.round(designWidth * minScale)
    property real minHeight: Math.round(designHeight * minScale)
    property real baseFontSize: isInstance ? (cfg.fontSize ?? 12) : (SettingsData.desktopWidgetFontSize || 12)
    property real baseSpacing: isInstance ? (cfg.spacing ?? 4) : 4
    property real basePadding: isInstance ? (cfg.padding ?? 18) : 18

    // When the widget is scaled down, compensate text size more aggressively,
    // but also tighten spacing/padding so the bigger text still fits the fixed surface.
    // IMPORTANT: avoid depending on `contentScale` here, because `contentScale` depends on `designHeight`,
    // and `designHeight` depends on content that depends on font sizes -> binding loop.
    readonly property real widgetScaleForText: Math.max(0.01, Math.min(widgetWidth / designWidth, widgetHeight / defaultHeight))
    readonly property real textScale: Math.min(2.35, Math.max(1.0, 1.0 / widgetScaleForText))
    property real fontSize: Math.round(baseFontSize * textScale)
    property real spacing: Math.max(2, Math.round(baseSpacing / Math.pow(textScale, 0.55)))
    property real padding: Math.max(10, Math.round(basePadding / Math.pow(textScale, 0.45)))
    property real _targetOpacity: isInstance ? (cfg.transparency ?? 0.92) : (SettingsData.desktopWidgetTransparency ?? 0.92)
    property real widgetOpacity: _targetOpacity
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : (SettingsData.desktopWidgetWallpaperColors ?? false)

    onInstanceDataChanged: {
        if (isInstance && instanceData && instanceData.config) {
            _targetOpacity = instanceData.config.transparency ?? 0.92
            widgetOpacity = _targetOpacity
        }
    }

    Component.onCompleted: {
        if (!isInstance) {
            var updateGlobalOpacity = () => {
                _targetOpacity = SettingsData.desktopWidgetTransparency ?? 0.92
                widgetOpacity = _targetOpacity
            }
            if (typeof SettingsData.desktopWidgetTransparency !== "undefined") {
                SettingsData.desktopWidgetTransparencyChanged.connect(updateGlobalOpacity)
            }
        }
        if (typeof FastfetchService !== "undefined") FastfetchService.refreshAll()
        if (typeof HardwareService !== "undefined") HardwareService.refreshAll()
        if (typeof DgopService !== "undefined") DgopService.addRef(["cpu", "memory", "gpu"])
        pkgProbe.running = true
    }

    on_TargetOpacityChanged: {
        animateOpacity.restart()
    }

    NumberAnimation {
        id: animateOpacity
        target: rootItem; property: "widgetOpacity"
        from: widgetOpacity; to: _targetOpacity
        duration: 200; easing.type: Easing.InOutCubic
    }

    readonly property var matugenColorNames: [
        "primary", "secondary", "tertiary", "surface_tint",
        "primary_container", "secondary_container", "tertiary_container",
        "primary_fixed", "secondary_fixed", "tertiary_fixed"
    ]

    function getMatugenColor(index) {
        Theme.colorUpdateTrigger

        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const colorName = matugenColorNames[index % matugenColorNames.length]
            const colorMode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            if (Theme.matugenColors.colors[colorName] && Theme.matugenColors.colors[colorName][colorMode]) {
                return Theme.matugenColors.colors[colorName][colorMode]
            }
        }
        return null
    }

    // ── Package-count helper ─────────────────────────────────────────────────
    // Detects the OS family and runs the right package-manager query when
    // FastfetchService hasn't populated packages / packageManager.
    property string _pkgCount: "…"
    property string _pkgLabel: ""

    function shouldShow(key) {
        if (!isInstance || !cfg) return true
        if (cfg.hasOwnProperty(key)) return cfg[key] !== false
        return true
    }

    function getConfigValue(key, defaultValue) {
        if (!isInstance || !cfg) return defaultValue
        if (cfg.hasOwnProperty(key)) return cfg[key]
        return defaultValue
    }

    // Returns a human-readable packages string, querying the shell on distros
    // that FastfetchService doesn't cover (Fedora/RPM, Arch, Debian/dpkg).
    function packageString() {
        // 1 — Live query from pkgProbe first (most accurate, handles all distros)
        if (_pkgLabel !== "") return _pkgCount + " (" + _pkgLabel + ")"
        if (_pkgCount !== "…" && _pkgCount !== "N/A") return _pkgCount

        // 2 — Fallback to FastfetchService (if it has valid data)
        if (typeof FastfetchService !== "undefined" &&
            FastfetchService.packages &&
            FastfetchService.packages !== "" &&
            FastfetchService.packages !== "0" &&
            FastfetchService.packages !== "Unknown") {
            const mgr = FastfetchService.packageManager ? " (" + FastfetchService.packageManager + ")" : ""
            return FastfetchService.packages + mgr
        }

        return _pkgCount  // still "…" until processes finish
    }

    // Probe package count via shell – runs once on load.
    // Process is from Quickshell.Io; stdout is a StdioCollector child.
    Process {
        id: pkgProbe
        command: [
            "sh", "-c",
            "for mgr in nix-env pacman dnf apt dpkg rpm xbps-query apk emerge; do " +
            "  if command -v $mgr >/dev/null 2>&1; then " +
            "    case $mgr in " +
            "      nix-env) count=$(nix-env -q 2>/dev/null | wc -l) ;; " +
            "      pacman) count=$(pacman -Qq 2>/dev/null | wc -l) ;; " +
            "      dnf) count=$(dnf list installed 2>/dev/null | tail -n +2 | wc -l) ;; " +
            "      apt) count=$(dpkg-query -f '${binary:Package}\\n' -W 2>/dev/null | wc -l) ;; " +
            "      dpkg) count=$(dpkg-query -f '${binary:Package}\\n' -W 2>/dev/null | wc -l) ;; " +
            "      rpm) count=$(rpm -qa 2>/dev/null | wc -l) ;; " +
            "      xbps-query) count=$(xbps-query -l 2>/dev/null | wc -l) ;; " +
            "      apk) count=$(apk list -I 2>/dev/null | wc -l) ;; " +
            "      emerge) count=$(qlist -I 2>/dev/null | wc -l) ;; " +
            "    esac && echo \"$count $mgr\" && exit 0; " +
            "  fi; " +
            "done; echo 'N/A'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (raw !== "" && raw !== "N/A") {
                    const parts = raw.split(" ")
                    rootItem._pkgCount = parts[0] || "?"
                    rootItem._pkgLabel = parts[1] || ""
                } else {
                    rootItem._pkgCount = "N/A"
                    rootItem._pkgLabel = ""
                }
            }
        }
    }

    width: widgetWidth
    height: widgetHeight

    Component.onDestruction: {
        if (typeof DgopService !== "undefined") DgopService.removeRef(["cpu", "memory", "gpu"])
    }

    readonly property real contentScale: Math.max(0.01, Math.min(widgetWidth / designWidth, widgetHeight / designHeight))

    // ── Root card ────────────────────────────────────────────────────────────
    Item {
        id: surface
        width: rootItem.designWidth
        height: rootItem.designHeight
        anchors.centerIn: parent
        scale: rootItem.contentScale
        transformOrigin: Item.Center

        Rectangle {
        id: rootCard
        anchors.fill: parent
        radius: Theme.cornerRadius + 6
        color: {
            const baseAlpha = rootItem.widgetOpacity
            const mc = rootItem.getMatugenColor(4)  // primary_container
            if (mc) {
                const c = Qt.color(mc)
                return Qt.rgba(c.r, c.g, c.b, baseAlpha)
            }
            return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, baseAlpha)
        }
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
        border.width: 1
        antialiasing: true
        clip: true

        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: rootItem.padding
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: rootItem.padding

                // ── Header ───────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    radius: Theme.cornerRadius + 2
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.35)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                    border.width: 1
                    implicitHeight: headerRow.implicitHeight + rootItem.padding

                    RowLayout {
                        id: headerRow
                        anchors.fill: parent
                        anchors.margins: Math.max(10, Math.round(rootItem.padding * 0.8))
                        spacing: Math.max(10, Math.round(rootItem.padding * 0.8))

                        Item {
                            id: logoContainer
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72
                            Layout.alignment: Qt.AlignVCenter

                            SystemLogo {
                                anchors.fill: parent
                                visible: {
                                    const useCustom = rootItem.getConfigValue("useCustomLogo", false)
                                    const customPath = rootItem.getConfigValue("customLogoPath", "")
                                    return !useCustom || customPath === ""
                                }
                                colorOverride: rootItem._logoColor
                                brightnessOverride: 0.55
                            }

                            Image {
                                anchors.fill: parent
                                visible: {
                                    const useCustom = rootItem.getConfigValue("useCustomLogo", false)
                                    const customPath = rootItem.getConfigValue("customLogoPath", "")
                                    return useCustom && customPath !== ""
                                }
                                source: {
                                    const p = rootItem.getConfigValue("customLogoPath", "")
                                    return p ? "file://" + p : ""
                                }
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Row {
                                spacing: 0
                                StyledText {
                                    text: (typeof UserInfoService !== "undefined" ? (UserInfoService.username || "user") : "user")
                                    font.pixelSize: rootItem.fontSize + 7
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                                StyledText {
                                    text: "@"
                                    font.pixelSize: rootItem.fontSize + 7
                                    font.weight: Font.Bold
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                }
                                StyledText {
                                    text: (typeof FastfetchService !== "undefined" ? FastfetchService.hostname
                                           : (typeof HardwareService !== "undefined" ? HardwareService.hostname : "hostname"))
                                    font.pixelSize: rootItem.fontSize + 7
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    visible: rootItem.shouldShow("showUptime")
                                    radius: 999
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                    border.width: 1
                                    implicitHeight: uptimeText.implicitHeight + 8
                                    implicitWidth: uptimeText.implicitWidth + 14

                                    StyledText {
                                        id: uptimeText
                                        anchors.centerIn: parent
                                        text: (typeof FastfetchService !== "undefined" ? FastfetchService.uptime
                                              : (typeof UserInfoService !== "undefined" ? UserInfoService.shortUptime : "Unknown"))
                                        font.pixelSize: rootItem.fontSize
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                StyledText {
                                    text: Qt.formatDateTime(new Date(), "ddd • MMM d")
                                    font.pixelSize: rootItem.fontSize
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                                    visible: true
                                }
                            }
                        }
                    }
                }

                // ── Cards grid ───────────────────────────────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: rootItem.widgetWidth >= 700 ? 2 : 1
                    columnSpacing: rootItem.padding
                    rowSpacing: rootItem.padding

                    InfoCard {
                    title: "System"
                    iconChar: "󰻀"
                    Layout.fillWidth: true

                    Column {
                        width: parent.width
                        spacing: rootItem.spacing

                        InfoRow {
                            visible: rootItem.shouldShow("showOs")
                            label: "OS"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.osName
                                   : (typeof HardwareService !== "undefined" ? HardwareService.osName : "Unknown")
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showHost")
                            label: "Host"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.hostname
                                   : (typeof HardwareService !== "undefined" ? HardwareService.hostname : "Unknown")
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showKernel")
                            label: "Kernel"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.kernelVersion
                                   : (typeof HardwareService !== "undefined" ? HardwareService.kernelVersion : "Unknown")
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showRes")
                            label: "Resolution"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.resolution : "Unknown"
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showUptime")
                            label: "Uptime"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.uptime
                                   : (typeof UserInfoService !== "undefined" ? UserInfoService.shortUptime : "Unknown")
                        }
                    }
                    }

                    InfoCard {
                    title: "Hardware"
                    iconChar: "󰍛"
                    Layout.fillWidth: true

                    Column {
                        width: parent.width
                        spacing: rootItem.spacing

                        InfoRow {
                            visible: rootItem.shouldShow("showCpu")
                            label: "CPU"
                            value: (typeof FastfetchService !== "undefined" && FastfetchService.cpu)
                                   ? FastfetchService.cpu
                                   : (typeof HardwareService !== "undefined" ? HardwareService.cpuModel
                                      : (typeof DgopService !== "undefined" ? DgopService.cpuModel : "Unknown"))
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showGpu")
                            label: "GPU"
                            value: {
                                if (typeof HardwareService !== "undefined" && HardwareService.gpuModel)
                                    return HardwareService.gpuModel
                                if (typeof DgopService !== "undefined" &&
                                    DgopService.availableGpus &&
                                    DgopService.availableGpus.length > 0)
                                    return DgopService.availableGpus[0].name || "Unknown"
                                return "Unknown"
                            }
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showMemory")
                            label: "Memory"
                            value: {
                                if (typeof DgopService !== "undefined" && DgopService.totalMemoryMB > 0) {
                                    const pct = (DgopService.usedMemoryMB / DgopService.totalMemoryMB * 100).toFixed(1)
                                    return `${(DgopService.usedMemoryMB / 1024).toFixed(1)} GiB / ${(DgopService.totalMemoryMB / 1024).toFixed(1)} GiB  (${pct}%)`
                                }
                                if (typeof HardwareService !== "undefined")
                                    return HardwareService.usedMemory + " / " + HardwareService.totalMemory
                                return "Unknown"
                            }
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showDisk")
                            label: "Disk"
                            value: typeof HardwareService !== "undefined"
                                   ? HardwareService.diskUsed + " / " + HardwareService.diskTotal + "  (" + HardwareService.diskUsagePercent + ")"
                                   : "Unknown"
                        }
                    }
                    }

                    InfoCard {
                    title: "Software"
                    iconChar: "󰏖"
                    Layout.fillWidth: true

                    Column {
                        width: parent.width
                        spacing: rootItem.spacing

                        InfoRow {
                            visible: rootItem.shouldShow("showPackages")
                            label: "Packages"
                            // Reference _pkgCount and _pkgLabel directly so QML re-evaluates
                            // this binding whenever the shell probe updates them.
                            value: {
                                rootItem._pkgCount; rootItem._pkgLabel
                                return rootItem.packageString()
                            }
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showShell")
                            label: "Shell"
                            value: typeof FastfetchService !== "undefined"
                                   ? (FastfetchService.shell + (FastfetchService.shellVersion ? "  " + FastfetchService.shellVersion : ""))
                                   : (Quickshell.env("SHELL") ? Quickshell.env("SHELL").split("/").pop() : "Unknown")
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showDe")
                            label: "DE"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.desktopEnvironment : "Unknown"
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showWm")
                            label: "WM"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.windowManager : "Unknown"
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showTheme")
                            label: "Theme"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.theme : "Unknown"
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showIcons")
                            label: "Icons"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.icons : "Unknown"
                        }
                        InfoRow {
                            visible: rootItem.shouldShow("showFonts")
                            label: "Fonts"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.fonts : "Unknown"
                        }
                    }
                    }

                    InfoCard {
                    title: "Network"
                    iconChar: "󰛳"
                    Layout.fillWidth: true

                    Column {
                        width: parent.width
                        spacing: rootItem.spacing

                        InfoRow {
                            visible: rootItem.shouldShow("showLocalIp")
                            label: "Local IP"
                            value: typeof FastfetchService !== "undefined" ? FastfetchService.localIp : "Unknown"
                        }
                    }
                    }
                }

                // Bottom breathing room
                Item { Layout.fillWidth: true; height: rootItem.spacing }
            }
        }
    }
    }

    // ── InfoCard component ───────────────────────────────────────────────────
    component InfoCard: Rectangle {
        property string title: ""
        property string iconChar: ""
        // Allow `InfoCard { ...children... }` to populate the body like before.
        default property alias content: innerColumn.data

        radius: Theme.cornerRadius + 4
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.28)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
        border.width: 1
        antialiasing: true
        clip: true

        implicitHeight: cardCol.implicitHeight + Math.round(rootItem.padding * 0.9) * 2

        Column {
            id: cardCol
            anchors.fill: parent
            anchors.margins: Math.round(rootItem.padding * 0.9)
            spacing: Math.max(8, Math.round(rootItem.padding * 0.7))

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: (parent.parent && parent.parent.parent) ? (parent.parent.parent.iconChar || "") : ""
                        font.pixelSize: rootItem.fontSize + 2
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }

                StyledText {
                    text: parent.parent ? (parent.parent.title || "") : ""
                    font.pixelSize: rootItem.fontSize + 2
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                id: innerColumn
                width: parent.width
                spacing: rootItem.spacing + 1
            }
        }
    }

    // ── InfoRow component ────────────────────────────────────────────────────
    component InfoRow: Row {
        property string label: ""
        property string value: ""

        width: parent.width
        spacing: 0

        // Fixed-width label column
        Item {
            width: 110
            height: labelText.implicitHeight

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 8

                // fastfetch-style dot marker
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: labelText
                    text: parent.parent.parent.label
                    font.pixelSize: rootItem.fontSize
                    color: Qt.rgba(Theme.surfaceTextMedium.r,
                                   Theme.surfaceTextMedium.g,
                                   Theme.surfaceTextMedium.b, 0.72)
                    font.weight: rootItem.textScale > 1.05 ? Font.DemiBold : Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Thin dot separator
        StyledText {
            text: "·"
            font.pixelSize: rootItem.fontSize
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.45)
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2
            rightPadding: 6
        }

        StyledText {
            text: parent.value
            font.pixelSize: rootItem.fontSize
            font.weight: rootItem.textScale > 1.05 ? Font.DemiBold : Font.Normal
            color: Theme.surfaceText
            width: parent.width - 90 - 20
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}
