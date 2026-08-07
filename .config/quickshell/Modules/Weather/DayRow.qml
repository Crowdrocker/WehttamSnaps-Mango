import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// width and height are set by the parent Row — this card never sets its own.
// All internal sizes are driven purely by s (scale factor) with fixed pixel
// values — NOT height fractions — so content never grows beyond card bounds.
Rectangle {
    id: root

    property int  dayIndex: 0
    property bool isToday:  dayIndex === 0
    property var  forecast: WeatherService.weather.forecast[dayIndex] || null
    property real s:        1.0

    // Fixed content metrics scaled by s
    readonly property real _fs_day:   Math.round(13 * s)
    readonly property real _fs_hi:    Math.round(15 * s)
    readonly property real _fs_lo:    Math.round(11 * s)
    readonly property real _fs_sm:    Math.round(10 * s)
    readonly property real _icon:     Math.round(32 * s)
    readonly property real _icoSm:    Math.round(10 * s)
    readonly property real _gap:      Math.round(5  * s)
    readonly property real _gapTiny:  Math.round(3  * s)

    radius: Math.round(Theme.cornerRadius * 1.1)
    color: isToday
        ? Qt.rgba(Theme.primary.r,       Theme.primary.g,       Theme.primary.b,       0.15)
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.22)
    border.color: isToday
        ? Theme.primary
        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
    border.width: 2

    Column {
        anchors.centerIn: parent
        width:   parent.width - Math.round(4 * s)
        spacing: root._gap

        // Day name
        StyledText {
            text: isToday ? "Today" : (forecast ? forecast.day : "--")
            font.pixelSize: root._fs_day
            font.weight: isToday ? Font.SemiBold : Font.Medium
            color: isToday ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            elide: Text.ElideRight
        }

        // Divider
        Rectangle {
            width: parent.width * 0.6
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: isToday
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)
        }

        // Weather icon
        EHIcon {
            name: forecast ? WeatherService.getWeatherIcon(forecast.wCode) : "cloud"
            size: root._icon
            color: isToday ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // High temp
        StyledText {
            text: forecast ? (SettingsData.useFahrenheit ? forecast.tempMaxF : forecast.tempMax) + "°" : "--"
            font.pixelSize: root._fs_hi
            font.weight: Font.SemiBold
            color: isToday ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Low temp
        StyledText {
            text: forecast ? (SettingsData.useFahrenheit ? forecast.tempMinF : forecast.tempMin) + "°" : "--"
            font.pixelSize: root._fs_lo
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Divider
        Rectangle {
            width: parent.width * 0.6
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        }

        // Rain chance
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._gapTiny
            EHIcon {
                name: "water_drop"
                size: root._icoSm
                color: Qt.rgba(0.45, 0.72, 1.0, 0.80)
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: forecast ? forecast.precipitationProbability + "%" : "0%"
                font.pixelSize: root._fs_sm
                font.weight: Font.Medium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Sunrise / Sunset
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._gapTiny
            visible: forecast && forecast.sunrise && forecast.sunset

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root._gapTiny
                EHIcon { name: "wb_twilight"; size: root._icoSm; color: Qt.rgba(1.0, 0.80, 0.35, 0.75); anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: forecast ? forecast.sunrise : ""; font.pixelSize: root._fs_sm; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root._gapTiny
                EHIcon { name: "bedtime"; size: root._icoSm; color: Qt.rgba(0.65, 0.75, 1.0, 0.70); anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: forecast ? forecast.sunset : ""; font.pixelSize: root._fs_sm; color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
