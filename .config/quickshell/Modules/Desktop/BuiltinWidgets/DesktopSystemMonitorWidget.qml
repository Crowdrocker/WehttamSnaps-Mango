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
        switch (SettingsData.desktopSystemMonitorPosition) {
            case "top-left":      return { h: "left",   v: "top"    }
            case "top-center":    return { h: "center", v: "top"    }
            case "top-right":     return { h: "right",  v: "top"    }
            case "middle-left":   return { h: "left",   v: "center" }
            case "middle-center": return { h: "center", v: "center" }
            case "middle-right":  return { h: "right",  v: "center" }
            case "bottom-left":   return { h: "left",   v: "bottom" }
            case "bottom-center": return { h: "center", v: "bottom" }
            case "bottom-right":  return { h: "right",  v: "bottom" }
            default:              return { h: "left",   v: "top"    }
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "gpu"])
        show()
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "gpu"])
    }

    content: Rectangle {
        width: widgetWidth
        height: widgetHeight
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                       SettingsData.desktopSystemMonitorOpacity ?? 0.9)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                               SettingsData.desktopWidgetBorderOpacity)
        border.width: SettingsData.desktopWidgetBorderThickness

        anchors.left:            positionAnchors.h === "left"   ? parent.left            : undefined
        anchors.horizontalCenter:positionAnchors.h === "center" ? parent.horizontalCenter: undefined
        anchors.right:           positionAnchors.h === "right"  ? parent.right           : undefined
        anchors.top:             positionAnchors.v === "top"    ? parent.top             : undefined
        anchors.verticalCenter:  positionAnchors.v === "center" ? parent.verticalCenter  : undefined
        anchors.bottom:          positionAnchors.v === "bottom" ? parent.bottom          : undefined

        Column {
            anchors.centerIn: parent
            spacing: 6

            // Helper component: one stat row
            component StatRow: Row {
                property string iconName: ""
                property string label: ""
                property string valueText: "--"
                property color  valueColor: Theme.surfaceText
                property color  iconColor:  Theme.surfaceText

                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter

                EHIcon {
                    name: iconName
                    size: Theme.iconSize - 8
                    color: iconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    StyledText {
                        text: label
                        font.pixelSize: Theme.fontSizeSmall - 3
                        color: Theme.surfaceTextMedium
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: valueText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: valueColor
                    }
                }
            }

            // CPU
            StatRow {
                iconName: "memory"
                label: "CPU"
                valueText: {
                    const t = DgopService.cpuTemperature
                    const u = DgopService.cpuUsage
                    const tStr = (t !== undefined && t !== null && t >= 0) ? Math.round(t) + "°  " : "--°  "
                    const uStr = (u !== undefined && u !== null) ? Math.round(u) + "%" : "--%"
                    return tStr + uStr
                }
                valueColor: {
                    if (DgopService.cpuTemperature > 85 || DgopService.cpuUsage > 80) return Theme.tempDanger
                    if (DgopService.cpuTemperature > 69 || DgopService.cpuUsage > 60) return Theme.tempWarning
                    return Theme.surfaceText
                }
                iconColor: valueColor
            }

            // GPU
            StatRow {
                iconName: "auto_awesome_mosaic"
                label: "GPU"
                valueText: {
                    const t = DgopService.availableGpus?.length > 0
                              ? (DgopService.availableGpus[0].temperature || 0) : 0
                    return (t > 0) ? Math.round(t) + "°" : "--°"
                }
                valueColor: {
                    const t = DgopService.availableGpus?.length > 0
                              ? (DgopService.availableGpus[0].temperature || 0) : 0
                    if (t > 80) return Theme.tempDanger
                    if (t > 65) return Theme.tempWarning
                    return Theme.surfaceText
                }
                iconColor: valueColor
            }

            // RAM
            StatRow {
                iconName: "developer_board"
                label: "RAM"
                valueText: (DgopService.memoryUsage !== undefined && DgopService.memoryUsage !== null)
                           ? Math.round(DgopService.memoryUsage) + "%" : "--%"
                valueColor: {
                    if (DgopService.memoryUsage > 90) return Theme.tempDanger
                    if (DgopService.memoryUsage > 75) return Theme.tempWarning
                    return Theme.surfaceText
                }
                iconColor: valueColor
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            onPressed: { if (alwaysVisible) show() }
        }
    }
}
