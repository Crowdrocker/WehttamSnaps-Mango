import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: widgetRoot
    property var widgetData:  ({})
    property int widgetIndex: 0
    property int cardRadius: 16
    property real cardBorderAlpha: 0.08
    property real cardBgAlpha: 0.28
    property bool editMode: false
    property var cardBg: "transparent"
    property var cardBorder: "transparent"
    property var model: null
    property var gridRoot: null
    width:  parent.width
    height: 56
    radius: widgetRoot.cardRadius
    color:  widgetRoot.cardBg
    border.color: widgetRoot.cardBorder
    border.width: 1

    Row {
        anchors.left:          parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:    Theme.spacingS + 4
        spacing: 10

        EHIcon {
            name: BatteryService.charging
                ? "battery_charging_full"
                : (BatteryService.chargePercent < 20 ? "battery_alert" : "battery_full")
            size: Theme.iconSize
            color: BatteryService.charging
                ? Theme.primary
                : (BatteryService.chargePercent < 20 ? Theme.error : Theme.surfaceText)
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: BatteryService.chargePercent
                ? Math.round(BatteryService.chargePercent) + "%"
                : "--%"
            font.pixelSize: 14
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            if (!widgetRoot.editMode) {
                const gp = mapToItem(null, 0, 0)
                widgetRoot.gridRoot.expandClicked(widgetRoot.widgetData, widgetRoot.widgetIndex, gp.x, gp.y, width, height)
            }
        }
    }

    EditModeOverlay {
        anchors.fill: parent
        editMode:    widgetRoot.editMode
        widgetData:  widgetRoot.widgetData
        widgetIndex: widgetRoot.widgetIndex
        showSizeControls: true
        isSlider: false
        onRemoveWidget:     function(index)             { widgetRoot.gridRoot.removeWidget(index) }
        onToggleWidgetSize: function(index)             { widgetRoot.gridRoot.toggleWidgetSize(index) }
        onMoveWidget:       function(fromIndex, toIndex) { widgetRoot.gridRoot.moveWidget(fromIndex, toIndex) }
    }
}