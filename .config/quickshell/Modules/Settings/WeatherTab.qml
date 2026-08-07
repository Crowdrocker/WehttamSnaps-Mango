import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: weatherTab

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: enableWeatherSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: enableWeatherSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        text: "Enable Weather"
                        description: "Show weather information in top bar and control center"
                        checked: SettingsData.weatherEnabled
                        onToggled: checked => {
                                       return SettingsData.setWeatherEnabled(
                                           checked)
                                   }
                    }
                }
            }

            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: temperatureSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: temperatureSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        text: "Use Fahrenheit"
                        description: "Use Fahrenheit instead of Celsius for temperature"
                        checked: SettingsData.useFahrenheit
                        onToggled: checked => {
                                       return SettingsData.setTemperatureUnit(
                                           checked)
                                   }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }

            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: locationSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: locationSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    EHToggle {
                        width: parent.width
                        text: "Auto Location"
                        description: "Automatically determine your location using your IP address"
                        checked: SettingsData.useAutoLocation
                        onToggled: checked => {
                                       return SettingsData.setAutoLocation(
                                           checked)
                                   }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: !SettingsData.useAutoLocation

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        StyledText {
                            text: "Custom Location"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        RowLayout {
                                width: parent.width
                                spacing: Theme.spacingM

                                Column {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: (parent.width - Theme.spacingM) / 2
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: "Latitude"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    EHTextField {
                                        id: latitudeInput
                                        width: parent.width
                                        height: Theme.scaledHeight(48)
                                        placeholderText: "40.7128"
                                        backgroundColor: Theme.surfaceVariant
                                        normalBorderColor: Theme.primarySelected
                                        focusedBorderColor: Theme.primary
                                        keyNavigationTab: longitudeInput

                                        Component.onCompleted: {
                                            if (SettingsData.weatherCoordinates) {
                                                const coords = SettingsData.weatherCoordinates.split(',')
                                                if (coords.length > 0) {
                                                    text = coords[0].trim()
                                                }
                                            }
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onWeatherCoordinatesChanged() {
                                                if (SettingsData.weatherCoordinates) {
                                                    const coords = SettingsData.weatherCoordinates.split(',')
                                                    if (coords.length > 0) {
                                                        latitudeInput.text = coords[0].trim()
                                                    }
                                                }
                                            }
                                        }

                                        onTextEdited: {
                                            if (text && longitudeInput.text) {
                                                const coords = text + "," + longitudeInput.text
                                                SettingsData.weatherCoordinates = coords
                                                SettingsData.saveSettings()
                                            }
                                        }
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: (parent.width - Theme.spacingM) / 2
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: "Longitude"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    EHTextField {
                                        id: longitudeInput
                                        width: parent.width
                                        height: Theme.scaledHeight(48)
                                        placeholderText: "-74.0060"
                                        backgroundColor: Theme.surfaceVariant
                                        normalBorderColor: Theme.primarySelected
                                        focusedBorderColor: Theme.primary
                                        keyNavigationTab: locationSearchInput
                                        keyNavigationBacktab: latitudeInput

                                        Component.onCompleted: {
                                            if (SettingsData.weatherCoordinates) {
                                                const coords = SettingsData.weatherCoordinates.split(',')
                                                if (coords.length > 1) {
                                                    text = coords[1].trim()
                                                }
                                            }
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onWeatherCoordinatesChanged() {
                                                if (SettingsData.weatherCoordinates) {
                                                    const coords = SettingsData.weatherCoordinates.split(',')
                                                    if (coords.length > 1) {
                                                        longitudeInput.text = coords[1].trim()
                                                    }
                                                }
                                            }
                                        }

                                        onTextEdited: {
                                            if (text && latitudeInput.text) {
                                                const coords = latitudeInput.text + "," + text
                                                SettingsData.weatherCoordinates = coords
                                                SettingsData.saveSettings()
                                            }
                                        }
                                    }
                                }
                            }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Location Search"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.weight: Font.Medium
                            }

                            EHLocationSearch {
                                id: locationSearchInput
                                width: parent.width
                                currentLocation: ""
                                placeholderText: "New York, NY"
                                keyNavigationBacktab: longitudeInput
                                onLocationSelected: (displayName, coordinates) => {
                                                        SettingsData.setWeatherLocation(displayName, coordinates)

                                                        const coords = coordinates.split(',')
                                                        if (coords.length >= 2) {
                                                            latitudeInput.text = coords[0].trim()
                                                            longitudeInput.text = coords[1].trim()
                                                        }
                                                    }
                            }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
}
