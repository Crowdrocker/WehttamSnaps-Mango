import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: weatherModal

    function show()   { visible = true  }
    function hide()   { visible = false }
    function toggle() { visible = !visible }

    objectName: "weatherModal"
    title: "Weather - " + (WeatherService.weather.city || "Halifax")
    minimumSize: Qt.size(320, 400)
    implicitWidth:  960
    implicitHeight: 880
    backgroundColor: Theme.surfaceContainer
    visible: false

    // ── Scale factor: fit to whichever dimension is tighter ──────────────────
    // Reference design: 960 × 880. s is the largest value that fits both axes.
    readonly property real sW: width  / 960
    readonly property real sH: (height - titleBar.height) / 828   // 828 = 880 - 52 title
    readonly property real s:  Math.max(0.28, Math.min(sW, sH))

    // WMO codes: 51-67 drizzle/rain, 71-77 snow, 80-82 showers, 85-86 snow showers,
    //            95-99 thunderstorm — all trigger the rain shader overlay
    readonly property bool isRainy: {
        const c = WeatherService.weather.wCode
        return (c >= 51 && c <= 67) || (c >= 71 && c <= 77) ||
               (c >= 80 && c <= 86) || (c >= 95 && c <= 99)
    }

    // Elapsed seconds for the shader — only ticks when weather is rainy
    property real shaderTime: 0.0

    FrameAnimation {
        id: rainTimer
        running: weatherModal.visible && weatherModal.isRainy
        onTriggered: weatherModal.shaderTime += delta
    }

    onVisibleChanged: { if (visible) WeatherService.addRef() }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: weatherModal.hide()

        // ── Title bar ────────────────────────────────────────────────────────
        Item {
            id: titleBar
            anchors.left:  parent.left
            anchors.right: parent.right
            height: Math.round(13 * sW)   // title bar only scales with width
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       windowControls.tryStartMove()
                onDoubleClicked: windowControls.tryToggleMaximize()
            }
            Rectangle { anchors.fill: parent; color: Theme.surfaceContainer; opacity: 0.60 }

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     Math.round(20 * s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(10 * s)
                EHIcon {
                    name: WeatherService.weather.available
                        ? WeatherService.getWeatherIcon(WeatherService.weather.wCode, WeatherService.weather.isDay)
                        : "cloud_off"
                    size: Math.round(22 * s)
                    color: WeatherService.weather.available ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: WeatherService.weather.available ? (WeatherService.weather.city || "Weather") : "Weather"
                    font.pixelSize: Math.round(18 * s)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right:          parent.right
                anchors.rightMargin:    Math.round(10 * s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * s)
                EHActionButton { circular: false; iconName: "refresh"; iconSize: Math.round(18 * s); iconColor: Theme.surfaceText; onClicked: WeatherService.forceRefresh() }
                EHActionButton { circular: false; iconName: "close";   iconSize: Math.round(18 * s); iconColor: Theme.surfaceText; onClicked: weatherModal.hide() }
            }
        }

        // ── Loading / error ───────────────────────────────────────────────────
        Item {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    titleBar.bottom
            anchors.bottom: parent.bottom
            visible: !WeatherService.weather.available
            Column {
                anchors.centerIn: parent
                spacing: Math.round(18 * s)
                EHIcon {
                    name: WeatherService.weather.loading ? "cloud_sync" : "cloud_off"
                    size: Math.round(64 * s)
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: WeatherService.weather.loading ? "Loading weather data…" : "Weather data unavailable"
                    font.pixelSize: Math.round(16 * s)
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── Content area — fills exactly the space below the title bar ────────
        // Everything is anchored and sized with s so it always fits exactly.
        Item {
            id: contentArea
            anchors.left:        parent.left
            anchors.right:       parent.right
            anchors.top:         titleBar.bottom
            anchors.bottom:      parent.bottom
            anchors.margins:     Math.round(12 * s)
            visible: WeatherService.weather.available

            // ── Column of sections, each given a proportional share of height ──
            // Total proportions (reference): hero≈22%, cond≈26%, hourly≈20%, days≈32%
            // We use explicit height fractions of contentArea.height so everything fits.

            readonly property real gap:       Math.round(10 * s)
            readonly property real innerH:    height - gap * 3   // 4 sections → 3 gaps
            readonly property real heroH:     Math.round(innerH * 0.210)
            readonly property real condH:     Math.round(innerH * 0.255)
            readonly property real hourH:     Math.round(innerH * 0.210)
            readonly property real dayH:      innerH - heroH - condH - hourH  // remainder ~32.5%

            // ── HERO ─────────────────────────────────────────────────────────
            Rectangle {
                id: heroRect
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   parent.top
                height: contentArea.heroH
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Row {
                    anchors.centerIn: parent
                    spacing:          Math.round(24 * s)

                    EHIcon {
                        name:  WeatherService.getWeatherIcon(WeatherService.weather.wCode, WeatherService.weather.isDay)
                        size:  Math.round(72 * s)
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:               Math.round(4 * s)

                        // Temperature + unit
                        Row {
                            spacing: Math.round(3 * s)
                            StyledText {
                                text:           (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                                font.pixelSize: Math.round(60 * s)
                                font.weight:    Font.Light
                                color:          Theme.surfaceText
                            }
                            StyledText {
                                text:                    SettingsData.useFahrenheit ? "F" : "C"
                                font.pixelSize:          Math.round(22 * s)
                                color:                   Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.70)
                                anchors.verticalCenter:  parent.verticalCenter
                                anchors.verticalCenterOffset: Math.round(-8 * s)
                            }
                        }

                        // Condition description
                        StyledText {
                            text:           WeatherService.getWeatherCondition(WeatherService.weather.wCode)
                            font.pixelSize: Math.round(18 * s)
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.80)
                        }

                        // Feels like · Sunrise · Sunset
                        Row {
                            spacing: Math.round(16 * s)
                            Row {
                                spacing: Math.round(4 * s)
                                EHIcon { name: "device_thermostat"; size: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "Feels like " + (SettingsData.useFahrenheit ? WeatherService.weather.feelsLikeF : WeatherService.weather.feelsLike) + "°"; font.pixelSize: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                            }
                            Row {
                                spacing: Math.round(4 * s)
                                EHIcon { name: "wb_twilight"; size: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: WeatherService.weather.sunrise; font.pixelSize: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                            }
                            Row {
                                spacing: Math.round(4 * s)
                                EHIcon { name: "bedtime"; size: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: WeatherService.weather.sunset; font.pixelSize: Math.round(12 * s); color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55); anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }

                // ── Rain shader overlay ───────────────────────────────────────
                // Renders the rainy-window distortion effect over the hero rect
                // when the current weather condition is rain, drizzle, or snow.
                // Qt 6: OpacityMask is gone; use a clipping Item with radius
                // so the ShaderEffect never escapes the rounded corners.
                Item {
                    id: rainOverlayClip
                    anchors.fill: parent
                    // Clip children to the rounded hero rect shape
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled:    true
                        maskThresholdMin: 0.5
                        maskSource: Rectangle {
                            width:  rainOverlayClip.width
                            height: rainOverlayClip.height
                            radius: Theme.cornerRadius
                        }
                    }

                    visible: weatherModal.isRainy

                    ShaderEffect {
                        id: rainOverlay
                        anchors.fill: parent

                        opacity: weatherModal.isRainy ? 0.55 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }

                        // The shader needs to sample the background — grab the heroRect contents
                        property variant source: ShaderEffectSource {
                            sourceItem: heroRect
                            hideSource: false
                            live:       true
                        }

                        property real      time:             weatherModal.shaderTime
                        property vector2d  resolution:       Qt.vector2d(heroRect.width, heroRect.height)
                        property vector2d  sourceResolution: Qt.vector2d(heroRect.width, heroRect.height)

                        vertexShader:   "qrc:/quickshell/Modules/Weather/Shaders/ANIM_WP_Raining_vert.qsb"
                        fragmentShader: "qrc:/quickshell/Modules/Weather/Shaders/ANIM_WP_Raining_frag.qsb"
                    }
                }
            }

            // ── CURRENT CONDITIONS ────────────────────────────────────────────
            Rectangle {
                id: condRect
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   heroRect.bottom
                anchors.topMargin: contentArea.gap
                height: contentArea.condH
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Item {
                    anchors.fill:    parent
                    anchors.margins: Math.round(12 * s)

                    // Section header
                    Row {
                        id: condHeader
                        anchors.top:  parent.top
                        anchors.left: parent.left
                        height:       Math.round(20 * s)
                        spacing:      Math.round(8 * s)
                        EHIcon { name: "device_thermostat"; size: Math.round(16 * s); color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Current Conditions"; font.pixelSize: Math.round(13 * s); font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Single horizontal scrollable row of stat cards — same pattern as hourly
                    Flickable {
                        id: condFlickable
                        anchors.top:        condHeader.bottom
                        anchors.topMargin:  Math.round(6 * s)
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.bottom:     parent.bottom
                        contentWidth:       Math.max(condRow.implicitWidth, width)
                        clip:               true
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: condRow
                            height:  condFlickable.height
                            spacing: Math.round(6 * s)
                            x: Math.max(0, (condFlickable.width - implicitWidth) / 2)

                            StatBox { s: weatherModal.s; label: "Humidity";    value: WeatherService.weather.humidity + "%";                                                                                          iconName: "humidity_mid"; width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Wind Speed";  value: WeatherService.weather.wind || "--";                                                                                           iconName: "air";          width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Pressure";    value: WeatherService.weather.pressure + " hPa";                                                                                      iconName: "compress";     width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Rain Chance"; value: WeatherService.weather.precipitationProbability + "%";                                                                         iconName: "rainy";        width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "UV Index";    value: String(WeatherService.weather.uv);                                                                                             iconName: "wb_sunny";     width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Visibility";  value: WeatherService.weather.visibility + " m";                                                                                      iconName: "visibility";   width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Dew Point";   value: (SettingsData.useFahrenheit ? Math.round(WeatherService.weather.dewPoint * 9/5 + 32) : WeatherService.weather.dewPoint) + "°"; iconName: "dew_point";    width: Math.round(100 * weatherModal.s); height: parent.height }
                            StatBox { s: weatherModal.s; label: "Cloud Cover"; value: WeatherService.weather.cloudCover + "%";                                                                                       iconName: "cloud";        width: Math.round(100 * weatherModal.s); height: parent.height }
                        }
                    }
                }
            }

            // ── HOURLY FORECAST ───────────────────────────────────────────────
            Rectangle {
                id: hourRect
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.top:   condRect.bottom
                anchors.topMargin: contentArea.gap
                height: contentArea.hourH
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Item {
                    anchors.fill:    parent
                    anchors.margins: Math.round(12 * s)

                    Row {
                        id: hourHeader
                        anchors.top:  parent.top
                        anchors.left: parent.left
                        height:       Math.round(20 * s)
                        spacing:      Math.round(8 * s)
                        EHIcon { name: "schedule"; size: Math.round(16 * s); color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Hourly Forecast"; font.pixelSize: Math.round(13 * s); font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Flickable {
                        anchors.top:       hourHeader.bottom
                        anchors.topMargin: Math.round(6 * s)
                        anchors.left:      parent.left
                        anchors.right:     parent.right
                        anchors.bottom:    parent.bottom
                        contentWidth:      hourRow.width
                        clip:              true
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: hourRow
                            height:  parent.height
                            spacing: Math.round(6 * s)
                            Repeater {
                                model: Math.min(24, WeatherService.weather.hourly ? WeatherService.weather.hourly.length : 0)
                                HourBox {
                                    hourIndex: index
                                    s:         weatherModal.s
                                    height:    hourRow.height
                                    width:     Math.round(78 * weatherModal.s)
                                }
                            }
                        }
                    }
                }
            }

            // ── 7-DAY FORECAST ────────────────────────────────────────────────
            Rectangle {
                id: dayRect
                anchors.left:      parent.left
                anchors.right:     parent.right
                anchors.top:       hourRect.bottom
                anchors.topMargin: contentArea.gap
                anchors.bottom:    parent.bottom
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                border.width: 2

                Item {
                    anchors.fill:    parent
                    anchors.margins: Math.round(12 * s)

                    Row {
                        id: dayHeader
                        anchors.top:              parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        height:                   Math.round(20 * s)
                        spacing:                  Math.round(8 * s)
                        EHIcon { name: "calendar_month"; size: Math.round(16 * s); color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "10-Day Forecast"; font.pixelSize: Math.round(13 * s); font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Flickable {
                        id: dayFlickable
                        anchors.top:       dayHeader.bottom
                        anchors.topMargin: Math.round(6 * s)
                        anchors.left:      parent.left
                        anchors.right:     parent.right
                        anchors.bottom:    parent.bottom
                        clip:              true
                        flickableDirection: Flickable.HorizontalFlick
                        contentWidth:      Math.max(dayCardRow.implicitWidth, width)
                        contentHeight:     height

                        Row {
                            id: dayCardRow
                            height:  dayFlickable.height
                            spacing: Math.round(6 * s)
                            x: Math.max(0, (dayFlickable.width - implicitWidth) / 2)

                            Repeater {
                                id: dayRepeater
                                model: Math.min(10, WeatherService.weather.forecast.length)
                                DayRow {
                                    dayIndex: index
                                    s:        weatherModal.s
                                    width:    Math.round(90 * weatherModal.s)
                                    height:   dayCardRow.height
                                }
                            }
                        }
                    }
                }
            }

        } // end contentArea
    }

    FloatingWindowControls { id: windowControls; targetWindow: weatherModal }

    Component.onCompleted:   WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()
}
