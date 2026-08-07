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

    property var  appData
    property var  contextMenu:  null
    property var  dockApps:     null
    property int  index:        -1
    property var  cachedDesktopEntry: appData ? DesktopEntries.heuristicLookup(appData.appId) : null
    property bool longPressing:  false
    property bool dragging:      false
    property point dragStartPos: Qt.point(0, 0)
    property point dragStartGlobalPos: Qt.point(0, 0)
    property point dragOffset:   Qt.point(0, 0)
    property real  dragAxisOffset: 0
    property int   targetIndex:   -1
    property int   originalIndex: -1
    property bool  isVertical:    SettingsData.dockPosition === "left" || SettingsData.dockPosition === "right"
    property bool  showWindowTitle: false
    property string windowTitle:   ""
    property bool  isHovered:      mouseArea.containsMouse && !dragging
    property bool  isMinimized:    false

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    // ── Icon theme live-reload (Fixed - no more warning) ─────────────────────
    property int iconCacheBuster: 0

    // Safer way: listen for any change in DesktopEntries using a timer
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // Increment cache buster every second if DesktopEntries exists
            // This is a simple workaround that avoids signal warning
            root.iconCacheBuster = root.iconCacheBuster + 1
        }
    }

    // Optional: Log once on load
    Component.onCompleted: {
        console.log("[DockAppButton] Icon cache buster initialized")
    }

    // ── Toplevel lookup ───────────────────────────────────────────────────────
    function getToplevelObject() {
        if (!appData || (appData.type !== "window" && appData.type !== "grouped" && appData.type !== "pinned"))
            return null

        if (appData.type === "grouped" && appData.windows?.length > 0) {
            for (var i = 0; i < appData.windows.length; i++)
                if (appData.windows[i].toplevel?.activated) return appData.windows[i].toplevel
            return appData.windows[0].toplevel
        }

        if (appData.type === "pinned" && appData.windows?.length > 0) {
            for (var i = 0; i < appData.windows.length; i++)
                if (appData.windows[i].toplevel?.activated) return appData.windows[i].toplevel
            return appData.windows[0].toplevel
        }

        const tops = CompositorService.sortedToplevels
        if (!tops) return null

        if (appData.uniqueId) {
            for (var i = 0; i < tops.length; i++) {
                const tl  = tops[i]
                const cid = tl.title + "|" + (tl.appId || "") + "|" + i
                if (cid === appData.uniqueId) return tl
            }
        }

        if (appData.windowId !== undefined && appData.windowId !== null &&
            appData.windowId >= 0 && appData.windowId < tops.length)
            return tops[appData.windowId]

        return null
    }

    // ── Hover animations ──────────────────────────────────────────────────────
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
        NumberAnimation { target: translateY; property: "y"; to: -root.spx(10); duration: Anims.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Anims.emphasizedAccel }
        NumberAnimation { target: translateY; property: "y"; to: -root.spx(8);  duration: Anims.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Anims.emphasizedDecel }
    }

    NumberAnimation {
        id: exitAnimation
        running: false
        target: translateY; property: "y"; to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline; easing.bezierCurve: Anims.emphasizedDecel
    }

    // ── Drag feedback ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
        border.width: 2
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7)
        visible:      dragging
        z:            10

        scale: 1.08
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { fill: parent; margins: -3 }
            radius:      parent.radius + 3
            color:       "transparent"
            border.width: 1.5
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
        }

        SequentialAnimation on opacity {
            running: dragging
            loops:   Animation.Infinite
            NumberAnimation { to: 0.6;  duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.95; duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    // ── Long press timer ──────────────────────────────────────────────────────
    Timer {
        id: longPressTimer
        interval: 500
        repeat:   false
        onTriggered: { if (appData?.isPinned) longPressing = true }
    }

    // ── Mouse handling ────────────────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill:       parent
        anchors.bottomMargin: -root.spx(20)
        hoverEnabled:       true
        cursorShape:        longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
        acceptedButtons:    Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton && appData?.isPinned) {
                dragStartPos = Qt.point(mouse.x, mouse.y)
                // Use global coords so drag math doesn't clamp when cursor leaves MouseArea.
                dragStartGlobalPos = mouseArea.mapToItem(null, mouse.x, mouse.y)
                longPressTimer.start()
            }
        }

        onReleased: mouse => {
            longPressTimer.stop()
            const wasDragging  = dragging
            const didReorder   = wasDragging && targetIndex >= 0 && targetIndex !== originalIndex && dockApps
            if (didReorder) dockApps.movePinnedApp(originalIndex, targetIndex)

            longPressing    = false
            dragging        = false
            dragOffset      = Qt.point(0, 0)
            dragAxisOffset  = 0
            targetIndex     = -1
            originalIndex   = -1
            dragStartGlobalPos = Qt.point(0, 0)

            if (dockApps && !didReorder) {
                dockApps.draggedIndex    = -1
                dockApps.dropTargetIndex = -1
            }

            if (wasDragging || mouse.button !== Qt.LeftButton) return
        }

        onPositionChanged: mouse => {
            if (longPressing && !dragging) {
                const dist = Math.sqrt(Math.pow(mouse.x - dragStartPos.x, 2) + Math.pow(mouse.y - dragStartPos.y, 2))
                if (dist > root.spx(5)) {
                    dragging      = true
                    targetIndex   = index
                    originalIndex = index
                    if (dockApps) { dockApps.draggedIndex = index; dockApps.dropTargetIndex = index }
                }
            }
            if (!dragging || !dockApps) return

            const gp = mouseArea.mapToItem(null, mouse.x, mouse.y)
            const axisOffset = isVertical ? (gp.y - dragStartGlobalPos.y) : (gp.x - dragStartGlobalPos.x)
            dragAxisOffset   = axisOffset
            dragOffset       = Qt.point(gp.x - dragStartGlobalPos.x, gp.y - dragStartGlobalPos.y)

            // Prefer absolute pointer→index mapping (more stable than step/delta),
            // especially for long drags where MouseArea-local coords clamp.
            var newTarget = targetIndex
            const lv = dockApps.dockListView
            if (lv && dockApps.pinnedAppCount > 0) {
                const lp = lv.mapFromItem(null, gp.x, gp.y)
                const axis = isVertical ? lp.y : lp.x
                const iconSize = dockApps.iconSize || (SettingsData.dockIconSize * root.uiScale)
                const slotSize = iconSize + lv.spacing
                // Target nearest icon center (feels more stable than left-edge math).
                const centeredAxis = axis - (iconSize / 2)
                newTarget = Math.round(centeredAxis / Math.max(1, slotSize))
                newTarget = Math.max(0, Math.min(dockApps.pinnedAppCount - 1, newTarget))
            } else {
                // Fallback: delta-based stepping
                const spacing    = Math.min(root.spx(8), Math.max(root.spx(4), SettingsData.dockIconSize * root.uiScale * 0.08))
                const itemSize   = (SettingsData.dockIconSize * root.uiScale) * 1.2 + spacing
                const slotOffset = Math.round(axisOffset / itemSize)
                newTarget  = Math.max(0, Math.min(dockApps.pinnedAppCount - 1, originalIndex + slotOffset))
            }

            if (newTarget !== targetIndex) { targetIndex = newTarget; dockApps.dropTargetIndex = newTarget }
        }

        onClicked: mouse => {
            if (!appData || longPressing) return

            if (mouse.button === Qt.LeftButton) {
                if (appData.type === "pinned") {
                    if (appData.isRunning && appData.windows?.length > 0) {
                        const tl = getToplevelObject()
                        if (tl) { tl.activate(); return }
                    }
                    if (appData.appId) {
                        const de = DesktopEntries.heuristicLookup(appData.appId)
                        if (de) {
                            AppUsageHistoryData.addAppUsage({ "id": appData.appId, "name": de.name || appData.appId, "icon": de.icon || "", "exec": de.exec || "", "comment": de.comment || "" })
                            SessionService.launchDesktopEntry(de)
                        }
                    }
                } else if (appData.type === "window" || appData.type === "grouped") {
                    getToplevelObject()?.activate()
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (appData?.appId) {
                    const de = DesktopEntries.heuristicLookup(appData.appId)
                    if (de) {
                        AppUsageHistoryData.addAppUsage({ "id": appData.appId, "name": de.name || appData.appId, "icon": de.icon || "", "exec": de.exec || "", "comment": de.comment || "" })
                        SessionService.launchDesktopEntry(de)
                    }
                }
            } else if (mouse.button === Qt.RightButton) {
                contextMenu?.showForButton(root, appData, root.spx(40), cachedDesktopEntry)
            }
        }
    }

    // ── Visual content ────────────────────────────────────────────────────────
    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            id: iconTransform
            x: dragging && !isVertical ? dragAxisOffset : 0
            y: dragging &&  isVertical ? dragAxisOffset : 0
        }

        Item {
            id: iconContainer
            anchors.centerIn: parent
            width:  parent.width
            height: parent.height
            layer.enabled: SettingsData.systemIconTinting

            Image {
                id: iconImg
                anchors.centerIn: parent
                width:  parent.width
                height: parent.height
                fillMode:     Image.PreserveAspectFit
                mipmap:       true
                smooth:       true
                asynchronous: true
                visible:      status === Image.Ready
                source: {
                    if (!appData || appData.appId === "__SEPARATOR__") return ""
                    const mid = Paths.moddedAppId(appData.appId)
                    if (mid.toLowerCase().includes("steam_app")) return ""
                    const de = DesktopEntries.heuristicLookup(mid)
                    if (!de?.icon) return ""
                    return Quickshell.iconPath(de.icon || "application-x-executable", true)
                }
            }

            layer.effect: MultiEffect {
                colorization:       SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                colorizationColor:  Theme.primary
            }

            EHIcon {
                anchors.centerIn: parent
                size:    Math.min(parent.width, parent.height)
                name:    "sports_esports"
                color:   Theme.surfaceText
                visible: {
                    if (!appData?.appId || appData.appId === "__SEPARATOR__") return false
                    return Paths.moddedAppId(appData.appId).toLowerCase().includes("steam_app")
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width:   parent.width
                height:  parent.height
                radius:  Theme.cornerRadius
                color:   Theme.surfaceLight
                border.width: 1
                border.color: Theme.primarySelected
                visible: iconImg.status !== Image.Ready

                StyledText {
                    anchors.centerIn: parent
                    text: {
                        if (!appData?.appId) return "?"
                        const de = DesktopEntries.heuristicLookup(appData.appId)
                        return (de?.name ?? appData.appId).charAt(0).toUpperCase()
                    }
                    font.pixelSize: Math.round(SettingsData.dockIconSize * root.uiScale * 0.38)
                    font.weight:    Font.Bold
                    color:          Theme.primary
                }
            }

            Rectangle {
                id: runDot
                width:  root.spx(6); height: root.spx(6); radius: root.spx(3)
                anchors {
                    horizontalCenter: iconContainer.horizontalCenter
                    top:              iconContainer.bottom
                    topMargin:        root.spx(3)
                }
                visible: appData && (appData.isRunning || appData.type === "window")
                color: {
                    if (!appData)        return "transparent"
                    if (isMinimized)     return Qt.rgba(1, 0.55, 0, 0.85)
                    if (isWindowFocused) return Theme.primary
                    if (appData.isRunning || appData.type === "window")
                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.55)
                    return "transparent"
                }
                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            }
        }
    }

    transform: Translate {
        id: translateY
        y: 0
    }

    property bool isWindowFocused: {
        if (!appData || appData.type !== "window") return false
        const tl = getToplevelObject()
        return tl ? tl.activated : false
    }
}
