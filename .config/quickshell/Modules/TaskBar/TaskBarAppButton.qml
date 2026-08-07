import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    clip: false
    property var appData
    property var contextMenu: null
    property var taskBarApps: null
    property int index: -1
    property var cachedDesktopEntry: appData ? DesktopEntries.heuristicLookup(appData.appId) : null
    property bool longPressing: false
    property bool dragging: false
    property point dragStartPos: Qt.point(0, 0)
    property point dragOffset: Qt.point(0, 0)
    property real dragAxisOffset: 0
    property int targetIndex: -1
    property int originalIndex: -1
    property bool isHovered: mouseArea.containsMouse && !dragging
    property bool isMinimized: {
        const toplevel = getToplevelObject()
        if (!toplevel) {
            return false
        }
        return toplevel.minimized || false
    }
    property bool isWindowFocused: {
        if (!appData || appData.type !== "window") {
            return false
        }
        const toplevel = getToplevelObject()
        if (!toplevel) {
            return false
        }
        return toplevel.activated
    }

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

    // Match TaskBar scaling: global UI × taskbar scale.
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    width: parent ? parent.width : spx(36)
    height: parent ? parent.height : spx(36)

    transform: Translate { id: translateY; y: 0 }

    function getToplevelObject() {
        if (!appData || (appData.type !== "window" && appData.type !== "grouped" && appData.type !== "pinned")) {
            return null
        }

        if (appData.type === "grouped") {
            if (appData.windows && appData.windows.length > 0) {
                for (var i = 0; i < appData.windows.length; i++) {
                    if (appData.windows[i].toplevel && appData.windows[i].toplevel.activated) {
                        return appData.windows[i].toplevel
                    }
                }
                return appData.windows[0].toplevel
            }
            return null
        }

        if (appData.type === "pinned" && appData.windows && appData.windows.length > 0) {
            for (var i = 0; i < appData.windows.length; i++) {
                if (appData.windows[i].toplevel && appData.windows[i].toplevel.activated) {
                    return appData.windows[i].toplevel
                }
            }
            return appData.windows[0].toplevel
        }

        const sortedToplevels = CompositorService.sortedToplevels
        if (!sortedToplevels) {
            return null
        }

        if (appData.uniqueId) {
            for (var i = 0; i < sortedToplevels.length; i++) {
                const toplevel = sortedToplevels[i]
                const checkId = toplevel.title + "|" + (toplevel.appId || "") + "|" + i
                if (checkId === appData.uniqueId) {
                    return toplevel
                }
            }
        }

        if (appData.windowId !== undefined && appData.windowId !== null && appData.windowId >= 0) {
            if (appData.windowId < sortedToplevels.length) {
                return sortedToplevels[appData.windowId]
            }
        }

        return null
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
        border.width: 2
        border.color: Theme.primary
        visible: dragging
        z: -1
    }

    Rectangle {
        id: dragIndicator
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
        border.width: 3
        border.color: Theme.primary
        visible: dragging
        z: 10
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
        }
        
        scale: dragging ? 1.15 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        
        opacity: dragging ? 0.85 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        
        SequentialAnimation on opacity {
            running: dragging
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.85; duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: {
            if (isWindowFocused) {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            }
            if (isHovered) {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
            }
            return "transparent"
        }
        border.width: isWindowFocused ? 1 : 0
        border.color: Theme.primary
        visible: !dragging
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    Timer {
        id: longPressTimer

        interval: 500
        repeat: false
        onTriggered: {
            if (appData && appData.isPinned) {
                longPressing = true
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => {
                       if (mouse.button === Qt.LeftButton && appData && appData.isPinned) {
                           dragStartPos = Qt.point(mouse.x, mouse.y)
                           longPressTimer.start()
                       }
                   }
        onReleased: mouse => {
                        longPressTimer.stop()

                        const wasDragging = dragging
                        const didReorder = wasDragging && targetIndex >= 0 && targetIndex !== originalIndex && taskBarApps

                        if (didReorder)
                            taskBarApps.movePinnedApp(originalIndex, targetIndex)

                        longPressing = false
                        dragging = false
                        dragOffset = Qt.point(0, 0)
                        dragAxisOffset = 0
                        targetIndex = -1
                        originalIndex = -1

                        if (taskBarApps && !didReorder) {
                            taskBarApps.draggedIndex = -1
                            taskBarApps.dropTargetIndex = -1
                        }

                        if (wasDragging || mouse.button !== Qt.LeftButton)
                            return
                    }
        onPositionChanged: mouse => {
                               if (longPressing && !dragging) {
                                   const distance = Math.sqrt(Math.pow(mouse.x - dragStartPos.x, 2) + Math.pow(mouse.y - dragStartPos.y, 2))
                                   if (distance > 5) {
                                       dragging = true
                                       targetIndex = index
                                       originalIndex = index
                                       if (taskBarApps) {
                                           taskBarApps.draggedIndex = index
                                           taskBarApps.dropTargetIndex = index
                                       }
                                   }
                               }
                               
                               if (!dragging || !taskBarApps)
                                   return

                               // Calculate offset along horizontal axis
                               const axisOffset = mouse.x - dragStartPos.x
                               dragAxisOffset = axisOffset
                               dragOffset = Qt.point(mouse.x - dragStartPos.x, mouse.y - dragStartPos.y)

                               // Calculate slot-based target index
                               const spacing = taskBarApps ? taskBarApps.iconSpacing : 4
                               const itemSize = root.width + spacing
                               const slotOffset = Math.round(axisOffset / itemSize)
                               const newTargetIndex = Math.max(0, Math.min(taskBarApps.pinnedAppCount - 1, originalIndex + slotOffset))

                               if (newTargetIndex !== targetIndex) {
                                   targetIndex = newTargetIndex
                                   taskBarApps.dropTargetIndex = newTargetIndex
                               }
                           }
        onClicked: mouse => {
                       if (!appData || longPressing) {
                           return
                       }

                       if (mouse.button === Qt.LeftButton) {
                           if (appData.type === "pinned") {
                               if (appData.isRunning && appData.windows && appData.windows.length > 0) {
                                   const toplevel = getToplevelObject()
                                   if (toplevel) {
                                       toplevel.activate()
                                   }
                               } else {
                                   if (appData && appData.appId) {
                                       const desktopEntry = DesktopEntries.heuristicLookup(appData.appId)
                                       if (desktopEntry) {
                                           AppUsageHistoryData.addAppUsage({
                                                                               "id": appData.appId,
                                                                               "name": desktopEntry.name || appData.appId,
                                                                               "icon": desktopEntry.icon || "",
                                                                               "exec": desktopEntry.exec || "",
                                                                               "comment": desktopEntry.comment || ""
                                                                           })
                                       }
                                       SessionService.launchDesktopEntry(desktopEntry)
                                   }
                               }
                           } else if (appData.type === "window") {
                               const toplevel = getToplevelObject()
                               if (toplevel) {
                                   toplevel.activate()
                               }
                           } else if (appData.type === "grouped") {
                               const toplevel = getToplevelObject()
                               if (toplevel) {
                                   toplevel.activate()
                               }
                           }
                       } else if (mouse.button === Qt.MiddleButton) {
                           if (appData && appData.appId) {
                               const desktopEntry = DesktopEntries.heuristicLookup(appData.appId)
                               if (desktopEntry) {
                                   AppUsageHistoryData.addAppUsage({
                                                                       "id": appData.appId,
                                                                       "name": desktopEntry.name || appData.appId,
                                                                       "icon": desktopEntry.icon || "",
                                                                       "exec": desktopEntry.exec || "",
                                                                       "comment": desktopEntry.comment || ""
                                                                   })
                               }
                             SessionService.launchDesktopEntry(desktopEntry)
                           }
                       } else if (mouse.button === Qt.RightButton) {
                           if (contextMenu && typeof contextMenu.showForButton === "function") {
                               contextMenu.showForButton(root, appData, 40, cachedDesktopEntry)
                           }
                       }
                   }
    }

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            id: iconTransform
            x: {
                if (dragging)
                    return dragAxisOffset
                return 0
            }
        }

        Item {
            id: iconContainer
            anchors.centerIn: parent
            width: root.width
            height: root.height
            layer.enabled: SettingsData.systemIconTinting

            Image {
                id: iconImg

                anchors.centerIn: parent
                width: root.width * 0.8
                height: root.height * 0.8
                sourceSize.width: root.width
                sourceSize.height: root.height
                fillMode: Image.PreserveAspectFit
                source: {
                    if (!appData || appData.appId === "__SEPARATOR__") {
                        return ""
                    }
                    const moddedId = Paths.moddedAppId(appData.appId)
                    if (moddedId.toLowerCase().includes("steam_app")) {
                        return ""
                    }
                    const desktopEntry = DesktopEntries.heuristicLookup(moddedId)
                    return desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : ""
                }
                mipmap: true
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }

            layer.effect: MultiEffect {
                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                colorizationColor: Theme.primary
            }
        }

        EHIcon {
            anchors.centerIn: parent
            size: root.width * 0.8
            name: "sports_esports"
            color: Theme.surfaceText
            visible: {
                if (!appData || !appData.appId || appData.appId === "__SEPARATOR__") {
                    return false
                }
                const moddedId = Paths.moddedAppId(appData.appId)
                return moddedId.toLowerCase().includes("steam_app")
            }
        }

        Rectangle {
            width: root.width * 0.8
            height: root.height * 0.8
            anchors.centerIn: parent
            visible: iconImg.status !== Image.Ready && !iconImg.visible
            color: Theme.surfaceLight
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.primarySelected

            Text {
                anchors.centerIn: parent
                text: {
                    if (!appData || !appData.appId) {
                        return "?"
                    }

                    const desktopEntry = DesktopEntries.heuristicLookup(appData.appId)
                    if (desktopEntry && desktopEntry.name) {
                        return desktopEntry.name.charAt(0).toUpperCase()
                    }

                    return appData.appId.charAt(0).toUpperCase()
                }
                font.pixelSize: 14
                color: Theme.primary
                font.weight: Font.Bold
            }
        }

        Rectangle {
            anchors.horizontalCenter: iconContainer.horizontalCenter
            anchors.bottom: iconContainer.bottom
            anchors.bottomMargin: 2
            width: 4
            height: 4
            radius: 2
            visible: appData && (appData.isRunning || appData.type === "window")
            color: {
                if (!appData) {
                    return "transparent"
                }

                if (isMinimized) {
                    return Qt.rgba(1, 0.5, 0, 0.8)
                }

                if (isWindowFocused) {
                    return Theme.primary
                }

                if (appData.isRunning || appData.type === "window") {
                    return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                }

                return "transparent"
            }
        }
    }
}
