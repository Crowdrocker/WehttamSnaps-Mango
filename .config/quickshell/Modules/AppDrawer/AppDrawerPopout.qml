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

Item {
    id: appDrawerPopout
    objectName: "appDrawerPopout"

    property string triggerSection: "left"
    property var triggerScreen: null
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 0
    property string barPosition: "bottom"
    property real barThickness: 48 * Appearance.uiScaleRatio

    property bool shouldBeVisible: false

    // Shorthand for scale ratio — used everywhere internally
    readonly property real s: Appearance.uiScaleRatio

    property real popupWidth: 850 * (SettingsData.appDrawerScale || 1.0) * s
    property real popupHeight: 800 * (SettingsData.appDrawerScale || 1.0) * s

    // Calculate additional bar thickness for multi-bar setups
    readonly property real topBarThickness: {
        var thickness = 0
        // Top bar thickness
        if (SettingsData?.topBarVisible && SettingsData?.topBarPosition === "top") {
            thickness += ((SettingsData?.topBarHeight || 40) * (SettingsData?.topbarScale || 1) + (SettingsData?.topBarSpacing || 4) + (SettingsData?.topBarTopMargin || 0)) * s
        }
        // Mini panel thickness (when at top)
        if (SettingsData?.showMiniPanel && SettingsData?.minipanelPosition === "top" && !SettingsData?.minipanelFloat) {
            thickness += ((SettingsData?.miniPanelHeight || 48) * (SettingsData?.miniPanelScale || 1) + (SettingsData?.miniPanelSpacing || 4) + (SettingsData?.miniPanelBottomGap || 0)) * s
        }
        return thickness
    }
    readonly property real bottomBarThickness: {
        if (SettingsData?.showtopbar && !SettingsData?.topbarFloating) {
            return (((SettingsData?.topbarExclusiveZone || SettingsData?.topbarHeight || 64) * (SettingsData?.topbarScale || 1)) + (SettingsData?.topbarBottomGap || 0)) * s
        }
        if (SettingsData?.topbarVisible && !SettingsData?.topbarFloat) {
            return ((SettingsData?.topbarHeight || 54) * (SettingsData?.topbarScale || 1) + (SettingsData?.topBarSpacing || 4)) * s
        }
        return 0
    }

    readonly property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"

    function show() {
        shouldBeVisible = true
    }

    function close() {
        shouldBeVisible = false
    }

    function toggle() {
        shouldBeVisible = !shouldBeVisible
    }

    function setTriggerPosition(x, y, width, section, screen) {
        console.log(`[AppDrawerPopout] setTriggerPosition: (${x}, ${y}), width=${width}, section="${section}", screen=${screen ? screen.width + 'x' + screen.height : 'null'}`);
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen

        if (shouldBeVisible) {
            updatePosition()
        }
    }

    function updatePosition() {
        if (window.visible) {
            window.updatePosition()
        }
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            updatePosition()
            appLauncher.searchQuery = ""
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

    AppLauncher {
        id: appLauncher

        viewMode: SettingsData.appLauncherViewMode
        gridColumns: 4
        onAppLaunched: appDrawerPopout.close()
        onViewModeSelected: function (mode) {
            SettingsData.setAppLauncherViewMode(mode)
        }
    }

    PowerConfirmationModal {
        id: powerConfirmationModal

        onConfirmed: function(action) {
            switch(action) {
                case "logout":
                    SessionService.logout()
                    break
                case "reboot":
                    SessionService.reboot()
                    break
                case "poweroff":
                    SessionService.poweroff()
                    break
            }
        }
    }

    function getAppDataFromId(appId) {
        if (!appId) return null

        const desktopEntry = DesktopEntries.heuristicLookup(appId)
        if (desktopEntry) {
            return {
                name: desktopEntry.name || "",
                exec: desktopEntry.execString || desktopEntry.exec || "",
                icon: desktopEntry.icon || "application-x-executable",
                comment: desktopEntry.comment || "",
                categories: desktopEntry.categories || [],
                desktopEntry: desktopEntry
            }
        }
        return null
    }

    PanelWindow {
        id: window

        visible: appDrawerPopout.shouldBeVisible

        WlrLayershell.namespace: "quickshell:dock:blur"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Get screen based on preferences - respect user settings from DisplaysTab
        screen: {
            const prefs = SettingsData.screenPreferences && SettingsData.screenPreferences["appDrawer"]
            if (prefs && Array.isArray(prefs) && prefs.length > 0 && !prefs.includes("all")) {
                // User selected specific screen(s) - find matching screen
                const targetName = prefs[0]
                const found = Quickshell.screens.find(s => s.name === targetName)
                return found || appDrawerPopout.triggerScreen || Quickshell.screens[0]
            }
            // Default: use trigger screen or primary
            return appDrawerPopout.triggerScreen || Quickshell.screens[0]
        }
        color: "transparent"

        function updatePosition() {
            // Get the screen to use - respect user settings from DisplaysTab
            const prefs = SettingsData.screenPreferences && SettingsData.screenPreferences["appDrawer"]
            let screen
            if (prefs && Array.isArray(prefs) && prefs.length > 0 && !prefs.includes("all")) {
                // User selected specific screen(s) - find matching screen
                const targetName = prefs[0]
                screen = Quickshell.screens.find(s => s.name === targetName)
            }
            if (!screen) screen = appDrawerPopout.triggerScreen || Quickshell.screens[0]
            if (!screen) return

            const screenX = screen.x || 0
            const screenY = screen.y || 0

            const topBarSpace = appDrawerPopout.topBarThickness
            const bottomBarSpace = appDrawerPopout.bottomBarThickness

            const extraPadding = Theme.spacingS
            const availableHeight = screen.height - topBarSpace - bottomBarSpace - Theme.spacingM * 2 - extraPadding * 2
            let popupW = appDrawerPopout.popupWidth
            let popupH = appDrawerPopout.popupHeight

            if (popupH > availableHeight) {
                popupH = availableHeight
                console.log(`[AppDrawerPopout] Adjusted height to fit: ${popupH} (available: ${availableHeight})`)
            }
            if (popupW > screen.width - Theme.spacingL * 2) {
                popupW = screen.width - Theme.spacingL * 2
            }

            const spacing = Theme.spacingM

            let targetX = 0
            let targetY = 0

            // Always center the popup on the primary screen, ignoring trigger section
            // This ensures the AppDrawer shows dead center of the main monitor
            targetX = (screen.width - popupW) / 2
            targetY = topBarSpace + extraPadding + (availableHeight - popupH) / 2

            let localTargetX = targetX
            let localTargetY = targetY

            if (appDrawerPopout.triggerX >= screenX) localTargetX -= screenX
            if (appDrawerPopout.triggerY >= screenY) localTargetY -= screenY

            localTargetX = Math.max(spacing, Math.min(localTargetX, screen.width - popupW - spacing))
            const minY = topBarSpace + spacing + extraPadding
            // When topbar is enabled at top, account for it in maxY calculation
            const maxY = screen.height - popupH - bottomBarSpace - topBarSpace - spacing - extraPadding
            localTargetY = Math.max(minY, Math.min(localTargetY, maxY))

            console.log(`[AppDrawerPopout] Position: (${localTargetX}, ${localTargetY}), Size: ${popupW}x${popupH}`)
            console.log(`[AppDrawerPopout] Bar thickness - Top: ${topBarSpace}, Bottom: ${bottomBarSpace}`)
            console.log(`[AppDrawerPopout] Y bounds - minY: ${minY}, maxY: ${maxY}`)

            launcherPanel.x = localTargetX
            launcherPanel.y = localTargetY
            launcherPanel.width = popupW
            launcherPanel.height = popupH
        }

        onVisibleChanged: if (visible) updatePosition()

        MouseArea {
            anchors.fill: parent
            onClicked: appDrawerPopout.close()
            z: -1
        }

        Rectangle {
            id: launcherPanel

            // Convenience scale shorthand scoped to this panel
            readonly property real s: appDrawerPopout.s

            width: appDrawerPopout.popupWidth
            height: appDrawerPopout.popupHeight

            property alias searchField: searchField

            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, Math.max(0.5, SettingsData.appDrawerTransparency || 0.92))
            radius: Theme.cornerRadius
            antialiasing: true
            smooth: true
            clip: true

            Item {
                id: keyHandler

                anchors.fill: parent
                focus: true

                readonly property var keyMappings: {
                    const mappings = {}
                    mappings[Qt.Key_Escape] = () => appDrawerPopout.close()
                    mappings[Qt.Key_Down]   = () => appLauncher.selectNext()
                    mappings[Qt.Key_Up]     = () => appLauncher.selectPrevious()
                    mappings[Qt.Key_Return] = () => appLauncher.launchSelected()
                    mappings[Qt.Key_Enter]  = () => appLauncher.launchSelected()

                    if (appLauncher.viewMode === "grid") {
                        mappings[Qt.Key_Right] = () => appLauncher.selectNextInRow()
                        mappings[Qt.Key_Left]  = () => appLauncher.selectPreviousInRow()
                    }

                    return mappings
                }

                Keys.onPressed: function (event) {
                    if (keyMappings[event.key]) {
                        keyMappings[event.key]()
                        event.accepted = true
                        return
                    }

                    if (!searchField.activeFocus && event.text && /[a-zA-Z0-9\s]/.test(event.text)) {
                        searchField.forceActiveFocus()
                        searchField.insertText(event.text)
                        event.accepted = true
                    }
                }

                // ── Two-column layout ────────────────────────────────────────
                Row {
                    anchors.fill: parent
                    anchors.margins: 0
                    spacing: 0
                    clip: true

                    // ── LEFT PANEL (pinned apps + power controls) ────────────
                    Rectangle {
                        width: parent.width * 0.4 + 2
                        height: parent.height
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.05)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingL
                            clip: true

                            // ── Pinned apps ──────────────────────────────────
                            ColumnLayout {
                                id: pinnedAppsColumn
                                Layout.fillWidth: true
                                spacing: Theme.spacingM
                                clip: true

                                StyledText {
                                    text: "Pinned"
                                    font.pixelSize: (Theme.fontSizeLarge + 2) * launcherPanel.s
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }

                                // Separator below section heading
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                }

                                Grid {
                                    Layout.fillWidth: true
                                    columns: 3
                                    rowSpacing: Theme.spacingM / 2
                                    columnSpacing: Theme.spacingM / 2
                                    clip: true

                                    Repeater {
                                        model: Math.min(15, SessionData.startMenuPinnedApps.length)

                                        Rectangle {
                                            // Each cell fills 1/3 of the grid width
                                            readonly property real cellSize: (pinnedAppsColumn.width - Theme.spacingM) / 3
                                            width: cellSize
                                            height: 100 * launcherPanel.s
                                            radius: Theme.cornerRadius
                                            color: pinnedMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                            border.color: pinnedMouseArea.containsMouse ? Theme.primary : "transparent"
                                            border.width: 1

                                            property var appData: getAppDataFromId(SessionData.startMenuPinnedApps[index])

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingXS

                                                Item {
                                                    width: 64 * launcherPanel.s
                                                    height: 64 * launcherPanel.s
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    layer.enabled: SettingsData.systemIconTinting

                                                    Image {
                                                        id: pinnedIconImg
                                                        anchors.centerIn: parent
                                                        width: 64 * launcherPanel.s
                                                        height: 64 * launcherPanel.s
                                                        sourceSize.width: 64 * launcherPanel.s
                                                        sourceSize.height: 64 * launcherPanel.s
                                                        fillMode: Image.PreserveAspectFit
                                                        source: Quickshell.iconPath(parent.parent.parent.appData?.icon || "", true)
                                                        smooth: true
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }

                                                    layer.effect: MultiEffect {
                                                        colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                                        colorizationColor: Theme.primary
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: !pinnedIconImg.visible
                                                        color: Theme.surfaceLight
                                                        radius: Theme.cornerRadius
                                                        border.width: 1
                                                        border.color: Theme.primarySelected

                                                        StyledText {
                                                            anchors.centerIn: parent
                                                            text: (parent.parent.parent.appData?.name && parent.parent.parent.appData.name.length > 0)
                                                                  ? parent.parent.parent.appData.name.charAt(0).toUpperCase()
                                                                  : "A"
                                                            font.pixelSize: 16 * launcherPanel.s
                                                            color: Theme.primary
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    text: parent.parent.parent.appData?.name || ""
                                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                    maximumLineCount: 1
                                                }
                                            }

                                            MouseArea {
                                                id: pinnedMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        if (parent.appData) appLauncher.launchApp(parent.appData)
                                                    } else if (mouse.button === Qt.RightButton) {
                                                        pinnedContextMenu.show(mouse.x, mouse.y, parent.appData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Spacer — takes all remaining vertical space ───
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }

                            // ── Power controls ───────────────────────────────
                            ColumnLayout {
                                id: powerControlsColumn
                                Layout.fillWidth: true
                                spacing: Theme.spacingM
                                clip: true

                                // Divider above power controls
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                                }

                                // Quick-toggle + power buttons row
                                Row {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXS

                                    // Idle inhibitor
                                    Rectangle {
                                        id: idleInhibitorButton
                                        width: 36 * launcherPanel.s
                                        height: 36 * launcherPanel.s
                                        radius: Theme.cornerRadius
                                        property bool isInhibiting: false
                                        color: idleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                        border.color: idleInhibitorButton.isInhibiting ? Theme.primary : (idleArea.containsMouse ? Theme.outline : "transparent")
                                        border.width: idleInhibitorButton.isInhibiting ? 2 : (idleArea.containsMouse ? 1 : 0)

                                        Text {
                                            anchors.centerIn: parent
                                            text: idleInhibitorButton.isInhibiting ? "coffee" : "bedtime"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 20 * launcherPanel.s
                                            color: Theme.surfaceText
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
                                            idleInhibitorButton.isInhibiting = true
                                        }
                                    }

                                    // Night light
                                    Rectangle {
                                        id: nightLightButton
                                        width: 36 * launcherPanel.s
                                        height: 36 * launcherPanel.s
                                        radius: Theme.cornerRadius
                                        color: nightArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                        border.color: nightLightButton.enabled ? Theme.primary : (nightArea.containsMouse ? Theme.outline : "transparent")
                                        border.width: nightLightButton.enabled ? 2 : (nightArea.containsMouse ? 1 : 0)
                                        property bool enabled: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "nightlight"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 20 * launcherPanel.s
                                            color: Theme.surfaceText
                                        }

                                        MouseArea {
                                            id: nightArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                nightLightButton.enabled = !nightLightButton.enabled
                                                if (nightLightButton.enabled) {
                                                    nightLightOn.startDetached()
                                                } else {
                                                    nightLightOff.startDetached()
                                                }
                                            }
                                        }

                                        Process { id: nightLightOn;  command: ["gammastep"]         }
                                        Process { id: nightLightOff; command: ["pkill", "gammastep"] }
                                    }

                                    // Reload / Lock / Logout / Restart / Shutdown
                                    Repeater {
                                        model: [
                                            { icon: "refresh",             tooltip: "Reload",    action: "reload"   },
                                            { icon: "lock",                tooltip: "Lock",      action: "lock" },
                                            { icon: "logout",              tooltip: "Logout",    action: "logout",   needsConfirmation: true },
                                            { icon: "restart_alt",         tooltip: "Restart",   action: "reboot",   needsConfirmation: true },
                                            { icon: "power_settings_new",  tooltip: "Shutdown",  action: "poweroff", needsConfirmation: true }
                                        ]

                                        Rectangle {
                                            width: 36 * launcherPanel.s
                                            height: 36 * launcherPanel.s
                                            radius: Theme.cornerRadius
                                            color: powerArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                font.family: "Material Symbols Rounded"
                                                font.pixelSize: 20 * launcherPanel.s
                                                color: Theme.surfaceText
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
                                                            "logout":   { title: "Log Out",  message: "Are you sure you want to log out?"              },
                                                            "reboot":   { title: "Restart",  message: "Are you sure you want to restart the system?"   },
                                                            "poweroff": { title: "Shutdown", message: "Are you sure you want to shut down the system?" }
                                                        }
                                                        const selected = actions[modelData.action]
                                                        if (selected) {
                                                            powerConfirmationModal.showConfirmation(modelData.action, selected.title, selected.message)
                                                        }
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

                    // ── RIGHT PANEL (search + app list) ──────────────────────
                    Rectangle {
                        width: parent.width * 0.6
                        height: parent.height
                        color: "transparent"
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingL
                            clip: true

                            // Search field
                            EHTextField {
                                id: searchField

                                Layout.fillWidth: true
                                height: 48 * launcherPanel.s
                                cornerRadius: Theme.cornerRadius
                                backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                normalBorderColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                focusedBorderColor: Theme.primary
                                leftIconName: "search"
                                leftIconSize: Theme.iconSize * launcherPanel.s
                                leftIconColor: Theme.surfaceVariantText
                                leftIconFocusedColor: Theme.primary
                                showClearButton: true
                                font.pixelSize: Theme.fontSizeMedium * launcherPanel.s
                                textColor: Theme.surfaceText
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingS
                                enabled: appDrawerPopout.shouldBeVisible
                                ignoreLeftRightKeys: true
                                keyForwardTargets: [keyHandler]
                                placeholderText: "Type here to search"

                                onTextEdited: {
                                    appLauncher.searchQuery = text
                                }

                                Keys.onPressed: function (event) {
                                    if (event.key === Qt.Key_Escape) {
                                        appDrawerPopout.close()
                                        event.accepted = true
                                        return
                                    }

                                    const isEnterKey = [Qt.Key_Return, Qt.Key_Enter].includes(event.key)
                                    const hasText = text.length > 0

                                    if (isEnterKey && hasText) {
                                        if (appLauncher.keyboardNavigationActive && appLauncher.model.count > 0) {
                                            appLauncher.launchSelected()
                                        } else if (appLauncher.model.count > 0) {
                                            appLauncher.launchApp(appLauncher.model.get(0))
                                        }
                                        event.accepted = true
                                        return
                                    }

                                    const navigationKeys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right]
                                    const isNavigationKey = navigationKeys.includes(event.key)
                                    const isEmptyEnter = isEnterKey && !hasText
                                    event.accepted = !(isNavigationKey || isEmptyEnter)
                                }

                                Connections {
                                    target: appDrawerPopout
                                    function onShouldBeVisibleChanged() {
                                        if (!appDrawerPopout.shouldBeVisible) searchField.focus = false
                                    }
                                }
                            }

                            // Separator between search and app list
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            }

                            // App list — fills all remaining height
                            EHListView {
                                id: appList
                                visible: appLauncher.viewMode !== "grid"

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property int itemHeight: 60 * launcherPanel.s
                                property int iconSize: 48 * launcherPanel.s
                                property bool showDescription: false
                                property int itemSpacing: Theme.spacingM
                                property bool hoverUpdatesSelection: false
                                property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive

                                signal keyboardNavigationReset
                                signal itemClicked(int index, var modelData)
                                signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                                function ensureVisible(index) {
                                    if (index < 0 || index >= count) return

                                    var itemY = index * (itemHeight + itemSpacing)
                                    var itemBottom = itemY + itemHeight
                                    if (itemY < contentY)
                                        contentY = itemY
                                    else if (itemBottom > contentY + height)
                                        contentY = itemBottom - height
                                }

                                clip: true
                                model: appLauncher.model
                                currentIndex: appLauncher.selectedIndex
                                spacing: itemSpacing
                                focus: true
                                interactive: true
                                cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
                                reuseItems: true

                                onCurrentIndexChanged: {
                                    if (keyboardNavigationActive) ensureVisible(currentIndex)
                                }
                                onItemClicked: function (index, modelData) {
                                    appLauncher.launchApp(modelData)
                                }
                                onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                                    contextMenu.show(mouseX, mouseY, modelData)
                                }
                                onKeyboardNavigationReset: {
                                    appLauncher.keyboardNavigationActive = false
                                }

                                delegate: Item {
                                    width: ListView.view.width
                                    height: appList.itemHeight

                                    // Horizontal inset — gives the hover pill left/right breathing room
                                    readonly property real hPad: Theme.spacingS

                                    Rectangle {
                                        id: appItemRect
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: parent.hPad
                                        anchors.rightMargin: parent.hPad
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height - Theme.spacingXS

                                        // Slightly rounder than default for a pill-like feel
                                        radius: Theme.cornerRadius * 1.5

                                        color: ListView.isCurrentItem
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                            : listMouseArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                                                : "transparent"

                                        border.color: ListView.isCurrentItem
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                            : "transparent"
                                        border.width: ListView.isCurrentItem ? 1 : 0

                                        Behavior on color  { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                        Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                        RowLayout {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin: Theme.spacingM
                                                rightMargin: Theme.spacingM
                                            }
                                            spacing: Theme.spacingM

                                            // App icon
                                            Item {
                                                width: appList.iconSize
                                                height: appList.iconSize
                                                Layout.alignment: Qt.AlignVCenter
                                                layer.enabled: SettingsData.systemIconTinting

                                                Image {
                                                    id: listIconImg
                                                    anchors.centerIn: parent
                                                    width: appList.iconSize
                                                    height: appList.iconSize
                                                    sourceSize.width: appList.iconSize
                                                    sourceSize.height: appList.iconSize
                                                    fillMode: Image.PreserveAspectFit
                                                    source: Quickshell.iconPath(model.icon, true)
                                                    smooth: true
                                                    asynchronous: true
                                                    visible: status === Image.Ready
                                                }

                                                layer.effect: MultiEffect {
                                                    colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                                    colorizationColor: Theme.primary
                                                }

                                                // Fallback initial badge
                                                Rectangle {
                                                    anchors.fill: parent
                                                    visible: !listIconImg.visible
                                                    color: Theme.surfaceLight
                                                    radius: Theme.cornerRadius
                                                    border.width: 1
                                                    border.color: Theme.primarySelected

                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
                                                        font.pixelSize: 16 * launcherPanel.s
                                                        color: Theme.primary
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }

                                            // Name + description
                                            Column {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingXXS

                                                StyledText {
                                                    width: parent.width
                                                    text: model.name || ""
                                                    font.pixelSize: Theme.fontSizeMedium * launcherPanel.s
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: listMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        z: 10
                                        onEntered: {
                                            if (appList.hoverUpdatesSelection && !appList.keyboardNavigationActive)
                                                appList.currentIndex = index
                                        }
                                        onPositionChanged: {
                                            appList.keyboardNavigationReset()
                                        }
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

                    property var currentApp: null
                    property bool menuVisible: false

                    readonly property string appId: (currentApp && currentApp.desktopEntry) ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""
                    readonly property bool isPinned: appId && SessionData.isPinnedApp(appId)
                    readonly property bool isStartMenuPinned: appId && SessionData.isStartMenuPinnedApp(appId)

                    function show(x, y, app) {
                        currentApp = app

                        const menuWidth  = 180 * launcherPanel.s
                        const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2

                        let finalX = x + Theme.spacingS
                        let finalY = y + Theme.spacingS

                        if (finalX + menuWidth > appDrawerPopout.popupWidth)
                            finalX = x - menuWidth - Theme.spacingS
                        if (finalY + menuHeight > appDrawerPopout.popupHeight)
                            finalY = y - menuHeight - Theme.spacingS

                        finalX = Math.max(Theme.spacingS, Math.min(finalX, appDrawerPopout.popupWidth  - menuWidth  - Theme.spacingS))
                        finalY = Math.max(Theme.spacingS, Math.min(finalY, appDrawerPopout.popupHeight - menuHeight - Theme.spacingS))

                        contextMenu.x = finalX
                        contextMenu.y = finalY
                        contextMenu.visible = true
                        contextMenu.menuVisible = true
                    }

                    function close() {
                        contextMenu.menuVisible = false
                        Qt.callLater(() => { contextMenu.visible = false })
                    }

                    visible: false
                    width: 180 * launcherPanel.s
                    height: menuColumn.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.popupBackground()
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    z: 1000
                    opacity: menuVisible ? 1 : 0
                    scale: menuVisible ? 1 : 0.85

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.spacingXS
                        anchors.leftMargin: Theme.spacingXXS
                        anchors.rightMargin: -Theme.spacingXXS
                        anchors.bottomMargin: -Theme.spacingXS
                        radius: parent.radius
                        color: Theme.shadowMedium
                        z: parent.z - 1
                    }

                    Column {
                        id: menuColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingXXS

                        // Pin to topbar
                        Rectangle {
                            width: parent.width
                            height: 32 * launcherPanel.s
                            radius: Theme.cornerRadius
                            color: pinMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: contextMenu.isPinned ? "keep_off" : "push_pin"
                                    size: (Theme.iconSize - 2) * launcherPanel.s
                                    color: Theme.surfaceText
                                    opacity: 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: contextMenu.isPinned ? "Unpin from topbar" : "Pin to topbar"
                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: pinMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry) return
                                    if (contextMenu.isPinned) {
                                        SessionData.removePinnedApp(contextMenu.appId)
                                    } else {
                                        SessionData.addPinnedApp(contextMenu.appId)
                                    }
                                    contextMenu.close()
                                }
                            }
                        }

                        // Pin to Start Menu
                        Rectangle {
                            width: parent.width
                            height: 32 * launcherPanel.s
                            radius: Theme.cornerRadius
                            color: startMenuPinMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: contextMenu.isStartMenuPinned ? "keep_off" : "push_pin"
                                    size: (Theme.iconSize - 2) * launcherPanel.s
                                    color: Theme.surfaceText
                                    opacity: 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: contextMenu.isStartMenuPinned ? "Unpin from Start Menu" : "Pin to Start Menu"
                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: startMenuPinMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry) return
                                    if (contextMenu.isStartMenuPinned) {
                                        SessionData.removeStartMenuPinnedApp(contextMenu.appId)
                                    } else {
                                        SessionData.addStartMenuPinnedApp(contextMenu.appId)
                                    }
                                    contextMenu.close()
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: parent.width - Theme.spacingS * 2
                            height: 5
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            }
                        }

                        // Launch
                        Rectangle {
                            width: parent.width
                            height: 32 * launcherPanel.s
                            radius: Theme.cornerRadius
                            color: launchMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "launch"
                                    size: (Theme.iconSize - 2) * launcherPanel.s
                                    color: Theme.surfaceText
                                    opacity: 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Launch"
                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: launchMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (contextMenu.currentApp) appLauncher.launchApp(contextMenu.currentApp)
                                    contextMenu.close()
                                }
                            }
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                    Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                }

                // ── Pinned apps context menu ─────────────────────────────────
                Rectangle {
                    id: pinnedContextMenu

                    property var currentApp: null
                    property bool menuVisible: false

                    readonly property string appId: (currentApp && currentApp.desktopEntry) ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""

                    function show(x, y, app) {
                        currentApp = app

                        const menuWidth  = 180 * launcherPanel.s
                        const menuHeight = pinnedMenuColumn.implicitHeight + Theme.spacingS * 2

                        let finalX = x + Theme.spacingS
                        let finalY = y + Theme.spacingS

                        if (finalX + menuWidth > appDrawerPopout.popupWidth)
                            finalX = x - menuWidth - Theme.spacingS
                        if (finalY + menuHeight > appDrawerPopout.popupHeight)
                            finalY = y - menuHeight - Theme.spacingS

                        finalX = Math.max(Theme.spacingS, Math.min(finalX, appDrawerPopout.popupWidth  - menuWidth  - Theme.spacingS))
                        finalY = Math.max(Theme.spacingS, Math.min(finalY, appDrawerPopout.popupHeight - menuHeight - Theme.spacingS))

                        pinnedContextMenu.x = finalX
                        pinnedContextMenu.y = finalY
                        pinnedContextMenu.visible = true
                        pinnedContextMenu.menuVisible = true
                    }

                    function close() {
                        pinnedContextMenu.menuVisible = false
                        Qt.callLater(() => { pinnedContextMenu.visible = false })
                    }

                    visible: false
                    width: 180 * launcherPanel.s
                    height: pinnedMenuColumn.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.popupBackground()
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    z: 1000
                    opacity: menuVisible ? 1 : 0
                    scale: menuVisible ? 1 : 0.85

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.popupBackground()
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1
                    }

                    Column {
                        id: pinnedMenuColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingXXS

                        // Launch
                        Rectangle {
                            width: parent.width
                            height: 32 * launcherPanel.s
                            radius: Theme.cornerRadius
                            color: launchPinnedMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "launch"
                                    size: (Theme.iconSize - 2) * launcherPanel.s
                                    color: Theme.surfaceText
                                    opacity: 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Launch"
                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: launchPinnedMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pinnedContextMenu.currentApp) appLauncher.launchApp(pinnedContextMenu.currentApp)
                                    pinnedContextMenu.close()
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: parent.width
                            height: 5
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            }
                        }

                        // Unpin from Start Menu
                        Rectangle {
                            width: parent.width
                            height: 32 * launcherPanel.s
                            radius: Theme.cornerRadius
                            color: unpinMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "keep_off"
                                    size: (Theme.iconSize - 2) * launcherPanel.s
                                    color: Theme.surfaceText
                                    opacity: 0.7
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Unpin from Start Menu"
                                    font.pixelSize: Theme.fontSizeSmall * launcherPanel.s
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: unpinMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pinnedContextMenu.currentApp && pinnedContextMenu.appId) {
                                        SessionData.removeStartMenuPinnedApp(pinnedContextMenu.appId)
                                    }
                                    pinnedContextMenu.close()
                                }
                            }
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                    Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                }

                // ── Dismiss overlays when clicking outside menus ─────────────
                MouseArea {
                    anchors.fill: parent
                    visible: contextMenu.visible
                    z: 999
                    onClicked: contextMenu.close()

                    MouseArea {
                        x: contextMenu.x
                        y: contextMenu.y
                        width: contextMenu.width
                        height: contextMenu.height
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: pinnedContextMenu.visible
                    z: 999
                    onClicked: pinnedContextMenu.close()

                    MouseArea {
                        x: pinnedContextMenu.x
                        y: pinnedContextMenu.y
                        width: pinnedContextMenu.width
                        height: pinnedContextMenu.height
                    }
                }
            }
        }
    }
}
