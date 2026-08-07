import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: hyprlandCursorTab

    property var parentModal: null

    readonly property bool isHyprland: typeof CompositorService !== "undefined" && CompositorService.isHyprland

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
            // CATEGORY 1: Hardware & Performance
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: hwSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: hwSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "memory"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Hardware & Performance"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "Enable Hyprcursor"; description: "Use Hyprland's cursor engine when available"; checked: SettingsData.hyprlandCursorEnableHyprcursor; onToggled: checked => SettingsData.setHyprlandCursorEnableHyprcursor(checked) }

                    // No Hardware Cursors
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - hwCursorsDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "No Hardware Cursors"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "0 = auto, 1 = off, 2 = on"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        EHDropdown {
                            id: hwCursorsDropdown; width: 120
                            text: "Mode"; options: ["0", "1", "2"]
                            currentValue: String(SettingsData.hyprlandCursorNoHardwareCursors)
                            onValueChanged: v => SettingsData.setHyprlandCursorNoHardwareCursors(parseInt(v, 10))
                        }
                    }

                    // Use CPU Buffer
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - cpuBufDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Use CPU Buffer"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Force CPU-backed cursor buffers (useful on some GPUs). 0 = auto, 1 = off, 2 = on"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                        EHDropdown {
                            id: cpuBufDropdown; width: 120
                            text: "Mode"; options: ["0", "1", "2"]
                            currentValue: String(SettingsData.hyprlandCursorUseCpuBuffer)
                            onValueChanged: v => SettingsData.setHyprlandCursorUseCpuBuffer(parseInt(v, 10))
                        }
                    }

                    // No Break FS VRR
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - noBreakDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "No Break FS VRR"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Avoid VRR framerate spikes on cursor movement. 0 = off, 1 = on, 2 = auto"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; width: parent.width }
                        }
                        EHDropdown {
                            id: noBreakDropdown; width: 120
                            text: "Mode"; options: ["0", "1", "2"]
                            currentValue: String(SettingsData.hyprlandCursorNoBreakFsVrr)
                            onValueChanged: v => SettingsData.setHyprlandCursorNoBreakFsVrr(parseInt(v, 10))
                        }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Min Refresh Rate"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Minimum refresh rate when no_break_fs_vrr is active"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandCursorMinRefreshRate; minimum: 1; maximum: 240; unit: "Hz"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandCursorMinRefreshRate(v) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Hotspot Padding"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Padding between screen edges and the cursor hotspot"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.hyprlandCursorHotspotPadding; minimum: 0; maximum: 20; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandCursorHotspotPadding(v) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Warping
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: warpSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: warpSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "open_with"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Warping"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle { width: parent.width; text: "No Warps"; description: "Prevent cursor warping during focus/keybind changes"; checked: SettingsData.hyprlandCursorNoWarps; onToggled: checked => SettingsData.setHyprlandCursorNoWarps(checked) }
                    EHToggle { width: parent.width; text: "Persistent Warps"; description: "Return cursor to its last position inside the window when refocused"; checked: SettingsData.hyprlandCursorPersistentWarps; onToggled: checked => SettingsData.setHyprlandCursorPersistentWarps(checked) }
                    EHToggle { width: parent.width; text: "Warp Back After Non-Mouse Input"; description: "Return cursor to prior position after keyboard or other input"; checked: SettingsData.hyprlandCursorWarpBackAfterNonMouseInput; onToggled: checked => SettingsData.setHyprlandCursorWarpBackAfterNonMouseInput(checked) }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - warpWsDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Warp on Workspace Change"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "0 = off, 1 = on, 2 = force"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        EHDropdown { id: warpWsDropdown; width: 120; text: "Mode"; options: ["0", "1", "2"]; currentValue: String(SettingsData.hyprlandCursorWarpOnChangeWorkspace); onValueChanged: v => SettingsData.setHyprlandCursorWarpOnChangeWorkspace(parseInt(v, 10)) }
                    }

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        Column {
                            width: parent.width - warpSpecialDropdown.width - Theme.spacingM
                            spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                            StyledText { text: "Warp on Special Workspace"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "0 = off, 1 = on, 2 = force"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        EHDropdown { id: warpSpecialDropdown; width: 120; text: "Mode"; options: ["0", "1", "2"]; currentValue: String(SettingsData.hyprlandCursorWarpOnToggleSpecial); onValueChanged: v => SettingsData.setHyprlandCursorWarpOnToggleSpecial(parseInt(v, 10)) }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Default Monitor"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Monitor name to place cursor on startup. Leave empty for auto"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHTextField { width: parent.width; height: 36; text: SettingsData.hyprlandCursorDefaultMonitor; placeholderText: "leave empty to auto"; onEditingFinished: SettingsData.setHyprlandCursorDefaultMonitor(text) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Visibility
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: visSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: visSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "visibility"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Visibility"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Inactive Timeout"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Seconds of inactivity before hiding. 0 disables hiding"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandCursorInactiveTimeout); minimum: 0; maximum: 60; unit: "s"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandCursorInactiveTimeout(v) }
                    }

                    EHToggle { width: parent.width; text: "Hide on Key Press"; description: "Hide cursor until mouse moves after any key press"; checked: SettingsData.hyprlandCursorHideOnKeyPress; onToggled: checked => SettingsData.setHyprlandCursorHideOnKeyPress(checked) }
                    EHToggle { width: parent.width; text: "Hide on Touch"; description: "Hide cursor when touch input is used last"; checked: SettingsData.hyprlandCursorHideOnTouch; onToggled: checked => SettingsData.setHyprlandCursorHideOnTouch(checked) }
                    EHToggle { width: parent.width; text: "Hide on Tablet"; description: "Hide cursor when tablet input is used last"; checked: SettingsData.hyprlandCursorHideOnTablet; onToggled: checked => SettingsData.setHyprlandCursorHideOnTablet(checked) }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 4: Zoom
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: zoomSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1
                visible: isHyprland

                Column {
                    id: zoomSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "zoom_in"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Zoom"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Zoom Factor"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Magnification amount around the cursor"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        EHSlider { width: parent.width; height: 24; value: Math.round(SettingsData.hyprlandCursorZoomFactor * 100); minimum: 100; maximum: 400; unit: "%"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderDragFinished: v => SettingsData.setHyprlandCursorZoomFactor(v / 100) }
                    }

                    EHToggle { width: parent.width; text: "Zoom Rigid"; description: "Keep cursor centered when zoomed"; checked: SettingsData.hyprlandCursorZoomRigid; onToggled: checked => SettingsData.setHyprlandCursorZoomRigid(checked) }
                    EHToggle { width: parent.width; text: "Detached Camera"; description: "Move camera only when cursor reaches screen edge"; checked: SettingsData.hyprlandCursorZoomDetachedCamera; onToggled: checked => SettingsData.setHyprlandCursorZoomDetachedCamera(checked) }
                    EHToggle { width: parent.width; text: "Disable AA"; description: "Disable antialiasing while zoomed for a pixelated look"; checked: SettingsData.hyprlandCursorZoomDisableAa; onToggled: checked => SettingsData.setHyprlandCursorZoomDisableAa(checked) }
                }
            }
        }
    }
}
