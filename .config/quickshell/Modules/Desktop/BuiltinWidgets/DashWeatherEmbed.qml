// Dash weather — fills the DesktopEventHorizonWidget content area precisely.
// Fixed: stat values now visible, hourly cards fully rendered, scale uses height+width.
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    anchors.fill: parent
    clip: true

    // Scale on the SMALLER axis so nothing ever overflows regardless of widget shape.
    // Widget default is 720x520; content area after chrome ~720x(420ish).
    // This item IS the content area (anchors.fill with spacingS margins in the widget).
    readonly property real s: Math.max(0.50, Math.min(1.15,
        Math.min(root.width / 380, root.height / 430)
    ))

    readonly property real gap:  Math.max(4,  Math.round(5  * s))
    readonly property real padS: Math.max(6,  Math.round(8  * s))
    readonly property real padM: Math.max(10, Math.round(12 * s))

    readonly property real navH: Math.round(36 * s)
    readonly property real heroH: Math.round(92 * s)

    // Stats: two rows — each cell is one row: icon + label + value.
    readonly property real statCellH: Math.max(50, Math.round(54 * s))
    readonly property real statsH:    statCellH * 2 + gap + padS * 2 + 2

    // Hourly: time → icon → temp (no section header — band height is list + padding only).
    readonly property real hourlyCardH: Math.max(74, Math.round(78 * s))
    readonly property real hourlyBandH: hourlyCardH + padS * 2 + Math.max(4, Math.round(6 * s))

    readonly property var w: WeatherService.weather

    /// Event Horizon dash: panel fills follow SettingsData.desktopEventHorizonChromeBackgroundOpacity.
    readonly property real _ehChromeBg: SettingsData.desktopEventHorizonChromeBackgroundOpacity
    function bgA(a) {
        return Math.min(1, Math.max(0, a * _ehChromeBg))
    }

    function fmtVis(m) {
        if (m === undefined || m === null || isNaN(m)) return "—"
        if (m >= 1000) return (Math.round(m / 100) / 10).toFixed(1) + " km"
        return Math.round(m) + " m"
    }

    Component.onCompleted:   WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    // ── Stat tile ─────────────────────────────────────────────────────────
    component StatMini: Rectangle {
        id: cell
        property real   s:        1
        property string label:    ""
        property string value:    ""
        property string iconName: ""

        radius: 6
        clip:   true
        color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, root.bgA(0.12))
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.22))
        border.width: 1

        readonly property real innerPad: Math.max(4, Math.round(5 * cell.s))
        readonly property real iconSz:   Math.max(15, Math.round(18 * cell.s))

        // Icon + text (label) + stats (value) — one horizontal row; label elides, value keeps width.
        RowLayout {
            anchors.fill: parent
            anchors.margins: cell.innerPad
            spacing: Math.max(Theme.spacingXS + 1, Math.round(5 * cell.s))

            EHIcon {
                Layout.alignment: Qt.AlignVCenter
                name: cell.iconName
                size: cell.iconSz
                color: Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: cell.label
                font.pixelSize: Math.max(8, Math.round(10 * cell.s))
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                text: cell.value
                font.pixelSize: Math.max(10, Math.round(12 * cell.s))
                font.weight: 600
                color: Theme.surfaceText
                maximumLineCount: 1
                elide: Text.ElideNone
            }
        }
    }

    // ── Root column ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing:      root.gap

        // Nav
        RowLayout {
            Layout.fillWidth:     true
            Layout.preferredHeight: root.navH
            Layout.maximumHeight:   root.navH
            spacing: Theme.spacingS

            EHActionButton {
                iconName:  "refresh"
                iconSize:  Theme.iconSize - 2
                iconColor: Theme.surfaceVariantText
                enabled:   w.available
                onClicked: WeatherService.forceRefresh()
            }
            StyledText {
                Layout.fillWidth:    true
                horizontalAlignment: Text.AlignHCenter
                text:                w.city || "Weather"
                font.pixelSize:      Math.round(Theme.fontSizeMedium * s)
                font.weight:         Font.DemiBold
                color:               Theme.surfaceText
                elide:               Text.ElideRight
            }
            EHActionButton {
                iconName:  "thermostat"
                iconSize:  Theme.iconSize - 2
                iconColor: Theme.surfaceVariantText
                onClicked: SettingsData.setTemperatureUnit(!SettingsData.useFahrenheit)
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth:     true
            Layout.preferredHeight: 1
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.18))
        }

        // Unavailable
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible: !w.available

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM
                width: Math.min(parent.width, 320)

                EHIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name:  w.loading ? "cloud_sync" : "cloud_off"
                    size:  Math.round(40 * s)
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width:               parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode:            Text.WordWrap
                    text: w.loading ? "Loading weather…"
                                    : "Weather unavailable. Check location in Settings."
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.surfaceVariantText
                }
            }
        }

        // Available
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:  w.available
            spacing:  root.gap

            // Hero
            Rectangle {
                Layout.fillWidth:     true
                Layout.preferredHeight: root.heroH
                Layout.maximumHeight:   root.heroH
                radius: 6
                clip:   true
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, root.bgA(0.10))
                border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.bgA(0.18))
                border.width: 1

                Item {
                    anchors.left:         parent.left
                    anchors.right:        parent.right
                    anchors.top:          parent.top
                    anchors.bottom:       parent.bottom
                    anchors.leftMargin:   root.padM
                    anchors.rightMargin:  root.padM
                    anchors.topMargin:    root.padM
                    anchors.bottomMargin: root.padM + 10

                    RowLayout {
                        anchors.centerIn: parent
                        width:   Math.min(parent.width, implicitWidth)
                        spacing: Math.round(16 * s)

                        EHIcon {
                            name:  WeatherService.getWeatherIcon(w.wCode, w.isDay)
                            size:  Math.round(46 * s)
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: Math.round(3 * s)
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: Math.min(260, Math.floor(parent.parent.width * 0.62))

                            RowLayout {
                                spacing: Math.round(4 * s)
                                StyledText {
                                    text:           (SettingsData.useFahrenheit ? w.tempF : w.temp) + "°"
                                    font.pixelSize: Math.round(32 * s)
                                    font.weight:    Font.Light
                                    color:          Theme.surfaceText
                                }
                                StyledText {
                                    text:           SettingsData.useFahrenheit ? "F" : "C"
                                    font.pixelSize: Math.round(12 * s)
                                    color:          Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Math.round(5 * s)
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text:             WeatherService.getWeatherCondition(w.wCode)
                                font.pixelSize:   Math.round(Theme.fontSizeSmall * s)
                                color:            Theme.surfaceVariantText
                                wrapMode:         Text.WordWrap
                                maximumLineCount: 2
                                elide:            Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Stats grid — narrower card centered so it lines up with the hero block above.
            Item {
                Layout.fillWidth:     true
                Layout.preferredHeight: root.statsH
                Layout.maximumHeight:   root.statsH

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 2
                    width: Math.min(parent.width - 8, Math.floor(parent.width * 0.92))
                    height: root.statsH
                    radius: 6
                    clip:   true
                    color:  "transparent"
                    border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.bgA(0.18))
                    border.width: 1

                    GridLayout {
                        anchors.fill:    parent
                        anchors.margins: root.padS
                        rowSpacing:      root.gap
                        columnSpacing:   root.gap
                        columns: 3
                        rows:    2

                        StatMini {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "Humidity"
                        value:    w.humidity !== undefined ? (w.humidity + "%") : "—"
                        iconName: "humidity_mid"
                    }
                    StatMini {
                        Layout.fillWidth:     true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "Wind"
                        value:    w.wind || "—"
                        iconName: "air"
                    }
                    StatMini {
                        Layout.fillWidth:     true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "Feels"
                        value:    (SettingsData.useFahrenheit ? w.feelsLikeF : w.feelsLike) !== undefined
                                  ? ((SettingsData.useFahrenheit ? w.feelsLikeF : w.feelsLike) + "°") : "—"
                        iconName: "device_thermostat"
                    }
                    StatMini {
                        Layout.fillWidth:     true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "UV"
                        value:    w.uv !== undefined ? String(w.uv) : "—"
                        iconName: "wb_sunny"
                    }
                    StatMini {
                        Layout.fillWidth:     true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "Pressure"
                        value:    w.pressure !== undefined && w.pressure !== null
                                  ? (w.pressure + " hPa") : "—"
                        iconName: "compress"
                    }
                    StatMini {
                        Layout.fillWidth:     true
                        Layout.preferredHeight: root.statCellH
                        s: root.s; label: "Visibility"
                        value:    root.fmtVis(w.visibility)
                        iconName: "visibility"
                    }
                    }
                }
            }

            Item {
                Layout.fillWidth:     true
                Layout.preferredHeight: 7
            }

            // Hourly band (no heading — horizontal strip only)
            Rectangle {
                Layout.fillWidth:     true
                Layout.preferredHeight: root.hourlyBandH
                Layout.maximumHeight:   root.hourlyBandH
                radius: 6
                clip:   true
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, root.bgA(0.08))
                border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.bgA(0.14))
                border.width: 1

                ListView {
                        id: hourList
                        anchors {
                            fill:         parent
                            leftMargin:   root.padS
                            rightMargin:  root.padS
                            topMargin:    root.padS
                            bottomMargin: root.padS
                        }
                        orientation: ListView.Horizontal
                        spacing: Math.max(6, Math.round(8 * s))
                        clip:    true
                        model:   w.hourly && w.hourly.length > 0 ? Math.min(24, w.hourly.length) : 0

                        delegate: Rectangle {
                            required property int index
                            width:  Math.round(56 * s)
                            // height fills the list which equals hourlyCardH
                            height: hourList.height
                            radius: 6
                            clip:   true
                            color:  index === 0
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.14))
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, root.bgA(0.18))
                            border.color: index === 0 ? Theme.primary
                                                      : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.bgA(0.25))
                            border.width: index === 0 ? 2 : 1

                            property var h: w.hourly[index]

                            ColumnLayout {
                                anchors.fill:    parent
                                anchors.margins: Math.max(4, Math.round(5 * s))
                                spacing: Math.max(1, Math.round(2 * s))

                                // Time
                                StyledText {
                                    Layout.fillWidth:    true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: {
                                        if (index === 0) return "Now"
                                        if (!h || !h.time) return "—"
                                        try {
                                            const d = new Date(h.time)
                                            if (isNaN(d.getTime())) return "—"
                                            if (SettingsData.use24HourClock)
                                                return String(d.getHours()).padStart(2, "0") + ":00"
                                            const hr   = d.getHours()
                                            const disp = hr === 0 ? 12 : (hr > 12 ? hr - 12 : hr)
                                            return disp + (hr >= 12 ? "p" : "a")
                                        } catch (e) { return "—" }
                                    }
                                    font.pixelSize: Math.max(9, Math.round(10 * s))
                                    font.weight:    index === 0 ? 600 : Font.Normal
                                    color:          index === 0 ? Theme.primary : Theme.surfaceVariantText
                                }

                                // Icon — fills space between time and temp, icon centered in that band
                                Item {
                                    Layout.fillWidth:  true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: Math.max(20, Math.round(24 * s))
                                    EHIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: 2
                                        name:  h ? WeatherService.getWeatherIcon(h.wCode, h.isDay) : "cloud"
                                        size:  Math.max(20, Math.round(22 * s))
                                        color: index === 0 ? Theme.primary : Theme.surfaceText
                                    }
                                }

                                // Temp
                                StyledText {
                                    Layout.fillWidth:    true
                                    horizontalAlignment: Text.AlignHCenter
                                    text:           h ? ((SettingsData.useFahrenheit ? h.tempF : h.temp) + "°") : "—"
                                    font.pixelSize: Math.max(10, Math.round(12 * s))
                                    font.weight:    Font.Medium
                                    color:          Theme.surfaceText
                                }
                            }
                        }
                    }
            }

            // Forecast — takes all remaining space (no heading)
            Rectangle {
                Layout.fillWidth:    true
                Layout.fillHeight:   true
                Layout.minimumHeight: Math.round(80 * s)
                Layout.topMargin:    2
                radius: 6
                clip:   true
                color:  "transparent"
                border.color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, root.bgA(0.18))
                border.width: 1

                ListView {
                    id: forecastLv
                        anchors.fill:    parent
                        anchors.margins: 1
                        spacing: 0
                        clip:    true
                        model:   w.forecast && w.forecast.length > 0 ? Math.min(7, w.forecast.length) : 0

                        // Distribute height evenly across rows
                        readonly property real rowH: Math.max(32, Math.floor(
                            (forecastLv.height - Math.max(0, forecastLv.count - 1))
                            / Math.max(1, forecastLv.count)
                        ))
                        readonly property real hPad: root.padS
                        readonly property real dayW: Math.round(70 * s)

                        delegate: Column {
                            required property int index
                            width: forecastLv.width
                            readonly property var day: w.forecast[index]

                            Rectangle {
                                width:  parent.width
                                height: forecastLv.rowH
                                radius: index === 0 ? 6 : 0
                                color:  index === 0
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.bgA(0.08))
                                        : "transparent"

                                RowLayout {
                                    anchors.fill:        parent
                                    anchors.leftMargin:  forecastLv.hPad
                                    anchors.rightMargin: forecastLv.hPad
                                    anchors.topMargin:   Math.max(5, Math.round(7 * s))
                                    anchors.bottomMargin: Math.max(5, Math.round(7 * s))
                                    spacing: Theme.spacingS

                                    StyledText {
                                        Layout.preferredWidth: forecastLv.dayW
                                        Layout.maximumWidth:   forecastLv.dayW
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text:           day ? day.day : "—"
                                        font.pixelSize: Math.max(10, Math.round(Theme.fontSizeSmall * s))
                                        font.weight:    index === 0 ? Font.DemiBold : Font.Medium
                                        color:          index === 0 ? Theme.primary : Theme.surfaceText
                                        elide:          Text.ElideRight
                                    }

                                    EHIcon {
                                        name:  day ? WeatherService.getWeatherIcon(day.wCode, true) : "cloud"
                                        size:  Math.max(16, Math.round(18 * s))
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.topMargin: 1
                                    }

                                    StyledText {
                                        text: day
                                              ? ((SettingsData.useFahrenheit ? day.tempMaxF : day.tempMax) + "°/"
                                                 + (SettingsData.useFahrenheit ? day.tempMinF : day.tempMin) + "°")
                                              : "—"
                                        font.pixelSize: Math.max(10, Math.round(Theme.fontSizeSmall * s))
                                        font.weight:    Font.Medium
                                        color:          Theme.surfaceText
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        Layout.preferredWidth: Math.round(44 * s)
                                        spacing: Theme.spacingXXS
                                        visible: day && day.precipitationProbability > 0
                                        Layout.alignment: Qt.AlignVCenter

                                        EHIcon {
                                            name:  "water_drop"
                                            size:  Math.max(10, Math.round(12 * s))
                                            color: Qt.rgba(0.45, 0.72, 1.0, 0.85)
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        StyledText {
                                            text:           day ? (day.precipitationProbability + "%") : ""
                                            font.pixelSize: Math.max(9, Math.round(10 * s))
                                            color:          Theme.surfaceVariantText
                                            Layout.alignment: Qt.AlignVCenter
                                            verticalAlignment: Text.AlignVCenter
                                            Layout.topMargin: -1
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width:   parent.width
                                height:  1
                                visible: index < forecastLv.count - 1
                                color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.bgA(0.22))
                            }
                        }
                    }
            }
        }
    }
}
