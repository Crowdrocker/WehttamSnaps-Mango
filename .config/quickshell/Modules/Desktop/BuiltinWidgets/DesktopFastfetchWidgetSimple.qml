import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

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
    property real defaultWidth: 750
    property real defaultHeight: 550
    property real minWidth: 500
    property real minHeight: 400

    /// When true, height follows fastfetch content (+ padding); use for embedded dash column.
    property bool naturalHeightMode: false
    property bool hideNetwork: false
    property real naturalMinHeight: 100
    /// When true, outer card has no border regardless of fastfetch popup border settings.
    property bool suppressCardBorder: false
    /// Event Horizon dash: multiply card fill alpha (default 1).
    property real chromeBackgroundOpacityScale: 1.0

    property real fontSize: isInstance ? (cfg.fontSize ?? 13) : (SettingsData.desktopWidgetFontSize || 13)
    property real spacing: isInstance ? (cfg.spacing ?? 5) : 5
    property real padding: isInstance ? (cfg.padding ?? 18) : 18
    // Use the global Fastfetch opacity slider (like popups).
    // NOTE: do not read cfg.transparency here; per-instance values would "lock" opacity and make
    // the global slider appear broken.
    property real widgetOpacity: (SettingsData.fastfetchPopupTransparency ?? 0.92)
    property bool useWallpaperColors: isInstance ? (cfg.wallpaperColors ?? false) : (SettingsData.desktopWidgetWallpaperColors ?? false)

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

    readonly property var matugenColorNames: [
        "primary_container",
        "secondary_container",
        "tertiary_container"
    ]
    function getMatugenColor(index) {
        Theme.colorUpdateTrigger
        if (useWallpaperColors && Theme.matugenColors && Theme.matugenColors.colors) {
            const name = matugenColorNames[index % matugenColorNames.length]
            const mode = (typeof SessionData !== "undefined" && SessionData.isLightMode) ? "light" : "dark"
            const v = Theme.matugenColors.colors[name]?.[mode]
            if (v) return v
        }
        return null
    }

    // Package helper (same behavior as old widget)
    property string _pkgCount: "…"
    property string _pkgLabel: ""
    function packageString() {
        if (_pkgLabel !== "") return _pkgCount + " (" + _pkgLabel + ")"
        if (_pkgCount !== "…" && _pkgCount !== "N/A") return _pkgCount
        if (typeof FastfetchService !== "undefined" &&
            FastfetchService.packages &&
            FastfetchService.packages !== "" &&
            FastfetchService.packages !== "0" &&
            FastfetchService.packages !== "Unknown") {
            const mgr = FastfetchService.packageManager ? " (" + FastfetchService.packageManager + ")" : ""
            return FastfetchService.packages + mgr
        }
        return _pkgCount
    }

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
                    root._pkgCount = parts[0] || "?"
                    root._pkgLabel = parts[1] || ""
                } else {
                    root._pkgCount = "N/A"
                    root._pkgLabel = ""
                }
            }
        }
    }

    Component.onCompleted: {
        if (typeof FastfetchService !== "undefined") FastfetchService.refreshAll()
        if (typeof HardwareService !== "undefined") HardwareService.refreshAll()
        if (typeof DgopService !== "undefined") DgopService.addRef(["cpu", "memory", "gpu"])
        pkgProbe.running = true
    }
    Component.onDestruction: {
        if (typeof DgopService !== "undefined") DgopService.removeRef(["cpu", "memory", "gpu"])
    }

    readonly property real naturalContentOuterHeight: Math.ceil(contentCol.implicitHeight + root.padding * 2)

    implicitWidth: widgetWidth
    implicitHeight: naturalHeightMode
        ? Math.max(naturalMinHeight, naturalContentOuterHeight)
        : widgetHeight

    width: widgetWidth
    height: naturalHeightMode ? implicitHeight : widgetHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: {
            const baseAlpha = root.widgetOpacity * root.chromeBackgroundOpacityScale
            const mc = root.getMatugenColor(0)
            if (mc) {
                const c = Qt.color(mc)
                return Qt.rgba(c.r, c.g, c.b, Math.min(1, baseAlpha))
            }
            return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Math.min(1, baseAlpha))
        }
        border.color: {
            const dynamic = SettingsData.fastfetchPopupDynamicBorderColors ?? false
            if (dynamic) return Theme.primary
            const op = SettingsData.fastfetchPopupBorderOpacity ?? 0.30
            return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, op)
        }
        border.width: root.suppressCardBorder
            ? 0
            : (SettingsData.fastfetchPopupBorderEnabled ?? false)
                ? Math.max(1, SettingsData.fastfetchPopupBorderThickness ?? 2)
                : 0
        antialiasing: true
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: root.padding
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                width: parent.width
                spacing: 0

                readonly property int sectionGap: 12

                // Header (simple, readable)
                Row {
                    width: parent.width
                    spacing: root.padding

                    Item {
                        id: logoContainer
                        width: 72
                        height: 72
                        anchors.verticalCenter: parent.verticalCenter

                        SystemLogo {
                            anchors.fill: parent
                            visible: {
                                const useCustom = root.getConfigValue("useCustomLogo", false)
                                const customPath = root.getConfigValue("customLogoPath", "")
                                return !useCustom || customPath === ""
                            }
                            colorOverride: root._logoColor
                            brightnessOverride: 0.55
                        }

                        Image {
                            anchors.fill: parent
                            visible: {
                                const useCustom = root.getConfigValue("useCustomLogo", false)
                                const customPath = root.getConfigValue("customLogoPath", "")
                                return useCustom && customPath !== ""
                            }
                            source: {
                                const p = root.getConfigValue("customLogoPath", "")
                                return p ? "file://" + p : ""
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }
                    }

                    Column {
                        width: parent.width - logoContainer.width - parent.spacing
                        spacing: 3

                        StyledText {
                            text: (typeof UserInfoService !== "undefined" ? (UserInfoService.username || "user") : "user")
                                  + "@" +
                                  (typeof FastfetchService !== "undefined" ? (FastfetchService.hostname || "host") : "host")
                            font.pixelSize: root.fontSize + 8
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        StyledText {
                            visible: root.shouldShow("showUptime")
                            text: (typeof FastfetchService !== "undefined" ? FastfetchService.uptime
                                  : (typeof UserInfoService !== "undefined" ? UserInfoService.shortUptime : "Unknown"))
                            font.pixelSize: root.fontSize + 1
                            font.weight: Font.DemiBold
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.75)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: contentCol.sectionGap
                }

                InfoCard {
                    title: "System"
                    iconChar: "󰻀"
                    InfoRow { visible: root.shouldShow("showOs"); label: "OS"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.osName || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showHost"); label: "Host"; value: typeof HardwareService !== "undefined" ? (HardwareService.hostname || "Unknown") : (typeof FastfetchService !== "undefined" ? (FastfetchService.hostname || "Unknown") : "Unknown") }
                    InfoRow { visible: root.shouldShow("showKernel"); label: "Kernel"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.kernelVersion || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showRes"); label: "Resolution"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.resolution || "Unknown") : "Unknown" }
                }

                Item {
                    width: parent.width
                    height: contentCol.sectionGap
                }

                InfoCard {
                    title: "Hardware"
                    iconChar: "󰍛"
                    InfoRow { visible: root.shouldShow("showCpu"); label: "CPU"; value: (typeof FastfetchService !== "undefined" && FastfetchService.cpu) ? FastfetchService.cpu : (typeof HardwareService !== "undefined" ? (HardwareService.cpuModel || "Unknown") : "Unknown") }
                    InfoRow { visible: root.shouldShow("showGpu"); label: "GPU"; value: typeof HardwareService !== "undefined" ? (HardwareService.gpuModel || "Unknown") : "Unknown" }
                    InfoRow {
                        visible: root.shouldShow("showMemory")
                        label: "Memory"
                        value: {
                            if (typeof DgopService !== "undefined" && DgopService.totalMemoryMB > 0) {
                                const pct = (DgopService.usedMemoryMB / DgopService.totalMemoryMB * 100).toFixed(1)
                                return `${(DgopService.usedMemoryMB / 1024).toFixed(1)} GiB / ${(DgopService.totalMemoryMB / 1024).toFixed(1)} GiB (${pct}%)`
                            }
                            if (typeof HardwareService !== "undefined")
                                return (HardwareService.usedMemory || "Unknown") + " / " + (HardwareService.totalMemory || "Unknown")
                            return "Unknown"
                        }
                    }
                    InfoRow { visible: root.shouldShow("showDisk"); label: "Disk"; value: typeof HardwareService !== "undefined" ? ((HardwareService.diskUsed || "?") + " / " + (HardwareService.diskTotal || "?") + " (" + (HardwareService.diskUsagePercent || "?") + ")") : "Unknown" }
                }

                Item {
                    width: parent.width
                    height: contentCol.sectionGap
                }

                InfoCard {
                    title: "Software"
                    iconChar: "󰏖"
                    InfoRow { visible: root.shouldShow("showPackages"); label: "Packages"; value: root.packageString() }
                    InfoRow {
                        visible: root.shouldShow("showShell")
                        label: "Shell"
                        value: typeof FastfetchService !== "undefined"
                               ? ((FastfetchService.shell || "shell") + (FastfetchService.shellVersion ? (" " + FastfetchService.shellVersion) : ""))
                               : (Quickshell.env("SHELL") ? Quickshell.env("SHELL").split("/").pop() : "Unknown")
                    }
                    InfoRow { visible: root.shouldShow("showDe"); label: "DE"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.desktopEnvironment || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showWm"); label: "WM"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.windowManager || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showTheme"); label: "Theme"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.theme || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showIcons"); label: "Icons"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.icons || "Unknown") : "Unknown" }
                    InfoRow { visible: root.shouldShow("showFonts"); label: "Fonts"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.fonts || "Unknown") : "Unknown" }
                }

                Item {
                    width: parent.width
                    height: contentCol.sectionGap
                    visible: !root.hideNetwork
                }

                InfoCard {
                    visible: !root.hideNetwork
                    title: "Network"
                    iconChar: "󰛳"
                    InfoRow { visible: root.shouldShow("showLocalIp"); label: "Local IP"; value: typeof FastfetchService !== "undefined" ? (FastfetchService.localIp || "Unknown") : "Unknown" }
                }
            }
        }
    }

    component InfoCard: Column {
        property string title: ""
        property string iconChar: ""
        default property alias content: innerCol.data

        width: parent.width
        spacing: 8

        Row {
            width: parent.width
            spacing: 8
            Rectangle {
                width: 3
                height: titleText.implicitHeight
                radius: 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                id: titleText
                text: (iconChar ? (iconChar + "  ") : "") + title
                font.pixelSize: root.fontSize + 2
                font.weight: Font.Bold
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            id: innerCol
            width: parent.width
            spacing: 8
            leftPadding: 6
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        }
    }

    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""

        width: parent.width
        spacing: 0

        Item {
            Layout.alignment: Qt.AlignVCenter
            width: 120
            implicitHeight: labelText.implicitHeight

            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                height: labelText.implicitHeight

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                }

                StyledText {
                    id: labelText
                    Layout.alignment: Qt.AlignVCenter
                    text: label
                    font.pixelSize: root.fontSize + 1
                    font.weight: Font.Medium
                    lineHeight: 1.0
                    lineHeightMode: Text.ProportionalHeight
                    verticalAlignment: Text.AlignVCenter
                    color: Qt.rgba(Theme.surfaceTextMedium.r, Theme.surfaceTextMedium.g, Theme.surfaceTextMedium.b, 0.78)
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "·"
            font.pixelSize: root.fontSize + 1
            font.weight: Font.Medium
            lineHeight: 1.0
            lineHeightMode: Text.ProportionalHeight
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.45)
            leftPadding: 2
            rightPadding: 6
        }

        StyledText {
            id: valueText
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: value || ""
            font.pixelSize: root.fontSize + 1
            font.weight: Font.Medium
            lineHeight: 1.0
            lineHeightMode: Text.ProportionalHeight
            verticalAlignment: Text.AlignVCenter
            color: Theme.surfaceText
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}

