import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: pkgModal

    // ── Public API ────────────────────────────────────────────────────────────
    property int  currentTabIndex: 0   // 0=Search  1=Installed  2=Updates
    property bool isCompactMode:   width < 680

    signal closingModal()

    function show()   { visible = true  }
    function hide()   { visible = false }
    function toggle() { visible = !visible }

    function showTab(idx) {
        if (idx >= 0 && idx <= 2) currentTabIndex = idx
        visible = true
    }

    // ── Window config ─────────────────────────────────────────────────────────
    objectName:   "packageManagerModal"
    title:        "PikaPack"
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
    visible: false

    // ── IPC ───────────────────────────────────────────────────────────────────
    IpcHandler {
        function open():   string { pkgModal.show();   return "PKG_OPEN"   }
        function close():  string { pkgModal.hide();   return "PKG_CLOSE"  }
        function toggle(): string { pkgModal.toggle(); return "PKG_TOGGLE" }
        target: "pikapack"
    }

    // ── Init service when window opens ────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            PackageManagerService.init()
        } else {
            closingModal()
        }
    }

    // ── Root focus scope ──────────────────────────────────────────────────────
    FocusScope {
        anchors.fill: parent
        focus: true

        // Close on Escape
        Keys.onEscapePressed: pkgModal.hide()

        Column {
            anchors.fill: parent
            spacing: 0

            // ── Title bar ─────────────────────────────────────────────────────
            Item {
                id: titleBar
                width:  parent.width
                height: 48
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

                // Left: icon + title
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
                        text:            "PikaPack"
                        font.pixelSize:  Theme.fontSizeXLarge
                        color:           Theme.surfaceText
                        font.weight:     Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Distro + manager badge
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

                // Right: window controls
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
                        iconName:  "close"
                        iconSize:  Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: pkgModal.hide()
                    }
                }
            }

            // ── Tab bar ───────────────────────────────────────────────────────
            PKGTabBar {
                id: tabBar
                width:        parent.width
                currentIndex: pkgModal.currentTabIndex
                onTabSelected: (idx) => { pkgModal.currentTabIndex = idx }
            }

            // ── Content area ──────────────────────────────────────────────────
            Item {
                width:  parent.width
                height: parent.height - titleBar.height - tabBar.height
                clip:   true

                // Search tab
                Loader {
                    anchors.fill: parent
                    active:   pkgModal.currentTabIndex === 0
                    visible:  active
                    asynchronous: false
                    sourceComponent: Component {
                        PKGSearchTab { parentModal: pkgModal }
                    }
                }

                // Installed tab
                Loader {
                    anchors.fill: parent
                    active:   pkgModal.currentTabIndex === 1
                    visible:  active
                    asynchronous: true
                    sourceComponent: Component {
                        PKGInstalledTab { parentModal: pkgModal }
                    }
                }

                // Updates tab
                Loader {
                    anchors.fill: parent
                    active:   pkgModal.currentTabIndex === 2
                    visible:  active
                    asynchronous: true
                    sourceComponent: Component {
                        PKGUpdatesTab { parentModal: pkgModal }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: pkgModal
    }
}
