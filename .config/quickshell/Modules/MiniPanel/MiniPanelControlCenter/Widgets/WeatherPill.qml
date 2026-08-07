import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

CompoundPill {
    id: root

    property var widgetData: ({})
    property int widgetIndex: 0

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    iconName: WeatherService.weather.available ? WeatherService.getWeatherIcon(WeatherService.weather.wCode) : "cloud_off"

    isActive: WeatherService.weather.available

    primaryText: {
        if (!WeatherService.weather.available) {
            return "Weather"
        }
        const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp
        return `${temp}°${SettingsData.useFahrenheit ? "F" : "C"}`
    }

    secondaryText: {
        if (!WeatherService.weather.available) {
            return "No data"
        }
        return WeatherService.weather.city || "Current location"
    }

    iconColor: {
        if (!WeatherService.weather.available) {
            return Theme.surfaceVariantText
        }
        return Theme.primary
    }

    onToggled: {
        expandClicked()
    }
}
