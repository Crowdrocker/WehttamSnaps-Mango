import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property var screen: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth:   200
    property real widgetHeight:  200
    property real defaultWidth:  500
    property real defaultHeight: 200
    property real minWidth:  400
    property real minHeight: 150

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight

    readonly property real baseWidth:  500
    readonly property real baseHeight: 200
    readonly property real sf: Math.min(widgetWidth / baseWidth, widgetHeight / baseHeight)

    readonly property real gpuTemperature:   (DgopService.availableGpus?.length > 0) ? (DgopService.availableGpus[0].temperature  || -1) : -1
    readonly property real gpuMemoryUsedMB:  (DgopService.availableGpus?.length > 0) ? (DgopService.availableGpus[0].memoryUsedMB  || 0)  : 0
    readonly property real gpuMemoryTotalMB: (DgopService.availableGpus?.length > 0) ? (DgopService.availableGpus[0].memoryTotalMB || 0)  : 0
    readonly property real gpuMemoryUsage:   gpuMemoryTotalMB > 0 ? (gpuMemoryUsedMB / gpuMemoryTotalMB) * 100 : 0

    function fmtNet(bps) {
        if (!bps || bps < 0) return "0 B"
        if (bps < 1024) return Math.round(bps) + " B"
        if (bps < 1048576) return (bps / 1024).toFixed(1) + " KB"
        return (bps / 1048576).toFixed(1) + " MB"
    }
    function fmtVRAM() {
        if (gpuMemoryTotalMB <= 0) return "--"
        return (gpuMemoryUsedMB / 1024).toFixed(1) + "/" + (gpuMemoryTotalMB / 1024).toFixed(1) + " GB"
    }
    function getShortCpuName() {
        const f = DgopService.cpuModel || "CPU"
        return f.replace(/^(AMD|Intel\s*\(R\)?)\s*/i, "")
                .replace(/\s*\([RT]M\)/g, "")
                .replace(/\s+Processor$/i, "")
                .replace(/\s+CPU$/i, "")
                .replace(/\s+@\s+[\d.]+GHz.*$/i, "")
                .replace(/\s+\d+\s*-?\s*Core.*/i, "")
                .replace(/\s+Radeon\s+Graphics.*/i, "")
                .replace(/\s+with.*/i, "")
                .trim() || f
    }
    function getShortGpuName() {
        if (!DgopService.availableGpus?.length) return "GPU"
        const f = DgopService.availableGpus[0].displayName || "GPU"
        return f.replace(/^(AMD\s+Radeon|Radeon|NVIDIA\s+GeForce|GeForce|Intel\s+Arc|Intel\s+UHD|Intel\s+HD|NVIDIA|Intel|AMD)\s*/i, "")
                .replace(/\s*\/\s*Max-Q.*/i, "")
                .replace(/\s*\/\s*.*/i, "")
                .replace(/\s*\([^)]*\)/g, "")
                .trim() || f
    }

    Component.onCompleted:  DgopService.addRef(["cpu","memory","gpu","network","system"])
    Component.onDestruction:DgopService.removeRef(["cpu","memory","gpu","network","system"])

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                       isInstance ? (cfg?.transparency ?? 0.9) : 0.9)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        border.width: 1

        // ── Reusable circle dial ──────────────────────────────────────────────
        component CircleDial: Item {
            property real  value:      0.0
            property color ringColor:  Theme.primary
            property string centerIcon: ""
            property string centerText: ""
            property string subText:   ""

            readonly property real sw: 7 * root.sf

            width:  (parent.width - 6 * Theme.spacingXS * root.sf) / 7
            height: parent.height

            // Canvas ring
            Canvas {
                id: dialCanvas
                anchors.centerIn: parent
                width:  Math.min(parent.width, parent.height) * 0.92
                height: width

                property real val: parent.value
                property color col: parent.ringColor
                onValChanged: requestPaint()
                onColChanged: requestPaint()

                Behavior on val {
                    NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2, cy = height / 2
                    var r = Math.min(width, height) / 2 - parent.sw / 2
                    // track
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    ctx.lineWidth = parent.sw; ctx.lineCap = "round"; ctx.stroke()
                    // fill
                    if (val > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + val * 2 * Math.PI)
                        ctx.strokeStyle = col
                        ctx.lineWidth = parent.sw; ctx.lineCap = "round"; ctx.stroke()
                    }
                }
            }

            // Center content
            Column {
                anchors.centerIn: dialCanvas
                spacing: 1
                width: dialCanvas.width - sw * 2 - 6

                EHIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: centerIcon
                    size: (Theme.iconSizeSmall - 3) * root.sf
                    color: ringColor
                    visible: centerIcon !== ""
                }
                StyledText {
                    width: parent.width
                    text: centerText
                    font.pixelSize: (Theme.fontSizeSmall - 2) * root.sf
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    color: ringColor
                    visible: centerText !== ""
                }
                StyledText {
                    width: parent.width
                    text: subText
                    font.pixelSize: (Theme.fontSizeSmall - 4) * root.sf
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    color: Theme.surfaceTextMedium
                    visible: subText !== ""
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spacingS * root.sf
            spacing: Theme.spacingXS * root.sf

            CircleDial {
                value: (DgopService.cpuUsage || 0) / 100
                ringColor: {
                    if (DgopService.cpuUsage > 80) return Theme.error
                    if (DgopService.cpuUsage > 60) return Theme.warning
                    return Theme.primary
                }
                centerIcon: "memory"
                centerText: Math.round(DgopService.cpuUsage || 0) + "%"
                subText: getShortCpuName()
            }

            CircleDial {
                value: Math.min(Math.max((DgopService.cpuTemperature || 40) / 100, 0), 1)
                ringColor: {
                    if (DgopService.cpuTemperature > 85) return Theme.error
                    if (DgopService.cpuTemperature > 69) return Theme.warning
                    return Theme.primary
                }
                centerIcon: "device_thermostat"
                centerText: {
                    const t = DgopService.cpuTemperature || 0
                    return (t < 0) ? "--°" : Math.round(t) + "°"
                }
                subText: "CPU Temp"
            }

            CircleDial {
                value: (DgopService.memoryUsage || 0) / 100
                ringColor: {
                    if (DgopService.memoryUsage > 90) return Theme.error
                    if (DgopService.memoryUsage > 75) return Theme.warning
                    return Theme.primary
                }
                centerIcon: "developer_board"
                centerText: Math.round(DgopService.memoryUsage || 0) + "%"
                subText: "RAM"
            }

            CircleDial {
                value: Math.min(Math.max(root.gpuTemperature <= 0 ? 0 : root.gpuTemperature / 100, 0), 1)
                ringColor: {
                    if (root.gpuTemperature > 85) return Theme.error
                    if (root.gpuTemperature > 69) return Theme.warning
                    return Theme.primary
                }
                centerIcon: "auto_awesome_mosaic"
                centerText: root.gpuTemperature <= 0 ? "--°" : Math.round(root.gpuTemperature) + "°"
                subText: getShortGpuName()
            }

            CircleDial {
                value: root.gpuMemoryUsage / 100
                ringColor: {
                    if (root.gpuMemoryUsage > 90) return Theme.error
                    if (root.gpuMemoryUsage > 75) return Theme.warning
                    return Theme.primary
                }
                centerIcon: "memory"
                centerText: Math.round(root.gpuMemoryUsage || 0) + "%"
                subText: fmtVRAM()
            }

            CircleDial {
                value: Math.min(Math.max((DgopService.networkRxRate || 0) / (10 * 1024 * 1024), 0), 1)
                ringColor: Theme.primary
                centerIcon: "download"
                centerText: ""
                subText: fmtNet(DgopService.networkRxRate || 0)
            }

            CircleDial {
                value: Math.min(Math.max((DgopService.networkTxRate || 0) / (10 * 1024 * 1024), 0), 1)
                ringColor: Theme.primary
                centerIcon: "upload"
                centerText: ""
                subText: fmtNet(DgopService.networkTxRate || 0)
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
        }
    }
}
