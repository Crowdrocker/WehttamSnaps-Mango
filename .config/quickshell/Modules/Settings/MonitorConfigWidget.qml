import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modals.FileBrowser

Column {
    id: root

    property var monitorData: null
    property var monitorCapabilities: ({})
    property var initialCapabilities: ({})
    property int mangoHdrDepth: 2
    signal settingChanged(string setting, var value)
    signal mangoGlobalSettingChanged(string key, var value)

    spacing: Theme.spacingL

    onMonitorCapabilitiesChanged: {
        if (Object.keys(initialCapabilities).length === 0 && monitorCapabilities &&
            Object.keys(monitorCapabilities).length > 0) {
            initialCapabilities = JSON.parse(JSON.stringify(monitorCapabilities))
        }
    }

    readonly property var hardwareCaps: {
        if (typeof MonitorCapabilitiesService !== "undefined" && MonitorCapabilitiesService.capabilities) {
            return MonitorCapabilitiesService.capabilities[monitorData ? monitorData.name : ""] || {}
        }
        return {}
    }

    readonly property bool supportsHDR: {
        if (hardwareCaps.hdr === true) return true
        if (monitorCapabilities && monitorCapabilities.hdr === true) return true
        if (monitorData) {
            var cm = (monitorData.cm || "").toLowerCase()
            if (cm === "hdr" || cm === "hdredid") return true
            if (monitorData.supports_hdr === true || monitorData.supports_hdr === "1" || monitorData.supports_hdr === 1) return true
        }
        return false
    }

    readonly property bool supportsVRR: {
        if (hardwareCaps.vrr === true) return true
        if (monitorCapabilities && monitorCapabilities.vrr !== undefined && monitorCapabilities.vrr !== null) return true
        return false
    }

    readonly property bool supports10Bit: {
        if (hardwareCaps.ten_bit === true) return true
        if (monitorCapabilities) {
            var format = (monitorCapabilities.currentFormat || "").toLowerCase()
            if (format.includes("2101010") || format.includes("101010") || format.includes("30")) return true
        }
        return false
    }

    readonly property bool supportsWideColor: {
        if (supportsHDR) return true
        if (monitorCapabilities) {
            if (monitorCapabilities.availableModes) {
                for (var i = 0; i < monitorCapabilities.availableModes.length; i++) {
                    var modeStr = monitorCapabilities.availableModes[i]
                    if (typeof modeStr !== 'string') continue
                    var mode = modeStr.toLowerCase()
                    if (mode.includes("bt2020") || mode.includes("dci") || mode.includes("p3")) return true
                }
            }
            if ((monitorCapabilities.max_luminance || 0) > 300) return true
        }
        return false
    }

    // ── Shared label width ───────────────────────────────────────────────────
    readonly property int labelWidth: 120

    // ── Helper: setting row ──────────────────────────────────────────────────
    // Used as an inline pattern: Row { + StyledText label + control }

    // ════════════════════════════════════════════════════════════════════════
    // SECTION 1: Monitor Identity & Enable/Disable
    // ════════════════════════════════════════════════════════════════════════
    StyledRect {
        width: parent.width
        height: identitySection.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1

        Column {
            id: identitySection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            // Monitor name + make/model
            Row {
                width: parent.width
                spacing: Theme.spacingM

                EHIcon {
                    name: monitorData && monitorData.disabled ? "desktop_access_disabled" : "desktop_windows"
                    size: Theme.iconSize
                    color: monitorData && monitorData.disabled ? Theme.surfaceVariantText : Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: monitorData ? monitorData.name : "Unknown Monitor"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: monitorData && monitorData.disabled ? Theme.surfaceVariantText : Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            var caps = root.monitorCapabilities || {}
                            var make = caps.make || ""
                            var model = caps.model || ""
                            if (make && model) return make + " " + model
                            if (model) return model
                            if (make) return make
                            var desc = caps.description || ""
                            return desc ? desc.split(" ").slice(0, 3).join(" ") : ""
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        visible: text !== ""
                    }
                }
            }

            EHToggle {
                width: parent.width
                text: "Disable this monitor"
                description: "Remove this monitor from the active display configuration"
                checked: monitorData ? monitorData.disabled : false
                onToggled: checked => {
                    if (monitorData) {
                        monitorData.disabled = checked
                        settingChanged("disabled", checked ? "true" : "false")
                    }
                }
            }

            StyledText {
                width: parent.width
                text: "This monitor is disabled. Enable it above to configure settings."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                visible: monitorData && monitorData.disabled
                wrapMode: Text.WordWrap
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // SECTION 2: Display Settings
    // ════════════════════════════════════════════════════════════════════════
    StyledRect {
        width: parent.width
        height: displaySection.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: !monitorData || !monitorData.disabled
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        Column {
            id: displaySection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "Display"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Resolution
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "Resolution"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    id: resolutionDropdown
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Resolution"
                    options: {
                        if (!monitorCapabilities || !monitorCapabilities.resolutions || monitorCapabilities.resolutions.length === 0) {
                            if (monitorData && monitorData.resolution) return [monitorData.resolution]
                            return ["No resolutions available"]
                        }
                        return monitorCapabilities.resolutions
                    }
                    currentValue: monitorData ? (monitorData.resolution || "") : ""
                    onValueChanged: value => {
                        if (monitorData && value && value !== "No resolutions available") {
                            monitorData.resolution = value
                            settingChanged("resolution", value)
                            refreshGroup.selectedResolution = value
                            refreshGroup.forceUpdate = !refreshGroup.forceUpdate
                        }
                    }
                }
            }

            // Refresh Rate
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "Refresh Rate"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    id: refreshGroup
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Refresh Rate"

                    property string selectedResolution: monitorData ? (monitorData.resolution || "") : ""
                    property bool forceUpdate: false

                    options: {
                        var _ = forceUpdate
                        if (!monitorCapabilities) {
                            return monitorData && monitorData.refreshRate ? [monitorData.refreshRate.toString() + " Hz"] : ["N/A"]
                        }
                        var res = selectedResolution || (monitorData ? monitorData.resolution : "")
                        if (monitorCapabilities.resolutionRefreshMap && res && monitorCapabilities.resolutionRefreshMap[res])
                            return monitorCapabilities.resolutionRefreshMap[res].map(r => r.toString() + " Hz")
                        if (monitorCapabilities.refreshRates && monitorCapabilities.refreshRates.length > 0)
                            return monitorCapabilities.refreshRates.map(r => r.toString() + " Hz")
                        return monitorData && monitorData.refreshRate ? [monitorData.refreshRate.toString() + " Hz"] : ["N/A"]
                    }

                    currentValue: {
                        var _ = forceUpdate
                        if (!monitorData || !monitorData.refreshRate) return ""
                        var rate = parseFloat(monitorData.refreshRate)
                        var res = selectedResolution || (monitorData ? monitorData.resolution : "")
                        var rates = (monitorCapabilities && monitorCapabilities.resolutionRefreshMap && res && monitorCapabilities.resolutionRefreshMap[res])
                            ? monitorCapabilities.resolutionRefreshMap[res]
                            : (monitorCapabilities && monitorCapabilities.refreshRates ? monitorCapabilities.refreshRates : [])
                        // Find closest match
                        var best = null, bestD = Infinity
                        for (var i = 0; i < rates.length; i++) {
                            var d = Math.abs(rates[i] - rate)
                            if (d < bestD) { bestD = d; best = rates[i] }
                        }
                        return best !== null ? best.toString() + " Hz" : rate.toString() + " Hz"
                    }

                    onValueChanged: value => {
                        if (!monitorData || !value || value === "N/A") return
                        var rate = parseFloat(value.replace(" Hz", ""))
                        if (!isNaN(rate)) {
                            monitorData.refreshRate = rate.toString()
                            settingChanged("refreshRate", rate.toString())
                        }
                    }
                }
            }

            // Scale
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "Scale"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHSlider {
                    width: parent.width - root.labelWidth - scaleVal.implicitWidth - Theme.spacingM * 2
                    minimum: 10; maximum: 20
                    value: {
                        if (!monitorData) return 10
                        return Math.round(Math.max(1.0, Math.min(2.0, parseFloat(monitorData.scale) || 1.0)) * 10)
                    }
                    onSliderDragFinished: v => {
                        if (monitorData) {
                            var s = (v / 10.0).toFixed(1)
                            monitorData.scale = s
                            settingChanged("scale", s)
                        }
                    }
                }
                StyledText {
                    id: scaleVal
                    text: monitorData ? Math.max(1.0, Math.min(2.0, parseFloat(monitorData.scale) || 1.0)).toFixed(1) + "x" : "1.0x"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Transform
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "Transform"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Transform"
                    options: ["Normal (0°)", "90°", "180°", "270°", "Flipped", "Flipped + 90°", "Flipped + 180°", "Flipped + 270°"]
                    currentValue: {
                        if (!monitorData) return "Normal (0°)"
                        var opts = ["Normal (0°)", "90°", "180°", "270°", "Flipped", "Flipped + 90°", "Flipped + 180°", "Flipped + 270°"]
                        return opts[parseInt(monitorData.transform) || 0] || "Normal (0°)"
                    }
                    onValueChanged: value => {
                        if (monitorData) {
                            var opts = ["Normal (0°)", "90°", "180°", "270°", "Flipped", "Flipped + 90°", "Flipped + 180°", "Flipped + 270°"]
                            var idx = opts.indexOf(value)
                            if (idx >= 0) { monitorData.transform = idx.toString(); settingChanged("transform", idx.toString()) }
                        }
                    }
                }
            }

            // Bit Depth (Hyprland monitorv2 only)
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: !CompositorService.isMango
                StyledText {
                    text: "Bit Depth"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Bit Depth"
                    options: supports10Bit ? ["8-bit", "10-bit"] : ["8-bit"]
                    currentValue: (monitorData && monitorData.bitdepth === "10" && supports10Bit) ? "10-bit" : "8-bit"
                    onValueChanged: value => {
                        if (!monitorData) return
                        var bd = (value === "10-bit" && supports10Bit) ? "10" : ""
                        monitorData.bitdepth = bd
                        settingChanged("bitdepth", bd)
                    }
                }
            }

            // VRR
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: supportsVRR
                opacity: visible ? 1 : 0
                StyledText {
                    text: "VRR"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "VRR"
                    options: CompositorService.isMango ? ["Disabled", "On"] : ["Disabled", "Global", "Fullscreen"]
                    currentValue: {
                        if (!monitorData) return "Disabled"
                        var v = monitorData.vrr
                        if (CompositorService.isMango)
                            return (v === 1 || v === "1" || v === true) ? "On" : "Disabled";

                        if (v === 1 || v === "1" || v === true) return "Global"
                        if (v === 2 || v === "2") return "Fullscreen"
                        return "Disabled"
                    }
                    onValueChanged: value => {
                        if (!monitorData) return
                        var v = CompositorService.isMango ? (value === "On" ? "1" : "0") : value === "Global" ? "1" : value === "Fullscreen" ? "2" : "0"
                        monitorData.vrr = parseInt(v)
                        settingChanged("vrr", v)
                    }
                }
            }

            // Custom Mode (MangoWM only)
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: CompositorService.isMango
                StyledText { text: "Custom Mode"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHToggle {
                    checked: monitorData && (monitorData.custom === "1" || monitorData.custom === 1)
                    onToggled: checked => {
                        if (monitorData) {
                            monitorData.custom = checked ? "1" : "0"
                            settingChanged("custom", monitorData.custom)
                        }
                    }
                }
            }

            // Serial (MangoWM only)
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: CompositorService.isMango
                StyledText { text: "Serial"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHTextField {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    height: 32
                    text: monitorData ? (monitorData.mangoSerial || "") : ""
                    placeholderText: "leave empty to match all"
                    onEditingFinished: {
                        if (monitorData) {
                            monitorData.mangoSerial = text
                            settingChanged("mangoSerial", text)
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // SECTION 3: Color Settings
    // ════════════════════════════════════════════════════════════════════════
    StyledRect {
        width: parent.width
        height: colorSection.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: (!monitorData || !monitorData.disabled) && !CompositorService.isNiri && !CompositorService.isMango
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        Column {
            id: colorSection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                EHIcon { name: "palette"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "Color Settings"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "Color Management"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Color Management"
                    options: {
                        var opts = ["Auto", "sRGB"]
                        if (supportsWideColor) opts.push("DCI P3", "Display P3", "Adobe RGB", "Wide (BT2020)")
                        opts.push("EDID")
                        if (supportsHDR) opts.push("HDR", "HDR EDID")
                        return opts
                    }
                    currentValue: {
                        if (!monitorData) return "Auto"
                        var map = { "auto": "Auto", "srgb": "sRGB", "dcip3": "DCI P3", "dp3": "Display P3",
                                    "adobe": "Adobe RGB", "wide": "Wide (BT2020)", "edid": "EDID", "hdr": "HDR", "hdredid": "HDR EDID" }
                        var val = map[(monitorData.cm || "").toLowerCase()] || "Auto"
                        if (!supportsHDR && (val === "HDR" || val === "HDR EDID")) return "Auto"
                        if (!supportsWideColor && (val === "DCI P3" || val === "Display P3" || val === "Adobe RGB" || val === "Wide (BT2020)")) return "Auto"
                        return val
                    }
                    onValueChanged: value => {
                        if (monitorData) {
                            var map = { "Auto": "auto", "sRGB": "srgb", "DCI P3": "dcip3", "Display P3": "dp3",
                                        "Adobe RGB": "adobe", "Wide (BT2020)": "wide", "EDID": "edid", "HDR": "hdr", "HDR EDID": "hdredid" }
                            monitorData.cm = map[value] || "auto"
                            settingChanged("cm", monitorData.cm)
                        }
                    }
                }
            }

            // ICC Profile
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText {
                    text: "ICC Profile"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    width: root.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {
                    width: parent.width - root.labelWidth - browseBtn.width - clearBtn.width - Theme.spacingM * 3
                    height: 36
                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!monitorData || !monitorData.icc) return "No profile selected"
                            var parts = String(monitorData.icc).split("/")
                            return parts[parts.length - 1]
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: monitorData && monitorData.icc ? Theme.surfaceText : Theme.surfaceVariantText
                        elide: Text.ElideMiddle
                    }
                }
                StyledRect {
                    id: clearBtn
                    height: 36
                    implicitWidth: clearBtnText.implicitWidth + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
                    border.color: Theme.error
                    border.width: 1
                    visible: monitorData && !!monitorData.icc
                    StyledText {
                        id: clearBtnText
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                    }
                    StateLayer {
                        stateColor: Theme.error
                        cornerRadius: parent.radius
                        onClicked: {
                            if (monitorData) {
                                monitorData.icc = ""
                                settingChanged("icc", "")
                            }
                        }
                    }
                }
                StyledRect {
                    id: browseBtn
                    height: 36
                    implicitWidth: browseBtnText.implicitWidth + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Theme.primary
                    border.width: 1
                    StyledText {
                        id: browseBtnText
                        anchors.centerIn: parent
                        text: "Browse"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                    StateLayer {
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        onClicked: iccFileBrowser.open()
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: iccFileBrowser
        browserTitle: "Select ICC Profile"
        browserIcon: "palette"
        fileExtensions: ["*.icm", "*.icc"]
        selectFolderMode: false
        onFileSelected: path => {
            if (monitorData) {
                monitorData.icc = path
                settingChanged("icc", path)
            }
            close()
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // SECTION 4: HDR Settings
    // ════════════════════════════════════════════════════════════════════════
    StyledRect {
        width: parent.width
        height: hdrSection.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: (!monitorData || !monitorData.disabled) && !CompositorService.isNiri && (supportsHDR || CompositorService.isMango)
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        Column {
            id: hdrSection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                EHIcon { name: "wb_sunny"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "HDR Settings"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // HDR Support
            Row {
                width: parent.width
                spacing: Theme.spacingM
                StyledText { text: "HDR Support"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "HDR Support"
                    options: CompositorService.isMango ? ["Off", "On"] : ["Auto", "Force On", "Force Off"]
                    currentValue: {
                        if (!monitorData) return CompositorService.isMango ? "Off" : "Auto"
                        var v = monitorData.supports_hdr
                        if (v === 1 || v === "1" || v === true) return CompositorService.isMango ? "On" : "Force On"
                        if (v === -1 || v === "-1") return "Force Off"
                        return CompositorService.isMango ? "Off" : "Auto"
                    }
                    onValueChanged: value => {
                        if (!monitorData) return
                        var v
                        if (CompositorService.isMango) {
                            v = value === "On" ? "1" : "0"
                        } else {
                            v = value === "Force On" ? "1" : value === "Force Off" ? "-1" : "0"
                        }
                        monitorData.supports_hdr = parseInt(v)
                        settingChanged("supports_hdr", v)
                    }
                }
            }

            // HDR Depth (MangoWM only, global setting)
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: CompositorService.isMango
                StyledText { text: "HDR Depth"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "HDR Depth"
                    options: ["Default", "HDR8", "HDR10"]
                    currentValue: {
                        var d = parseInt(root.mangoHdrDepth, 10)
                        if (isNaN(d) || d < 0 || d > 2) d = 2
                        return ["Default", "HDR8", "HDR10"][d]
                    }
                    onValueChanged: value => {
                        var d = ["Default", "HDR8", "HDR10"].indexOf(value)
                        if (d < 0) d = 2
                        root.mangoGlobalSettingChanged("hdr_depth", d)
                    }
                }
            }

            // HDR info note (MangoWM only)
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: CompositorService.isMango
                Item { width: root.labelWidth; height: 1 }
                StyledText {
                    text: "HDR requires hdr:1 per-monitor and env=WLR_RENDERER,vulkan set before launch. Relogin to apply."
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                    width: parent.width - root.labelWidth - Theme.spacingM
                    wrapMode: Text.WordWrap
                }
            }

            // Wide Color
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: !CompositorService.isMango
                StyledText { text: "Wide Color"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "Wide Color"
                    options: ["Auto", "Force On", "Force Off"]
                    currentValue: {
                        if (!monitorData) return "Auto"
                        var v = monitorData.supports_wide_color
                        if (v === 1 || v === "1" || v === true) return "Force On"
                        if (v === -1 || v === "-1") return "Force Off"
                        return "Auto"
                    }
                    onValueChanged: value => {
                        if (!monitorData) return
                        var v = value === "Force On" ? "1" : value === "Force Off" ? "-1" : "0"
                        monitorData.supports_wide_color = parseInt(v)
                        settingChanged("supports_wide_color", v)
                    }
                }
            }

            // SDR EOTF
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: !CompositorService.isMango
                StyledText { text: "SDR EOTF"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHDropdown {
                    width: parent.width - root.labelWidth - Theme.spacingM
                    text: "SDR EOTF"
                    options: ["Follow", "sRGB", "Gamma 2.2"]
                    currentValue: {
                        var idx = Math.max(0, Math.min(2, parseInt(monitorData ? monitorData.sdr_eotf : 0) || 0))
                        return ["Follow", "sRGB", "Gamma 2.2"][idx]
                    }
                    onValueChanged: value => {
                        if (!monitorData) return
                        var idx = ["Follow", "sRGB", "Gamma 2.2"].indexOf(value)
                        if (idx >= 0) { monitorData.sdr_eotf = idx.toString(); settingChanged("sdr_eotf", idx.toString()) }
                    }
                }
            }

            // SDR Brightness
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: !CompositorService.isMango
                StyledText { text: "SDR Brightness"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - sdrBrightVal.implicitWidth - Theme.spacingM * 2
                    minimum: 10; maximum: 200
                    value: Math.round((parseFloat(monitorData ? monitorData.sdrbrightness : 1.0) || 1.0) * 100)
                    onSliderDragFinished: v => {
                        if (monitorData) { var b = (v / 100.0).toFixed(2); monitorData.sdrbrightness = b; settingChanged("sdrbrightness", b) }
                    }
                }
                StyledText { id: sdrBrightVal; text: (parseFloat(monitorData ? monitorData.sdrbrightness : 1.0) || 1.0).toFixed(2); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // SDR Saturation
            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: !CompositorService.isMango
                StyledText { text: "SDR Saturation"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - sdrSatVal.implicitWidth - Theme.spacingM * 2
                    minimum: 0; maximum: 200
                    value: Math.round((parseFloat(monitorData ? monitorData.sdrsaturation : 1.0) || 1.0) * 100)
                    onSliderDragFinished: v => {
                        if (monitorData) { var s = (v / 100.0).toFixed(2); monitorData.sdrsaturation = s; settingChanged("sdrsaturation", s) }
                    }
                }
                StyledText { id: sdrSatVal; text: (parseFloat(monitorData ? monitorData.sdrsaturation : 1.0) || 1.0).toFixed(2); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // SECTION 5: Luminance
    // ════════════════════════════════════════════════════════════════════════
    StyledRect {
        width: parent.width
        height: luminanceSection.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: (!monitorData || !monitorData.disabled) && supportsHDR && !CompositorService.isNiri && !CompositorService.isMango
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

        Column {
            id: luminanceSection
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                EHIcon { name: "brightness_6"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    text: "Luminance"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // SDR Min
            Row {
                width: parent.width; spacing: Theme.spacingM
                StyledText { text: "SDR Min"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - sdrMinVal.implicitWidth - Theme.spacingM * 2
                    minimum: 0; maximum: 10
                    value: Math.round(((monitorData ? monitorData.sdr_min_luminance : 0.0) || 0.0) * 1000)
                    onSliderDragFinished: v => {
                        if (monitorData) { var val = (v / 1000.0).toFixed(3); monitorData.sdr_min_luminance = parseFloat(val); settingChanged("sdr_min_luminance", val) }
                    }
                }
                StyledText { id: sdrMinVal; text: ((monitorData ? monitorData.sdr_min_luminance : 0.0) || 0.0).toFixed(3); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // SDR Max
            Row {
                width: parent.width; spacing: Theme.spacingM
                StyledText { text: "SDR Max"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - sdrMaxVal.implicitWidth - Theme.spacingM * 2
                    minimum: 80; maximum: 400
                    value: (monitorData ? monitorData.sdr_max_luminance : 200) || 200
                    onSliderDragFinished: v => {
                        if (monitorData) { monitorData.sdr_max_luminance = v; settingChanged("sdr_max_luminance", v.toString()) }
                    }
                }
                StyledText { id: sdrMaxVal; text: ((monitorData ? monitorData.sdr_max_luminance : 200) || 200) + " nits"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // Min
            Row {
                width: parent.width; spacing: Theme.spacingM
                StyledText { text: "Min"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - minLumVal.implicitWidth - Theme.spacingM * 2
                    minimum: 0; maximum: 10
                    value: Math.round(((monitorData ? monitorData.min_luminance : 0.0) || 0.0) * 1000)
                    onSliderDragFinished: v => {
                        if (monitorData) { var val = (v / 1000.0).toFixed(3); monitorData.min_luminance = parseFloat(val); settingChanged("min_luminance", val) }
                    }
                }
                StyledText { id: minLumVal; text: ((monitorData ? monitorData.min_luminance : 0.0) || 0.0).toFixed(3); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // Max
            Row {
                width: parent.width; spacing: Theme.spacingM
                StyledText { text: "Max"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - maxLumVal.implicitWidth - Theme.spacingM * 2
                    minimum: 0; maximum: 2000
                    value: (monitorData ? monitorData.max_luminance : 0) || 0
                    onSliderDragFinished: v => {
                        if (monitorData) { monitorData.max_luminance = v; settingChanged("max_luminance", v.toString()) }
                    }
                }
                StyledText { id: maxLumVal; text: ((monitorData ? monitorData.max_luminance : 0) || 0) + " nits"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // Max Avg
            Row {
                width: parent.width; spacing: Theme.spacingM
                StyledText { text: "Max Avg"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; width: root.labelWidth; anchors.verticalCenter: parent.verticalCenter }
                EHSlider {
                    width: parent.width - root.labelWidth - maxAvgVal.implicitWidth - Theme.spacingM * 2
                    minimum: 0; maximum: 2000
                    value: (monitorData ? monitorData.max_avg_luminance : 0) || 0
                    onSliderDragFinished: v => {
                        if (monitorData) { monitorData.max_avg_luminance = v; settingChanged("max_avg_luminance", v.toString()) }
                    }
                }
                StyledText { id: maxAvgVal; text: ((monitorData ? monitorData.max_avg_luminance : 0) || 0) + " nits"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}