import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandInputTab

    property var parentModal: null
    property var inputDevices: []
    property string selectedInputDevice: ""
    property bool inputDevicesLoading: false

    readonly property bool isHyprland: typeof CompositorService !== "undefined" && CompositorService.isHyprland

    function refreshInputDevices() {
        if (!CompositorService || !CompositorService.isHyprland) return
        inputDevicesLoading = true
        hyprlandDevicesProcess.running = true
    }

    function rotationLabel(value) {
        var val = parseInt(value, 10)
        if (val === 90)  return "90°"
        if (val === 180) return "180°"
        if (val === 270) return "270°"
        return "0°"
    }

    Process {
        id: hyprlandDevicesProcess
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                inputDevicesLoading = false
                try {
                    const data = JSON.parse(text)
                    const deviceList = []
                    function addDevices(devices, typeLabel) {
                        if (!devices || !Array.isArray(devices)) return
                        devices.forEach(dev => { if (dev && dev.name) deviceList.push({ "name": dev.name, "type": typeLabel }) })
                    }
                    addDevices(data.touch,       "Touch")
                    addDevices(data.tablets,      "Tablet")
                    addDevices(data.tabletPads,   "Tablet Pad")
                    addDevices(data.tabletTools,  "Tablet Tool")
                    addDevices(data.mice,         "Mouse")
                    inputDevices = deviceList
                    if (inputDevices.length > 0) {
                        var exists = inputDevices.some(dev => dev.name === selectedInputDevice)
                        if (!exists) selectedInputDevice = inputDevices[0].name
                    } else {
                        selectedInputDevice = ""
                    }
                } catch (e) {
                    inputDevices = []
                    selectedInputDevice = ""
                }
            }
        }
    }

    Component.onCompleted: refreshInputDevices()

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
            // CATEGORY 1: Keyboard
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: kbSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: kbSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "keyboard"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Keyboard"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Layout"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "XKB layout string, e.g. us,ru"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandInputKbLayout; placeholderText: "e.g. us,ru"; onEditingFinished: SettingsData.setHyprlandInputKbLayout(text) }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Variant"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandInputKbVariant; placeholderText: "e.g. ,phonetic"; onEditingFinished: SettingsData.setHyprlandInputKbVariant(text) }
                        }
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Model"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandInputKbModel; placeholderText: "e.g. pc105"; onEditingFinished: SettingsData.setHyprlandInputKbModel(text) }
                        }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Options"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandInputKbOptions; placeholderText: "e.g. grp:alt_shift_toggle"; onEditingFinished: SettingsData.setHyprlandInputKbOptions(text) }
                        }
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Rules"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandInputKbRules; placeholderText: "leave blank for default"; onEditingFinished: SettingsData.setHyprlandInputKbRules(text) }
                        }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Repeat Rate"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandInputRepeatRate; minimum: 1; maximum: 60; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandInputRepeatRate(v) }
                        }
                        Column {
                            width: (parent.width - Theme.spacingM) / 2; spacing: Theme.spacingS
                            StyledText { text: "Repeat Delay"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandInputRepeatDelay; minimum: 100; maximum: 1000; unit: "ms"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandInputRepeatDelay(v) }
                        }
                    }

                    EHToggle { width: parent.width; text: "Numlock by Default"; description: "Enable numlock on startup"; checked: SettingsData.hyprlandInputNumlockByDefault; onToggled: checked => SettingsData.setHyprlandInputNumlockByDefault(checked) }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Pointer
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: pointerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: pointerSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "mouse"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Pointer"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Left Handed"; description: "Swap primary and secondary mouse buttons"; checked: SettingsData.hyprlandInputLeftHanded; onToggled: checked => SettingsData.setHyprlandInputLeftHanded(checked) }
                    EHToggle { width: parent.width; text: "Natural Scroll"; description: "Reverse scroll direction to match touchpad-style movement"; checked: SettingsData.hyprlandInputNaturalScroll; onToggled: checked => SettingsData.setHyprlandInputNaturalScroll(checked) }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Sensitivity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandInputSensitivity * 100); minimum: -100; maximum: 100; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandInputSensitivity(v / 100) }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - accelDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Accel Profile"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Pointer acceleration profile"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        EHDropdown { id: accelDropdown; width: 160; text: "Profile"; options: ["adaptive", "flat"]; currentValue: SettingsData.hyprlandInputAccelProfile; onValueChanged: v => SettingsData.setHyprlandInputAccelProfile(v) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Follow Mouse"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "0 = disabled, 1 = focus on hover, 2 = focus + warp"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandInputFollowMouse; minimum: 0; maximum: 2; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandInputFollowMouse(v) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Follow Mouse Threshold"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Cursor movement required to trigger focus-on-hover"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandInputFollowMouseThreshold; minimum: 0; maximum: 200; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandInputFollowMouseThreshold(v) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Per-Device Rotation
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: deviceSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: deviceSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header + Refresh button
                    Row {
                        width: parent.width; spacing: Theme.spacingM

                        Row {
                            spacing: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            EHIcon { name: "rotate_right"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                StyledText { text: "Per-Device Rotation"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Rotate touch/tablet devices individually (Hyprland 0.52+)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }
                        }

                        Item { width: 1; height: 1; Layout.fillWidth: true }

                        StyledRect {
                            height: 32
                            width: refreshLbl.implicitWidth + Theme.spacingL * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                            border.color: Theme.primary; border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                id: refreshLbl
                                anchors.centerIn: parent
                                text: inputDevicesLoading ? "Refreshing..." : "Refresh"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                            }

                            StateLayer { stateColor: Theme.primary; cornerRadius: parent.radius; onClicked: refreshInputDevices() }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: inputDevicesLoading ? "Loading devices..." : "No input devices found."
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        visible: inputDevicesLoading || inputDevices.length === 0
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingM
                        visible: inputDevices.length > 0

                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            StyledText { text: "Input Device"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHDropdown {
                                width: parent.width
                                text: "Select device"
                                options: inputDevices.map(dev => dev.name)
                                currentValue: selectedInputDevice
                                onValueChanged: v => selectedInputDevice = v
                            }
                            StyledText {
                                text: { var m = inputDevices.find(dev => dev.name === selectedInputDevice); return m ? "Type: " + m.type : "" }
                                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                                visible: selectedInputDevice !== ""
                            }
                        }

                        Column {
                            width: parent.width; spacing: Theme.spacingS
                            visible: selectedInputDevice !== ""
                            StyledText { text: "Rotation"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHDropdown {
                                width: parent.width
                                text: "Rotation"
                                options: ["0°", "90°", "180°", "270°"]
                                currentValue: rotationLabel(SettingsData.getHyprlandInputDeviceRotation(selectedInputDevice))
                                onValueChanged: v => {
                                    if (!selectedInputDevice) return
                                    SettingsData.setHyprlandInputDeviceRotation(selectedInputDevice, parseInt(v, 10))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
