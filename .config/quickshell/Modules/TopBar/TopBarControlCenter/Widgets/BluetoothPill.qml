import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    // Do NOT override horizontalPadding / contentSpacing — use CompoundPill defaults.

    property var primaryDevice: {
        if (!BluetoothService.adapter?.devices) return null
        for (let d of [...BluetoothService.adapter.devices.values.filter(
                dev => dev && (dev.paired || dev.trusted))]) {
            if (d?.connected) return d
        }
        return null
    }

    iconName: {
        if (!BluetoothService.available) return "bluetooth_disabled"
        if (!BluetoothService.adapter?.enabled) return "bluetooth_disabled"
        if (primaryDevice) return BluetoothService.getDeviceIcon(primaryDevice)
        return "bluetooth"
    }

    iconColor: Theme.primary
    isActive: !!(BluetoothService.available && BluetoothService.adapter?.enabled)
    showExpandArea: BluetoothService.available

    primaryText: {
        if (!BluetoothService.available) return "Bluetooth"
        if (!BluetoothService.adapter) return "No adapter"
        return BluetoothService.adapter.enabled ? "Bluetooth" : "Bluetooth"
    }

    secondaryText: {
        if (!BluetoothService.available) return "No adapters found"
        if (!BluetoothService.adapter?.enabled) return "Disabled"
        if (primaryDevice)
            return primaryDevice.name || primaryDevice.alias || primaryDevice.deviceName || "Connected"
        return "No devices connected"
    }

    onToggled: {
        if (BluetoothService.available && BluetoothService.adapter)
            BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
    }
}
