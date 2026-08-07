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
    property real widgetHeight: 30
    property real barHeight: 48
    property string barPosition: "top"  // Accept bar position from parent
    property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))

    signal clicked()

    property bool isHovered: controlCenterArea.containsMouse
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    onIsHoveredChanged: {
        if (isHovered) {
            exitAnimation.stop()
            if (!bounceAnimation.running) bounceAnimation.restart()
        } else {
            bounceAnimation.stop()
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: bounceAnimation
        running: false
        NumberAnimation { target: translateY; property: "y"; to: -root.spx(10); duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: translateY; property: "y"; to: -root.spx(8);  duration: 120; easing.type: Easing.InCubic }
    }

    NumberAnimation {
        id: exitAnimation
        running: false
        target: translateY; property: "y"; to: 0
        duration: 150
        easing.type: Easing.OutCubic
    }

    width: isBarVertical ? widgetHeight : (controlIndicatorsRow.implicitWidth + horizontalPadding * 2)
    height: isBarVertical ? (controlIndicatorsColumn.implicitHeight + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = controlCenterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    transform: Translate { id: translateY; y: 0 }

    Row {
        id: controlIndicatorsRow
        visible: !isBarVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
            
        }

        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showAudioIcon

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
                size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
                color: Theme.surfaceText
                anchors.centerIn: parent
                
            }

            MouseArea {
                id: audioWheelArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: function(wheelEvent) {
                    let delta = wheelEvent.angleDelta.y;
                    let currentVolume = (AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.volume * 100) || 0;
                    let newVolume;
                    if (delta > 0) {
                        newVolume = Math.min(100, currentVolume + 5);
                    } else {
                        newVolume = Math.max(0, currentVolume - 5);
                    }
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = false;
                        AudioService.sink.audio.volume = newVolume / 100;
                        AudioService.volumeChanged();
                    }
                    wheelEvent.accepted = true;
                }
            }

        }

        Rectangle {
            width: micIcon.implicitWidth + 4
            height: micIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showMicIcon && PrivacyService.microphoneActive

            EHIcon {
                id: micIcon

                name: {
                    if (AudioService.source && AudioService.source.audio) {
                        return AudioService.source.audio.muted ? "mic_off" : "mic";
                    }
                    return "mic";
                }
                size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
                color: {
                    if (AudioService.source && AudioService.source.audio) {
                        return AudioService.source.audio.muted ? Theme.outlineButton : Theme.primary;
                    }
                    return Theme.primary;
                }
                anchors.centerIn: parent
                
            }

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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
            color: controlCenterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.showNetworkIcon && !root.showBluetoothIcon && !root.showAudioIcon && (!root.showMicIcon || !PrivacyService.microphoneActive)
            
        }
    }
    
    Column {
        id: controlIndicatorsColumn
        visible: isBarVertical
        anchors.centerIn: parent
        spacing: Theme.spacingXS

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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
            color: BluetoothService.enabled ? Theme.primary : Theme.outlineButton
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showBluetoothIcon && BluetoothService.available && BluetoothService.enabled
            
        }

        Rectangle {
            width: audioIconVertical.implicitWidth + 4
            height: audioIconVertical.implicitHeight + 4
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showAudioIcon

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
                size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
                color: Theme.surfaceText
                anchors.centerIn: parent
                
            }

            MouseArea {
                id: audioWheelAreaVertical

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onWheel: function(wheelEvent) {
                    let delta = wheelEvent.angleDelta.y;
                    let currentVolume = (AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.volume * 100) || 0;
                    let newVolume;
                    if (delta > 0) {
                        newVolume = Math.min(100, currentVolume + 5);
                    } else {
                        newVolume = Math.max(0, currentVolume - 5);
                    }
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = false;
                        AudioService.sink.audio.volume = newVolume / 100;
                        AudioService.volumeChanged();
                    }
                    wheelEvent.accepted = true;
                }
            }
        }

        Rectangle {
            width: micIconVertical.implicitWidth + 4
            height: micIconVertical.implicitHeight + 4
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showMicIcon && PrivacyService.microphoneActive

            EHIcon {
                id: micIconVertical

                name: {
                    if (AudioService.source && AudioService.source.audio) {
                        return AudioService.source.audio.muted ? "mic_off" : "mic";
                    }
                    return "mic";
                }
                size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
                color: {
                    if (AudioService.source && AudioService.source.audio) {
                        return AudioService.source.audio.muted ? Theme.outlineButton : Theme.primary;
                    }
                    return Theme.primary;
                }
                anchors.centerIn: parent
                
            }

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
            size: Math.min(Theme.iconSize - 8, widgetHeight - 8)
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
        onClicked: root.clicked()
    }
}
