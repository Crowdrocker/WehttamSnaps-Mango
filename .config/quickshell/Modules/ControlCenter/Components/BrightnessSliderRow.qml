import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

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
    height: parent.height || 56

    readonly property var _devices: (DisplayService.devices || []).filter(d => d && d.name && !d.name.includes("kbd"))
    readonly property var _primary: _devices.length > 0 ? _devices[0] : null
    readonly property string _primaryName: _primary ? (_primary.name || "") : ""
    readonly property int _deviceCount: _devices.length

    function _brightness() {
        return (DisplayService.getDeviceBrightness(_primaryName) ?? 1)
    }

    Rectangle {
        anchors.fill: parent
        radius: widgetRoot.cardRadius
        color: widgetRoot.cardBg
        border.color: widgetRoot.cardBorder
        border.width: 1
        antialiasing: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS + 2
            anchors.rightMargin: Theme.spacingS + 2
            spacing: Theme.spacingS

            EHIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "brightness_medium"
                size: Theme.iconSize
                color: DisplayService.brightnessAvailable ? Theme.primary : Theme.surfaceText
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: _deviceCount > 1 ? ("Display (" + _deviceCount + ")") : "Display"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                EHSlider {
                    id: primarySlider
                    Layout.fillWidth: true
                    height: 14
                    enabled: DisplayService.brightnessAvailable && _primaryName !== ""
                    minimum: 1
                    maximum: 100
                    showValue: false
                    valueOverride: _brightness()
                    thumbOutlineColor: Theme.surfaceContainer
                    trackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
                    onSliderValueChanged: function(newValue) {
                        if (!enabled) return
                        DisplayService.setBrightness(newValue, _primaryName)
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 28
                height: 28
                radius: 8
                color: expandArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                border.color: expandArea.containsMouse ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25) : "transparent"
                border.width: expandArea.containsMouse ? 1 : 0
                antialiasing: true

                EHIcon {
                    anchors.centerIn: parent
                    name: "expand_more"
                    size: 18
                    color: Theme.surfaceText
                }

                MouseArea {
                    id: expandArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widgetRoot.editMode || !widgetRoot.gridRoot) return
                        const gp = widgetRoot.mapToItem(null, 0, 0)
                        widgetRoot.gridRoot.expandClicked(widgetRoot.widgetData, widgetRoot.widgetIndex, gp.x, gp.y, widgetRoot.width, widgetRoot.height)
                    }
                }
            }
        }
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