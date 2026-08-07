import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.AppDrawer
import qs.Modals
import qs.Services
import qs.Widgets
import "." as DockAppDrawer

Item {
    id: appDrawerPopout
    objectName: "appDrawerPopout"

    property string triggerSection: "left"
    property var    triggerScreen:  null
    property real   triggerX:       0
    property real   triggerY:       0
    property real   triggerWidth:   0
    property string barPosition:    "bottom"
    // Thickness of the triggering bar (Dock) in screen px.
    property real   barThickness:   48 * (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)

    property bool shouldBeVisible: false

    // ── Single scale shorthand ────────────────────────────────────────────────
    // Keep placement tied to the real bar sizes (global×module scale), while
    // allowing the drawer content to be scaled separately.
    readonly property real ui:      (Appearance.combinedScale || 1)
    readonly property real dockUi:  ui * (SettingsData.dockScale || 1)
    // Drawer content should scale the same regardless of which bar opens it.
    // Tie content size to global UI scale + appDrawerScale only.
    readonly property real s:       ui * (SettingsData.appDrawerScale || 1.0)

    property real popupWidth:  850 * s
    property real popupHeight: 800 * s

    // ── Bar thickness — cached as simple readonly properties ──────────────────
    // Using explicit conditional chains rather than nested ?. avoids repeated
    // property-access micro-allocations on every binding re-evaluation.
    readonly property real topBarThickness: {
        var t = 0
        if (SettingsData.topBarVisible && SettingsData.topBarPosition === "top")
            t += ((SettingsData.topBarHeight || 40) * (SettingsData.topbarScale || 1)
                  + (SettingsData.topBarSpacing || 4)
                  + (SettingsData.topBarTopMargin || 0)) * ui
        if (SettingsData.showMiniPanel && SettingsData.minipanelPosition === "top"
                && !SettingsData.minipanelFloat)
            t += ((SettingsData.miniPanelHeight || 48) * (SettingsData.miniPanelScale || 1)
                  + (SettingsData.miniPanelSpacing || 4)
                  + (SettingsData.miniPanelBottomGap || 0)) * ui
        return t
    }
    readonly property real bottomBarThickness: {
        if (SettingsData.showDock && !SettingsData.dockFloating)
            return ((SettingsData.dockExclusiveZone || SettingsData.dockHeight || 64)
                    + (SettingsData.dockBottomGap || 0)) * dockUi
        if (SettingsData.dockVisible && !SettingsData.dockFloat)
            return ((SettingsData.dockHeight || 54)
                    + (SettingsData.topBarSpacing || 4)) * dockUi
        return 0
    }

    readonly property bool isBarVertical: SettingsData.topBarPosition === "left"
                                       || SettingsData.topBarPosition === "right"

    // ── Public API ────────────────────────────────────────────────────────────
    function show()   { shouldBeVisible = true  }
    function close()  { shouldBeVisible = false }
    function toggle() { shouldBeVisible = !shouldBeVisible }

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX      = x
        triggerY      = y
        triggerWidth  = width
        triggerSection = section
        triggerScreen  = screen
        if (shouldBeVisible) updatePosition()
    }

    function updatePosition() {
        if (window.visible) window.updatePosition()
    }

    onShouldBeVisibleChanged: {
        // Sync visibility into the launcher so it can defer expensive rebuilds
        appLauncher.drawerVisible = shouldBeVisible
        if (shouldBeVisible) {
            updatePosition()
            appLauncher.searchQuery   = ""
            appLauncher.selectedIndex = 0
            appLauncher.setCategory("All")
            Qt.callLater(() => {
                if (searchField) {
                    searchField.text = ""
                    searchField.forceActiveFocus()
                }
            })
        }
    }

    // ── App launcher logic (non-visual) ───────────────────────────────────────
    DockAppDrawer.AppLauncher {
        id: appLauncher
        viewMode:    SettingsData.appLauncherViewMode
        gridColumns: 4
        onAppLaunched:      appDrawerPopout.close()
        onViewModeSelected: function(mode) { SettingsData.setAppLauncherViewMode(mode) }
    }

    PowerConfirmationModal {
        id: powerConfirmationModal
        onConfirmed: function(action) {
            switch (action) {
                case "logout":   SessionService.logout();   break
                case "reboot":   SessionService.reboot();   break
                case "poweroff": SessionService.poweroff(); break
            }
        }
    }

    function getAppDataFromId(appId) {
        if (!appId) return null
        const de = DesktopEntries.heuristicLookup(appId)
        if (!de) return null
        return {
            name:         de.name         || "",
            exec:         de.execString   || de.exec || "",
            icon:         de.icon         || "application-x-executable",
            comment:      de.comment      || "",
            categories:   de.categories   || [],
            desktopEntry: de
        }
    }

    // ── Window ────────────────────────────────────────────────────────────────
    PanelWindow {
        id: window

        visible: appDrawerPopout.shouldBeVisible

        WlrLayershell.namespace:     "quickshell:dock:blur"
        WlrLayershell.layer:         WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None

        anchors { top: true; left: true; right: true; bottom: true }

        screen: appDrawerPopout.triggerScreen || Quickshell.screens[0]
        color:  "transparent"

        function updatePosition() {
            if (!appDrawerPopout.triggerScreen) return

            const screen        = appDrawerPopout.triggerScreen
            const topBarSpace   = appDrawerPopout.topBarThickness
            const bottomBarSpace = appDrawerPopout.bottomBarThickness
            const extraPadding  = Theme.spacingS
            const spacing       = Theme.spacingM

            const availH = screen.height - topBarSpace - bottomBarSpace
                           - Theme.spacingM * 2 - extraPadding * 2

            let popupW = appDrawerPopout.popupWidth
            let popupH = appDrawerPopout.popupHeight

            if (popupH > availH) popupH = availH
            if (popupW > screen.width - Theme.spacingL * 2)
                popupW = screen.width - Theme.spacingL * 2

            let targetX = 0, targetY = 0
            let section = appDrawerPopout.triggerSection
            if (section === "dock") section = appDrawerPopout.barPosition

            const cx = appDrawerPopout.triggerX + appDrawerPopout.triggerWidth / 2

            // NOTE: PanelWindow with anchors { top/left/right/bottom: true } and
            // WlrLayershell.exclusiveZone: -1 renders in screen-local coordinates.
            // triggerX/triggerY are already screen-local (set via mapToItem(null,...)),
            // and screen.width/height are screen-local dimensions — so all arithmetic
            // here is already in the correct space. Do NOT subtract screen.x / screen.y;
            // doing so would break stacked or side-by-side layouts where the monitor's
            // global compositor origin is non-zero.
            if (section === "bottom") {
                targetX = cx - popupW / 2
                targetY = screen.height - bottomBarSpace - popupH - spacing - extraPadding
            } else if (section === "top") {
                targetX = cx - popupW / 2
                targetY = topBarSpace + spacing + extraPadding
            } else if (section === "left") {
                targetX = appDrawerPopout.triggerX + appDrawerPopout.triggerWidth + spacing
                targetY = topBarSpace + extraPadding + (availH - popupH) / 2
            } else if (section === "right") {
                targetX = appDrawerPopout.triggerX - popupW - spacing
                targetY = topBarSpace + extraPadding + (availH - popupH) / 2
            } else {
                targetX = (screen.width - popupW) / 2
                targetY = topBarSpace + extraPadding + (availH - popupH) / 2
            }

            let localX = targetX
            let localY = targetY

            const minY = topBarSpace + spacing + extraPadding
            const maxY = screen.height - popupH - bottomBarSpace - topBarSpace - spacing - extraPadding

            localX = Math.max(spacing, Math.min(localX, screen.width - popupW - spacing))
            localY = Math.max(minY,    Math.min(localY, maxY))

            launcherPanel.x      = localX
            launcherPanel.y      = localY
            launcherPanel.width  = popupW
            launcherPanel.height = popupH
        }

        onVisibleChanged: if (visible) updatePosition()

        // Dismiss on backdrop click
        MouseArea {
            anchors.fill: parent
            onClicked: appDrawerPopout.close()
            z: -1
        }

        // ── Main panel ────────────────────────────────────────────────────────
        Rectangle {
            id: launcherPanel

            readonly property real s: appDrawerPopout.s

            // ── Hoisted color constants — evaluated once, not per-delegate ────
            readonly property color primaryHover12:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
            readonly property color primaryHover10:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
            readonly property color primaryActive18: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            readonly property color primaryBorder35: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
            readonly property color outlineFaint:    Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            readonly property color outlineFaint20:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)

            property alias searchField: searchField

            width:  appDrawerPopout.popupWidth
            height: appDrawerPopout.popupHeight

            color: Qt.rgba(
                Theme.surfaceContainer.r,
                Theme.surfaceContainer.g,
                Theme.surfaceContainer.b,
                Math.max(0.5, SettingsData.appDrawerTransparency || 0.92)
            )
            radius:       Theme.cornerRadius
            border.color: SettingsData.appDrawerDynamicBorderColors
                          ? Theme.primary
                          : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                                    SettingsData.appDrawerBorderOpacity !== undefined
                                        ? SettingsData.appDrawerBorderOpacity
                                        : 0.30)
            border.width: SettingsData.appDrawerBorderEnabled
                          ? Math.max(1, SettingsData.appDrawerBorderThickness !== undefined
                                        ? SettingsData.appDrawerBorderThickness
                                        : 2)
                          : 0
            antialiasing: true
            smooth:       true
            clip:         true

            // ── Open / close animation — SmoothedAnimation syncs to vsync ────
            // The panel fades+scales in; SmoothedAnimation uses the compositor
            // frame clock so it is naturally refresh-rate aware.
            opacity: appDrawerPopout.shouldBeVisible ? 1.0 : 0.0
            scale:   appDrawerPopout.shouldBeVisible ? 1.0 : 0.94

            Behavior on opacity {
                SmoothedAnimation {
                    velocity:  -1        // velocity=-1 means use duration
                    duration:  Theme.mediumDuration
                    easing.type: Theme.emphasizedEasing
                }
            }
            Behavior on scale {
                SmoothedAnimation {
                    velocity:  -1
                    duration:  Theme.mediumDuration
                    easing.type: Theme.emphasizedEasing
                }
            }

            // ── Key handler ───────────────────────────────────────────────────
            Item {
                id: keyHandler
                anchors.fill: parent
                focus: true

                // Build mappings once; viewMode is accessed only inside the handler
                // (not as a binding dependency of the property itself).
                function handleKey(key) {
                    if      (key === Qt.Key_Escape) { appDrawerPopout.close();           return true }
                    else if (key === Qt.Key_Down)   { appLauncher.selectNext();          return true }
                    else if (key === Qt.Key_Up)     { appLauncher.selectPrevious();      return true }
                    else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                        appLauncher.launchSelected(); return true
                    }
                    if (appLauncher.viewMode === "grid") {
                        if      (key === Qt.Key_Right) { appLauncher.selectNextInRow();     return true }
                        else if (key === Qt.Key_Left)  { appLauncher.selectPreviousInRow(); return true }
                    }
                    return false
                }

                Keys.onPressed: function(event) {
                    if (handleKey(event.key)) {
                        event.accepted = true
                        return
                    }
                    if (!searchField.activeFocus && event.text && /[a-zA-Z0-9\s]/.test(event.text)) {
                        searchField.forceActiveFocus()
                        searchField.insertText(event.text)
                        event.accepted = true
                    }
                }

                // ── Two-column layout ─────────────────────────────────────────
                Row {
                    anchors.fill: parent
                    spacing: 0
                    clip: true

                    // ── LEFT: pinned apps + power controls ────────────────────
                    Rectangle {
                        width:  parent.width * 0.4 + 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                                        Theme.surfaceVariant.b, 0.05)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill:    parent
                            anchors.margins: Theme.spacingL
                            spacing:         Theme.spacingL
                            clip:            true

                            // ── Pinned apps ───────────────────────────────────
                            ColumnLayout {
                                id: pinnedAppsColumn
                                Layout.fillWidth: true
                                spacing: Theme.spacingM
                                clip: true

                                StyledText {
                                    text:            "Pinned"
                                    font.pixelSize:  (Theme.fontSizeLarge + 2) * launcherPanel.s
                                    font.weight:     Font.Bold
                                    color:           Theme.surfaceText
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color:  launcherPanel.outlineFaint
                                }

                                Grid {
                                    Layout.fillWidth: true
                                    columns:      3
                                    rowSpacing:   Theme.spacingM / 2
                                    columnSpacing: Theme.spacingM / 2
                                    clip: true

                                    Repeater {
                                        model: Math.min(15, SessionData.startMenuPinnedApps.length)

                                        Rectangle {
                                            readonly property real cellSize: (pinnedAppsColumn.width - Theme.spacingM) / 3
                                            // Cache app data once at creation time; reevaluate only when pinned list changes
                                            readonly property var appData: appDrawerPopout.getAppDataFromId(
                                                SessionData.startMenuPinnedApps[index]
                                            )

                                            width:  cellSize
                                            height: 100 * launcherPanel.s
                                            radius: Theme.cornerRadius
                                            color:  pinnedMouseArea.containsMouse
                                                    ? launcherPanel.primaryHover12 : "transparent"
                                            border.color: pinnedMouseArea.containsMouse
                                                    ? Theme.primary : "transparent"
                                            border.width: 1

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingXS

                                                Item {
                                                    readonly property real iconSizePx: 64 * launcherPanel.s
                                                    width:  iconSizePx
                                                    height: iconSizePx
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    // layer only enabled when tinting is on — avoids a GPU
                                                    // texture allocation per cell when tinting is off
                                                    layer.enabled: SettingsData.systemIconTinting
                                                    layer.effect: MultiEffect {
                                                        colorization:      SettingsData.systemIconTinting
                                                                           ? SettingsData.iconTintIntensity : 0
                                                        colorizationColor: Theme.primary
                                                    }

                                                    Image {
                                                        id: pinnedIconImg
                                                        anchors.fill:      parent
                                                        sourceSize.width:  parent.iconSizePx
                                                        sourceSize.height: parent.iconSizePx
                                                        fillMode:          Image.PreserveAspectFit
                                                        source:            Quickshell.iconPath(
                                                            appData ? appData.icon || "" : "", true
                                                        )
                                                        smooth:       true
                                                        asynchronous: true
                                                        visible:      status === Image.Ready
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible:      !pinnedIconImg.visible
                                                        color:        Theme.surfaceLight
                                                        radius:       Theme.cornerRadius
                                                        border.width: 1
                                                        border.color: Theme.primarySelected

                                                        StyledText {
                                                            anchors.centerIn: parent
                                                            text: (appData && appData.name && appData.name.length > 0)
                                                                  ? appData.name.charAt(0).toUpperCase() : "A"
                                                            font.pixelSize: 16 * launcherPanel.s
                                                            color:          Theme.primary
                                                            font.weight:    Font.Bold
                                                        }
                                                    }
                                                }

                                                StyledText {
                                                    width:               cellSize
                                                    text:                appData ? appData.name || "" : ""
                                                    font.pixelSize:      Theme.fontSizeSmall * launcherPanel.s
                                                    color:               Theme.surfaceText
                                                    font.weight:         Font.Medium
                                                    elide:               Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                    maximumLineCount:    1
                                                }
                                            }

                                            MouseArea {
                                                id: pinnedMouseArea
                                                anchors.fill:    parent
                                                hoverEnabled:    true
                                                cursorShape:     Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        if (appData) appLauncher.launchApp(appData)
                                                    } else if (mouse.button === Qt.RightButton) {
                                                        pinnedContextMenu.show(mouse.x, mouse.y, appData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Spacer
                            Item { Layout.fillWidth: true; Layout.fillHeight: true }

                            // ── Power controls ────────────────────────────────
                            ColumnLayout {
                                id: powerControlsColumn
                                Layout.fillWidth: true
                                spacing: Theme.spacingM
                                clip:    true

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color:  launcherPanel.outlineFaint
                                }

                                Row {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXS

                                    // Idle inhibitor
                                    Rectangle {
                                        id: idleInhibitorButton
                                        width:   36 * launcherPanel.s
                                        height:  36 * launcherPanel.s
                                        radius:  Theme.cornerRadius
                                        property bool isInhibiting: false
                                        color:        idleArea.containsMouse
                                                      ? launcherPanel.primaryHover12 : "transparent"
                                        border.color: isInhibiting ? Theme.primary
                                                      : idleArea.containsMouse ? Theme.outline : "transparent"
                                        border.width: isInhibiting ? 2 : idleArea.containsMouse ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text:             parent.isInhibiting ? "coffee" : "bedtime"
                                            font.family:      "Material Symbols Rounded"
                                            font.pixelSize:   20 * launcherPanel.s
                                            color:            Theme.surfaceText
                                        }

                                        MouseArea {
                                            id: idleArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (idleInhibitorButton.isInhibiting) {
                                                    startHypridle.startDetached()
                                                    idleInhibitorButton.isInhibiting = false
                                                } else {
                                                    killHypridle.startDetached()
                                                    idleInhibitorButton.isInhibiting = true
                                                }
                                            }
                                        }

                                        Process { id: killHypridle;  command: ["pkill", "hypridle"] }
                                        Process { id: startHypridle; command: ["hypridle"]           }

                                        Component.onCompleted: {
                                            killHypridle.startDetached()
                                            isInhibiting = true
                                        }
                                    }

                                    // Night light
                                    Rectangle {
                                        id: nightLightButton
                                        width:   36 * launcherPanel.s
                                        height:  36 * launcherPanel.s
                                        radius:  Theme.cornerRadius
                                        property bool enabled: false
                                        color:        nightArea.containsMouse
                                                      ? launcherPanel.primaryHover12 : "transparent"
                                        border.color: enabled ? Theme.primary
                                                      : nightArea.containsMouse ? Theme.outline : "transparent"
                                        border.width: enabled ? 2 : nightArea.containsMouse ? 1 : 0

                                        Text {
                                            anchors.centerIn: parent
                                            text:           "nightlight"
                                            font.family:    "Material Symbols Rounded"
                                            font.pixelSize: 20 * launcherPanel.s
                                            color:          Theme.surfaceText
                                        }

                                        MouseArea {
                                            id: nightArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                nightLightButton.enabled = !nightLightButton.enabled
                                                if (nightLightButton.enabled) nightLightOn.startDetached()
                                                else                          nightLightOff.startDetached()
                                            }
                                        }

                                        Process { id: nightLightOn;  command: ["gammastep"]         }
                                        Process { id: nightLightOff; command: ["pkill", "gammastep"] }
                                    }

                                    // Reload / Lock / Logout / Restart / Shutdown
                                    Repeater {
                                        model: [
                                            { icon: "refresh",            tooltip: "Reload",   action: "reload"   },
                                            { icon: "lock",               tooltip: "Lock",     action: "lock" },
                                            { icon: "logout",             tooltip: "Logout",   action: "logout",  needsConfirmation: true },
                                            { icon: "restart_alt",        tooltip: "Restart",  action: "reboot",  needsConfirmation: true },
                                            { icon: "power_settings_new", tooltip: "Shutdown", action: "poweroff",needsConfirmation: true }
                                        ]

                                        Rectangle {
                                            width:  36 * launcherPanel.s
                                            height: 36 * launcherPanel.s
                                            radius: Theme.cornerRadius
                                            color:  powerArea.containsMouse
                                                    ? launcherPanel.primaryHover12 : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text:           modelData.icon
                                                font.family:    "Material Symbols Rounded"
                                                font.pixelSize: 20 * launcherPanel.s
                                                color:          Theme.surfaceText
                                            }

                                            MouseArea {
                                                id: powerArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (modelData.action === "reload") {
                                                        Quickshell.execDetached(["/usr/lib/xdg-desktop-portal-gtk"])
                                                        Quickshell.reload(true)
                                                        appDrawerPopout.close()
                                                    } else if (modelData.action === "lock") {
                                                        IdleService.lockRequested()
                                                        appDrawerPopout.close()
                                                    } else if (modelData.needsConfirmation) {
                                                        const actions = {
                                                            "logout":   { title: "Log Out",  message: "Are you sure you want to log out?"             },
                                                            "reboot":   { title: "Restart",  message: "Are you sure you want to restart the system?"  },
                                                            "poweroff": { title: "Shutdown", message: "Are you sure you want to shut down the system?" }
                                                        }
                                                        const sel = actions[modelData.action]
                                                        if (sel) powerConfirmationModal.showConfirmation(
                                                            modelData.action, sel.title, sel.message
                                                        )
                                                        appDrawerPopout.close()
                                                    } else {
                                                        Quickshell.execDetached(modelData.command)
                                                        appDrawerPopout.close()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── RIGHT: search + app list ──────────────────────────────
                    Rectangle {
                        width:  parent.width * 0.6
                        height: parent.height
                        color:  "transparent"
                        clip:   true

                        ColumnLayout {
                            anchors.fill:    parent
                            anchors.margins: Theme.spacingL
                            spacing:         Theme.spacingL
                            clip:            true

                            // Search field
                            EHTextField {
                                id: searchField

                                Layout.fillWidth:  true
                                height:            48 * launcherPanel.s
                                autoExpandWidth:   false
                                cornerRadius:      Theme.cornerRadius
                                backgroundColor:   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                                                           Theme.surfaceVariant.b, 0.3)
                                normalBorderColor: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                                           Theme.outline.b, 0.3)
                                focusedBorderColor: Theme.primary
                                leftIconName:       "search"
                                leftIconSize:       Theme.iconSize * launcherPanel.s
                                leftIconColor:      Theme.surfaceVariantText
                                leftIconFocusedColor: Theme.primary
                                showClearButton:    true
                                font.pixelSize:     Theme.fontSizeMedium * launcherPanel.s
                                textColor:          Theme.surfaceText
                                topPadding:         Theme.spacingS
                                bottomPadding:      Theme.spacingS
                                enabled:            appDrawerPopout.shouldBeVisible
                                ignoreLeftRightKeys: true
                                keyForwardTargets:  [keyHandler]
                                placeholderText:    "Type here to search"

                                onTextEdited: appLauncher.searchQuery = text

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Escape) {
                                        appDrawerPopout.close()
                                        event.accepted = true
                                        return
                                    }
                                    const isEnterKey = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                    if (isEnterKey && text.length > 0) {
                                        if (appLauncher.keyboardNavigationActive && appLauncher.model.count > 0)
                                            appLauncher.launchSelected()
                                        else if (appLauncher.model.count > 0)
                                            appLauncher.launchApp(appLauncher.model.get(0))
                                        event.accepted = true
                                        return
                                    }
                                    const navKeys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right]
                                    event.accepted = !(navKeys.includes(event.key) || (isEnterKey && text.length === 0))
                                }

                                Connections {
                                    target: appDrawerPopout
                                    function onShouldBeVisibleChanged() {
                                        if (!appDrawerPopout.shouldBeVisible) searchField.focus = false
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color:  launcherPanel.outlineFaint
                            }

                            // ── App list ──────────────────────────────────────
                            EHListView {
                                id: appList
                                visible: appLauncher.viewMode !== "grid"

                                Layout.fillWidth:  true
                                Layout.fillHeight: true

                                property int  itemHeight:   60 * launcherPanel.s
                                property int  iconSize:     48 * launcherPanel.s
                                property bool showDescription: false
                                property int  itemSpacing:  Theme.spacingM
                                property bool hoverUpdatesSelection: false
                                property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive

                                signal keyboardNavigationReset
                                signal itemClicked(int index, var modelData)
                                signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                                function ensureVisible(index) {
                                    if (index < 0 || index >= count) return
                                    const itemY      = index * (itemHeight + itemSpacing)
                                    const itemBottom = itemY + itemHeight
                                    if (itemY < contentY)
                                        contentY = itemY
                                    else if (itemBottom > contentY + height)
                                        contentY = itemBottom - height
                                }

                                clip:        true
                                model:       appLauncher.model
                                currentIndex: appLauncher.selectedIndex
                                spacing:     itemSpacing
                                focus:       true
                                interactive: true
                                // Cache buffer sized to ~3 screens — enough to prevent blank-row
                                // flicker when scrolling fast on high-refresh displays.
                                cacheBuffer: Math.max(0, height * 3)
                                reuseItems: true

                                onCurrentIndexChanged: {
                                    if (keyboardNavigationActive) ensureVisible(currentIndex)
                                }
                                onItemClicked:      function(index, modelData) { appLauncher.launchApp(modelData) }
                                onItemRightClicked: function(index, modelData, mx, my) { contextMenu.show(mx, my, modelData) }
                                onKeyboardNavigationReset: { appLauncher.keyboardNavigationActive = false }

                                delegate: Item {
                                    width:  ListView.view.width
                                    height: appList.itemHeight

                                    readonly property real hPad: Theme.spacingS

                                    Rectangle {
                                        id: appItemRect
                                        anchors {
                                            left:            parent.left
                                            right:           parent.right
                                            leftMargin:      parent.hPad
                                            rightMargin:     parent.hPad
                                            verticalCenter:  parent.verticalCenter
                                        }
                                        height: parent.height - Theme.spacingXS
                                        radius: Theme.cornerRadius * 1.5

                                        // Using direct ternary — no Behavior here.
                                        // Behaviors on color inside delegates create one
                                        // ColorAnimation object per visible row. On a 120 Hz
                                        // display with 20+ visible rows that is 20+ animation
                                        // objects firing every frame even when nothing moves.
                                        color: ListView.isCurrentItem
                                               ? launcherPanel.primaryActive18
                                               : listMouseArea.containsMouse
                                                 ? launcherPanel.primaryHover10 : "transparent"

                                        border.color: ListView.isCurrentItem
                                                      ? launcherPanel.primaryBorder35 : "transparent"
                                        border.width: ListView.isCurrentItem ? 1 : 0

                                        RowLayout {
                                            anchors {
                                                left:          parent.left
                                                right:         parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin:    Theme.spacingM
                                                rightMargin:   Theme.spacingM
                                            }
                                            spacing: Theme.spacingM

                                            Item {
                                                width:  appList.iconSize
                                                height: appList.iconSize
                                                Layout.alignment: Qt.AlignVCenter
                                                layer.enabled: SettingsData.systemIconTinting
                                                layer.effect: MultiEffect {
                                                    colorization:      SettingsData.systemIconTinting
                                                                       ? SettingsData.iconTintIntensity : 0
                                                    colorizationColor: Theme.primary
                                                }

                                                Image {
                                                    id: listIconImg
                                                    anchors.fill:      parent
                                                    sourceSize.width:  appList.iconSize
                                                    sourceSize.height: appList.iconSize
                                                    fillMode:          Image.PreserveAspectFit
                                                    source:            Quickshell.iconPath(model.icon, true)
                                                    smooth:       true
                                                    asynchronous: true
                                                    visible:      status === Image.Ready
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible:      !listIconImg.visible
                                                    color:        Theme.surfaceLight
                                                    radius:       Theme.cornerRadius
                                                    border.width: 1
                                                    border.color: Theme.primarySelected

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: (model.name && model.name.length > 0)
                                                              ? model.name.charAt(0).toUpperCase() : "A"
                                                        font.pixelSize: 16 * launcherPanel.s
                                                        color:          Theme.primary
                                                        font.weight:    Font.Bold
                                                    }
                                                }
                                            }

                                            Column {
                                                Layout.alignment:  Qt.AlignVCenter
                                                Layout.fillWidth:  true
                                                spacing:           Theme.spacingXXS

                                                StyledText {
                                                    width:          parent.width
                                                    text:           model.name || ""
                                                    font.pixelSize: Theme.fontSizeMedium * launcherPanel.s
                                                    color:          Theme.surfaceText
                                                    font.weight:    Font.Medium
                                                    elide:          Text.ElideRight
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: listMouseArea
                                            anchors.fill:    parent
                                            hoverEnabled:    true
                                            cursorShape:     Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            z: 10
                                            onEntered: {
                                                if (appList.hoverUpdatesSelection && !appList.keyboardNavigationActive)
                                                    appList.currentIndex = index
                                            }
                                            onPositionChanged: appList.keyboardNavigationReset()
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    appList.itemClicked(index, model)
                                                } else if (mouse.button === Qt.RightButton) {
                                                    var panelPos = mapToItem(contextMenu.parent, mouse.x, mouse.y)
                                                    appList.itemRightClicked(index, model, panelPos.x, panelPos.y)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            EHGridView {
                                id: appGrid
                                visible: appLauncher.viewMode === "grid"

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                clip: true
                                model: appLauncher.model
                                currentIndex: appLauncher.selectedIndex
                                focus: true
                                interactive: true
                                cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
                                cellWidth: Math.max(80 * launcherPanel.s, width / 4)
                                cellHeight: 100 * launcherPanel.s

                                property int iconSize: 48 * launcherPanel.s
                                property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive

                                signal itemClicked(int index, var modelData)
                                signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                                onCurrentIndexChanged: {
                                    if (keyboardNavigationActive) {
                                        var itemY = Math.floor(currentIndex / Math.floor(width / cellWidth)) * cellHeight
                                        if (itemY < contentY)
                                            contentY = itemY
                                        else if (itemY + cellHeight > contentY + height)
                                            contentY = itemY + cellHeight - height
                                    }
                                }
                                onItemClicked: function (index, modelData) {
                                    appLauncher.launchApp(modelData)
                                }
                                onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                                    contextMenu.show(mouseX, mouseY, modelData)
                                }

                                delegate: Item {
                                    width: appGrid.cellWidth
                                    height: appGrid.cellHeight

                                    Rectangle {
                                        id: gridItemBg
                                        anchors.centerIn: parent
                                        width: parent.width - Theme.spacingM
                                        height: parent.height - Theme.spacingS
                                        radius: Theme.cornerRadius
                                        color: GridView.isCurrentItem
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                            : gridMouseArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                                                : "transparent"
                                        border.color: GridView.isCurrentItem
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                            : "transparent"
                                        border.width: GridView.isCurrentItem ? 1 : 0

                                        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                        Column {
                                            anchors.centerIn: parent
                                            width: gridItemBg.width - Theme.spacingS
                                            spacing: Theme.spacingXS

                                            Item {
                                                width: appGrid.iconSize
                                                height: appGrid.iconSize
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Image {
                                                    id: gridIconImg
                                                    anchors.fill: parent
                                                    sourceSize.width: appGrid.iconSize
                                                    sourceSize.height: appGrid.iconSize
                                                    fillMode: Image.PreserveAspectFit
                                                    source: Quickshell.iconPath(model.icon, true)
                                                    smooth: true
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: !gridIconImg.visible
                                                    color: Theme.surfaceLight
                                                    radius: Theme.cornerRadius
                                                    border.width: 1
                                                    border.color: Theme.primarySelected

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
                                                        font.pixelSize: 20 * launcherPanel.s
                                                        color: Theme.primary
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }

                                            StyledText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: parent.width
                                                text: model.name || ""
                                                font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                                color: Theme.surfaceText
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: gridMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                appGrid.itemClicked(index, model)
                                            } else if (mouse.button === Qt.RightButton) {
                                                var panelPos = mapToItem(contextMenu.parent, mouse.x, mouse.y)
                                                appGrid.itemRightClicked(index, model, panelPos.x, panelPos.y)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── App list context menu ────────────────────────────────────

                Rectangle {
                    id: contextMenu

                    property var  currentApp:  null
                    property bool menuVisible: false

                    readonly property string appId: (currentApp && currentApp.desktopEntry)
                        ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""
                    readonly property bool isPinned:          appId && SessionData.isPinnedApp(appId)
                    readonly property bool isStartMenuPinned: appId && SessionData.isStartMenuPinnedApp(appId)

                    function show(x, y, app) {
                        currentApp = app
                        const menuW = 180 * launcherPanel.s
                        const menuH = menuColumn.implicitHeight + Theme.spacingS * 2
                        let fx = x + Theme.spacingS
                        let fy = y + Theme.spacingS
                        if (fx + menuW > appDrawerPopout.popupWidth)  fx = x - menuW - Theme.spacingS
                        if (fy + menuH > appDrawerPopout.popupHeight) fy = y - menuH - Theme.spacingS
                        fx = Math.max(Theme.spacingS, Math.min(fx, appDrawerPopout.popupWidth  - menuW - Theme.spacingS))
                        fy = Math.max(Theme.spacingS, Math.min(fy, appDrawerPopout.popupHeight - menuH - Theme.spacingS))
                        contextMenu.x = fx; contextMenu.y = fy
                        contextMenu.visible = true
                        contextMenu.menuVisible = true
                    }
                    function close() {
                        contextMenu.menuVisible = false
                        Qt.callLater(() => { contextMenu.visible = false })
                    }

                    visible:      false
                    width:        180 * launcherPanel.s
                    height:       menuColumn.implicitHeight + Theme.spacingS * 2
                    radius:       Theme.cornerRadius
                    color:        Theme.popupBackground()
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    z: 1000
                    opacity: menuVisible ? 1 : 0
                    scale:   menuVisible ? 1 : 0.85

                    // Drop shadow
                    Rectangle {
                        anchors { fill: parent; topMargin: Theme.spacingXS; leftMargin: Theme.spacingXXS
                                  rightMargin: -Theme.spacingXXS; bottomMargin: -Theme.spacingXS }
                        radius: parent.radius
                        color:  Theme.shadowMedium
                        z:      parent.z - 1
                    }

                    Column {
                        id: menuColumn
                        anchors.fill:    parent
                        anchors.margins: Theme.spacingS
                        spacing:         Theme.spacingXXS

                        AppMenuEntry {
                            scale_s:  launcherPanel.s
                            iconName: contextMenu.isPinned ? "keep_off" : "push_pin"
                            label:    contextMenu.isPinned ? "Unpin from Dock" : "Pin to Dock"
                            onActivated: {
                                if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry) return
                                if (contextMenu.isPinned) SessionData.removePinnedApp(contextMenu.appId)
                                else                      SessionData.addPinnedApp(contextMenu.appId)
                                contextMenu.close()
                            }
                        }

                        AppMenuEntry {
                            scale_s:  launcherPanel.s
                            iconName: contextMenu.isStartMenuPinned ? "keep_off" : "push_pin"
                            label:    contextMenu.isStartMenuPinned ? "Unpin from Start Menu" : "Pin to Start Menu"
                            onActivated: {
                                if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry) return
                                if (contextMenu.isStartMenuPinned) SessionData.removeStartMenuPinnedApp(contextMenu.appId)
                                else                               SessionData.addStartMenuPinnedApp(contextMenu.appId)
                                contextMenu.close()
                            }
                        }

                        AppMenuSep {}

                        AppMenuEntry {
                            scale_s:  launcherPanel.s
                            iconName: "launch"
                            label:    "Launch"
                            onActivated: {
                                if (contextMenu.currentApp) appLauncher.launchApp(contextMenu.currentApp)
                                contextMenu.close()
                            }
                        }
                    }

                    Behavior on opacity {
                        SmoothedAnimation { velocity: -1; duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }
                    Behavior on scale {
                        SmoothedAnimation { velocity: -1; duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }
                }

                // ── Pinned apps context menu ─────────────────────────────────
                Rectangle {
                    id: pinnedContextMenu

                    property var  currentApp:  null
                    property bool menuVisible: false

                    readonly property string appId: (currentApp && currentApp.desktopEntry)
                        ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""

                    function show(x, y, app) {
                        currentApp = app
                        const menuW = 180 * launcherPanel.s
                        const menuH = pinnedMenuColumn.implicitHeight + Theme.spacingS * 2
                        let fx = x + Theme.spacingS
                        let fy = y + Theme.spacingS
                        if (fx + menuW > appDrawerPopout.popupWidth)  fx = x - menuW - Theme.spacingS
                        if (fy + menuH > appDrawerPopout.popupHeight) fy = y - menuH - Theme.spacingS
                        fx = Math.max(Theme.spacingS, Math.min(fx, appDrawerPopout.popupWidth  - menuW - Theme.spacingS))
                        fy = Math.max(Theme.spacingS, Math.min(fy, appDrawerPopout.popupHeight - menuH - Theme.spacingS))
                        pinnedContextMenu.x = fx; pinnedContextMenu.y = fy
                        pinnedContextMenu.visible = true
                        pinnedContextMenu.menuVisible = true
                    }
                    function close() {
                        pinnedContextMenu.menuVisible = false
                        Qt.callLater(() => { pinnedContextMenu.visible = false })
                    }

                    visible:      false
                    width:        180 * launcherPanel.s
                    height:       pinnedMenuColumn.implicitHeight + Theme.spacingS * 2
                    radius:       Theme.cornerRadius
                    color:        Theme.popupBackground()
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    z: 1000
                    opacity: menuVisible ? 1 : 0
                    scale:   menuVisible ? 1 : 0.85

                    Rectangle {
                        anchors.fill:  parent
                        radius:        parent.radius
                        color:         Theme.popupBackground()
                        border.color:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width:  1
                    }

                    Column {
                        id: pinnedMenuColumn
                        anchors.fill:    parent
                        anchors.margins: Theme.spacingS
                        spacing:         Theme.spacingXXS

                        AppMenuEntry {
                            scale_s:  launcherPanel.s
                            iconName: "launch"
                            label:    "Launch"
                            onActivated: {
                                if (pinnedContextMenu.currentApp) appLauncher.launchApp(pinnedContextMenu.currentApp)
                                pinnedContextMenu.close()
                            }
                        }

                        AppMenuSep {}

                        AppMenuEntry {
                            scale_s:  launcherPanel.s
                            iconName: "keep_off"
                            label:    "Unpin from Start Menu"
                            onActivated: {
                                if (pinnedContextMenu.currentApp && pinnedContextMenu.appId)
                                    SessionData.removeStartMenuPinnedApp(pinnedContextMenu.appId)
                                pinnedContextMenu.close()
                            }
                        }
                    }

                    Behavior on opacity {
                        SmoothedAnimation { velocity: -1; duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }
                    Behavior on scale {
                        SmoothedAnimation { velocity: -1; duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }
                }

                // ── Dismiss overlays on backdrop click ───────────────────────
                MouseArea {
                    anchors.fill: parent
                    visible:      contextMenu.visible
                    z: 999
                    onClicked: contextMenu.close()
                    MouseArea {
                        x: contextMenu.x; y: contextMenu.y
                        width: contextMenu.width; height: contextMenu.height
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible:      pinnedContextMenu.visible
                    z: 999
                    onClicked: pinnedContextMenu.close()
                    MouseArea {
                        x: pinnedContextMenu.x; y: pinnedContextMenu.y
                        width: pinnedContextMenu.width; height: pinnedContextMenu.height
                    }
                }
            }
        }
    }
}
