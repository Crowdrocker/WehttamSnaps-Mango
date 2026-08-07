import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property int hourOffset: 0

    property var currentHour: {
        const now = new Date()
        const hourTime = new Date(now.getTime() + hourOffset * 3600000)
        const hour = hourTime.getHours()
        const isPM = hour >= 12
        const displayHour = hour === 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return {
            hour: displayHour + (isPM ? " PM" : " AM"),
            fullHour: hour
        }
    }

    property bool isNow: hourOffset === 0

    radius: Theme.cornerRadius * 0.6
    height: 70
    width: 55
    
    color: isNow 
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
    border.color: isNow ? Theme.primary : "transparent"
    border.width: isNow ? 1 : 0

    Column {
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            text: isNow ? "Now" : currentHour.hour
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: isNow ? Font.SemiBold : Font.Normal
            color: isNow ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        EHIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: 24
            color: isNow ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: isNow ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}