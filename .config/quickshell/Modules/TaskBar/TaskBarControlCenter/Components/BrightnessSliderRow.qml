import QtQuick
import qs.Services
import qs.Modules.ControlCenter.Widgets as CCWidgets

Item {
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
    height: parent.height || 90

    CCWidgets.BrightnessSliderRow {
        anchors.fill: parent
    }

    EditModeOverlay {
        anchors.fill: parent
        editMode:    widgetRoot.editMode
        widgetData:  widgetRoot.widgetData
        widgetIndex: widgetRoot.widgetIndex
        showSizeControls: true
        isSlider: true
        onRemoveWidget:     function(index)             { widgetRoot.gridRoot.removeWidget(index) }
        onToggleWidgetSize: function(index)             { widgetRoot.gridRoot.toggleWidgetSize(index) }
        onMoveWidget:       function(fromIndex, toIndex) { widgetRoot.gridRoot.moveWidget(fromIndex, toIndex) }
    }
}