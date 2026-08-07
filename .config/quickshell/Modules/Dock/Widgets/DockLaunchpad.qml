import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property real widgetHeight:  40
    property var  parentScreen:  null
    property real padding:       1
    property bool pillEnabled: SettingsData.dockLaunchpadPillEnabled
    // Match DockTrashBin behavior: compute size from dock icon slider.
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    readonly property real iconPx: (SettingsData.dockIconSize || 1) * uiScale
    readonly property real s: widgetHeight / 30
    readonly property bool isHovered: mouseArea.containsMouse

    width:  pillEnabled ? root.iconPx + root.spx(16) : root.iconPx
    height: root.widgetHeight

    Rectangle {
        id: pillBackground
        anchors.fill: parent
        visible: root.pillEnabled
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Theme.widgetTransparency)
        radius: Theme.widgetRadius
        clip: true
    }

    // ── Hover background pill ─────────────────────────────────────────────────
    Rectangle {
        id: hoverBg
        anchors.centerIn: parent
        width:  parent.width  - 4 * root.s
        height: parent.height - 4 * root.s
        radius: Theme.widgetRadius * 1.2
        color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0)
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    // ── Icon — attached to translate so the bounce actually moves it ──────────
    Image {
        id: launchpadIcon
        anchors.centerIn: parent
        width:    root.iconPx
        height:   root.iconPx
        source:   Theme.isLightMode
                  ? Qt.resolvedUrl("../../../assets/Light_Launchpad.png")
                  : Qt.resolvedUrl("../../../assets/Dark_Launchpad.png")
        smooth:   true
        fillMode: Image.PreserveAspectFit
        mipmap:   true
        antialiasing: true

        transform: Translate {
            id: iconTransform
            y: 0
        }
    }

    // ── Bounce on hover ───────────────────────────────────────────────────────
    onIsHoveredChanged: {
        if (isHovered) {
            exitAnimation.stop()
            hoverBg.color = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
            if (!bounceAnimation.running) bounceAnimation.restart()
        } else {
            bounceAnimation.stop()
            hoverBg.color = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0)
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: bounceAnimation
        running: false

        NumberAnimation {
            target:   iconTransform
            property: "y"
            to:       -7 * root.s
            duration: Anims.durShort
            easing.type:        Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }
        NumberAnimation {
            target:   iconTransform
            property: "y"
            to:       -5 * root.s
            duration: Anims.durShort
            easing.type:        Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    NumberAnimation {
        id: exitAnimation
        running:  false
        target:   iconTransform
        property: "y"
        to:       0
        duration: Anims.durShort
        easing.type:        Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }

    // ── Click ─────────────────────────────────────────────────────────────────
    function getLaunchpadLoader() {
        let current = root
        while (current) {
            if (current.launchpadLoader) return current.launchpadLoader
            current = current.parent
        }
        if (typeof launchpadLoader !== "undefined") return launchpadLoader
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

    MouseArea {
        id: mouseArea
        anchors.fill:    parent
        hoverEnabled:    true
        cursorShape:     Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked:       root.openLaunchpad()
    }
}
