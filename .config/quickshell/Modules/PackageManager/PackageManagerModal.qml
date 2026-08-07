import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.PackageManager

FloatingWindow {
    id: pkgModal

    // ── Public API ────────────────────────────────────────────────────────────
    property int  currentTabIndex: 0   // 0=Home 1=Search  2=Installed 3=Updates
    property bool isCompactMode:   width < 680

    onCurrentTabIndexChanged: console.log("[Modal] currentTabIndex:", currentTabIndex)

    signal closingModal()

    function show()   { visible = true  }
    function hide()   { visible = false }
    function toggle() { visible = !visible }
    
    function getLocalInstallWindow() { return localInstallWin }
    function getUpgradeWindow() { return upgradeWin }

    function showTab(idx) {
        if (idx >= 0 && idx <= 4) currentTabIndex = idx
        visible = true
    }

    // ── Window config ─────────────────────────────────────────────────────────
    objectName:   "packageManagerModal"
    title:        "WehttamSnaps Package Manager"
    minimumSize:  Qt.size(520, 420)
    implicitWidth: {
        const sw = (typeof screen !== "undefined" && screen) ? screen.width : 1920
        if (sw >= 3840) return 1300
        if (sw >= 2560) return 1100
        if (sw >= 1920) return 960
        return Math.max(520, Math.min(900, sw * 0.65))
    }
    implicitHeight: {
        const sh = (typeof screen !== "undefined" && screen) ? screen.height : 1080
        return Math.min(860, Math.max(420, sh - 120))
    }
    backgroundColor: Theme.surfaceContainer
    visible:         false


    // ── Multi-selection state ────────────────────────────────────────────────
    property var selectedPackages: []

    function isSelected(pkg) {
        return selectedPackages.some(p => p.name === pkg.name && p.source === pkg.source)
    }

    function togglePackage(pkg) {
        if (isSelected(pkg)) {
            selectedPackages = selectedPackages.filter(p => !(p.name === pkg.name && p.source === pkg.source))
        } else {
            selectedPackages = selectedPackages.concat([pkg])
        }
    }

    function selectPackage(pkg) {
        togglePackage(pkg)
    }

    function clearSelection() {
        selectedPackages = []
    }

    // ── IPC ───────────────────────────────────────────────────────────────────
    IpcHandler {
        function open():   string { pkgModal.show();   return "PKG_OPEN"   }
        function close():  string { pkgModal.hide();   return "PKG_CLOSE"  }
        function toggle(): string { pkgModal.toggle(); return "PKG_TOGGLE" }
        target: "WehttamSnaps Package Manager"
    }

    // ── Init service when window opens ───────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            PackageManagerService.init()
        } else {
            closingModal()
        }
    }

    Connections {
        target: PackageManagerService
        function onCapabilitiesDetected() {
            PackageManagerService.checkForUpdates()
        }
    }

    Connections {
        target: pkgModal
        function onClosingModal() {
            PackageManagerService.searchResults = []
        }
    }

    // ── Root focus scope ──────────────────────────────────────────────────────
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: pkgModal.hide()

        // Title bar
        Item {
            id: titleBar
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       windowControls.tryStartMove()
                onDoubleClicked: windowControls.tryToggleMaximize()
            }

            Rectangle {
                anchors.fill: parent
                color:   Theme.surfaceContainer
                opacity: 0.55
            }

            Row {
                anchors.left:           parent.left
                anchors.leftMargin:     Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                EHIcon {
                    name:  "inventory_2"
                    size:  Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text:            "WehttamSnaps Package Manager"
                    font.pixelSize:  Theme.fontSizeXLarge
                    color:           Theme.surfaceText
                    font.weight:     Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    visible: PackageManagerService.pkgManager !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width:  distroLabel.implicitWidth + Theme.spacingM * 2
                    height: 22
                    radius: height / 2
                    color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                    border.width: 1

                    StyledText {
                        id: distroLabel
                        anchors.centerIn: parent
                        text: {
                            const d = PackageManagerService.distribution
                            const p = PackageManagerService.pkgManager
                            if (!d && !p) return ""
                            const distroName = d ? (d.charAt(0).toUpperCase() + d.slice(1)) : ""
                            return distroName + (p ? " · " + p : "")
                        }
                        font.pixelSize:  Theme.fontSizeXS
                        font.weight:     Font.Bold
                        font.letterSpacing: 0.5
                        color: Theme.primary
                    }
                }
            }

            Row {
                anchors.right:      parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.top:        parent.top
                anchors.topMargin:  Theme.spacingM
                spacing: Theme.spacingXS

                EHActionButton {
                    visible:   windowControls.supported
                    circular:  false
                    iconName:  pkgModal.maximized ? "fullscreen_exit" : "fullscreen"
                    iconSize:  Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: windowControls.tryToggleMaximize()
                }

                EHActionButton {
                    circular:  false
                    iconName:  "settings"
                    iconSize:  Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: pkgSettingsModal.open()
                }

                EHActionButton {
                    circular:  false
                    iconName:  "close"
                    iconSize:  Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: pkgModal.hide()
                }
            }
        }

        // Sidebar + Content area
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: parent.bottom
            spacing: 0

            // Sidebar
            PackageManagerSidebar {
                id: sidebar
                height: parent.height
                currentIndex: pkgModal.currentTabIndex
                onCurrentIndexChanged: pkgModal.currentTabIndex = sidebar.currentIndex
            }

            // Content area
            Item {
                width: parent.width - sidebar.effectiveWidth
                height: parent.height
                clip: true

                // Home tab — always active so bindings stay live; same pattern as updatesLoader
                Loader {
                    id: homeLoader
                    anchors.fill: parent
                    active: true
                    visible: pkgModal.currentTabIndex === 0
                    sourceComponent: Component {
                        PKGHomeTab { parentModal: pkgModal }
                    }
                }

                // Search tab
                Loader {
                    id: searchLoader
                    anchors.fill: parent
                    active: pkgModal.currentTabIndex === 1
                    visible: pkgModal.currentTabIndex === 1  // FIX: was "visible: active"
                    sourceComponent: Component {
                        PKGSearchTab { parentModal: pkgModal }
                    }
                }

                // Installed tab
                Loader {
                    id: installedLoader
                    anchors.fill: parent
                    active: pkgModal.currentTabIndex === 2
                    visible: pkgModal.currentTabIndex === 2  // FIX: was "visible: active"
                    sourceComponent: Component {
                        PKGInstalledTab { parentModal: pkgModal }
                    }
                }

                // Updates tab — always active so the component is never destroyed/recreated
                // on tab switches. This prevents the async checkForUpdates() callback from
                // firing while the Home tab is active and bleeding update cards into it.
                Loader {
                    id: updatesLoader
                    anchors.fill: parent
                    active: true
                    visible: pkgModal.currentTabIndex === 3
                    sourceComponent: Component {
                        PKGUpdatesTab { parentModal: pkgModal }
                    }
                }

                // Local Install tab
                Loader {
                    id: localInstallLoader
                    anchors.fill: parent
                    active: pkgModal.currentTabIndex === 4
                    visible: pkgModal.currentTabIndex === 4
                    sourceComponent: Component {
                        PKGLocalInstallTab { parentModal: pkgModal }
                    }
                }

                // ── Multi-select action bar ──────────────────────────────────
                Rectangle {
                    id: multiActionBar
                    visible: pkgModal.selectedPackages.length > 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 52
                    color:  Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.97)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    property int toInstall: pkgModal.selectedPackages.filter(p => !p.installed).length
                    property int toRemove:  pkgModal.selectedPackages.filter(p => p.installed).length

                    RowLayout {
                        anchors {
                            left:        parent.left
                            leftMargin:  Theme.spacingL
                            right:       parent.right
                            rightMargin: Theme.spacingL
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Theme.spacingM

                        Row {
                            spacing: Theme.spacingS
                            Layout.fillWidth: true

                            Rectangle {
                                width:  selCountLabel.implicitWidth + Theme.spacingM * 2
                                height: 24; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                border.width: 1
                                StyledText {
                                    id: selCountLabel
                                    anchors.centerIn: parent
                                    text: pkgModal.selectedPackages.length + " selected"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }

                            Rectangle {
                                visible: multiActionBar.toInstall > 0
                                width:  installCountLbl.implicitWidth + Theme.spacingM * 2
                                height: 24; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color:  Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                border.width: 1
                                StyledText {
                                    id: installCountLbl
                                    anchors.centerIn: parent
                                    text: multiActionBar.toInstall + " to install"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: Theme.primary
                                }
                            }

                            Rectangle {
                                visible: multiActionBar.toRemove > 0
                                width:  removeCountLbl.implicitWidth + Theme.spacingM * 2
                                height: 24; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color:  Qt.rgba(0.937, 0.325, 0.314, 0.08)
                                border.color: Qt.rgba(0.937, 0.325, 0.314, 0.22)
                                border.width: 1
                                StyledText {
                                    id: removeCountLbl
                                    anchors.centerIn: parent
                                    text: multiActionBar.toRemove + " to remove"
                                    font.pixelSize: Theme.fontSizeXS
                                    color: "#EF5350"
                                }
                            }
                        }

                        EHActionButton {
                            iconName: "deselect"
                            iconSize: 18
                            iconColor: Theme.surfaceVariantText
                            circular: false
                            onClicked: pkgModal.clearSelection()
                        }

                        Rectangle {
                            height: 32
                            width: applyRow.implicitWidth + Theme.spacingL * 2
                            radius: 8
                            Layout.alignment: Qt.AlignVCenter
                            color: applyArea.containsMouse
                                ? Qt.darker(Theme.primary, 1.1)
                                : Theme.primary
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: applyRow
                                anchors.centerIn: parent
                                spacing: 6
                                EHIcon {
                                    name: (multiActionBar.toInstall > 0 && multiActionBar.toRemove > 0)
                                        ? "sync_alt"
                                        : (multiActionBar.toRemove > 0 ? "delete" : "download")
                                    size: 16
                                    color: Theme.onPrimary
                                }
                                StyledText {
                                    text: (multiActionBar.toInstall > 0 && multiActionBar.toRemove > 0)
                                        ? "Apply changes"
                                        : (multiActionBar.toRemove > 0 ? "Remove all" : "Install all")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.onPrimary
                                }
                            }

                            MouseArea {
                                id: applyArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const pkgs = pkgModal.selectedPackages.slice()
                                    if (pkgs.length === 0) return
                                    installPopup.openPackages(pkgs)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: pkgModal
    }

    PackageManagerSettings {
        id: pkgSettingsModal
    }

    InstallPopupWindow {
        id: installPopup
        onBatchCompleted: pkgModal.clearSelection()
    }

    PKGLocalInstallWindow {
        id: localInstallWin
    }

    PKGUpgradeWindow {
        id: upgradeWin
    }
}
