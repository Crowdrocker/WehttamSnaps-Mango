import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: upgradeWindow

    objectName:      "pkgUpgradeWindow"
    title:           "Upgrade Packages"

    minimumSize:     Qt.size(1000, 700)
    implicitWidth:   1100
    implicitHeight:  750
    backgroundColor: Theme.surfaceContainer
    visible:         false

    function open() {
        _reset()
        visible = true
        if (PackageManagerService.availableUpdates.length === 0) {
            PackageManagerService.checkForUpdates()
        }
    }

    function _reset() {
        isUpgrading    = false
        upgradeDone    = false
        upgradeSuccess = false
        terminalOutput = ""
        errorMessage   = ""
    }

    property bool   isUpgrading:    false
    property bool   upgradeDone:    false
    property bool   upgradeSuccess: false
    property string terminalOutput: ""
    property string errorMessage:   ""

    // ── Stdio collectors ────────────────────────────────────────────────────
    // stdout and stderr are merged into terminalOutput in arrival order by
    // appending each new chunk rather than replacing the whole buffer.

    StdioCollector {
        id: upgradeCollector
        onTextChanged: upgradeWindow.terminalOutput = upgradeCollector.text
                                                    + upgradeErrCollector.text
    }

    StdioCollector {
        id: upgradeErrCollector
        onTextChanged: upgradeWindow.terminalOutput = upgradeCollector.text
                                                    + upgradeErrCollector.text
    }

    // ── Upgrade process ─────────────────────────────────────────────────────
    // FIX: upgradeProc now runs the package manager directly with its stdout
    // and stderr wired to the collectors above.  The old code ran a terminal
    // emulator here instead; because most terminals fork/detach immediately
    // and return exit-code 0, onExited fired before a single package was
    // installed, making the Install button appear to do nothing.
    // tailProc, tailTimer, _logFile, and the Qt.createQmlObject clearProc
    // workarounds are all removed — they are no longer needed.
    Process {
        id: upgradeProc
        stdout: upgradeCollector
        stderr: upgradeErrCollector
        onExited: function(code) {
            upgradeWindow.isUpgrading   = false
            upgradeWindow.upgradeDone   = true
            upgradeWindow.upgradeSuccess = (code === 0)
            upgradeWindow.terminalOutput += (code === 0)
                ? "\n[Upgrade complete!]\n"
                : "\n[Exit code: " + code + "]\n"
            PackageManagerService.checkForUpdates()
        }
    }

    // ── Public API ──────────────────────────────────────────────────────────

    function cancelUpgrade() {
        if (upgradeProc.running) {
            upgradeProc.running = false
            terminalOutput += "\n[Cancelled by user]\n"
            isUpgrading    = false
            upgradeDone    = true
            upgradeSuccess = false
        }
    }

    function startUpgrade() {
        if (isUpgrading || upgradeDone) return

        isUpgrading    = true
        terminalOutput = ""
        errorMessage   = ""

        const pkgManager = PackageManagerService.pkgManager
        let cmdArgs = []

        if (pkgManager === "pikman") {
            cmdArgs = ["pikman", "upgrade", "-y"]
        } else if (pkgManager === "apt") {
            cmdArgs = ["pkexec", "apt", "upgrade", "-y"]
        } else if (pkgManager === "pacman") {
            const aurHelper = PackageManagerService.aurHelper
            if (aurHelper === "paru" || aurHelper === "yay") {
                // AUR helpers must run as the user (not under pkexec).
                // Chain: elevate pacman first, then run the AUR helper normally.
                cmdArgs = ["bash", "-c",
                    "pkexec pacman -Syu --noconfirm && " + aurHelper + " -Syu --noconfirm"]
            } else {
                cmdArgs = ["pkexec", "pacman", "-Syu", "--noconfirm"]
            }
        } else if (pkgManager === "dnf") {
            cmdArgs = ["pkexec", "dnf", "upgrade", "--skip-file-locks", "-y"]
        } else {
            isUpgrading  = false
            errorMessage = "No supported package manager for upgrade"
            return
        }

        console.log("[UpgradeWindow] Running:", cmdArgs.join(" "))
        upgradeProc.command = cmdArgs
        upgradeProc.running = true
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    function getSourceColorValue(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"
            case "aur":     return "#a9e34b"
            case "apt":     return "#FF9F43"
            case "dnf":     return "#EF5350"
            case "flatpak": return "#9775fa"
            default:        return Theme.surfaceVariantText
        }
    }

    // ── Window chrome ────────────────────────────────────────────────────────

    FloatingWindowControls {
        id: winCtrl
        targetWindow: upgradeWindow
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (!upgradeWindow.isUpgrading) upgradeWindow.hide()

        Item {
            id: titleBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 44
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed:       winCtrl.tryStartMove()
                onDoubleClicked: winCtrl.tryToggleMaximize()
            }

            Rectangle {
                anchors.fill: parent
                color:   Theme.surfaceContainer
                opacity: 0.6
            }

            RowLayout {
                anchors {
                    left: parent.left; leftMargin: Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingM

                EHIcon {
                    name:  "upgrade"
                    size:  Theme.iconSize
                    color: "#FF9F43"
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text:           "Upgrade Packages"
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight:    Font.Medium
                    color:          Theme.surfaceText
                }

                Rectangle {
                    visible: PackageManagerService.availableUpdates.length > 0
                    height:  22
                    width:   countLabel.implicitWidth + Theme.spacingM * 2
                    radius:  11
                    Layout.leftMargin: Theme.spacingS
                    Layout.alignment:  Qt.AlignVCenter
                    color:        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                    border.width: 1

                    StyledText {
                        id: countLabel
                        anchors.centerIn: parent
                        text:           PackageManagerService.availableUpdates.length + " pending"
                        font.pixelSize: Theme.fontSizeXS
                        font.weight:    Font.Bold
                        color:          Theme.primary
                    }
                }
            }

            EHActionButton {
                anchors {
                    right: parent.right; rightMargin: Theme.spacingM
                    verticalCenter: parent.verticalCenter
                }
                circular:  false
                iconName:  "close"
                iconSize:  Theme.iconSize - 4
                iconColor: Theme.surfaceText
                enabled:   !upgradeWindow.isUpgrading
                onClicked: upgradeWindow.hide()
            }
        }

        // ── Body ─────────────────────────────────────────────────────────────

        RowLayout {
            anchors {
                top:    titleBar.bottom
                left:   parent.left
                right:  parent.right
                bottom: actionBar.top
                margins: Theme.spacingL
            }
            spacing: Theme.spacingL

            // Left column — package list
            Column {
                Layout.fillWidth:    true
                Layout.preferredWidth: 0
                Layout.fillHeight:   true
                spacing: Theme.spacingM

                StyledText {
                    text:           "Packages to Update (" + PackageManagerService.availableUpdates.length + ")"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight:    Font.Medium
                    color:          Theme.surfaceText
                }

                Rectangle {
                    width:  parent.width
                    height: parent.height - 30
                    radius: 8
                    color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                    border.width: 1

                    EHFlickable {
                        anchors.fill:  parent
                        contentHeight: updatesCol.implicitHeight + Theme.spacingM * 2
                        contentWidth:  width
                        clip: true

                        ScrollBar.vertical: ScrollBar {}

                        Column {
                            id: updatesCol
                            width:   parent.width - Theme.spacingM * 2
                            x:       Theme.spacingM
                            y:       Theme.spacingM
                            spacing: Theme.spacingS

                            Repeater {
                                model: PackageManagerService.availableUpdates

                                delegate: Item {
                                    id: updateItem
                                    required property var modelData
                                    required property int index

                                    readonly property string cardColor: upgradeWindow.getSourceColorValue(modelData.source)

                                    width:  updatesCol.width
                                    height: updateCard.implicitHeight

                                    // Glow halo
                                    Rectangle {
                                        anchors.centerIn: updateCard
                                        width:   updateCard.width  - 12
                                        height:  updateCard.height - 8
                                        radius:  18
                                        color:   "transparent"
                                        visible: updateHover.containsMouse
                                        border.color: Qt.rgba(
                                            Qt.color(updateItem.cardColor).r,
                                            Qt.color(updateItem.cardColor).g,
                                            Qt.color(updateItem.cardColor).b, 0.18)
                                        border.width: 6
                                    }

                                    Rectangle {
                                        id: updateCard
                                        width:          parent.width
                                        implicitHeight: updateCardRow.implicitHeight + Theme.spacingM + Theme.spacingS
                                        radius: 10
                                        clip:   true

                                        color: updateHover.containsMouse ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.05)
                                        border.color: updateHover.containsMouse
                                            ? Qt.rgba(Qt.color(updateItem.cardColor).r, Qt.color(updateItem.cardColor).g, Qt.color(updateItem.cardColor).b, 0.55)
                                            : Qt.rgba(1,1,1,0.10)
                                        border.width: 1
                                        Behavior on color        { ColorAnimation { duration: 180 } }
                                        Behavior on border.color { ColorAnimation { duration: 180 } }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: Qt.rgba(
                                                Qt.color(updateItem.cardColor).r,
                                                Qt.color(updateItem.cardColor).g,
                                                Qt.color(updateItem.cardColor).b,
                                                updateHover.containsMouse ? 0.07 : 0.03)
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                        }

                                        RowLayout {
                                            id: updateCardRow
                                            anchors {
                                                left: parent.left; right: parent.right; top: parent.top
                                                leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
                                                topMargin: Theme.spacingS + 2; bottomMargin: Theme.spacingS + 2
                                            }
                                            spacing: Theme.spacingS

                                            Rectangle {
                                                width: 34; height: 34; radius: 8
                                                Layout.alignment: Qt.AlignVCenter
                                                color: Qt.rgba(Qt.color(updateItem.cardColor).r, Qt.color(updateItem.cardColor).g, Qt.color(updateItem.cardColor).b, 0.15)
                                                border.color: Qt.rgba(Qt.color(updateItem.cardColor).r, Qt.color(updateItem.cardColor).g, Qt.color(updateItem.cardColor).b, 0.35)
                                                border.width: 1

                                                EHIcon {
                                                    anchors.centerIn: parent
                                                    size:  20
                                                    color: updateItem.cardColor
                                                    name: {
                                                        switch (modelData.source) {
                                                            case "pacman":  return "deployed_code"
                                                            case "aur":     return "code"
                                                            case "apt":     return "terminal"
                                                            case "dnf":     return "package_2"
                                                            case "flatpak": return "apps"
                                                            default:        return "inventory_2"
                                                        }
                                                    }
                                                }
                                            }

                                            Column {
                                                Layout.fillWidth: true
                                                spacing: 5

                                                StyledText {
                                                    text:           modelData.name || ""
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight:    Font.Bold
                                                    color:          Theme.surfaceText
                                                    elide:          Text.ElideRight
                                                    width:          parent.width
                                                }

                                                RowLayout {
                                                    width:   parent.width
                                                    spacing: Theme.spacingXS

                                                    StyledText {
                                                        text:           modelData.version || "–"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color:          Theme.surfaceVariantText
                                                        elide:          Text.ElideRight
                                                        Layout.fillWidth:   true
                                                        Layout.maximumWidth: implicitWidth
                                                    }

                                                    StyledText {
                                                        text:           "→"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color:          Theme.surfaceVariantText
                                                    }

                                                    StyledText {
                                                        text:           modelData.newVersion || "?"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color:          updateItem.cardColor
                                                        font.weight:    Font.Medium
                                                        elide:          Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: updateHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right column — terminal output
            Column {
                Layout.fillWidth:    true
                Layout.preferredWidth: 0
                Layout.fillHeight:   true
                spacing: Theme.spacingM

                StyledText {
                    text:           "Terminal Output"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight:    Font.Medium
                    color:          Theme.surfaceText
                }

                Rectangle {
                    width:  parent.width
                    height: parent.height - 30
                    radius: 8
                    color:  Theme.surfaceContainer
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                    border.width: 1
                    clip: true

                    EHFlickable {
                        anchors {
                            fill:    parent
                            margins: Theme.spacingM
                        }
                        contentHeight: termText.implicitHeight
                        contentWidth:  width
                        clip: true

                        ScrollBar.vertical: ScrollBar {}

                        TextEdit {
                            id: termText
                            text:             upgradeWindow.terminalOutput
                            font.pixelSize:   11
                            font.family:      "monospace"
                            color:            Theme.surfaceText
                            readOnly:         true
                            selectByKeyboard: false
                            wrapMode:         TextEdit.Wrap
                            width:            parent.width

                            onTextChanged: cursorPosition = length
                        }
                    }
                }

                StyledText {
                    visible:        upgradeWindow.errorMessage !== ""
                    text:           upgradeWindow.errorMessage
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.error
                    wrapMode:       Text.Wrap
                    width:          parent.width
                }
            }
        }

        // ── Action bar ───────────────────────────────────────────────────────

        Rectangle {
            id: actionBar
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 52
            color:  Theme.surfaceContainer
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1

            RowLayout {
                anchors {
                    left:        parent.left;  leftMargin:  Theme.spacingL
                    right:       parent.right; rightMargin: Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingM

                StyledText {
                    visible:        upgradeWindow.upgradeDone
                    text:           upgradeWindow.upgradeSuccess
                        ? "All packages upgraded successfully!"
                        : "Upgrade incomplete or failed"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight:    Font.Medium
                    color:          upgradeWindow.upgradeSuccess ? Theme.primary : Theme.error
                    Layout.fillWidth: true
                }

                StyledText {
                    visible:        upgradeWindow.isUpgrading
                    text:           "Installing..."
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight:    Font.Medium
                    color:          Theme.primary
                    Layout.fillWidth: true
                }

                // Cancel button
                Rectangle {
                    width:   106; height: 36
                    radius:  8
                    visible: upgradeWindow.isUpgrading
                    color:   cancelArea.containsMouse
                        ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.20)
                        : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.10)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.40)
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        EHIcon {
                            name:  "cancel"
                            size:  16
                            color: Theme.error
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text:           "Cancel"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    Font.Bold
                            color:          Theme.error
                        }
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    upgradeWindow.cancelUpgrade()
                    }
                }

                // Install button
                Rectangle {
                    width:   106; height: 36
                    radius:  8
                    color:   (installBtnArea.containsMouse && !upgradeWindow.isUpgrading && !upgradeWindow.upgradeDone)
                        ? Qt.darker(Theme.primary, 1.1)
                        : Theme.primary
                    opacity: (!upgradeWindow.isUpgrading && !upgradeWindow.upgradeDone) ? 1.0 : 0.5
                    border.color: Theme.primary
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        EHIcon {
                            name:  "upgrade"
                            size:  16
                            color: Theme.onPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text:           "Install"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    Font.Bold
                            color:          Theme.onPrimary
                        }
                    }

                    MouseArea {
                        id: installBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      !upgradeWindow.isUpgrading && !upgradeWindow.upgradeDone
                        onClicked:    upgradeWindow.startUpgrade()
                    }
                }
            }
        }
    }
}
