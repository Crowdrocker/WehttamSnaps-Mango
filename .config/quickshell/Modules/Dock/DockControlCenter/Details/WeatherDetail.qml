import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    // Height driven only by visible content column — no circular ref
    implicitHeight: contentCol.implicitHeight + Theme.spacingM * 2
    radius:       Theme.cornerRadius
    color:        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    Column {
        id: contentCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingM }
        spacing: Theme.spacingS

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            width:   parent.width
            height:  36
            spacing: Theme.spacingS

            EHIcon {
                name:  "cloud"
                size:  Theme.fontSizeMedium
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text:             "Weather"
                font.pixelSize:   Theme.fontSizeMedium
                font.weight:      600
                color:            Theme.surfaceText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Refresh button
            EHActionButton {
                iconName: "refresh"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                enabled: WeatherService.weather.available
                onClicked: WeatherService.forceRefresh()
            }

            // Temperature unit toggle
            EHActionButton {
                iconName: "thermostat"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                onClicked: SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
            }
        }

        // ── No data state ─────────────────────────────────────────────────────
        Item {
            width:   parent.width
            height:  80
            visible: !WeatherService.weather.available

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                EHIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name:  "cloud_off"
                    size:  32
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "No weather data available"
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.surfaceVariantText
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "Check settings to enable weather"
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.surfaceVariantText
                }
            }
        }

        // ── Weather content ───────────────────────────────────────────────────
        Column {
            width:   parent.width
            spacing: Theme.spacingS
            visible: WeatherService.weather.available

            // Current weather row
            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                // Icon and temp
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
                            font.weight: 300
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: SettingsData.useFahrenheit ? "Fahrenheit" : "Celsius"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Location and description
                Column {
                    spacing: 2
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop

                    StyledText {
                        text: WeatherService.weather.city || "Current location"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: 500
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: WeatherService.weather.description || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: text.length > 0
                    }
                }
            }

            // Divider
            Rectangle {
                width:  parent.width
                height:  1
                color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            }

            // Stats row
            Row {
                width: parent.width
                spacing: Theme.spacingS

                // Feels like
                StatPill {
                    label: "Feels Like"
                    value: WeatherService.weather.feelsLike
                           ? ((SettingsData.useFahrenheit ? WeatherService.weather.feelsLikeF : WeatherService.weather.feelsLike) + "°") : "--"
                    icon: "thermostat"
                }

                // Humidity
                StatPill {
                    label: "Humidity"
                    value: WeatherService.weather.humidity ? (WeatherService.weather.humidity + "%") : "--"
                    icon: "humidity_low"
                }

                // Wind
                StatPill {
                    label: "Wind"
                    value: WeatherService.weather.wind || "--"
                    icon: "air"
                }

                // Visibility
                StatPill {
                    label: "Visibility"
                    value: WeatherService.weather.visibility || "--"
                    icon: "visibility"
                }
            }

            // Divider
            Rectangle {
                width:  parent.width
                height:  1
                color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            }

            // 5-day forecast
            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "5-Day Forecast"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: 600
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: 5

                        Rectangle {
                            id: forecastDayCell
                            required property int index
                            property var  d:       { var x = new Date(); x.setDate(x.getDate() + index); return x }
                            property bool isToday: index === 0
                            property var  fd:      (WeatherService.weather.forecast?.length > index)
                                                   ? WeatherService.weather.forecast[index] : null

                            width:  (parent.width - Theme.spacingXS * 4) / 5
                            height: 70
                            radius: Theme.cornerRadius * 0.5
                            color:  isToday
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
                                    font.pixelSize: Math.max(1, Math.round((Number(Theme.fontSizeSmall) || 12) - 1))
                                    font.weight: forecastDayCell.isToday ? 600 : 400
                                    color: forecastDayCell.isToday ? Theme.primary : Theme.surfaceText
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
                                               + "°")
                                            : "--/--"
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    font.weight: 500
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

    // Stat pill component (inline)
    component StatPill: Rectangle {
        property string label: ""
        property string value: ""
        property string icon: ""

        width:  (parent.width - Theme.spacingS * 3) / 4
        height: 50
        radius: Theme.cornerRadius * 0.5
        color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)

        Column {
            width: parent.width
            anchors.centerIn: parent
            spacing: 2

            EHIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name:  icon
                size:  14
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
                font.pixelSize: Theme.fontSizeSmall
                font.weight: 500
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}