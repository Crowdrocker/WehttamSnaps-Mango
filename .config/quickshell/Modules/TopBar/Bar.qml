import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: topbar

    WlrLayershell.namespace: "quickshell:bar:blur"

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property var modelData
    screen: modelData
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 32
    implicitWidth: 32

    Rectangle {
        id: bar
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        radius: 0
        border.color: "#333333"
        border.width: 0
        layer.enabled: true
    }
}