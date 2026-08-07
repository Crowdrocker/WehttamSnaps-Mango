import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Modules.Settings
import qs.Services
import qs.Widgets

FloatingWindow {
    id: settingsModal
    

    property alias profileBrowser: profileBrowser
    property alias wallpaperBrowser: wallpaperBrowser
    property alias sidebar: sidebar
    property int currentTabIndex: 0
    property bool shouldHaveFocus: visible
    property bool allowFocusOverride: false
    property alias shouldBeVisible: settingsModal.visible
    property bool isCompactMode: width < 700
    property bool menuVisible: !isCompactMode
    property bool enableAnimations: true

    signal closingModal()

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    function showWithTab(tabIndex: int) {
        if (tabIndex >= 0)
            currentTabIndex = tabIndex;
        visible = true;
    }

    function showWithTabName(tabName: string) {
        var idx = sidebar.resolveTabIndex(tabName);
        if (idx >= 0)
            currentTabIndex = idx;
        visible = true;
    }

    function resolveTabIndex(tabName: string): int {
        return sidebar.resolveTabIndex(tabName);
    }

    function toggleMenu() {
        enableAnimations = true;
        menuVisible = !menuVisible;
    }

    function adjustedColor(baseColor) {
        var brightness = (typeof SettingsData !== "undefined" && SettingsData.settingsBrightness !== undefined)
            ? SettingsData.settingsBrightness
            : 1.0
        var contrast = (typeof SettingsData !== "undefined" && SettingsData.settingsContrast !== undefined)
            ? SettingsData.settingsContrast
            : 1.0
        var whiteBalance = (typeof SettingsData !== "undefined" && SettingsData.settingsWhiteBalance !== undefined)
            ? SettingsData.settingsWhiteBalance
            : 1.0
        var highlights = (typeof SettingsData !== "undefined" && SettingsData.settingsHighlights !== undefined)
            ? SettingsData.settingsHighlights
            : 1.0
        function applyContrast(channel) {
            return Math.min(1, Math.max(0, ((channel - 0.5) * contrast) + 0.5))
        }
        function applyHighlights(channel) {
            if (highlights === 1.0) {
                return channel
            }
            if (highlights > 1.0) {
                var amount = Math.min(0.4, highlights - 1.0)
                return Math.min(1, channel + (1 - channel) * (amount / 0.4))
            }
            var reduce = Math.min(0.4, 1.0 - highlights)
            return Math.max(0, channel * (1 - (reduce / 0.4)))
        }
        return Qt.rgba(
                    applyHighlights(applyContrast(Math.min(1, baseColor.r * brightness * whiteBalance))),
                    applyHighlights(applyContrast(Math.min(1, baseColor.g * brightness))),
                    applyHighlights(applyContrast(Math.min(1, baseColor.b * brightness * (2 - whiteBalance)))),
                    baseColor.a)
    }

    objectName: "settingsModal"
    title: "Settings"
    minimumSize: Qt.size(500, 400)
    implicitWidth: {
        const screenWidth = (typeof screen !== "undefined" && screen && screen.width) ? screen.width : 1920
        if (screenWidth >= 3840) return 1400
        if (screenWidth >= 2560) return 1200
        if (screenWidth >= 1920) return 1000
        if (screenWidth >= 1280) return 900
        return Math.max(500, Math.min(900, screenWidth * 0.7))
    }
    implicitHeight: {
        const screenHeight = (typeof screen !== "undefined" && screen && screen.height) ? screen.height : 1080
        return Math.min(940, Math.max(400, screenHeight - 100))
    }
    backgroundColor: adjustedColor(Theme.surfaceContainer)
    visible: false

    onIsCompactModeChanged: {
        enableAnimations = false;
        if (!isCompactMode) {
            menuVisible = true;
        }
        Qt.callLater(() => {
            enableAnimations = true;
        });
    }

    onVisibleChanged: {
        if (!visible) {
            closingModal();
        } else {
            Qt.callLater(() => {
                if (sidebar && sidebar.focusSearch) {
                    sidebar.focusSearch();
                }
            });
        }
    }

    IpcHandler {
        function open(): string {
            settingsModal.show();
            return "SETTINGS_OPEN_SUCCESS";
        }

        function close(): string {
            settingsModal.hide();
            return "SETTINGS_CLOSE_SUCCESS";
        }

        function toggle(): string {
            settingsModal.toggle();
            return "SETTINGS_TOGGLE_SUCCESS";
        }

        target: "settings"
    }

    IpcHandler {
        function browse(type: string) {
            if (type === "wallpaper") {
                wallpaperBrowser.allowStacking = false;
                wallpaperBrowser.open();
            } else if (type === "profile") {
                profileBrowser.allowStacking = false;
                profileBrowser.open();
            }
        }

        target: "file"
    }

    FileBrowserModal {
        id: profileBrowser

        allowStacking: true
        parentModal: settingsModal
        browserTitle: "Select Profile Image"
        browserIcon: "person"
        browserType: "profile"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: (path) => {
            if (typeof PortalService !== "undefined" && PortalService.setProfileImage) {
                PortalService.setProfileImage(path);
            }
            close();
        }
        onDialogClosed: () => {
            allowStacking = true;
        }
    }

    FileBrowserModal {
        id: wallpaperBrowser

        allowStacking: true
        parentModal: settingsModal
        browserTitle: "Select Wallpaper"
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: (path) => {
            if (typeof SessionData !== "undefined" && SessionData.setWallpaper) {
                SessionData.setWallpaper(path);
            }
            close();
        }
        onDialogClosed: () => {
            allowStacking = true;
        }
    }

    FocusScope {
        id: contentFocusScope

        anchors.fill: parent
        focus: true

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: 48
                z: 10

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Rectangle {
                    anchors.fill: parent
                    color: adjustedColor(Theme.surfaceContainer)
                    opacity: 0.5
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    EHActionButton {
                        visible: settingsModal.isCompactMode
                        circular: false
                        iconName: "menu"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: settingsModal.toggleMenu()
                    }

                    EHIcon {
                        name: "settings"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "Settings"
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingXS

                    // Sidebar collapse toggle — replaces fullscreen button
                    EHActionButton {
                        circular: false
                        iconName: sidebar.collapsed ? "menu_open" : "menu"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: sidebar.collapsed = !sidebar.collapsed
                    }

                    EHActionButton {
                        visible: windowControls.supported
                        circular: false
                        iconName: settingsModal.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    EHActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: settingsModal.hide()
                    }
                }
            }

            Rectangle {
                id: readOnlyBanner

                property bool showBanner: (typeof SettingsData !== "undefined" && SettingsData._isReadOnly !== undefined && SettingsData._isReadOnly && SettingsData._hasUnsavedChanges !== undefined && SettingsData._hasUnsavedChanges) || (typeof SessionData !== "undefined" && SessionData._isReadOnly !== undefined && SessionData._isReadOnly && SessionData._hasUnsavedChanges !== undefined && SessionData._hasUnsavedChanges)

                width: parent.width
                height: showBanner ? bannerContent.implicitHeight + Theme.spacingM * 2 : 0
                color: adjustedColor(Theme.surfaceContainerHigh)
                visible: showBanner
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    id: bannerContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "info"
                        size: Theme.iconSize
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: bannerText

                        text: "Settings are read-only. Changes will not persist."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(100, parent.width - (copySettingsButton.visible ? copySettingsButton.width + Theme.spacingM : 0) - (copySessionButton.visible ? copySessionButton.width + Theme.spacingM : 0) - Theme.spacingM * 2 - Theme.iconSize)
                        wrapMode: Text.WordWrap
                    }

                    StyledRect {
                        id: copySettingsButton

                        visible: typeof SettingsData !== "undefined" && SettingsData._isReadOnly !== undefined && SettingsData._isReadOnly && SettingsData._hasUnsavedChanges !== undefined && SettingsData._hasUnsavedChanges
                        width: implicitWidth
                        height: 32
                        radius: Theme.cornerRadius
                        color: Theme.primary

                        StyledText {
                            anchors.centerIn: parent
                            text: "settings.json"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryText
                            font.weight: Font.Medium
                        }

                        StateLayer {
                            stateColor: Theme.primary
                            cornerRadius: Theme.cornerRadius
                            onClicked: {
                                if (typeof SettingsData !== "undefined" && SettingsData.getCurrentSettingsJson && typeof Quickshell !== "undefined") {
                                    Quickshell.execDetached(["EH", "cl", "copy", SettingsData.getCurrentSettingsJson()]);
                                    if (typeof ToastService !== "undefined" && ToastService.showInfo) {
                                        ToastService.showInfo("Copied to clipboard");
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        id: copySessionButton

                        visible: typeof SessionData !== "undefined" && SessionData._isReadOnly !== undefined && SessionData._isReadOnly && SessionData._hasUnsavedChanges !== undefined && SessionData._hasUnsavedChanges
                        width: implicitWidth
                        height: 32
                        radius: Theme.cornerRadius
                        color: Theme.primary

                        StyledText {
                            anchors.centerIn: parent
                            text: "session.json"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.primaryText
                            font.weight: Font.Medium
                        }

                        StateLayer {
                            stateColor: Theme.primary
                            cornerRadius: Theme.cornerRadius
                            onClicked: {
                                if (typeof SessionData !== "undefined" && SessionData.getCurrentSessionJson && typeof Quickshell !== "undefined") {
                                    Quickshell.execDetached(["EH", "cl", "copy", SessionData.getCurrentSessionJson()]);
                                    if (typeof ToastService !== "undefined" && ToastService.showInfo) {
                                        ToastService.showInfo("Copied to clipboard");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48 - readOnlyBanner.height
                clip: true

                SettingsSidebar {
                    id: sidebar

                    anchors.left: parent.left
                    width: sidebar.effectiveWidth
                    visible: settingsModal.isCompactMode ? settingsModal.menuVisible : true
                    parentModal: settingsModal
                    currentIndex: settingsModal.currentTabIndex
                    onCurrentIndexChanged: {
                        settingsModal.currentTabIndex = currentIndex;
                        if (settingsModal.isCompactMode) {
                            settingsModal.enableAnimations = true;
                            settingsModal.menuVisible = false;
                        }
                    }
                }

                Item {
                    anchors.left: settingsModal.isCompactMode ? (settingsModal.menuVisible ? sidebar.right : parent.left) : sidebar.right
                    anchors.right: parent.right
                    height: parent.height
                    clip: true

                    SettingsContent {
                        id: content

                        anchors.fill: parent
                        parentModal: settingsModal
                        currentIndex: settingsModal.currentTabIndex
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: settingsModal
    }
}
