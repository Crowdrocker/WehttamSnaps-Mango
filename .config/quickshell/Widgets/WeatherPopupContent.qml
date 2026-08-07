// Shared body for WeatherPopup + desktop Event Horizon Dash (same UI as popup)
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showCloseButton: true
    signal closeRequested()

    implicitWidth: 380
    implicitHeight: contentCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * SettingsData.weatherPopupWidgetBackgroundOpacity)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    Column {
        id: contentCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingM }
        spacing: Theme.spacingS

        RowLayout {
            width: parent.width
            height: 36
            spacing: Theme.spacingS

            EHIcon {
                name: "cloud"
                size: Math.round(Theme.fontSizeMedium || Theme.fontSizeSmall || 14)
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text: "Weather"
                font.pixelSize: Math.round(Theme.fontSizeMedium || Theme.fontSizeSmall || 14)
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            EHActionButton {
                iconName: "refresh"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                enabled: WeatherService.weather.available
                onClicked: WeatherService.forceRefresh()
            }

            EHActionButton {
                iconName: "thermostat"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                onClicked: SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
            }

            EHActionButton {
                visible: root.showCloseButton
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                onClicked: root.closeRequested()
            }
        }

        Item {
            width: parent.width
            height: 80
            visible: !WeatherService.weather.available

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                EHIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "cloud_off"
                    size: 32
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No weather data available"
                    font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Check settings to enable weather"
                    font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                    color: Theme.surfaceVariantText
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: WeatherService.weather.available

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingS

                    EHIcon {
                        name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                        size: 48
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: 2

                        StyledText {
                            text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                            font.pixelSize: 36
                            font.weight: Font.Light
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: SettingsData.useFahrenheit ? "Fahrenheit" : "Celsius"
                            font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Column {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        text: WeatherService.weather.city || "Current location"
                        font.pixelSize: Math.round(Theme.fontSizeMedium || Theme.fontSizeSmall || 14)
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: WeatherService.weather.description || ""
                        font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                        color: Theme.surfaceVariantText
                        visible: text.length > 0
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                StatPill {
                    label: "Feels Like"
                    value: WeatherService.weather.feelsLike
                        ? ((SettingsData.useFahrenheit ? WeatherService.weather.feelsLikeF : WeatherService.weather.feelsLike) + "°") : "--"
                    icon: "thermostat"
                }

                StatPill {
                    label: "Humidity"
                    value: WeatherService.weather.humidity ? (WeatherService.weather.humidity + "%") : "--"
                    icon: "humidity_low"
                }

                StatPill {
                    label: "Wind"
                    value: WeatherService.weather.wind || "--"
                    icon: "air"
                }

                StatPill {
                    label: "Visibility"
                    value: WeatherService.weather.visibility || "--"
                    icon: "visibility"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "5-Day Forecast"
                    font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: 5

                        Rectangle {
                            property var d: {
                                const x = new Date()
                                x.setDate(x.getDate() + index)
                                return x
                            }
                            property bool isToday: index === 0
                            property var fd: (WeatherService.weather.forecast?.length > index)
                                ? WeatherService.weather.forecast[index] : null

                            width: (parent.width - Theme.spacingXS * 4) / 5
                            height: 70
                            radius: Theme.cornerRadius * 0.5
                            color: isToday
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                            border.width: isToday ? 1 : 0

                            Column {
                                width: parent.width
                                anchors.centerIn: parent
                                spacing: 2

                                StyledText {
                                    text: Qt.locale().dayName(d.getDay(), Locale.ShortFormat)
                                    font.pixelSize: Math.max(1, Math.round((Theme.fontSizeSmall || 12) - 1))
                                    font.weight: isToday ? Font.DemiBold : Font.Normal
                                    color: isToday ? Theme.primary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                EHIcon {
                                    name: fd ? WeatherService.getWeatherIcon(fd.wCode || 0) : "cloud"
                                    size: 20
                                    color: isToday ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: fd ? ((SettingsData.useFahrenheit ? (fd.tempMaxF || fd.tempMax) : (fd.tempMax || 0))
                                        + "°/" +
                                        (SettingsData.useFahrenheit ? (fd.tempMinF || fd.tempMin) : (fd.tempMin || 0))
                                        + "°") : "--/--"
                                    font.pixelSize: Math.max(1, Math.round((Theme.fontSizeSmall || 12) - 2))
                                    font.weight: Font.Medium
                                    color: isToday ? Theme.primary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component StatPill: Rectangle {
        property string label: ""
        property string value: ""
        property string icon: ""

        width: (parent.width - Theme.spacingS * 3) / 4
        height: 50
        radius: Theme.cornerRadius * 0.5
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)

        Column {
            width: parent.width
            anchors.centerIn: parent
            spacing: 2

            EHIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: icon
                size: 14
                color: Theme.primary
            }
            StyledText {
                text: label
                font.pixelSize: 9
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: value
                font.pixelSize: Math.round(Theme.fontSizeSmall || 12)
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
