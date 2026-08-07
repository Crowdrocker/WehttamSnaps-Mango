import QtQuick
import QtQuick.Layouts
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
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    width:  parent.width
    height: widgetRoot.spx(56)
    radius: widgetRoot.cardRadius
    color:  widgetRoot.cardBg
    border.color: widgetRoot.cardBorder
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: widgetRoot.spx(10)

        EHIcon {
            Layout.alignment: Qt.AlignVCenter
            name: PerformanceService.getCurrentModeInfo().icon
            size: Theme.iconSize
            color: PerformanceService.getCurrentModeInfo().color
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: PerformanceService.isChanging
                ? "Changing..."
                : PerformanceService.getCurrentModeInfo().name
            font.pixelSize: Math.max(12, widgetRoot.spx(14))
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        enabled: !widgetRoot.editMode && !PerformanceService.isChanging
        onClicked: {
            if (widgetRoot.editMode || PerformanceService.isChanging) return
            const modes = ["power-saver", "balanced", "performance"]
            const cur   = modes.indexOf(PerformanceService.currentMode)
            PerformanceService.setMode(modes[(cur + 1) % modes.length])
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