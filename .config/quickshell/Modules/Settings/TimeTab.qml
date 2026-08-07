import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: timeTab

    property var filteredTimezones: []
    property string timezoneSearchText: ""

    property int formatUpdateTrigger: 0

    Component.onCompleted: {
        TimeService.refreshStatus()
        TimeService.listTimezones()
        filteredTimezones = TimeService.availableTimezones
    }

    Connections {
        target: TimeService
        function onAvailableTimezonesChanged() { updateFilteredTimezones() }
        function onCurrentTimezoneChanged() { SettingsData.setSystemTimezone(TimeService.currentTimezone) }
    }

    Connections {
        target: SettingsData
        function onUse24HourClockChanged()      { formatUpdateTrigger++ }
        function onShowAmPmIn24HourChanged()    { formatUpdateTrigger++ }
        function onDockClockShowFullDateChanged(){ formatUpdateTrigger++ }
        function onDockClockShowSecondsChanged() { formatUpdateTrigger++ }
        function onDockClockUse12HourChanged()  { formatUpdateTrigger++ }
        function onDockClockShowAmPmChanged()   { formatUpdateTrigger++ }
        function onDockClockFontSizeChanged()   { formatUpdateTrigger++ }
    }

    function updateFilteredTimezones() {
        if (!timezoneSearchText || timezoneSearchText.length === 0) {
            filteredTimezones = TimeService.availableTimezones
        } else {
            const search = timezoneSearchText.toLowerCase()
            filteredTimezones = TimeService.availableTimezones.filter(tz => tz.toLowerCase().includes(search))
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // CURRENT TIME
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: currentTimeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: currentTimeSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "access_time"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Current Time"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText {
                                text: {
                                    timeTab.formatUpdateTrigger
                                    const now = new Date()
                                    if (SettingsData.use24HourClock) {
                                        if (SettingsData.showAmPmIn24Hour) {
                                            const h = now.getHours(); const m = now.getMinutes()
                                            const period = h >= 12 ? "PM" : "AM"
                                            return String(h).padStart(2, '0') + ":" + String(m).padStart(2, '0') + " " + period + " " + now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                                        }
                                        return now.toLocaleTimeString(Qt.locale(), "HH:mm") + " " + now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                                    }
                                    const timeStr = now.toLocaleTimeString(Qt.locale(), "h:mm AP")
                                    return timeStr.replace(/\./g, "").trim() + " " + now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                                }
                                font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText
                            }
                            StyledText {
                                text: "UTC: " + (TimeService.universalTime || "")
                                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                                visible: TimeService.universalTime && TimeService.universalTime.length > 0
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // TIME FORMAT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: timeFormatSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: timeFormatSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "schedule"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Time Format"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Configure how time is displayed"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }
                    EHToggle { width: parent.width; text: "Use 24-hour time format"; checked: SettingsData.use24HourClock; onToggled: checked => SettingsData.setClockFormat(checked) }
                    EHToggle { width: parent.width; text: "Show AM/PM in 24-hour mode"; description: "Display AM/PM indicators when using 24-hour time format"; checked: SettingsData.showAmPmIn24Hour; onToggled: checked => SettingsData.setShowAmPmIn24Hour(checked) }
                    EHToggle { width: parent.width; text: "Stack Time Format"; description: "Display time in a vertical stacked format"; checked: SettingsData.clockStackedFormat; onToggled: checked => SettingsData.setClockStackedFormat(checked) }
                    EHToggle { width: parent.width; text: "Bold Time Font"; description: "Make the time text bold"; checked: SettingsData.clockBoldFont; onToggled: checked => SettingsData.setClockBoldFont(checked) }
                }
            }

            // ════════════════════════════════════════════════════════════
            // DOCK CLOCK
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: dockClockSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dockClockSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "dock"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Dock Clock Display"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Configure dock clock appearance and format"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }
                    EHToggle { width: parent.width; text: "Show Full Date"; description: "Display the complete date above the time"; checked: SettingsData.dockClockShowFullDate; onToggled: checked => SettingsData.dockClockShowFullDate = checked }
                    EHToggle { width: parent.width; text: "Show Seconds"; description: "Include seconds in the time display"; checked: SettingsData.dockClockShowSeconds; onToggled: checked => SettingsData.dockClockShowSeconds = checked }
                    EHToggle { width: parent.width; text: "Use 12-Hour Format"; description: "Display time in 12-hour format with AM/PM"; checked: SettingsData.dockClockUse12Hour; onToggled: checked => SettingsData.dockClockUse12Hour = checked }
                    EHToggle { width: parent.width; text: "Show AM/PM"; description: "Display AM/PM indicators when using 12-hour format"; checked: SettingsData.dockClockShowAmPm; onToggled: checked => SettingsData.dockClockShowAmPm = checked }

                    // Dock clock preview
                    StyledRect {
                        width: parent.width
                        height: dockPreviewRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1

                        Row {
                            id: dockPreviewRow
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            StyledText {
                                text: "Preview:"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: {
                                    // depend on all relevant settings so this re-evaluates on any change
                                    SettingsData.dockClockUse12Hour
                                    SettingsData.dockClockShowAmPm
                                    SettingsData.dockClockShowSeconds
                                    SettingsData.dockClockShowFullDate
                                    const now = new Date()
                                    let fmt = SettingsData.dockClockUse12Hour
                                        ? (SettingsData.dockClockShowSeconds ? "h:mm:ss" : "h:mm")
                                        : (SettingsData.dockClockShowSeconds ? "HH:mm:ss" : "HH:mm")
                                    let timeStr = Qt.formatTime(now, fmt)
                                    if (SettingsData.dockClockUse12Hour && SettingsData.dockClockShowAmPm)
                                        timeStr += " " + Qt.formatTime(now, "ap").toUpperCase()
                                    if (SettingsData.dockClockShowFullDate)
                                        timeStr = now.toLocaleDateString(Qt.locale(), "ddd d MMM") + "  " + timeStr
                                    return timeStr
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Font Size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Dock clock font size scale"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider {
                            width: parent.width; height: 24
                            minimum: 5; maximum: 20
                            value: Math.round(SettingsData.dockClockFontSize * 10)
                            unit: "%"; showValue: true; wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderValueChanged: newValue => { SettingsData.dockClockFontSize = newValue / 10.0 }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // TIMEZONE
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: timezoneSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: timezoneSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "public"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Timezone"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Select your system timezone"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                    }
                    EHTextField {
                        id: timezoneSearchField; width: parent.width
                        placeholderText: "Search timezone (e.g., America, Europe, Asia)"
                        text: timezoneSearchText
                        onTextChanged: { timezoneSearchText = text; updateFilteredTimezones() }
                    }
                    EHDropdown {
                        width: parent.width; text: "Select Timezone"
                        description: "Current: " + (TimeService.currentTimezone || "Loading...")
                        currentValue: TimeService.currentTimezone || ""
                        enableFuzzySearch: true
                        options: filteredTimezones.length > 0 ? filteredTimezones : (TimeService.availableTimezones.length > 0 ? TimeService.availableTimezones : ["Loading timezones..."])
                        onValueChanged: value => { if (value && value !== TimeService.currentTimezone && value !== "Loading timezones...") TimeService.setTimezone(value) }
                    }

                    StyledRect {
                        width: parent.width
                        height: timezoneInfo.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                        visible: TimeService.lastError && TimeService.lastError.length > 0

                        Column {
                            id: timezoneInfo
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS
                            StyledText { text: "Error: " + TimeService.lastError; font.pixelSize: Theme.fontSizeSmall; color: Theme.error; wrapMode: Text.WordWrap; width: parent.width }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // NETWORK TIME
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: ntpSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: ntpSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "sync"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Network Time"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    EHToggle { width: parent.width; text: "Network Time Synchronization"; description: "Automatically synchronize system time with internet time servers"; checked: TimeService.ntpEnabled; onToggled: checked => TimeService.setNTP(checked) }
                    StyledText {
                        text: "Status: " + (TimeService.systemClockSynchronized ? "Synchronized" : "Not synchronized") + " (" + TimeService.ntpServiceStatus + ")"
                        font.pixelSize: Theme.fontSizeSmall
                        color: TimeService.systemClockSynchronized ? Theme.success : Theme.surfaceVariantText
                        visible: TimeService.ntpServiceStatus && TimeService.ntpServiceStatus.length > 0
                        width: parent.width
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CALENDAR
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: calendarSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: calendarSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "event"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Calendar Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    EHDropdown {
                        width: parent.width; text: "First Day of Week"; description: "Choose which day starts the week"
                        currentValue: { const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]; return days[SettingsData.firstDayOfWeek] || "Monday" }
                        options: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        onValueChanged: value => { const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]; const index = days.indexOf(value); if (index >= 0) SettingsData.setFirstDayOfWeek(index) }
                    }
                    EHDropdown {
                        width: parent.width; text: "Week Numbering"; description: "How weeks are numbered in calendars"
                        currentValue: SettingsData.weekNumbering || "ISO"
                        options: ["ISO", "US", "None"]
                        onValueChanged: value => { SettingsData.setWeekNumbering(value) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // DATE FORMAT
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: dateSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dateSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "calendar_today"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Date Format"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    readonly property var datePresets: [
                        { format: "ddd d",         label: "Day Date" },
                        { format: "ddd MMM d",      label: "Day Month Date" },
                        { format: "MMM d",          label: "Month Date" },
                        { format: "M/d",            label: "Numeric (M/D)" },
                        { format: "d/M",            label: "Numeric (D/M)" },
                        { format: "ddd d MMM yyyy", label: "Full with Year" },
                        { format: "yyyy-MM-dd",     label: "ISO Date" },
                        { format: "dddd, MMMM d",   label: "Full Day & Month" }
                    ]

                    readonly property var formatMap: ({
                        "System Default":   "",
                        "Day Date":         "ddd d",
                        "Day Month Date":   "ddd MMM d",
                        "Month Date":       "MMM d",
                        "Numeric (M/D)":    "M/d",
                        "Numeric (D/M)":    "d/M",
                        "Full with Year":   "ddd d MMM yyyy",
                        "ISO Date":         "yyyy-MM-dd",
                        "Full Day & Month": "dddd, MMMM d"
                    })

                    EHDropdown {
                        width: parent.width; text: "Top Bar Format"
                        description: "Preview: " + (SettingsData.clockDateFormat ? new Date().toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat) : new Date().toLocaleDateString(Qt.locale(), "ddd d"))
                        currentValue: {
                            if (!SettingsData.clockDateFormat || SettingsData.clockDateFormat.length === 0) return "System Default"
                            const match = dateSection.datePresets.find(p => p.format === SettingsData.clockDateFormat)
                            return match ? match.label : "Custom: " + SettingsData.clockDateFormat
                        }
                        options: ["System Default", "Day Date", "Day Month Date", "Month Date", "Numeric (M/D)", "Numeric (D/M)", "Full with Year", "ISO Date", "Full Day & Month", "Custom..."]
                        onValueChanged: value => {
                            if (value === "Custom...") { customFormatInput.visible = true }
                            else { customFormatInput.visible = false; SettingsData.setClockDateFormat(dateSection.formatMap[value] ?? "") }
                        }
                    }
                    EHTextField {
                        id: customFormatInput; width: parent.width; visible: false
                        placeholderText: "Enter custom top bar format (e.g., ddd MMM d)"
                        text: SettingsData.clockDateFormat
                        onTextChanged: { if (visible && text) SettingsData.setClockDateFormat(text) }
                    }

                    EHDropdown {
                        width: parent.width; text: "Lock Screen Format"
                        description: "Preview: " + (SettingsData.lockDateFormat ? new Date().toLocaleDateString(Qt.locale(), SettingsData.lockDateFormat) : new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat))
                        currentValue: {
                            if (!SettingsData.lockDateFormat || SettingsData.lockDateFormat.length === 0) return "System Default"
                            const match = dateSection.datePresets.find(p => p.format === SettingsData.lockDateFormat)
                            return match ? match.label : "Custom: " + SettingsData.lockDateFormat
                        }
                        options: ["System Default", "Day Date", "Day Month Date", "Month Date", "Numeric (M/D)", "Numeric (D/M)", "Full with Year", "ISO Date", "Full Day & Month", "Custom..."]
                        onValueChanged: value => {
                            if (value === "Custom...") { customLockFormatInput.visible = true }
                            else { customLockFormatInput.visible = false; SettingsData.setLockDateFormat(dateSection.formatMap[value] ?? "") }
                        }
                    }
                    EHTextField {
                        id: customLockFormatInput; width: parent.width; visible: false
                        placeholderText: "Enter custom lock screen format (e.g., dddd, MMMM d)"
                        text: SettingsData.lockDateFormat
                        onTextChanged: { if (visible && text) SettingsData.setLockDateFormat(text) }
                    }

                    // Format Legend
                    StyledRect {
                        width: parent.width
                        height: formatHelp.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1

                        Column {
                            id: formatHelp
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText { text: "Format Legend"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.primary }

                            Row {
                                width: parent.width; spacing: Theme.spacingL
                                Column {
                                    width: (parent.width - Theme.spacingL) / 2; spacing: 2
                                    StyledText { text: "• d — Day (1-31)";      font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• dd — Day (01-31)";    font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• ddd — Day (Mon)";     font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• dddd — Day (Monday)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• M — Month (1-12)";    font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                }
                                Column {
                                    width: (parent.width - Theme.spacingL) / 2; spacing: 2
                                    StyledText { text: "• MM — Month (01-12)";      font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• MMM — Month (Jan)";       font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• MMMM — Month (January)";  font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• yy — Year (24)";          font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                    StyledText { text: "• yyyy — Year (2024)";      font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
