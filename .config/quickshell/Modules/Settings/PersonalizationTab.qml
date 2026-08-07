import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: personalizationTab

    property var parentModal: null
    property string selectedMonitorName: {
        var screens = Quickshell.screens
        return screens.length > 0 ? screens[0].name : ""
    }

    Component.onCompleted: {
        WallpaperCyclingService.cyclingActive
    }

    EHFlickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: 0
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingL
            topPadding: Theme.spacingL
            bottomPadding: Theme.spacingL

            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: dynamicThemeSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dynamicThemeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "palette"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            StyledText {
                                text: "Dynamic Theming"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically extract colors from wallpaper"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        EHToggle {
                            id: toggle
                            checked: Theme.wallpaperPath !== "" && Theme.currentTheme === Theme.dynamic
                            enabled: ToastService.wallpaperErrorStatus !== "matugen_missing" && Theme.wallpaperPath !== ""
                            onToggled: toggled => {
                                           if (toggled)
                                           Theme.switchTheme(Theme.dynamic)
                                           else
                                           Theme.switchTheme("blue")
                                       }
                        }
                    }

                    StyledText {
                        text: "matugen not detected - dynamic theming unavailable"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        visible: ToastService.wallpaperErrorStatus === "matugen_missing"
                        width: parent.width
                        leftPadding: Theme.iconSize + Theme.spacingM
                    }

                }
            }


            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: displaySection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: displaySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Display Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Light Mode"
                        description: "Use light theme instead of dark theme"
                        checked: SessionData.isLightMode
                        onToggled: checked => {
                                       Theme.setLightMode(checked)
                                   }
                    }


                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    EHToggle {
                        id: nightModeToggle

                        width: parent.width
                        text: "Night Mode"
                        description: "Apply warm color temperature to reduce eye strain. Use automation settings below to control when it activates."
                        checked: DisplayService.nightModeEnabled
                        onToggled: checked => {
                                       DisplayService.toggleNightMode()
                                   }

                        Connections {
                            function onNightModeEnabledChanged() {
                                nightModeToggle.checked = DisplayService.nightModeEnabled
                            }

                            target: DisplayService
                        }
                    }

                    EHDropdown {
                        width: parent.width
                        text: "Temperature"
                        description: "Color temperature for night mode"
                        currentValue: SessionData.nightModeTemperature + "K"
                        options: {
                            var temps = []
                            for (var i = 2500; i <= 6000; i += 500) {
                                temps.push(i + "K")
                            }
                            return temps
                        }
                        onValueChanged: value => {
                                            var temp = parseInt(value.replace("K", ""))
                                            SessionData.setNightModeTemperature(temp)
                                        }
                    }

                    EHToggle {
                        id: automaticToggle
                        width: parent.width
                        text: "Automatic Control"
                        description: "Only adjust gamma based on time or location rules."
                        checked: SessionData.nightModeAutoEnabled
                        onToggled: checked => {
                                       if (checked && !DisplayService.nightModeEnabled) {
                                           DisplayService.toggleNightMode()
                                       } else if (!checked && DisplayService.nightModeEnabled) {
                                           DisplayService.toggleNightMode()
                                       }
                                       SessionData.setNightModeAutoEnabled(checked)
                                   }

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticToggle.checked = SessionData.nightModeAutoEnabled
                            }
                        }
                    }

                    Column {
                        id: automaticSettings
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SessionData.nightModeAutoEnabled

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticSettings.visible = SessionData.nightModeAutoEnabled
                            }
                        }

                        // Mode Selection Section
                        StyledRect {
                            width: parent.width
                            height: modeSelectionColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            border.width: 1

                            Column {
                                id: modeSelectionColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                StyledText {
                                    text: "Automation Mode"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: "Choose how night mode should be automatically controlled"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                EHTabBar {
                                    id: modeTabBarNight
                                    width: parent.width
                                    height: 45
                                    model: [{
                                            "text": "Time",
                                            "icon": "access_time"
                                        }, {
                                            "text": "Location",
                                            "icon": "place"
                                        }]

                                    Component.onCompleted: {
                                        currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0
                                        Qt.callLater(updateIndicator)
                                    }

                                    onTabClicked: index => {
                                                      DisplayService.setNightModeAutomationMode(index === 1 ? "location" : "time")
                                                      currentIndex = index
                                                  }

                                    Connections {
                                        target: SessionData
                                        function onNightModeAutoModeChanged() {
                                            modeTabBarNight.currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0
                                            Qt.callLater(modeTabBarNight.updateIndicator)
                                        }
                                    }
                                }
                            }
                        }

                        // Time Settings Section
                        StyledRect {
                            width: parent.width
                            height: timeSettingsColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            border.width: 1
                            visible: SessionData.nightModeAutoMode === "time"

                            Column {
                                id: timeSettingsColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    EHIcon {
                                        name: "access_time"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: "Time Schedule"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: "Set specific times for night mode to activate and deactivate"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                // Time settings with separated hour and minute sections
                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    // Start Time Section
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        StyledText {
                                            text: "Start Time"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        // Hour dropdown
                                        Column {
                                            spacing: Theme.spacingXS
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                text: "Hour"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                                width: 70
                                            }

                                            EHDropdown {
                                                width: 70
                                                height: 44
                                                text: ""
                                                currentValue: SessionData.nightModeStartHour.toString()
                                                options: {
                                                    var hours = []
                                                    for (var i = 0; i < 24; i++) {
                                                        hours.push(i.toString())
                                                    }
                                                    return hours
                                                }
                                                onValueChanged: value => {
                                                                    SessionData.setNightModeStartHour(parseInt(value))
                                                                }
                                            }
                                        }

                                        // 16px spacing between hour and minute
                                        Item {
                                            width: 28
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Minute dropdown
                                        Column {
                                            spacing: Theme.spacingXS
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                text: "Minute"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                                width: 70
                                            }

                                            EHDropdown {
                                                width: 70
                                                height: 44
                                                text: ""
                                                currentValue: SessionData.nightModeStartMinute.toString().padStart(2, '0')
                                                options: {
                                                    var minutes = []
                                                    for (var i = 0; i < 60; i += 5) {
                                                        minutes.push(i.toString().padStart(2, '0'))
                                                    }
                                                    return minutes
                                                }
                                                onValueChanged: value => {
                                                                    SessionData.setNightModeStartMinute(parseInt(value))
                                                                }
                                            }
                                        }
                                    }

                                    // End Time Section
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        StyledText {
                                            text: "End Time"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        // Hour dropdown
                                        Column {
                                            spacing: Theme.spacingXS
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                text: "Hour"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                                width: 70
                                            }

                                            EHDropdown {
                                                width: 70
                                                height: 44
                                                text: ""
                                                currentValue: SessionData.nightModeEndHour.toString()
                                                options: {
                                                    var hours = []
                                                    for (var i = 0; i < 24; i++) {
                                                        hours.push(i.toString())
                                                    }
                                                    return hours
                                                }
                                                onValueChanged: value => {
                                                                    SessionData.setNightModeEndHour(parseInt(value))
                                                                }
                                            }
                                        }

                                        // 16px spacing between hour and minute
                                        Item {
                                            width: 28
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Minute dropdown
                                        Column {
                                            spacing: Theme.spacingXS
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                text: "Minute"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                                horizontalAlignment: Text.AlignHCenter
                                                width: 70
                                            }

                                            EHDropdown {
                                                width: 70
                                                height: 44
                                                text: ""
                                                currentValue: SessionData.nightModeEndMinute.toString().padStart(2, '0')
                                                options: {
                                                    var minutes = []
                                                    for (var i = 0; i < 60; i += 5) {
                                                        minutes.push(i.toString().padStart(2, '0'))
                                                    }
                                                    return minutes
                                                }
                                                onValueChanged: value => {
                                                                    SessionData.setNightModeEndMinute(parseInt(value))
                                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Location Settings Section
                        StyledRect {
                            width: parent.width
                            height: locationSettingsColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            border.width: 1
                            visible: SessionData.nightModeAutoMode === "location"

                            Column {
                                id: locationSettingsColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    EHIcon {
                                        name: "place"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: "Location Settings"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: "Configure how your location is determined for sunrise/sunset calculations"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }
                                    }
                                }

                                EHToggle {
                                    width: parent.width
                                    text: "Auto-location"
                                    description: DisplayService.geoclueAvailable ? "Use automatic location detection (geoclue2)" : "Geoclue service not running - cannot auto-detect location"
                                    checked: SessionData.nightModeLocationProvider === "geoclue2"
                                    enabled: DisplayService.geoclueAvailable
                                    onToggled: checked => {
                                                   if (checked && DisplayService.geoclueAvailable) {
                                                       SessionData.setNightModeLocationProvider("geoclue2")
                                                       SessionData.setLatitude(0.0)
                                                       SessionData.setLongitude(0.0)
                                                   } else {
                                                       SessionData.setNightModeLocationProvider("")
                                                   }
                                               }
                                }

                                // Manual coordinates section
                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    visible: SessionData.nightModeLocationProvider !== "geoclue2"

                                    StyledText {
                                        text: "Manual Coordinates"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "Enter your latitude and longitude coordinates manually"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }

                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: "Latitude"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                            }

                                            EHTextField {
                                                Layout.fillWidth: true
                                                height: 44
                                                text: SessionData.latitude.toString()
                                                placeholderText: "0.0"
                                                onTextChanged: {
                                                    const lat = parseFloat(text) || 0.0
                                                    if (lat >= -90 && lat <= 90) {
                                                        SessionData.setLatitude(lat)
                                                    }
                                                }
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: "Longitude"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceVariantText
                                            }

                                            EHTextField {
                                                Layout.fillWidth: true
                                                height: 44
                                                text: SessionData.longitude.toString()
                                                placeholderText: "0.0"
                                                onTextChanged: {
                                                    const lon = parseFloat(text) || 0.0
                                                    if (lon >= -180 && lon <= 180) {
                                                        SessionData.setLongitude(lon)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: "Uses sunrise/sunset times to automatically adjust night mode based on your location."
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }


            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: lockScreenSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: lockScreenSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "lock"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Lock Screen"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Show Power Actions"
                        description: "Show power, restart, and logout buttons on the lock screen"
                        checked: SettingsData.lockScreenShowPowerActions
                        onToggled: checked => {
                                       SettingsData.setLockScreenShowPowerActions(checked)
                                   }
                    }
                }
            }

            // UI Scale Section
            StyledRect {
                width: Math.min(parent.width * 1.2, parent.parent ? parent.parent.width - 48 : parent.width * 1.2)
                height: uiScaleSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: uiScaleSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "fullscreen"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            spacing: Theme.spacingXS
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            StyledText {
                                text: "UI Scale"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Adjust the scale of UI elements (80% - 120%)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        StyledText {
                            text: Math.round(SettingsData.uiScaleRatio * 100) + "%"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    EHSlider {
                        width: parent.width
                        minimum: 80
                        maximum: 120
                        value: SettingsData.uiScaleRatio * 100
                        unit: "%"
                        onSliderValueChanged: value => {
                            SettingsData.uiScaleRatio = value / 100
                        }
                    }
                }
            }
        }
    }

}
