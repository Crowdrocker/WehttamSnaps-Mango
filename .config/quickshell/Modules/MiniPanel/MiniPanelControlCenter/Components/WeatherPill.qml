import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Details

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

    readonly property bool weatherExpanded: gridRoot
        && gridRoot.expandedSection === "weather"
        && gridRoot.expandedWidgetIndex === widgetIndex

    width:   parent.width
    implicitHeight: weatherColumn.implicitHeight
    height: implicitHeight
    radius: widgetRoot.cardRadius
    color: Qt.rgba(
        Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
        Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity ?? 1.0))
    border.color: widgetRoot.cardBorder
    border.width: 1
    clip: true

    Component.onCompleted:   WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    Column {
        id: weatherColumn
        width: parent.width
        spacing: 0

        // Collapsed summary strip (tap to expand / collapse detail in-place)
        Item {
            width:  parent.width
            height: 64

            Rectangle {
                id: weatherIconTile
                x: Theme.spacingS + 2
                anchors.verticalCenter: parent.verticalCenter
                width:  40
                height: 40
                radius: 12
                color: WeatherService.weather.available
                    ? Theme.primary
                    : Qt.rgba(
                        (Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)).r,
                        (Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)).g,
                        (Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1)).b,
                        Theme.popupTransparency || 0.92)

                EHIcon {
                    anchors.centerIn: parent
                    name: WeatherService.weather.available
                        ? WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                        : "cloud_off"
                    size: Theme.iconSize
                    color: WeatherService.weather.available ? Theme.primaryContainer : Theme.primary
                }
            }

            Column {
                anchors {
                    left:         weatherIconTile.right
                    leftMargin:   Theme.spacingM
                    right:        parent.right
                    rightMargin:  Theme.spacingS + 2
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                StyledText {
                    width: parent.width
                    text: {
                        if (!WeatherService.weather.available) return "Weather"
                        const temp = SettingsData.useFahrenheit
                            ? WeatherService.weather.tempF
                            : WeatherService.weather.temp
                        return (temp ?? "--") + "°" + (SettingsData.useFahrenheit ? "F" : "C")
                    }
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: WeatherService.weather.available
                        ? (WeatherService.weather.city || "Current location")
                        : "No data"
                    color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.7)
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                enabled: !widgetRoot.editMode
                onClicked: {
                    const gp = mapToItem(null, 0, 0)
                    widgetRoot.gridRoot.expandClicked(widgetRoot.widgetData, widgetRoot.widgetIndex, gp.x, gp.y, width, height)
                }
            }
        }

        Loader {
            id: weatherDetailLoader
            width:  parent.width
            active: widgetRoot.weatherExpanded
            visible: active
            height: item ? item.implicitHeight : 0
            sourceComponent: Component {
                WeatherDetail {
                    embeddedInPill: true
                    width: parent.width
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
        isSlider: false
        onRemoveWidget:     function(index)             { widgetRoot.gridRoot.removeWidget(index) }
        onToggleWidgetSize: function(index)             { widgetRoot.gridRoot.toggleWidgetSize(index) }
        onMoveWidget:       function(fromIndex, toIndex) { widgetRoot.gridRoot.moveWidget(fromIndex, toIndex) }
    }
}
