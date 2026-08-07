import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section:     "center"
    property var popupTarget:    null
    property var parentScreen:   null
    property real barHeight:     48
    property real widgetHeight:  30
    property real padding:       1
    property real iconSize:      64
    property real iconSpacing:   4
    property real scaleFactor:   1
    property bool isBarVertical: false

    signal clicked()

    // ── Scale ─────────────────────────────────────────────────────────────────
    readonly property real s:    widgetHeight / 30
    readonly property real hPad: SettingsData.topBarNoBackground ? 2 : Theme.spacingM * s

    // ── Weather data ──────────────────────────────────────────────────────────
    readonly property bool dataAvailable: WeatherService.weather.available
    readonly property string tempText: {
        const temp = SettingsData.useFahrenheit
            ? WeatherService.weather.tempF
            : WeatherService.weather.temp
        if (temp === undefined || temp === null) return "--°"
        return temp + "°"
    }
    readonly property string unitText: SettingsData.useFahrenheit ? "F" : "C"

    // ── Geometry ──────────────────────────────────────────────────────────────
    visible: SettingsData.weatherEnabled
    width:  visible ? weatherRow.implicitWidth + hPad * 2 : 0
    height: visible ? widgetHeight : 0
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius * s
    color: {
        if (SettingsData.topBarNoBackground) return "transparent"
        const base = weatherArea.containsMouse
            ? Theme.widgetBaseHoverColor
            : Theme.widgetBaseBackgroundColor
        return Qt.rgba(base.r, base.g, base.b, base.a * Theme.widgetTransparency)
    }

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on width {
        NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
    }

    Component.onCompleted:  WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    // ── Content ───────────────────────────────────────────────────────────────
    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS * s

        // Weather icon
        EHIcon {
            anchors.verticalCenter: parent.verticalCenter
            name:  WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size:  Math.round((Theme.fontSizeMedium + 2) * s)
            color: root.dataAvailable ? Theme.primary : Theme.surfaceTextMedium
            opacity: root.dataAvailable ? 1.0 : 0.5
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // Temperature
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.tempText
            font.pixelSize: Math.round((Theme.fontSizeMedium - 1) * s)
            font.weight:    Font.Medium
            color:          root.dataAvailable ? Theme.surfaceText : Theme.surfaceTextMedium
        }

        // Unit badge — small pill matching AM/PM badge in DockClock
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width:  unitLabel.implicitWidth + Math.round(Theme.spacingXS * s * 2)
            height: unitLabel.implicitHeight + Math.round(2 * s)
            radius: height / 2
            color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

            StyledText {
                id: unitLabel
                anchors.centerIn: parent
                text:           root.unitText
                font.pixelSize: Math.round(Theme.fontSizeSmall * 0.75 * s)
                font.weight:    Font.Medium
                color:          Theme.primary
            }
        }
    }

    // Signal to open weather popup
    signal openWeatherPopup()

    // ── Interaction ───────────────────────────────────────────────────────────
    MouseArea {
        id: weatherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            root.clicked()
            root.openWeatherPopup()
        }
    }
}
