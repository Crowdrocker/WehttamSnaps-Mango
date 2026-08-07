import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common

Item {
    property string colorOverride: ""
    property real brightnessOverride: 0.5
    property real contrastOverride: 1

    readonly property bool hasColorOverride: colorOverride !== ""

    property string resolvedSource: ""
    property bool isCachyOS: false

    IconImage {
        id: iconImg
        anchors.fill: parent
        visible: !parent.isCachyOS && parent.resolvedSource !== ""
        source: parent.resolvedSource
        smooth: true
        asynchronous: true
    }

    Image {
        id: directImg
        anchors.fill: parent
        visible: parent.isCachyOS && parent.resolvedSource !== ""
        source: parent.resolvedSource
        sourceSize.width:  parent.width
        sourceSize.height: parent.height
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release && echo \"$ID|$LOGO\""]

        stdout: StdioCollector {
            onStreamFinished: () => {
                                  const parts = text.trim().split("|")
                                  const id = parts[0]
                                  const logo = parts[1] || ""
                                  if (id === "cachyos") {
                                      isCachyOS = true
                                      resolvedSource = "file:///usr/share/icons/cachyos.svg"
                                  } else if (logo !== "") {
                                      isCachyOS = false
                                      resolvedSource = Quickshell.iconPath(logo, true)
                                  }
                              }
        }
    }

    layer.enabled: hasColorOverride
    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: colorOverride
        brightness: brightnessOverride
        contrast: contrastOverride
    }
}
