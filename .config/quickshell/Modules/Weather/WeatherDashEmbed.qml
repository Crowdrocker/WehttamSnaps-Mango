// Embeddable weather UI for Event Horizon Dash — same WeatherService + StatBox / HourBox / DayRow as WeatherModal.
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    anchors.fill: parent
    clip: true

    readonly property real s: Math.max(0.38, Math.min(0.92, Math.min(root.width / 520, root.height / 640)))
    readonly property real gap: Math.round(8 * s)

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    Flickable {
        anchors.fill: parent
        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: col.implicitHeight
        interactive: contentHeight > height

        Column {
            id: col
            width: root.width
            spacing: root.gap

            RowLayout {
                width: parent.width
                spacing: Theme.spacingS

                EHActionButton {
                    iconName: "refresh"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceVariantText
                    enabled: WeatherService.weather.available
                    onClicked: WeatherService.forceRefresh()
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: WeatherService.weather.city || "Weather"
                    font.pixelSize: Math.round(16 * s)
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                EHActionButton {
                    iconName: "thermostat"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceVariantText
                    onClicked: SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
                }
            }

            Item {
                width: parent.width
                height: Math.round(120 * s)
                visible: WeatherService.weather.available

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                    border.width: 2

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(18 * s)

                        EHIcon {
                            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode, WeatherService.weather.isDay)
                            size: Math.round(56 * s)
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: Math.round(4 * s)
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                spacing: Math.round(4 * s)
                                StyledText {
                                    text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                                    font.pixelSize: Math.round(40 * s)
                                    font.weight: Font.Light
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    text: SettingsData.useFahrenheit ? "F" : "C"
                                    font.pixelSize: Math.round(16 * s)
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.70)
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: Math.round(-6 * s)
                                }
                            }

                            StyledText {
                                text: WeatherService.getWeatherCondition(WeatherService.weather.wCode)
                                font.pixelSize: Math.round(14 * s)
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.80)
                                width: Math.min(root.width * 0.55, 280)
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.round(200)
                visible: !WeatherService.weather.available

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    EHIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: WeatherService.weather.loading ? "cloud_sync" : "cloud_off"
                        size: 40
                        color: Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: WeatherService.weather.loading ? "Loading weather…" : "Weather unavailable"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Math.round(118 * s)
                visible: WeatherService.weather.available
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Flickable {
                    id: condFlick
                    anchors.fill: parent
                    anchors.margins: Math.round(10 * s)
                    anchors.topMargin: Math.round(8 * s)
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    contentWidth: condRow.implicitWidth
                    interactive: contentWidth > width

                    Row {
                        id: condRow
                        height: parent.height
                        spacing: Math.round(6 * s)

                        StatBox {
                            s: root.s
                            label: "Humidity"
                            value: WeatherService.weather.humidity + "%"
                            iconName: "humidity_mid"
                            width: Math.round(96 * root.s)
                            height: parent.height
                        }
                        StatBox {
                            s: root.s
                            label: "Wind"
                            value: WeatherService.weather.wind || "--"
                            iconName: "air"
                            width: Math.round(96 * root.s)
                            height: parent.height
                        }
                        StatBox {
                            s: root.s
                            label: "Feels"
                            value: (SettingsData.useFahrenheit ? WeatherService.weather.feelsLikeF : WeatherService.weather.feelsLike) + "°"
                            iconName: "device_thermostat"
                            width: Math.round(96 * root.s)
                            height: parent.height
                        }
                        StatBox {
                            s: root.s
                            label: "UV"
                            value: String(WeatherService.weather.uv)
                            iconName: "wb_sunny"
                            width: Math.round(96 * root.s)
                            height: parent.height
                        }
                        StatBox {
                            s: root.s
                            label: "Visibility"
                            value: WeatherService.weather.visibility || "--"
                            iconName: "visibility"
                            width: Math.round(96 * root.s)
                            height: parent.height
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Math.round(100 * s)
                visible: WeatherService.weather.available && WeatherService.weather.hourly && WeatherService.weather.hourly.length > 0
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Math.round(10 * s)
                    spacing: Math.round(6 * s)
                    EHIcon { name: "schedule"; size: Math.round(14 * s); color: Theme.primary }
                    StyledText {
                        text: "Hourly"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Math.round(8 * s)
                    anchors.topMargin: Math.round(30 * s)
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    contentWidth: hourRow.implicitWidth
                    interactive: contentWidth > width

                    Row {
                        id: hourRow
                        height: parent.height
                        spacing: Math.round(6 * s)
                        Repeater {
                            model: Math.min(24, WeatherService.weather.hourly ? WeatherService.weather.hourly.length : 0)
                            HourBox {
                                hourIndex: index
                                s: root.s
                                height: hourRow.height
                                width: Math.round(72 * root.s)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Math.round(132 * s)
                visible: WeatherService.weather.available && WeatherService.weather.forecast && WeatherService.weather.forecast.length > 0
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Math.round(10 * s)
                    spacing: Math.round(6 * s)
                    EHIcon { name: "calendar_month"; size: Math.round(14 * s); color: Theme.primary }
                    StyledText {
                        text: "Forecast"
                        font.pixelSize: Math.round(12 * s)
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Math.round(8 * s)
                    anchors.topMargin: Math.round(32 * s)
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    contentWidth: dayCardRow.implicitWidth
                    interactive: contentWidth > width

                    Row {
                        id: dayCardRow
                        height: parent.height
                        spacing: Math.round(6 * s)
                        Repeater {
                            model: Math.min(10, WeatherService.weather.forecast.length)
                            DayRow {
                                dayIndex: index
                                s: root.s
                                width: Math.round(86 * root.s)
                                height: dayCardRow.height
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: openWeatherLink.implicitHeight + 8

                StyledText {
                    id: openWeatherLink
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: "Open full weather"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.primary
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: weatherModal.show()
                    }
                }
            }
        }
    }
}
