import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property var widgetData: null
    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon
    property bool showMicIcon: SettingsData.controlCenterShowMicIcon
    property real widgetHeight: 40
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real scaleFactor: widgetHeight / 40
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : 8 * scaleFactor
    property bool _pendingTriggerPosition: false
    property real _pendingTriggerX: 0
    property real _pendingTriggerY: 0
    property real _pendingTriggerWidth: 0
    property string _pendingTriggerSection: "topbar"
    property var _pendingTriggerScreen: null

    signal clicked()

    width: isBarVertical ? widgetHeight : (controlIndicatorsRow.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (controlIndicatorsColumn.implicitHeight + horizontalPadding * 2) : widgetHeight

    function applyTriggerPosition(target) {
        if (!target || !target.setTriggerPosition) {
            return
        }
        // Set bar properties for proper positioning
        const barPos = SettingsData.topBarPosition;
        const barHeight = SettingsData.topBarHeight * (SettingsData.topBarScale || 1);
        const margin = (barPos === "bottom" && !isBarVertical) ? (SettingsData.topBarTopMargin || 0) : 0;
        const effectiveBarHeight = barHeight + margin;
        console.log(`[ControlCenterButton] Setting bar properties: position="${barPos}", thickness=${barHeight}, margin=${margin}, effective=${effectiveBarHeight}`);
        target.barPosition = barPos;
        target.barThickness = effectiveBarHeight;
        console.log(`[ControlCenterButton] Calling setTriggerPosition: (${_pendingTriggerX}, ${_pendingTriggerY}), width=${_pendingTriggerWidth}, section="${_pendingTriggerSection}"`);
        target.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, _pendingTriggerScreen)
        _pendingTriggerPosition = false
    }

    onPopupTargetChanged: {
        if (_pendingTriggerPosition) {
            applyTriggerPosition(popupTarget)
        }
    }
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius * scaleFactor
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Row {
        id: controlIndicatorsRow
        visible: !isBarVertical
        anchors.centerIn: parent
        spacing: 6 * scaleFactor

        EHIcon {
            id: networkIcon

            name: {
                if (NetworkService.wifiToggling) {
                    return "sync";
                }

                if (NetworkService.networkStatus === "ethernet") {
                    return "lan";
                }

                return NetworkService.wifiSignalIcon;
            }
            size: 20 * scaleFactor
            color: {
                if (NetworkService.wifiToggling) {
                    return Theme.primary;
                }

                return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton;
            }
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showNetworkIcon
            
        }

        EHIcon {
            id: bluetoothIcon

            name: "bluetooth"
            size: 20 * scaleFactor
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
            
        }

        EHIcon {
            id: audioIcon

            name: {
                if (AudioService.sink && AudioService.sink.audio) {
                    if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                        return "volume_off";
                    } else if (AudioService.sink.audio.volume * 100 < 33) {
                        return "volume_down";
                    } else {
                        return "volume_up";
                    }
                }
                return "volume_up";
            }
            size: 20 * scaleFactor
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAudioIcon
            
        }

        EHIcon {
            id: micIcon
            visible: root.showMicIcon && PrivacyService.microphoneActive

            name: {
                if (AudioService.source && AudioService.source.audio) {
                    return AudioService.source.audio.muted ? "mic_off" : "mic";
                }
                return "mic";
            }
            size: 20 * scaleFactor
            color: {
                if (AudioService.source && AudioService.source.audio) {
                    return AudioService.source.audio.muted ? Theme.outlineButton : Theme.primary;
                }
                return Theme.primary;
            }
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                id: micClickArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.toggleMicMute();
                    }
                }
            }
        }

        EHIcon {
            name: "settings"
            size: 20 * scaleFactor
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon && (!root.showMicIcon || !PrivacyService.microphoneActive)
            
        }
    }
    
    Column {
        id: controlIndicatorsColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: 6 * scaleFactor

        EHIcon {
            id: networkIconVertical

            name: {
                if (NetworkService.wifiToggling) {
                    return "sync";
                }

                if (NetworkService.networkStatus === "ethernet") {
                    return "lan";
                }

                return NetworkService.wifiSignalIcon;
            }
            size: 20 * scaleFactor
            color: {
                if (NetworkService.wifiToggling) {
                    return Theme.primary;
                }

                return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.outlineButton;
            }
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showNetworkIcon
            
        }

        EHIcon {
            id: bluetoothIconVertical

            name: "bluetooth"
            size: 20 * scaleFactor
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
            
        }

        EHIcon {
            id: audioIconVertical

            name: {
                if (AudioService.sink && AudioService.sink.audio) {
                    if (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0) {
                        return "volume_off";
                    } else if (AudioService.sink.audio.volume * 100 < 33) {
                        return "volume_down";
                    } else {
                        return "volume_up";
                    }
                }
                return "volume_up";
            }
            size: 20 * scaleFactor
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showAudioIcon
            
        }

        EHIcon {
            id: micIconVertical
            visible: root.showMicIcon && PrivacyService.microphoneActive

            name: {
                if (AudioService.source && AudioService.source.audio) {
                    return AudioService.source.audio.muted ? "mic_off" : "mic";
                }
                return "mic";
            }
            size: 20 * scaleFactor
            color: {
                if (AudioService.source && AudioService.source.audio) {
                    return AudioService.source.audio.muted ? Theme.outlineButton : Theme.primary;
                }
                return Theme.primary;
            }
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
                id: micClickAreaVertical

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.toggleMicMute();
                    }
                }
            }
        }

        EHIcon {
            name: "settings"
            size: 20 * scaleFactor
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon && (!root.showMicIcon || !PrivacyService.microphoneActive)
            
        }
    }

    MouseArea {
        id: controlCenterArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            // Get button rect in screen coordinates (like SystemUpdate does)
            const rect = parent.mapToItem(null, 0, 0, width, height);
            const currentScreen = parentScreen || Screen;

            // Calculate center of button for proper positioning
            let triggerX = rect.x + rect.width / 2; // Center horizontally
            let triggerY = rect.y + rect.height / 2; // Center vertically

            if (isBarVertical) {
                if (SettingsData.topBarPosition === "right") {
                    // For right bar, position popup on the right side of the screen (like SystemUpdate)
                    const screenWidth = currentScreen.width || 2560;
                    triggerX = screenWidth - 210; // Center popup on right side of screen
                }
                // For vertical bars, Y position is already at button center
            } else {
                // For horizontal bars with auto-fit enabled, the bar may not span full width
                // But mapToItem(null, ...) already gives global desktop coordinates
                // So rect.x is already the correct global X position
                console.log(`[ControlCenterButton] Checking auto-fit: topBarAutoFit=${SettingsData.topBarAutoFit}, topBarPosition=${SettingsData.topBarPosition}`);
                if (SettingsData.topBarAutoFit && SettingsData.topBarPosition === "top") {
                    // rect.x from mapToItem(null, ...) is already global, no adjustment needed
                    console.log(`[ControlCenterButton] Auto-fit mode: rect.x=${rect.x}, using as-is`);
                }
            }
            // For horizontal bars, don't adjust triggerY - let the popup positioning handle it

            // For vertical bars, triggerSection indicates screen side
            // For horizontal bars, use "right" to match the button's position
            let triggerSection = isBarVertical ? SettingsData.topBarPosition : "right";

            // Store pending position in case popup isn't loaded yet
            _pendingTriggerX = triggerX;
            _pendingTriggerY = triggerY;
            _pendingTriggerWidth = isBarVertical ? height : width;
            _pendingTriggerSection = triggerSection;
            _pendingTriggerScreen = currentScreen;
            _pendingTriggerPosition = true;

            applyTriggerPosition(popupTarget);
            root.clicked();
        }
    }


}
