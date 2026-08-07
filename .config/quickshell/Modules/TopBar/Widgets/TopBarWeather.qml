import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS

    signal clicked()

    visible: SettingsData.weatherEnabled
    width: visible ? (isBarVertical ? widgetHeight : Math.min(100, weatherRow.implicitWidth + horizontalPadding * 2)) : 0
    height: visible ? (isBarVertical ? (weatherColumn.implicitHeight + horizontalPadding * 2) : widgetHeight) : 0
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = weatherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Ref {
        service: WeatherService
    }

    Row {
        id: weatherRow
        visible: !isBarVertical
        anchors.centerIn: parent
        spacing: Math.max(2, root.widgetHeight * 0.1)

        EHIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: root.widgetHeight * 0.6
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                if (temp === undefined || temp === null) {
                    return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                }

                return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
            }
            font.pixelSize: root.widgetHeight * 0.45
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

    }
    
    Column {
        id: weatherColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: Math.max(2, root.widgetHeight * 0.1)

        EHIcon {
            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
            size: root.widgetHeight * 0.6
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: {
                const temp = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                if (temp === undefined || temp === null) {
                    return "--°" + (SettingsData.useFahrenheit ? "F" : "C");
                }

                return temp + "°" + (SettingsData.useFahrenheit ? "F" : "C");
            }
            font.pixelSize: root.widgetHeight * 0.45
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

    }

    MouseArea {
        id: weatherArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const rect = root.mapToItem(null, 0, 0, root.width, root.height)
            const currentScreen = parentScreen || Screen
            weatherPopup.parentScreen = currentScreen
            weatherPopup.barPosition = SettingsData.topBarPosition || "top"
            weatherPopup.barThickness = (SettingsData.topBarHeight || 40) * (SettingsData.topbarScale || 1.0)
            weatherPopup.triggerX = rect.x
            weatherPopup.triggerY = rect.y
            weatherPopup.triggerWidth = rect.width

            if (weatherPopup.showPopup) weatherPopup.close()
            else weatherPopup.open()

            root.clicked()
        }
    }

    WeatherPopup {
        id: weatherPopup
    }


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
