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

    Component.onCompleted:  DgopService.addRef(["cpu","memory","gpu","network","system"])
    Component.onDestruction:DgopService.removeRef(["cpu","memory","gpu","network","system"])

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                       isInstance ? (cfg?.transparency ?? 0.9) : 0.9)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        border.width: 1

        // Reusable bar column component
        component BarCol: Column {
            property real  fillRatio: 0.0
            property color barColor: Theme.primary
            property string topLabel: "--"
            property string iconName: ""

            width:   (parent.width - 6 * Theme.spacingXS) / 7
            height:  parent.height
            spacing: Theme.spacingXS

            // Value label
            StyledText {
                width: parent.width
                text: topLabel
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                color: barColor
            }

            // Bar track
            Rectangle {
                width: 8
                height: parent.height - Theme.iconSizeSmall - Theme.spacingXS * 2 - 20
                radius: 4
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)

                Rectangle {
                    width: parent.width
                    height: parent.height * Math.min(Math.max(fillRatio, 0), 1)
                    radius: parent.radius
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    color: barColor

                    Behavior on height {
                        NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                    }
                }
            }

            // Icon
            Item {
                width: parent.width
                height: Theme.iconSizeSmall
                EHIcon {
                    name: iconName
                    size: Theme.iconSizeSmall
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    color: barColor
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingXS

            // CPU %
            BarCol {
                fillRatio: (DgopService.cpuUsage || 0) / 100
                topLabel:  Math.round(DgopService.cpuUsage || 0) + "%"
                iconName:  "memory"
                barColor: {
                    if (DgopService.cpuUsage > 80) return Theme.error
                    if (DgopService.cpuUsage > 60) return Theme.warning
                    return Theme.primary
                }
            }

            // CPU °C
            BarCol {
                fillRatio: Math.min(Math.max((DgopService.cpuTemperature || 40) / 100, 0), 1)
                topLabel: {
                    const t = DgopService.cpuTemperature || 0
                    return (t < 0 || t === undefined) ? "--°" : Math.round(t) + "°"
                }
                iconName: "device_thermostat"
                barColor: {
                    if (DgopService.cpuTemperature > 85) return Theme.error
                    if (DgopService.cpuTemperature > 69) return Theme.warning
                    return Theme.primary
                }
            }

            // RAM %
            BarCol {
                fillRatio: (DgopService.memoryUsage || 0) / 100
                topLabel:  Math.round(DgopService.memoryUsage || 0) + "%"
                iconName:  "developer_board"
                barColor: {
                    if (DgopService.memoryUsage > 90) return Theme.error
                    if (DgopService.memoryUsage > 75) return Theme.warning
                    return Theme.primary
                }
            }

            // GPU °C
            BarCol {
                fillRatio: Math.min(Math.max((root.gpuTemperature <= 0 ? 0 : root.gpuTemperature) / 100, 0), 1)
                topLabel: root.gpuTemperature <= 0 ? "--°" : Math.round(root.gpuTemperature) + "°"
                iconName: "auto_awesome_mosaic"
                barColor: {
                    if (root.gpuTemperature > 85) return Theme.error
                    if (root.gpuTemperature > 69) return Theme.warning
                    return Theme.primary
                }
            }

            // VRAM %
            BarCol {
                fillRatio: root.gpuMemoryUsage / 100
                topLabel:  Math.round(root.gpuMemoryUsage || 0) + "%"
                iconName:  "memory"
                barColor: {
                    if (root.gpuMemoryUsage > 90) return Theme.error
                    if (root.gpuMemoryUsage > 75) return Theme.warning
                    return Theme.primary
                }
            }

            // Network ↓
            BarCol {
                fillRatio: Math.min(Math.max((DgopService.networkRxRate || 0) / (10 * 1024 * 1024), 0), 1)
                topLabel: root.fmtNet(DgopService.networkRxRate || 0)
                iconName: "download"
                barColor: Theme.primary
            }

            // Network ↑
            BarCol {
                fillRatio: Math.min(Math.max((DgopService.networkTxRate || 0) / (10 * 1024 * 1024), 0), 1)
                topLabel: root.fmtNet(DgopService.networkTxRate || 0)
                iconName: "upload"
                barColor: Theme.primary
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
        }
    }
}
