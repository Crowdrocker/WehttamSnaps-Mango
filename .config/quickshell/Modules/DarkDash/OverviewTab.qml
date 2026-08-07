import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DarkDash.Overview

Item {
    id: root

    readonly property real uiScale: (Appearance.combinedScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    implicitWidth: spx(700)
    implicitHeight: spx(410)
    // StackLayout manages size - don't use anchors.fill here

    Component.onCompleted: {
    }

    signal switchToWeatherTab()

    Item {
        id: innerContainer
        anchors.fill: parent
        width: root.width
        height: root.height
        
        Component.onCompleted: {
        }

        ClockCard {
            x: 0
            y: 0
            width: Math.max(0, innerContainer.width * 0.2 - Theme.spacingM * 2)
            height: root.spx(180)
        }

        WeatherOverviewCard {
            id: weatherCard
            x: SettingsData.weatherEnabled ? Math.max(0, innerContainer.width * 0.2 - Theme.spacingM) : 0
            y: 0
            width: SettingsData.weatherEnabled ? Math.max(150, innerContainer.width * 0.3) : 0
            height: root.spx(100)
            visible: SettingsData.weatherEnabled

            Component.onCompleted: {
                if (typeof WeatherService !== "undefined") {
                } else {
                }
            }

            onWidthChanged: {
                if (width > 0) {
                }
            }

            onClicked: root.switchToWeatherTab()
        }

        UserInfoCard {
            x: SettingsData.weatherEnabled ? innerContainer.width * 0.5 : innerContainer.width * 0.2 - Theme.spacingM
            y: 0
            width: SettingsData.weatherEnabled ? innerContainer.width * 0.5 : innerContainer.width * 0.8
            height: root.spx(100)
        }

        CalendarOverviewCard {
            x: innerContainer.width * 0.2 - Theme.spacingM
            y: root.spx(100) + Theme.spacingM
            width: innerContainer.width * 0.6
            height: root.spx(300)
        }

        MediaOverviewCard {
            id: mediaCard
            x: innerContainer.width * 0.8
            y: root.spx(100) + Theme.spacingM
            width: Math.min(innerContainer.width * 0.2, implicitWidth)
            height: root.spx(300)

            // Media controls now live in `Widgets/MediaPopup.qml` opened from bar widgets.
        }
    }
}