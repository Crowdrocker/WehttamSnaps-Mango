import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: 200
    property real widgetHeight: 120
    property real defaultWidth: 200
    property real defaultHeight: 120
    property real minWidth: 150
    property real minHeight: 100

    property real widgetOpacity: isInstance ? (cfg?.transparency ?? 0.9) : 0.9

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "gpu"]);
    }
    
    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "gpu"]);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, root.widgetOpacity)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.desktopWidgetBorderOpacity)
        border.width: SettingsData.desktopWidgetBorderThickness
        antialiasing: true


        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                EHIcon {
                    name: "memory"
                    size: Theme.iconSize - 6
                    color: {
                        if (DgopService.cpuTemperature > 85) {
                            return Theme.tempDanger;
                        }
                        if (DgopService.cpuTemperature > 69) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: "CPU"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: {
                                if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature < 0) {
                                    return "--°";
                                }
                                return Math.round(DgopService.cpuTemperature) + "°";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: {
                                if (DgopService.cpuTemperature > 85) {
                                    return Theme.tempDanger;
                                }
                                if (DgopService.cpuTemperature > 69) {
                                    return Theme.tempWarning;
                                }
                                return Theme.surfaceText;
                            }

                        }

                        StyledText {
                            text: {
                                if (DgopService.cpuUsage === undefined || DgopService.cpuUsage === null) {
                                    return "--%";
                                }
                                return Math.round(DgopService.cpuUsage) + "%";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: {
                                if (DgopService.cpuUsage > 80) {
                                    return Theme.tempDanger;
                                }
                                if (DgopService.cpuUsage > 60) {
                                    return Theme.tempWarning;
                                }
                                return Theme.surfaceText;
                            }

                        }

                        StyledText {
                            text: {
                                if (DgopService.cpuFrequency > 0) {
                                    return DgopService.cpuFrequency.toFixed(1) + "GHz";
                                }
                                return "--GHz";
                            }
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.weight: Font.Medium
                            color: {
                                try {
                                    if (typeof PerformanceService !== 'undefined') {
                                        switch(PerformanceService.currentMode) {
                                            case "performance": return "#F44336";
                                            case "balanced": return "#FF9800";
                                            case "power-saver": return "#4CAF50";
                                            default: return Theme.surfaceTextMedium;
                                        }
                                    }
                                } catch (e) {
                                }
                                return Theme.surfaceTextMedium;
                            }

                        }
                    }
                }

                StyledText {
                    text: {
                        try {
                            if (typeof PerformanceService !== 'undefined') {
                                return PerformanceService.getCurrentModeInfo().name;
                            }
                        } catch (e) {
                        }
                        return "Unknown";
                    }
                    font.pixelSize: Theme.fontSizeSmall - 3
                    font.weight: Font.Normal
                    color: {
                        try {
                            if (typeof PerformanceService !== 'undefined') {
                                switch(PerformanceService.currentMode) {
                                    case "performance": return "#F44336";
                                    case "balanced": return "#FF9800";
                                    case "power-saver": return "#4CAF50";
                                    default: return Theme.surfaceTextMedium;
                                }
                            }
                        } catch (e) {
                        }
                        return Theme.surfaceTextMedium;
                    }

                }
            }

            Row {
                spacing: Theme.spacingS

                EHIcon {
                    name: "auto_awesome_mosaic"
                    size: Theme.iconSize - 6
                    color: {
                        const gpuTemp = DgopService.availableGpus && DgopService.availableGpus.length > 0 ? 
                                      (DgopService.availableGpus[0].temperature || 0) : 0;
                        if (gpuTemp > 80) {
                            return Theme.tempDanger;
                        }
                        if (gpuTemp > 65) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: "GPU"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: {
                            const gpuTemp = DgopService.availableGpus && DgopService.availableGpus.length > 0 ? 
                                          (DgopService.availableGpus[0].temperature || 0) : 0;
                            if (gpuTemp === undefined || gpuTemp === null || gpuTemp === 0) {
                                return "--°";
                            }
                            return Math.round(gpuTemp) + "°";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: {
                            const gpuTemp = DgopService.availableGpus && DgopService.availableGpus.length > 0 ? 
                                          (DgopService.availableGpus[0].temperature || 0) : 0;
                            if (gpuTemp > 80) {
                                return Theme.tempDanger;
                            }
                            if (gpuTemp > 65) {
                                return Theme.tempWarning;
                            }
                            return Theme.surfaceText;
                        }

                    }
                }
            }

            Row {
                spacing: Theme.spacingS

                EHIcon {
                    name: "developer_board"
                    size: Theme.iconSize - 6
                    color: {
                        if (DgopService.memoryUsage > 90) {
                            return Theme.tempDanger;
                        }
                        if (DgopService.memoryUsage > 75) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: "RAM"
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: {
                            if (DgopService.memoryUsage === undefined || DgopService.memoryUsage === null) {
                                return "--%";
                            }
                            return Math.round(DgopService.memoryUsage) + "%";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: {
                            if (DgopService.memoryUsage > 90) {
                                return Theme.tempDanger;
                            }
                            if (DgopService.memoryUsage > 75) {
                                return Theme.tempWarning;
                            }
                            return Theme.surfaceText;
                        }

                    }
                }
            }
        }
    }
}
