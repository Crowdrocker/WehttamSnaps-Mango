import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property real widgetHeight: 40
    property var  parentScreen: null
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    readonly property real iconPx: (SettingsData.taskbarIconSize || 39) * uiScale

    width:  iconPx
    height: iconPx
    color:  "transparent"

    property bool isHovered: launchpadArea.containsMouse

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

    transform: Translate { id: translateY; y: 0 }

    function getLaunchpadLoader() {
        let current = root
        while (current) {
            if (current.launchpadLoader) {
                return current.launchpadLoader
            }
            current = current.parent
        }
        if (typeof launchpadLoader !== "undefined") {
            return launchpadLoader
        }
        return null
    }

    function openLaunchpad() {
        const loader = getLaunchpadLoader()
        if (!loader) return
        loader.active = true
        if (loader.item) {
            loader.item.targetScreen = parentScreen
                || (root.Window && root.Window.window ? root.Window.window.screen : Screen)
            if (loader.item.show) loader.item.show()
        }
    }

    Image {
        id: launchpadIcon
        anchors.centerIn: parent
        width:  root.iconPx
        height: root.iconPx
        source: Theme.isLightMode
                  ? Qt.resolvedUrl("../../../assets/Light_Launchpad.png")
                  : Qt.resolvedUrl("../../../assets/Dark_Launchpad.png")
        smooth: true
        fillMode: Image.PreserveAspectFit
        mipmap: true
        antialiasing: true
    }

    MouseArea {
        id: launchpadArea
        anchors.fill:    parent
        hoverEnabled:    true
        cursorShape:     Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked:       root.openLaunchpad()
    }
}

