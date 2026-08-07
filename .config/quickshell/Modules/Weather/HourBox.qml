import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property int  hourIndex: 0
    property real s:         1.0

    property var hourData: {
        const h = WeatherService.weather.hourly
        if (!h || h.length === 0) return null
        return h[hourIndex] || null
    }

    property bool isNow: hourIndex === 0

    property string hourLabel: {
        if (isNow) return "Now"
        if (!hourData || !hourData.time) return "--"
        try {
            const d = new Date(hourData.time)
            if (isNaN(d.getTime())) return "--"
            if (typeof SettingsData !== "undefined" && SettingsData.use24HourClock)
                return String(d.getHours()).padStart(2, "0") + ":00"
            const h = d.getHours()
            const displayH = h === 0 ? 12 : (h > 12 ? h - 12 : h)
            return displayH + (h >= 12 ? " PM" : " AM")
        } catch (e) { return "--" }
    }

    // All sizes purely s-driven — no height fractions
    readonly property real _fs_label: Math.round(11 * s)
    readonly property real _icon:     Math.round(26 * s)
    readonly property real _fs_temp:  Math.round(14 * s)
    readonly property real _fs_precip: Math.round(10 * s)
    readonly property real _icoPrec:  Math.round(10 * s)
    readonly property real _gap:      Math.round(4  * s)

    radius: Math.round(Theme.cornerRadius * 0.8)
    color: isNow
        ? Qt.rgba(Theme.primary.r,       Theme.primary.g,       Theme.primary.b,       0.18)
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.28)
    border.color: isNow ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
    border.width: 2

    Column {
        anchors.centerIn: parent
        spacing: root._gap

        // Hour label
        StyledText {
            text: root.hourLabel
            font.pixelSize: root._fs_label
            font.weight: isNow ? Font.SemiBold : Font.Normal
            color: isNow ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Weather icon
        EHIcon {
            name: root.hourData
                ? WeatherService.getWeatherIcon(root.hourData.wCode, root.hourData.isDay)
                : WeatherService.getWeatherIcon(WeatherService.weather.wCode, WeatherService.weather.isDay)
            size: root._icon
            color: isNow ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.92)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Temperature
        StyledText {
            text: root.hourData
                ? (SettingsData.useFahrenheit ? root.hourData.tempF : root.hourData.temp) + "°"
                : (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
            font.pixelSize: root._fs_temp
            font.weight: Font.Medium
            color: isNow ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Precipitation probability
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(3 * root.s)
            visible: root.hourData !== null && root.hourData.precipitationProbability > 0
            EHIcon {
                name: "water_drop"
                size: root._icoPrec
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.hourData ? root.hourData.precipitationProbability + "%" : ""
                font.pixelSize: root._fs_precip
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
