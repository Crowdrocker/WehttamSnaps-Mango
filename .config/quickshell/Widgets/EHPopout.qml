import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root
    screen: triggerScreen

    WlrLayershell.namespace: "quickshell:dock:blur"

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    
    property real basePopupWidth: 720
    property real basePopupHeight: 540
    
    property real popupWidth: basePopupWidth
    property real popupHeight: basePopupHeight
    
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 80
    property real triggerHeight: 48
    property string triggerSection: ""
    property var triggerScreen: null
    
    property string barPosition: "bottom"
    property real barThickness: 48
    property real barSpacing: 4
    property real bottomGap: 0
    property bool autoFitWidth: false
    
    property real topBarThickness: 0
    property real bottomBarThickness: 0
    property bool enableAdaptiveHeight: true
    
    property real popupGap: 8
    property bool shouldBeVisible: false
    
    property color backgroundColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.95)
    property real borderWidth: 1
    property color borderColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    property int animationDuration: Theme.mediumDuration || 200
    
    property bool disableBackgroundClick: false
    
    property point calculatedPosition: Qt.point(0, 0)
    property real calculatedScale: 1.0
    property var lastPositionResult: null
    
    signal opened
    signal popoutClosed
    signal backgroundClicked

    function setTriggerPosition(x, y, width, height, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerHeight = height || barThickness
        triggerSection = section || ""
        triggerScreen = screen
        
        if (shouldBeVisible) {
            updatePosition()
        }
    }
    
    function updatePosition() {
        const screen = triggerScreen || root.screen
        
        if (!screen) {
            return
        }
        
        const scale = Appearance.combinedScale
        const scaledWidth = basePopupWidth * scale
        const scaledHeight = basePopupHeight * scale
        const scaledGap = popupGap * scale
        
        const screenW = screen.width || 1920
        const screenH = screen.height || 1080
        
        let x, y
        
        const triggerScreenRelX = triggerX - (screen.x || 0)
        const triggerScreenRelY = triggerY - (screen.y || 0)
        const widgetCenterX = triggerScreenRelX + (triggerWidth / 2)
        const widgetCenterY = triggerScreenRelY + (triggerHeight / 2)
        
        x = widgetCenterX - (scaledWidth / 2)
        
        const topBarSpace = topBarThickness || 0
        const bottomBarSpace = bottomBarThickness || 0
        const extraPadding = 16 * scale
        const maxAvailableHeight = screenH - topBarSpace - bottomBarSpace - scaledGap * 2 - extraPadding * 2
        
        let finalHeight = scaledHeight
        if (enableAdaptiveHeight && finalHeight > maxAvailableHeight) {
            finalHeight = maxAvailableHeight
        }
        
        if (barPosition === "top") {
            y = triggerScreenRelY + triggerHeight + scaledGap
            y = Math.min(y, screenH - finalHeight - scaledGap - bottomBarSpace - extraPadding)
        } else if (barPosition === "bottom") {
            y = triggerScreenRelY - finalHeight - scaledGap
            y = Math.max(y, scaledGap + topBarSpace + extraPadding)
        } else if (barPosition === "left") {
            y = widgetCenterY - (finalHeight / 2)
            y = Math.max(scaledGap, Math.min(screenH - finalHeight - scaledGap, y))
            x = triggerScreenRelX + triggerWidth + scaledGap
            x = Math.min(x, screenW - scaledWidth - scaledGap)
        } else if (barPosition === "right") {
            y = widgetCenterY - (finalHeight / 2)
            y = Math.max(scaledGap, Math.min(screenH - finalHeight - scaledGap, y))
            x = triggerScreenRelX - scaledWidth - scaledGap
            x = Math.max(x, scaledGap)
        }
        
        // Screen-relative X clamp for top/bottom bars
        if (barPosition === "top" || barPosition === "bottom") {
            x = Math.max(scaledGap, Math.min(screenW - scaledWidth - scaledGap, x))
        }
        
        popupWidth = scaledWidth
        popupHeight = finalHeight
        calculatedPosition = Qt.point(x, y)
        calculatedScale = scale
    }
    
    function open() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        updatePosition()
        opened()
    }
    
    function close() {
        shouldBeVisible = false
        closeTimer.restart()
    }
    
    function toggle() {
        if (shouldBeVisible) {
            close()
        } else {
            open()
        }
    }

    onTriggerXChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onTriggerYChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onTriggerScreenChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onBarPositionChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onBarThicknessChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onBasePopupWidthChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    onBasePopupHeightChanged: if (shouldBeVisible) Qt.callLater(updatePosition)
    
    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            updatePosition()
        }
    }
    
    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                popoutClosed()
            }
        }
    }
    
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: shouldBeVisible ? -1 : 0
    WlrLayershell.keyboardFocus: shouldBeVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    
    anchors {
        top: true
        left: true
    }
    
    margins {
        left: calculatedPosition.x
        top: calculatedPosition.y
    }
    
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    visible: shouldBeVisible
    
    MouseArea {
        anchors.fill: parent
        enabled: shouldBeVisible && visible && !root.disableBackgroundClick
        z: shouldBeVisible ? -1 : -2
        propagateComposedEvents: true
        
        onClicked: mouse => {
            if (!shouldBeVisible || root.disableBackgroundClick) {
                mouse.accepted = false
                return
            }
            
            var localPos = mapToItem(contentContainer, mouse.x, mouse.y)
            if (localPos.x < 0 || localPos.x > contentContainer.width || 
                localPos.y < 0 || localPos.y > contentContainer.height) {
                backgroundClicked()
                close()
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }
    }
    
    Item {
        id: contentContainer
        anchors.fill: parent
        z: 10
        
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9
        
        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
        }
        
        Rectangle {
            id: backgroundRect
            anchors.fill: parent
            color: root.backgroundColor
            radius: 14
            border.color: root.borderColor
            border.width: root.borderWidth
            antialiasing: true
        }
        
        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }
        
        Item {
            anchors.fill: parent
            focus: true
            
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    close()
                    event.accepted = true
                }
            }
            
            Component.onCompleted: forceActiveFocus()
            onVisibleChanged: if (visible) forceActiveFocus()
        }
    }
}
