import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
//  UpdateTab  —  Event Horizon Dotfiles updater
//  Checks GitHub releases, downloads & extracts into ~/.config/{hypr,quickshell}
//  with automatic pre-install backup and manual backup / restore support.
//
//  Required sibling files (same directory as this file):
//    UCard.qml  UDivider.qml  UActionButton.qml  UBackupRow.qml
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    property var parentModal: null

    readonly property bool isBusy: DotfilesUpdateService.isBusy

    // 0=idle  1=checking  2=updateAvailable  3=downloading  4=installing
    // 5=error  6=restoring  8=backingUp
    readonly property int uiState: {
        if (DotfilesUpdateService.hasError)        return 5
        if (DotfilesUpdateService.isRestoring)     return 6
        if (DotfilesUpdateService.isBackingUp)     return 8
        if (DotfilesUpdateService.isInstalling)    return 4
        if (DotfilesUpdateService.isDownloading)   return 3
        if (DotfilesUpdateService.updateAvailable) return 2
        if (DotfilesUpdateService.isChecking)      return 1
        return 0
    }

    function stateColor() {
        switch (uiState) {
            case 0: return Theme.primary
            case 1: return Theme.secondary
            case 2: return "#4CAF50"
            case 3: return Theme.secondary
            case 4: return Theme.secondary
            case 5: return "#EF5350"
            case 6: return "#FF9800"
            case 8: return "#FF9800"
        }
        return Theme.primary
    }

    function stateIcon() {
        switch (uiState) {
            case 0: return "check_circle"
            case 1: return "sync"
            case 2: return "upgrade"
            case 3: return "download"
            case 4: return "autorenew"
            case 5: return "error"
            case 6: return "restore"
            case 8: return "backup"
        }
        return "info"
    }

    readonly property bool iconShouldSpin:
        uiState === 1 || uiState === 3 || uiState === 4 || uiState === 6 || uiState === 8

    // ════════════════════════════════════════════════════════════════════════
    //  Scrollable body
    // ════════════════════════════════════════════════════════════════════════

    EHFlickable {
        id: scroller
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingXL * 2
        contentWidth: width

        Column {
            id: mainColumn
            width: scroller.width
            spacing: Theme.spacingL
            topPadding: Theme.spacingS
            bottomPadding: Theme.spacingXL

            // ── 1. Header ──────────────────────────────────────────────────
            RowLayout {
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                spacing: Theme.spacingM

                Item {
                    width: 52; height: 52
                    Layout.alignment: Qt.AlignVCenter

                    EHIcon {
                        id: headerIcon
                        anchors.centerIn: parent
                        name: root.stateIcon()
                        size: 44
                        color: root.stateColor()

                        RotationAnimation on rotation {
                            running: root.iconShouldSpin
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: 1400
                            easing.type: Easing.Linear
                        }

                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Event Horizon Dotfiles"
                        font.pixelSize: Theme.fontSizeXXL
                        font.weight: Font.ExtraBold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            var base = "Installed  v" + DotfilesUpdateService.currentVersion
                            var latest = DotfilesUpdateService.latestVersion
                            if (latest && latest !== DotfilesUpdateService.currentVersion)
                                return base + "   ·   Latest  v" + latest
                            return base
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Item {
                    width: 138; height: 36
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: root.isBusy
                            ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.6)
                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        border.color: root.isBusy ? Theme.outline : Theme.primary
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.isBusy ? "Cancel" : "Check for Updates"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: root.isBusy ? Theme.surfaceVariantText : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isBusy
                            ? DotfilesUpdateService.cancelOperation()
                            : DotfilesUpdateService.checkForUpdates()
                    }
                }
            }

            // ── 2. Status / progress card ──────────────────────────────────
            UCard {
                cWidth: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.stateColor()
                            Layout.alignment: Qt.AlignVCenter

                            SequentialAnimation on opacity {
                                running: root.iconShouldSpin
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }
                        }

                        StyledText {
                            text: DotfilesUpdateService.statusMessage
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        visible: DotfilesUpdateService.hasError
                        text: DotfilesUpdateService.errorMessage
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#EF5350"
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    // Progress bar
                    Item {
                        visible: DotfilesUpdateService.isDownloading || DotfilesUpdateService.isInstalling
                        width: parent.width
                        height: 6

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        }

                        Rectangle {
                            width: parent.width * (DotfilesUpdateService.downloadProgress / 100)
                            height: parent.height
                            radius: 3
                            color: root.stateColor()
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }

                        Rectangle {
                            visible: DotfilesUpdateService.isInstalling
                            width: parent.width * 0.3
                            height: parent.height
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.35)

                            SequentialAnimation on x {
                                running: DotfilesUpdateService.isInstalling
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: -(parent.parent.width * 0.3)
                                    to: parent.parent.width
                                    duration: 1200
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }

                    // Install button
                    Item {
                        visible: DotfilesUpdateService.updateAvailable && !root.isBusy
                        width: parent.width
                        height: visible ? 44 : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: "#4CAF50"

                            StyledText {
                                anchors.centerIn: parent
                                text: "Download & Install  v" + DotfilesUpdateService.latestVersion
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DotfilesUpdateService.downloadAndInstall()
                            }
                        }
                    }

                    // Reload button
                    Item {
                        visible: !DotfilesUpdateService.updateAvailable &&
                                 !root.isBusy &&
                                 DotfilesUpdateService.latestVersion !== "" &&
                                 DotfilesUpdateService.currentVersion === DotfilesUpdateService.latestVersion
                        width: parent.width
                        height: visible ? 40 : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 1

                            StyledText {
                                anchors.centerIn: parent
                                text: "Reload Quickshell"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DotfilesUpdateService.reloadQuickshell()
                            }
                        }
                    }
                }
            }

            // ── 3. Release Notes ───────────────────────────────────────────
            UCard {
                cWidth: parent.width
                visible: DotfilesUpdateService.releaseNotes !== ""

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "description"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Release Notes"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: DotfilesUpdateService.publishedAt !== ""
                            text: DotfilesUpdateService.publishedAt.slice(0, 10)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    UDivider { width: parent.width }

                    StyledText {
                        text: DotfilesUpdateService.releaseNotes
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.Wrap
                        lineHeight: 1.5
                    }
                }
            }

            // ── 4. Backup & Restore ────────────────────────────────────────
            UCard {
                cWidth: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "backup"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Backup & Restore"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Saves ~/.config/hypr  and  ~/.config/quickshell"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.family: "monospace"
                            }
                        }
                    }

                    UDivider { width: parent.width }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        UActionButton {
                            Layout.fillWidth: true
                            label: "Backup Now"
                            iconName: "backup"
                            accent: Theme.primary
                            enabled: !root.isBusy
                            onAction: DotfilesUpdateService.createBackup()
                        }

                        UActionButton {
                            Layout.fillWidth: true
                            label: "Refresh List"
                            iconName: "refresh"
                            accent: Theme.secondary
                            enabled: !root.isBusy
                            onAction: DotfilesUpdateService.refreshBackupList()
                        }
                    }

                    StyledText {
                        visible: DotfilesUpdateService.backupList.length > 0
                        text: "Saved backups  (" + DotfilesUpdateService.backupList.length + ")"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    Repeater {
                        model: DotfilesUpdateService.backupList

                        UBackupRow {
                            width: parent.width
                            backupLabel: modelData.label
                            canRestore:  !root.isBusy
                            onRestoreRequested: DotfilesUpdateService.restoreBackup()
                            onDeleteRequested:  DotfilesUpdateService.deleteBackup()
                        }
                    }

                    Item {
                        visible: DotfilesUpdateService.backupList.length === 0
                        width: parent.width
                        height: 48

                        StyledText {
                            anchors.centerIn: parent
                            text: "No backup found — use Backup Now to create one"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            opacity: 0.6
                        }
                    }
                }
            }

            // ── 5. Settings ────────────────────────────────────────────────
            UCard {
                cWidth: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "settings"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }
                    }

                    UDivider { width: parent.width }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Check on startup"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically check for updates when Quickshell starts"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        EHToggle {
                            id: autoCheckToggle
                            checked: true
                        }
                    }
                }
            }

            // ── 6. Footer ──────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 28

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    EHIcon {
                        name: "link"
                        size: 14
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "github.com/ryzendew/Event-Horizon-Dotfiles-Issue"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.family: "monospace"
                        opacity: 0.7
                    }
                }
            }

        }
    }
}
