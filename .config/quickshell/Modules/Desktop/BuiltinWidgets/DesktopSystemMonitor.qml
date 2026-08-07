import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

EHOSD {
    id: root

    property var screen: null
    property real widgetWidth: 200
    property real widgetHeight: 120
    property bool alwaysVisible: true

    osdWidth: widgetWidth
    osdHeight: widgetHeight
    enableMouseInteraction: true
    autoHideInterval: 0

    property var positionAnchors: {
        switch(SettingsData.desktopSystemMonitorPosition) {
            case "top-left": return { horizontal: "left", vertical: "top" }
            case "top-center": return { horizontal: "center", vertical: "top" }
            case "top-right": return { horizontal: "right", vertical: "top" }
            case "middle-left": return { horizontal: "left", vertical: "center" }
            case "middle-center": return { horizontal: "center", vertical: "center" }
            case "middle-right": return { horizontal: "right", vertical: "center" }
            case "bottom-left": return { horizontal: "left", vertical: "bottom" }
            case "bottom-center": return { horizontal: "center", vertical: "bottom" }
            case "bottom-right": return { horizontal: "right", vertical: "bottom" }
            default: return { horizontal: "left", vertical: "top" }
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "gpu"]);
        show();
    }
    
    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "gpu"]);
    }

    content: Rectangle {
        width: widgetWidth
        height: widgetHeight
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, SettingsData.desktopSystemMonitorOpacity ?? 0.9)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.desktopWidgetBorderOpacity)
        border.width: SettingsData.desktopWidgetBorderThickness
        antialiasing: true

        anchors.left: positionAnchors.horizontal === "left" ? parent.left : undefined
        anchors.horizontalCenter: positionAnchors.horizontal === "center" ? parent.horizontalCenter : undefined
        anchors.right: positionAnchors.horizontal === "right" ? parent.right : undefined
        anchors.top: positionAnchors.vertical === "top" ? parent.top : undefined
        anchors.verticalCenter: positionAnchors.vertical === "center" ? parent.verticalCenter : undefined
        anchors.bottom: positionAnchors.vertical === "bottom" ? parent.bottom : undefined


        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

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
                    anchors.horizontalCenter: parent.horizontalCenter

                }
            }

            Row {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

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
                anchors.horizontalCenter: parent.horizontalCenter

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

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            onPressed: {
                if (alwaysVisible) {
                    show();
                }
            }
        }
    }


}
