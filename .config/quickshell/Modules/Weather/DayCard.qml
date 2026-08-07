import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// DayCard: vertical card for one day of the 7-day forecast.
Rectangle {
    id: root

    property int dayIndex: 0
    property bool isToday: dayIndex === 0
    property var forecast: WeatherService.weather.forecast[dayIndex] || null

    implicitWidth:  150
    implicitHeight: cardCol.implicitHeight + 4

    radius: Theme.cornerRadius * 1.2
    color: isToday
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
        : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.22)
    border.color: isToday
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1

    Column {
        id: cardCol
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin:        2
        spacing: 10
        width: parent.width - 4

        // ── Day name ──────────────────────────────────────────────────
        StyledText {
            text: isToday ? "Today" : (forecast ? forecast.day : "--")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: isToday ? Font.SemiBold : Font.Medium
            color: isToday
                ? Theme.primary
                : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── Divider ───────────────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.55
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: isToday
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
        }

        // ── Weather icon ──────────────────────────────────────────────
        EHIcon {
            name: forecast ? WeatherService.getWeatherIcon(forecast.wCode) : "cloud"
            size: 48
            color: isToday
                ? Theme.primary
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── High temp ─────────────────────────────────────────────────
        StyledText {
            text: forecast
                ? (SettingsData.useFahrenheit ? forecast.tempMaxF : forecast.tempMax) + "°"
                : "--"
            font.pixelSize: Theme.fontSizeXL !== undefined ? Theme.fontSizeXL : Theme.fontSizeLarge + 6
            font.weight: Font.SemiBold
            color: isToday ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── Low temp ──────────────────────────────────────────────────
        StyledText {
            text: forecast
                ? (SettingsData.useFahrenheit ? forecast.tempMinF : forecast.tempMin) + "°"
                : "--"
            font.pixelSize: Theme.fontSizeMedium
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── Divider ───────────────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.55
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        }

        // ── Rain chance ───────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            EHIcon {
                name: "water_drop"
                size: 16
                color: Qt.rgba(0.45, 0.72, 1.0, 0.80)
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: forecast ? forecast.precipitationProbability + "%" : "0%"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Sunrise / Sunset ──────────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: forecast && forecast.sunrise && forecast.sunset
            bottomPadding: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                EHIcon {
                    name: "wb_twilight"
                    size: 15
                    color: Qt.rgba(1.0, 0.80, 0.35, 0.75)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: forecast ? forecast.sunrise : ""
                    font.pixelSize: Theme.fontSizeSmall + 1
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                EHIcon {
                    name: "bedtime"
                    size: 15
                    color: Qt.rgba(0.65, 0.75, 1.0, 0.70)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: forecast ? forecast.sunset : ""
                    font.pixelSize: Theme.fontSizeSmall + 1
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
