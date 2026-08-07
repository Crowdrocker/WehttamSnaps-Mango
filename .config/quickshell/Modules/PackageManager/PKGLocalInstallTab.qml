import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    property var recentInstalls: []

    function getLocalInstallWindow() {
        if (!root.parentModal || !root.parentModal.getLocalInstallWindow) return null
        return root.parentModal.getLocalInstallWindow()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _ext(path) {
        const p = path.trim()
        if (p.endsWith(".deb"))                           return "deb"
        if (p.endsWith(".rpm"))                           return "rpm"
        if (p.endsWith(".zst") || p.endsWith(".tar.zst")) return "zst"
        return ""
    }

    function _installCmd(fmt, path) {
        const safe = path.replace(/'/g, "'\\''")
        if (fmt === "deb") return "dpkg -i '" + safe + "'; apt-get install -f -y"
        if (fmt === "rpm") return "dnf install --skip-file-locks -y '" + safe + "' 2>/dev/null || rpm -ivh --force '" + safe + "'"
        if (fmt === "zst") return "pacman -U --noconfirm '" + safe + "'"
        return ""
    }

    // ── Direct-to-terminal install ────────────────────────────────────────────
    function _launchInstall(path) {
        const p = path.trim()
        if (p === "") return

        const fmt = _ext(p)
        if (fmt === "") {
            statusText.text    = "Unsupported format — choose a .deb, .rpm, or .zst file."
            statusText.isError = true
            return
        }

        const win = getLocalInstallWindow()
        console.log("[_launchInstall] win:", win)
        if (win) {
            win.openFile(p)
            statusText.text    = "Opening install dialog…"
            statusText.isError = false

            const entry   = { path: p, time: new Date().toLocaleTimeString() }
            recentInstalls = [entry].concat(recentInstalls.slice(0, 9))
        } else {
            statusText.text    = "Error: Install dialog not available"
            statusText.isError = true
        }
    }

    function _tryInstall() {
        _launchInstall(tabPathInput.text)
    }

    function _openFileBrowser() {
        if (!fileBrowserLoader.item) {
            fileBrowserLoader.active = true
        } else {
            _setupAndOpenBrowser()
        }
    }

    function _setupAndOpenBrowser() {
        const fb = fileBrowserLoader.item
        if (!fb) return
        fb.fileExtensions   = ["*.deb", "*.rpm", "*.zst", "*.tar.zst"]
        fb.browserTitle     = "Select Package to Install"
        fb.selectFolderMode = false
        fb.open()
    }

    function _onFileBrowserSelected(path) {
        tabPathInput.text = path
        if (fileBrowserLoader.item) fileBrowserLoader.item.close()
        _launchInstall(path)
    }

    // Process that fires the terminal
    Process {
        id: termProc
        onExited: function(code) {
            console.log("[LocalInstall] terminal exited:", code)
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────
    EHFlickable {
        anchors.fill:      parent
        anchors.topMargin: Theme.spacingL
        clip:              true
        contentHeight:     mainCol.implicitHeight + Theme.spacingXL
        contentWidth:      width

        Column {
            id: mainCol
            width:   parent.width
            spacing: Theme.spacingL

            // ── Install card ──────────────────────────────────────────────────
            Rectangle {
                width:  parent.width - Theme.spacingL * 2
                x:      Theme.spacingL
                implicitHeight: heroCol.implicitHeight + Theme.spacingL * 2
                radius: 10
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Column {
                    id: heroCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                    spacing: Theme.spacingM

                    // Header row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name:  "install_desktop"
                            size:  Theme.iconSize + 4
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                text:           "Install Local Package"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight:    Font.SemiBold
                                color:          Theme.surfaceText
                            }

                            StyledText {
                                text:           "Install a .deb, .rpm, or .zst file via the built-in installer"
                                font.pixelSize: Theme.fontSizeSmall
                                color:          Theme.surfaceVariantText
                            }
                        }
                    }

                    // Format chips
                    RowLayout {
                        width:   parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                { fmt: "DEB", color: "#FF9F43", distro: "Debian · Ubuntu" },
                                { fmt: "RPM", color: "#EF5350", distro: "Fedora · RHEL"   },
                                { fmt: "ZST", color: "#74c0fc", distro: "Arch Linux"      }
                            ]

                            Rectangle {
                                required property var modelData
                                implicitWidth:  fmtChipRow.implicitWidth + Theme.spacingM * 2
                                height:         28
                                radius:         height / 2
                                color:  Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.12)
                                border.color: Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.40)
                                border.width: 1

                                Row {
                                    id: fmtChipRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    StyledText {
                                        text:            modelData.fmt
                                        font.pixelSize:  Theme.fontSizeXS
                                        font.weight:     Font.Bold
                                        font.letterSpacing: 0.6
                                        color:           modelData.color
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text:           "·  " + modelData.distro
                                        font.pixelSize: Theme.fontSizeXS
                                        color:          Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.75)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Path input + Install button
                    RowLayout {
                        width:   parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 8
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                            border.color: tabPathInput.activeFocus
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingS }
                                spacing: Theme.spacingXS

                                EHIcon {
                                    name:  "folder_open"
                                    size:  18
                                    color: tabPathInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                TextInput {
                                    id: tabPathInput
                                    Layout.fillWidth: true
                                    font.pixelSize:   Theme.fontSizeMedium
                                    color:            Theme.surfaceText
                                    clip:             true

                                    StyledText {
                                        visible:        tabPathInput.text === ""
                                        text:           "/path/to/package.deb"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.32)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Keys.onReturnPressed: _tryInstall()
                                    Keys.onEnterPressed:  _tryInstall()
                                }

                                EHActionButton {
                                    visible:   tabPathInput.text !== ""
                                    circular:  false
                                    iconName:  "close"
                                    iconSize:  14
                                    iconColor: Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: {
                                        tabPathInput.text = ""
                                        statusText.text   = ""
                                    }
                                }

                                EHActionButton {
                                    circular:  false
                                    iconName:  "search"
                                    iconSize:  14
                                    iconColor: Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: _openFileBrowser()
                                }
                            }
                        }

                        // Install button
                        Rectangle {
                            width:  124; height: 42
                            radius: 8
                            color:  installBtnArea.containsMouse && tabPathInput.text !== ""
                                ? Qt.darker(Theme.primary, 1.1)
                                : Theme.primary
                            opacity: tabPathInput.text !== "" ? 1.0 : 0.5
                            Behavior on color   { ColorAnimation { duration: 120 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                EHIcon {
                                    name:  "terminal"
                                    size:  18
                                    color: Theme.onPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text:           "Install"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight:    Font.SemiBold
                                    color:          Theme.onPrimary
                                }
                            }

                            MouseArea {
                                id: installBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  tabPathInput.text !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked:    if (tabPathInput.text !== "") _tryInstall()
                            }
                        }
                    }

                    // Status / error feedback
                    StyledText {
                        id: statusText
                        property bool isError: false
                        visible:        text !== ""
                        text:           ""
                        font.pixelSize: Theme.fontSizeXS
                        color:          isError
                            ? "#EF5350"
                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }

                    StyledText {
                        visible:        statusText.text === ""
                        text:           "Browse for a file or paste a path above — press Enter or click Install."
                        font.pixelSize: Theme.fontSizeXS
                        color:          Theme.surfaceVariantText
                        opacity:        0.65
                        wrapMode:       Text.WordWrap
                        width:          parent.width
                    }
                }
            }

            // ── How it works ──────────────────────────────────────────────────
            Rectangle {
                width:  parent.width - Theme.spacingL * 2
                x:      Theme.spacingL
                implicitHeight: howCol.implicitHeight + Theme.spacingL * 2
                radius: 10
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                border.width: 1

                Column {
                    id: howCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                    spacing: Theme.spacingM

                    RowLayout {
                        spacing: Theme.spacingS
                        EHIcon { name: "help"; size: Theme.iconSize; color: Theme.primary }
                        StyledText {
                            text:           "How it works"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight:    Font.Medium
                            color:          Theme.surfaceText
                        }
                    }

                    Repeater {
                        model: [
                            { step: "1", icon: "search",   text: "Click the search icon to browse, or paste a full path" },
                            { step: "2", icon: "touch_app", text: "Press Enter or click Install — opens the install dialog" },
                            { step: "3", icon: "check",    text: "Review package details, then confirm to install" }
                        ]

                        RowLayout {
                            required property var modelData
                            width:   howCol.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                Layout.alignment: Qt.AlignVCenter
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text:            modelData.step
                                    font.pixelSize:  Theme.fontSizeSmall
                                    font.weight:     Font.Bold
                                    color:           Theme.primary
                                }
                            }

                            EHIcon {
                                name:  modelData.icon
                                size:  16
                                color: Theme.surfaceVariantText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text:           modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color:          Theme.surfaceVariantText
                                wrapMode:       Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Recent installs ───────────────────────────────────────────────
            Rectangle {
                visible: recentInstalls.length > 0
                width:   parent.width - Theme.spacingL * 2
                x:       Theme.spacingL
                implicitHeight: recentCol.implicitHeight + Theme.spacingL * 2
                radius: 10
                color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                border.width: 1

                Column {
                    id: recentCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        EHIcon { name: "history"; size: Theme.iconSize; color: Theme.surfaceVariantText }

                        StyledText {
                            text:           "Recent (this session)"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight:    Font.Medium
                            color:          Theme.surfaceText
                            Layout.fillWidth: true
                        }

                        EHActionButton {
                            circular:  false
                            iconName:  "clear_all"
                            iconSize:  16
                            iconColor: Theme.surfaceVariantText
                            onClicked: recentInstalls = []
                        }
                    }

                    Repeater {
                        model: recentInstalls

                        Item {
                            required property var modelData
                            required property int index
                            width:  recentCol.width
                            height: 36

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: recentItemArea.containsMouse
                                    ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.40)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                spacing: Theme.spacingS

                                EHIcon {
                                    name:  "draft"
                                    size:  14
                                    color: Theme.surfaceVariantText
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text:           modelData.path.split("/").pop()
                                    font.pixelSize: Theme.fontSizeSmall
                                    color:          Theme.surfaceText
                                    elide:          Text.ElideMiddle
                                }

                                StyledText {
                                    text:           modelData.time
                                    font.pixelSize: Theme.fontSizeXS
                                    color:          Theme.surfaceVariantText
                                    opacity:        0.6
                                }

                                EHActionButton {
                                    circular:  false
                                    iconName:  "replay"
                                    iconSize:  14
                                    iconColor: Theme.primary
                                    onClicked: _launchInstall(modelData.path)
                                }
                            }

                            MouseArea {
                                id: recentItemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    _launchInstall(modelData.path)
                            }
                        }
                    }
                }
            }

        }
    }

    // File browser loader
    Loader {
        id: fileBrowserLoader
        active: false
        source: "Modals/FileBrowser/FileBrowserModal.qml"
        onLoaded: {
            item.fileSelected.connect(_onFileBrowserSelected)
            item.dialogClosed.connect(function() { fileBrowserLoader.active = false })
            _setupAndOpenBrowser()
        }
    }
}
