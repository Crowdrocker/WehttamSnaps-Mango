import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Details

Item {
    id: root

    property string expandedSection: ""
    property real detailHeight: 250

    Loader {
        id: detailLoader
        width: parent.width
        height: parent.height - Theme.spacingS
        y: Theme.spacingS
        active: parent.height > 0
        sourceComponent: {
            switch (root.expandedSection) {
            case "network":
            case "wifi": return networkDetailComponent
            case "bluetooth": return bluetoothDetailComponent
            case "audioOutput": return audioOutputDetailComponent
            case "audioInput": return audioInputDetailComponent
            case "battery": return batteryDetailComponent
            case "brightnessSlider": return brightnessDetailComponent
            default: return null
            }
        }
        onItemChanged: {
            if (item) {
                Qt.callLater(function() {
                    if (item && item.implicitHeight > 0) {
                        root.detailHeight = item.implicitHeight
                    } else {
                        root.detailHeight = 250
                    }
                })
            } else {
                root.detailHeight = 250
            }
        }
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {}
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryDetailComponent
        BatteryDetail {}
    }

    Component {
        id: brightnessDetailComponent
        BrightnessDetail {}
    }
}