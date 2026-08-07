import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: opacityTab

    property var parentModal: null

    EHFlickable {
        anchors.fill:       parent
        anchors.topMargin:  Theme.spacingL
        clip:               true
        contentHeight:      mainColumn.implicitHeight + Theme.spacingL
        contentWidth:       width

        Column {
            id:      mainColumn
            width:   parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // OPACITY
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: transparencySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: transparencySection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    property bool transparencyAdvanced: SettingsData.opacityAdvancedControls

                    function _clamp01(v) { return Math.max(0, Math.min(1, v)) }
                    function _norm(v, fallback) {
                        const n = Number(v)
                        if (!Number.isFinite(n)) return fallback
                        // Some settings loaders historically stored 0-100; SettingsData normalizes most,
                        // but keep this guard so the UI never breaks if a value slips through.
                        const scaled = n > 1 ? (n / 100) : n
                        return _clamp01(scaled)
                    }

                    property real combinedTransparencyLevel: {
                        const values = [
                            _norm(SettingsData.topBarWidgetTransparency, 0.85),
                            _norm(SettingsData.popupTransparency, 0.92),
                            _norm(SettingsData.modalTransparency, 0.85),
                            _norm(SettingsData.notificationTransparency, 0.92),
                            _norm(SettingsData.controlCenterTransparency, 0.88),
                            _norm(SettingsData.appDrawerTransparency, 0.90),
                            _norm(SettingsData.spotlightTransparency, 0.93),
                            _norm(SettingsData.controlCenterWidgetBackgroundOpacity, 0.60),
                            _norm(SettingsData.weatherPopupTransparency, 0.95),
                            _norm(SettingsData.weatherPopupWidgetBackgroundOpacity, 0.60),
                            _norm(SettingsData.calendarPopupTransparency, 0.95),
                            _norm(SettingsData.calendarPopupWidgetBackgroundOpacity, 0.60),
                            _norm(SettingsData.mediaPopupTransparency, 0.95),
                            _norm(SettingsData.batteryPopupTransparency, 0.92)
                        ]
                        var sum = 0
                        for (var i = 0; i < values.length; ++i) sum += values[i]
                        return values.length ? sum / values.length : 0
                    }

                    function setCombinedTransparencyLevel(level) {
                        const clamped = Math.max(0, Math.min(1, level))
                        SettingsData.setTopBarWidgetTransparency(clamped)
                        SettingsData.setPopupTransparency(clamped)
                        SettingsData.setModalTransparency(clamped)
                        SettingsData.setNotificationTransparency(clamped)
                        SettingsData.setControlCenterTransparency(clamped)
                        SettingsData.setAppDrawerTransparency(clamped)
                        SettingsData.setSpotlightTransparency(clamped)
                        SettingsData.setControlCenterWidgetBackgroundOpacity(clamped)
                        SettingsData.setWeatherPopupTransparency(clamped)
                        SettingsData.setWeatherPopupWidgetBackgroundOpacity(clamped)
                        SettingsData.setCalendarPopupTransparency(clamped)
                        SettingsData.setCalendarPopupWidgetBackgroundOpacity(clamped)
                        SettingsData.setMediaPopupTransparency(clamped)
                        SettingsData.setBatteryPopupTransparency(clamped)
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon {
                            name: "opacity"; size: Theme.iconSize; color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Opacity"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium
                            color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text:      "Control the opacity levels of various UI elements"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:  Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Advanced controls"
                        description: "Show individual opacity controls for each UI element"
                        checked:     transparencySection.transparencyAdvanced
                        onToggled:   checked => {
                            transparencySection.transparencyAdvanced = checked
                            SettingsData.opacityAdvancedControls    = checked
                            SettingsData.saveSettings()
                        }
                    }

                    // ── Simple mode ───────────────────────────────────────────
                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        visible: !transparencySection.transparencyAdvanced

                        StyledText {
                            text: "Overall Opacity"; font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium; color: Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round(transparencySection.combinedTransparencyLevel * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                transparencySection.setCombinedTransparencyLevel(newValue / 100)
                            }
                        }
                    }

                    // ── Advanced mode ─────────────────────────────────────────
                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: transparencySection.transparencyAdvanced

                        // Top bar widgets
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Top Bar Widget Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.topBarWidgetTransparency, 0.85) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setTopBarWidgetTransparency(newValue / 100) } }
                        }
                        // Popups
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Popup Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.popupTransparency, 0.92) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setPopupTransparency(newValue / 100) } }
                        }
                        // Modal
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Modal Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.modalTransparency, 0.85) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setModalTransparency(newValue / 100) } }
                        }
                        EHToggle {
                            width: parent.width
                            text: "Settings Modal Dimming"
                            description: "Enable background dimming when settings modal is open"
                            checked: SettingsData.settingsModalDimmingEnabled
                            onToggled: (checked) => { SettingsData.settingsModalDimmingEnabled = checked; SettingsData.saveSettings() }
                        }
                        // Notifications
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Notification Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.notificationTransparency, 0.92) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setNotificationTransparency(newValue / 100) } }
                        }
                        // Control center
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Control Center Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.controlCenterTransparency, 0.88) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setControlCenterTransparency(newValue / 100) } }
                        }
                        // App drawer
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "App Drawer Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.appDrawerTransparency, 0.90) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setAppDrawerTransparency(newValue / 100) } }
                        }
                        // Spotlight
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Spotlight Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.spotlightTransparency, 0.93) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setSpotlightTransparency(newValue / 100) } }
                        }
                        // CC widget bg
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Control Center Widget Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.controlCenterWidgetBackgroundOpacity, 0.60) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setControlCenterWidgetBackgroundOpacity(newValue / 100) } }
                        }
                        // Weather popup
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Weather Popup Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.weatherPopupTransparency, 0.95) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setWeatherPopupTransparency(newValue / 100) } }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Weather Popup Widget Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.weatherPopupWidgetBackgroundOpacity * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setWeatherPopupWidgetBackgroundOpacity(newValue / 100) } }
                        }

                        // ── Calendar Popup opacity ────────────────────────────
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Calendar Popup Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.calendarPopupTransparency, 0.95) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setCalendarPopupTransparency(newValue / 100) } }
                        }
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Calendar Popup Widget Background Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.calendarPopupWidgetBackgroundOpacity * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setCalendarPopupWidgetBackgroundOpacity(newValue / 100) } }
                        }

                        // ── Media Popup opacity ───────────────────────────────
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Media Popup Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round(transparencySection._norm(SettingsData.mediaPopupTransparency, 0.95) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setMediaPopupTransparency(newValue / 100) } }
                        }

                        // ── Fastfetch opacity ─────────────────────────────────
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Fastfetch Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round((SettingsData.fastfetchPopupTransparency ?? 0.92) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setFastfetchPopupTransparency(newValue / 100) } }
                        }

                        // ── Battery opacity ───────────────────────────────────
                        Column { width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Battery Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: Math.round((SettingsData.batteryPopupTransparency ?? 0.92) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: newValue => { SettingsData.setBatteryPopupTransparency(newValue / 100) } }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // BATTERY BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: batteryBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: batteryBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "battery_full"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Battery Border"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text:           "Customise the border of the battery widget"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the battery widget"
                        checked:     SettingsData.batteryPopupBorderEnabled
                        onToggled:   checked => SettingsData.setBatteryPopupBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.batteryPopupDynamicBorderColors
                        onToggled:   checked => SettingsData.setBatteryPopupDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.batteryPopupBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.batteryPopupBorderThickness ?? 2
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setBatteryPopupBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.batteryPopupBorderEnabled && !SettingsData.batteryPopupDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.batteryPopupBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setBatteryPopupBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // MEDIA POPUP BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: mediaBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: mediaBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon {
                            name: "music_note"; size: Theme.iconSize; color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Media Popup Border"; font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text:           "Customise the border of the media popup"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the media popup"
                        checked:     SettingsData.mediaPopupBorderEnabled
                        onToggled:   checked => SettingsData.setMediaPopupBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.mediaPopupDynamicBorderColors
                        onToggled:   checked => SettingsData.setMediaPopupDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.mediaPopupBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Thickness"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.mediaPopupBorderThickness ?? 2
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setMediaPopupBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.mediaPopupBorderEnabled && !SettingsData.mediaPopupDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Opacity"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.mediaPopupBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setMediaPopupBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // FASTFETCH BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: fastfetchBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: fastfetchBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon {
                            name: "info"; size: Theme.iconSize; color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Fastfetch Border"; font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text:           "Customise the border of the Fastfetch widget"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the Fastfetch widget"
                        checked:     SettingsData.fastfetchPopupBorderEnabled
                        onToggled:   checked => SettingsData.setFastfetchPopupBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.fastfetchPopupDynamicBorderColors
                        onToggled:   checked => SettingsData.setFastfetchPopupDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.fastfetchPopupBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Thickness"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.fastfetchPopupBorderThickness ?? 2
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setFastfetchPopupBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.fastfetchPopupBorderEnabled && !SettingsData.fastfetchPopupDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Opacity"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.fastfetchPopupBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setFastfetchPopupBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CALENDAR POPUP BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: calendarBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: calendarBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon {
                            name: "calendar_today"; size: Theme.iconSize; color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "Calendar Popup Border"; font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium; color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text:           "Customise the border of the calendar popup"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    // Enable border toggle
                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the calendar popup"
                        checked:     SettingsData.calendarPopupBorderEnabled
                        onToggled:   checked => {
                            SettingsData.calendarPopupBorderEnabled = checked
                            SettingsData.saveSettings()
                        }
                    }

                    // Dynamic (theme-colour) border toggle
                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.calendarPopupDynamicBorderColors
                        onToggled:   checked => {
                            SettingsData.calendarPopupDynamicBorderColors = checked
                            SettingsData.saveSettings()
                        }
                    }

                    // Border thickness
                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.calendarPopupBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Thickness"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.calendarPopupBorderThickness ?? 2
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.calendarPopupBorderThickness = newValue
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    // Border opacity (only meaningful when dynamic is OFF)
                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.calendarPopupBorderEnabled && !SettingsData.calendarPopupDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText {
                            text:           "Border Opacity"
                            font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                            color:          Theme.surfaceText
                        }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.calendarPopupBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => {
                                SettingsData.calendarPopupBorderOpacity = newValue / 100
                                SettingsData.saveSettings()
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // APP DRAWER BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: appDrawerBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: appDrawerBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "apps"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "App Drawer Border"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text:           "Customise the border of the app drawer (Dock / TaskBar / MiniPanel / TopBar)"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the app drawer"
                        checked:     SettingsData.appDrawerBorderEnabled
                        onToggled:   checked => SettingsData.setAppDrawerBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.appDrawerDynamicBorderColors
                        onToggled:   checked => SettingsData.setAppDrawerDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.appDrawerBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.appDrawerBorderThickness ?? 2
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setAppDrawerBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.appDrawerBorderEnabled && !SettingsData.appDrawerDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.appDrawerBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setAppDrawerBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CONTROL CENTER BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: controlCenterBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: controlCenterBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "control_camera"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Control Center Border"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text:           "Customise the border of the control center"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the control center"
                        checked:     SettingsData.controlCenterBorderEnabled
                        onToggled:   checked => SettingsData.setControlCenterBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.controlCenterDynamicBorderColors
                        onToggled:   checked => SettingsData.setControlCenterDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.controlCenterBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.controlCenterBorderThickness ?? 1
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setControlCenterBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.controlCenterBorderEnabled && !SettingsData.controlCenterDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.controlCenterBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setControlCenterBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // VOLUME MIXER POPUP BORDER SETTINGS
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width:  parent.width
                height: volumeMixerBorderSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: volumeMixerBorderSection
                    anchors.left:    parent.left
                    anchors.right:   parent.right
                    anchors.top:     parent.top
                    anchors.margins: Theme.spacingL
                    spacing:         Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "volume_up"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Volume Mixer Border"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text:           "Customise the border of the volume mixer popup"
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        wrapMode:       Text.WordWrap; width: parent.width
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Show border"
                        description: "Draw a border around the volume mixer popup"
                        checked:     SettingsData.dockVolumePopupBorderEnabled
                        onToggled:   checked => SettingsData.setDockVolumePopupBorderEnabled(checked)
                    }

                    EHToggle {
                        width:       parent.width
                        text:        "Dynamic border colour"
                        description: "Use the current accent colour for the border instead of a fixed colour"
                        checked:     SettingsData.dockVolumePopupDynamicBorderColors
                        onToggled:   checked => SettingsData.setDockVolumePopupDynamicBorderColors(checked)
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.dockVolumePopupBorderEnabled
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Thickness"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        SettingsData.dockVolumePopupBorderThickness ?? 1
                            minimum: 1; maximum: 8; unit: "px"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockVolumePopupBorderThickness(newValue)
                        }
                    }

                    Column {
                        width:   parent.width
                        spacing: Theme.spacingS
                        enabled: SettingsData.dockVolumePopupBorderEnabled && !SettingsData.dockVolumePopupDynamicBorderColors
                        opacity: enabled ? 1 : 0.45

                        StyledText { text: "Border Opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider {
                            width: parent.width; height: 24
                            value:        Math.round((SettingsData.dockVolumePopupBorderOpacity ?? 0.30) * 100)
                            minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => SettingsData.setDockVolumePopupBorderOpacity(newValue / 100)
                        }
                    }
                }
            }

        } // mainColumn
    } // EHFlickable
}
