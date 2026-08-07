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
    property var controlCenterLoader: null
    property bool showNetworkIcon: SettingsData.controlCenterShowNetworkIcon
    property bool showBluetoothIcon: SettingsData.controlCenterShowBluetoothIcon
    property bool showAudioIcon: SettingsData.controlCenterShowAudioIcon
    property bool showMicIcon: SettingsData.controlCenterShowMicIcon
    property real widgetHeight: 40
    property real barHeight: 48
    property bool isBarVertical: SettingsData.minipanelPosition === "left" || SettingsData.minipanelPosition === "right"
    readonly property real scaleFactor: widgetHeight / 40
    readonly property real horizontalPadding: SettingsData.minipanelNoBackground ? 0 : 8 * scaleFactor
    property bool _pendingTriggerPosition: false
    property real _pendingTriggerX: 0
    property real _pendingTriggerY: 0
    property real _pendingTriggerWidth: 0
    property string _pendingTriggerSection: "minipanel"
    property var _pendingTriggerScreen: null

    signal clicked()

    width: isBarVertical ? widgetHeight : (controlIndicatorsRow.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (controlIndicatorsColumn.implicitHeight + horizontalPadding * 2) : widgetHeight

    function applyTriggerPosition(target) {
        if (!target || !target.setTriggerPosition) {
            return
        }
        // Set bar properties for proper positioning
        const barPos = SettingsData.minipanelPosition;
        const barHeight = SettingsData.miniPanelHeight * (SettingsData.miniPanelScale || 1);
        const margin = (barPos === "bottom" && !isBarVertical) ? (SettingsData.miniPanelTopMargin || 0) : 0;
        const effectiveBarHeight = barHeight + margin;
        target.barPosition = barPos;
        target.barThickness = effectiveBarHeight;
        // Pass auto-fit width setting to the popup for proper positioning
        const autoFitValue = SettingsData.miniPanelAutoFit;
        target.autoFitWidth = autoFitValue;
        target.autoFitWidth = autoFitValue;
        console.log(`[ControlCenterButton] After setting, target.autoFitWidth = ${target.autoFitWidth}`);
        console.log(`[ControlCenterButton] Calling setTriggerPosition: (${_pendingTriggerX}, ${_pendingTriggerY}), width=${_pendingTriggerWidth}, section="${_pendingTriggerSection}"`);
        target.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, _pendingTriggerScreen)
        _pendingTriggerPosition = false
    }

    onPopupTargetChanged: {
        if (_pendingTriggerPosition) {
            applyTriggerPosition(popupTarget)
        }
    }
    radius: SettingsData.minipanelNoBackground ? 0 : Theme.widgetRadius * scaleFactor
    color: {
        if (SettingsData.minipanelNoBackground) {
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
            if (root.controlCenterLoader) {
                const wasActive = root.controlCenterLoader.active
                root.controlCenterLoader.active = true
                if (root.controlCenterLoader.item) {
                    const pos = parent.mapToItem(null, 0, 0);
                    const currentScreen = parentScreen || Screen;

                    root.controlCenterLoader.item.parentScreen = currentScreen
                    root.controlCenterLoader.item.barPosition = SettingsData.miniPanelPosition || "top"
                    root.controlCenterLoader.item.barThickness = (SettingsData.miniPanelHeight || 48) * (SettingsData.miniPanelScale || 1)
                    root.controlCenterLoader.item.triggerX = pos.x
                    root.controlCenterLoader.item.triggerY = pos.y
                    root.controlCenterLoader.item.triggerWidth = width

                    if (!wasActive)
                        root.controlCenterLoader.item.open()
                    else
                        root.controlCenterLoader.item.toggle()
                }
            }
            root.clicked();
        }
    }


}
