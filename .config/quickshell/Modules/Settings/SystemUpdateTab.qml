import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
//  SystemUpdateTab  —  System package updater
//  Each available update is rendered as its own card with version diff,
//  a type badge, and a critical warning flag where appropriate.
//
//  States: 0=idle  1=checking  2=updatesAvailable  3=error
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    property var parentModal: null

    readonly property bool isBusy: SystemUpdateService.isChecking || SystemUpdateService.isCheckingFlatpak

    readonly property int uiState: {
        if (SystemUpdateService.hasError)        return 3
        if (SystemUpdateService.isChecking)      return 1
        if (SystemUpdateService.updateCount > 0) return 2
        return 0
    }

    function stateColor() {
        switch (uiState) {
            case 0: return Theme.primary
            case 1: return Theme.secondary
            case 2: return "#FF9F43"
            case 3: return "#EF5350"
        }
        return Theme.primary
    }

    function stateIcon() {
        switch (uiState) {
            case 0: return "check_circle"
            case 1: return "sync"
            case 2: return "upgrade"
            case 3: return "error"
        }
        return "info"
    }

    function stateLabel() {
        if (!SystemUpdateService.distributionSupported)
            return "Unsupported distribution"
        if (!SystemUpdateService.pkgManager)
            return "Detecting package manager..."
        if (SystemUpdateService.isChecking || SystemUpdateService.isCheckingFlatpak)
            return "Checking for updates..."
        if (SystemUpdateService.hasError)
            return "Update check failed"
        
        const sysCount = SystemUpdateService.updateCount
        const flatCount = SystemUpdateService.flatpakUpdates.length
        const totalCount = sysCount + flatCount
        
        if (totalCount === 0)
            return "System is up to date"
        
        let label = ""
        if (sysCount > 0) {
            label += sysCount + " system update" + (sysCount === 1 ? "" : "s")
        }
        if (flatCount > 0) {
            if (label !== "") label += ", "
            label += flatCount + " flatpak" + (flatCount === 1 ? "" : "s")
        }
        return label + " available"
    }

    // Classify a package name into a rough category for the badge
    function pkgCategory(name) {
        const n = name.toLowerCase()
        if (n === "linux" || n.startsWith("linux-"))          return "kernel"
        if (n === "systemd" || n === "glibc" || n === "wayland"
            || n === "dbus" || n === "util-linux")            return "system"
        if (n.startsWith("mesa") || n.startsWith("vulkan")
            || n.startsWith("nvidia") || n.startsWith("amd")) return "graphics"
        if (n.startsWith("firefox") || n.startsWith("chromium")
            || n.startsWith("brave"))                         return "browser"
        if (n.startsWith("python") || n.startsWith("node")
            || n === "rust" || n === "go" || n === "java")    return "runtime"
        if (n.startsWith("pipewire") || n.startsWith("pulse")
            || n.startsWith("alsa"))                          return "audio"
        if (n.startsWith("gtk") || n.startsWith("qt")
            || n.startsWith("lib"))                           return "library"
        if (name.startsWith("org.") || name.includes(".flatpak"))
                                               return "flatpak"
        return "package"
    }

    function categoryColor(cat) {
        switch (cat) {
            case "kernel":   return "#EF5350"
            case "system":   return "#FF9F43"
            case "graphics": return "#74c0fc"
            case "browser":  return "#63e6be"
            case "runtime":  return "#da77f2"
            case "audio":    return "#f783ac"
            case "library":  return "#a9e34b"
            case "flatpak":  return "#9775fa"
            default:         return Theme.surfaceVariantText
        }
    }

    function categoryLabel(cat) {
        switch (cat) {
            case "kernel":   return "Kernel"
            case "system":   return "System"
            case "graphics": return "Graphics"
            case "browser":  return "Browser"
            case "runtime":  return "Runtime"
            case "audio":    return "Audio"
            case "library":  return "Library"
            case "flatpak":  return "Flatpak"
            default:         return "Package"
        }
    }

    function isCritical(cat) {
        return (cat === "kernel" || cat === "system") && cat !== "flatpak"
    }

    readonly property bool iconShouldSpin: uiState === 1

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

                // Animated state icon
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

                // Title + subtitle
                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "System Updates"
                        font.pixelSize: Theme.fontSizeXXL
                        font.weight: Font.ExtraBold
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            if (!SystemUpdateService.distributionSupported)
                                return "Unsupported distribution"
                            if (!SystemUpdateService.pkgManager)
                                return "Detecting package manager..."
                            const distro = SystemUpdateService.distribution.charAt(0).toUpperCase()
                                         + SystemUpdateService.distribution.slice(1)
                            return distro + " · " + SystemUpdateService.pkgManager
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // Check button
                Item {
                    width: 148; height: 36
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

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        EHIcon {
                            name: "refresh"
                            size: Theme.fontSizeSmall + 2
                            color: root.isBusy ? Theme.surfaceVariantText : Theme.primary

                            RotationAnimation on rotation {
                                running: root.iconShouldSpin
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 1000
                                easing.type: Easing.Linear
                            }
                        }

                        StyledText {
                            text: root.isBusy ? "Checking..." : "Check for Updates"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: root.isBusy ? Theme.surfaceVariantText : Theme.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { 
                            if (!root.isBusy) SystemUpdateService.checkForUpdates()
                            if (SystemUpdateService.flatpakAvailable) SystemUpdateService.checkForFlatpakUpdates()
                        }
                    }
                }
            }

            // ── 2. Status summary card ─────────────────────────────────────
            UCard {
                cWidth: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    // Status row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        // Pulsing dot
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

                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        StyledText {
                            text: root.stateLabel()
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Error message
                    StyledText {
                        visible: SystemUpdateService.hasError
                        text: SystemUpdateService.errorMessage
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#EF5350"
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    // Install all button (system packages only)
                    Item {
                        visible: SystemUpdateService.updateCount > 0 && !root.isBusy
                        width: parent.width
                        height: visible ? 44 : 0

                        Rectangle {
                            id: installBtn
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: installBtnArea.containsMouse ? "#43A047" : "#4CAF50"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                EHIcon {
                                    name: "download"
                                    size: Theme.fontSizeMedium + 2
                                    color: "#ffffff"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: "Install All  ·  "
                                        + SystemUpdateService.updateCount
                                        + " update"
                                        + (SystemUpdateService.updateCount === 1 ? "" : "s")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            MouseArea {
                                id: installBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemUpdateService.runUpdates()
                            }
                        }
                    }
                }
            }

            // ── 3. Per-package update cards ────────────────────────────────
            Column {
                id: updateCardsColumn
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                spacing: Theme.spacingS
                visible: SystemUpdateService.availableUpdates.length > 0 || (SystemUpdateService.flatpakAvailable && SystemUpdateService.flatpakUpdates.length > 0)

                // Section header
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    EHIcon {
                        name: "inventory_2"
                        size: Theme.iconSize
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "Available Updates"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: SystemUpdateService.availableUpdates.length + " packages"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                // One card per package
                Repeater {
                    model: SystemUpdateService.availableUpdates

                    delegate: Item {
                        id: cardItem
                        required property var modelData
                        required property int index
                        width: updateCardsColumn.width

                        readonly property string cat:    root.pkgCategory(cardItem.modelData.name)
                        readonly property string cColor: root.categoryColor(cat)
                        readonly property bool   crit:   root.isCritical(cat)

                        height: pkgCard.implicitHeight

                        // Staggered fade-in
                        opacity: 0
                        Component.onCompleted: appearTimer.start()

                        Timer {
                            id: appearTimer
                            interval: cardItem.index * 45
                            onTriggered: cardItem.opacity = 1
                        }
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        // ── Glow layer beneath the card ──────────────────────
                        Rectangle {
                            anchors.centerIn: pkgCard
                            width:  pkgCard.width  - 12
                            height: pkgCard.height - 8
                            radius: 18
                            color:  "transparent"
                            visible: cardHover.containsMouse
                            layer.enabled: true
                            layer.effect: null   // glow via border only; blur not available without effects module
                            border.color: Qt.rgba(
                                Qt.color(cardItem.cColor).r,
                                Qt.color(cardItem.cColor).g,
                                Qt.color(cardItem.cColor).b, 0.18)
                            border.width: 6
                        }

                        // ── Main glass card ───────────────────────────────────
                        Rectangle {
                            id: pkgCard
                            width: parent.width
                            implicitHeight: cardRow.implicitHeight + Theme.spacingL * 2
                            radius: 16
                            clip: true

                            // Frosted glass base — layered for depth
                            color: cardHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.09)
                                : Qt.rgba(1, 1, 1, 0.05)

                            border.color: cardHover.containsMouse
                                ? Qt.rgba(
                                    Qt.color(cardItem.cColor).r,
                                    Qt.color(cardItem.cColor).g,
                                    Qt.color(cardItem.cColor).b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Behavior on color        { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            // Coloured tint wash in the bg — category hue bleeds through the glass
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(
                                    Qt.color(cardItem.cColor).r,
                                    Qt.color(cardItem.cColor).g,
                                    Qt.color(cardItem.cColor).b,
                                    cardHover.containsMouse ? 0.07 : 0.03)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            // ── Card content ──────────────────────────────────
                            RowLayout {
                                id: cardRow
                                anchors {
                                    left:        parent.left
                                    right:       parent.right
                                    top:         parent.top
                                    leftMargin:  Theme.spacingL
                                    rightMargin: Theme.spacingL
                                    topMargin:   Theme.spacingL
                                    bottomMargin: Theme.spacingL
                                }
                                spacing: Theme.spacingM

                                // ── Type icon bubble ──────────────────────────
                                Rectangle {
                                    width:  38; height: 38
                                    radius: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Qt.rgba(
                                        Qt.color(cardItem.cColor).r,
                                        Qt.color(cardItem.cColor).g,
                                        Qt.color(cardItem.cColor).b, 0.15)
                                    border.color: Qt.rgba(
                                        Qt.color(cardItem.cColor).r,
                                        Qt.color(cardItem.cColor).g,
                                        Qt.color(cardItem.cColor).b, 0.35)
                                    border.width: 1

                                    EHIcon {
                                        anchors.centerIn: parent
                                        size: 20
                                        color: cardItem.cColor
                                        name: {
                                            switch (cardItem.cat) {
                                                case "kernel":   return "memory"
                                                case "system":   return "settings_suggest"
                                                case "graphics": return "videocam"
                                                case "browser":  return "language"
                                                case "runtime":  return "code"
                                                case "audio":    return "volume_up"
                                                case "library":  return "library_books"
                                                case "flatpak":  return "apps"
                                                default:         return "inventory_2"
                                            }
                                        }
                                    }
                                }

                                // ── Package name + version diff ───────────────
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    // Name + critical badge row
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: cardItem.modelData.name
                                            font.pixelSize: Theme.fontSizeMedium * 2
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Critical badge
                                        Rectangle {
                                            visible: cardItem.crit
                                            width:  critLabel.implicitWidth + Theme.spacingS * 2
                                            height: critLabel.implicitHeight + 4
                                            radius: 4
                                            color: Qt.rgba(Qt.color("#EF5350").r, Qt.color("#EF5350").g, Qt.color("#EF5350").b, 0.15)
                                            border.color: Qt.rgba(Qt.color("#EF5350").r, Qt.color("#EF5350").g, Qt.color("#EF5350").b, 0.45)
                                            border.width: 1
                                            Layout.alignment: Qt.AlignVCenter

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 3

                                                EHIcon {
                                                    name: "warning"
                                                    size: 10
                                                    color: "#EF5350"
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                StyledText {
                                                    id: critLabel
                                                    text: "CRITICAL"
                                                    font.pixelSize: Theme.fontSizeXS
                                                    font.weight: Font.Bold
                                                    color: "#EF5350"
                                                    font.letterSpacing: 0.6
                                                }
                                            }
                                        }
                                    }

                                    // Version diff
                                    RowLayout {
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: cardItem.modelData.currentVersion
                                            font.pixelSize: Theme.fontSizeSmall * 2
                                            color: Theme.surfaceVariantText
                                        }

                                        EHIcon {
                                            name: "arrow_forward"
                                            size: Theme.fontSizeSmall * 2
                                            color: Theme.surfaceVariantText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        StyledText {
                                            text: cardItem.modelData.newVersion
                                            font.pixelSize: Theme.fontSizeSmall * 2
                                            color: cardItem.cColor
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                // ── Category pill badge ───────────────────────
                                Rectangle {
                                    width:  catText.implicitWidth + Theme.spacingM * 2
                                    height: catText.implicitHeight + Theme.spacingXS * 2
                                    radius: height / 2
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Qt.rgba(
                                        Qt.color(cardItem.cColor).r,
                                        Qt.color(cardItem.cColor).g,
                                        Qt.color(cardItem.cColor).b, 0.12)
                                    border.color: Qt.rgba(
                                        Qt.color(cardItem.cColor).r,
                                        Qt.color(cardItem.cColor).g,
                                        Qt.color(cardItem.cColor).b, 0.35)
                                    border.width: 1

                                    StyledText {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: root.categoryLabel(cardItem.cat).toUpperCase()
                                        font.pixelSize: Theme.fontSizeXS
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.7
                                        color: cardItem.cColor
                                    }
                                }
                            }

                            MouseArea {
                                id: cardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            // ── 3b. Flatpak update card ─────────────────────────────────────────
            Column {
                id: flatpakCard
                width: parent.width - Theme.spacingL * 2
                x: Theme.spacingL
                spacing: Theme.spacingS
                visible: SystemUpdateService.flatpakAvailable && SystemUpdateService.flatpakUpdates.length > 0

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    EHIcon {
                        name: "apps"
                        size: Theme.iconSize
                        color: "#9775fa"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "Flatpak Updates"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: SystemUpdateService.flatpakUpdates.length + " flatpak" + (SystemUpdateService.flatpakUpdates.length === 1 ? "" : "s")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                Repeater {
                    model: SystemUpdateService.flatpakUpdates

                    delegate: Item {
                        id: flatpakCardItem
                        required property var modelData
                        required property int index
                        width: flatpakCard.width

                        readonly property string cColor: "#9775fa"

                        height: flatpakPkgCard.implicitHeight

                        opacity: 0
                        Component.onCompleted: flatpakAppearTimer.start()

                        Timer {
                            id: flatpakAppearTimer
                            interval: flatpakCardItem.index * 45
                            onTriggered: flatpakCardItem.opacity = 1
                        }
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.centerIn: flatpakPkgCard
                            width:  flatpakPkgCard.width  - 12
                            height: flatpakPkgCard.height - 8
                            radius: 18
                            color:  "transparent"
                            visible: flatpakCardHover.containsMouse
                            layer.enabled: true
                            border.color: Qt.rgba(0.592, 0.459, 0.980, 0.18)
                            border.width: 6
                        }

                        Rectangle {
                            id: flatpakPkgCard
                            width: parent.width
                            implicitHeight: flatpakCardRow.implicitHeight + Theme.spacingL * 2
                            radius: 16
                            clip: true
                            color: flatpakCardHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.09)
                                : Qt.rgba(1, 1, 1, 0.05)
                            border.color: flatpakCardHover.containsMouse
                                ? Qt.rgba(0.592, 0.459, 0.980, 0.55)
                                : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(0.592, 0.459, 0.980,
                                    flatpakCardHover.containsMouse ? 0.07 : 0.03)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            RowLayout {
                                id: flatpakCardRow
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: Theme.spacingL
                                    rightMargin: Theme.spacingL
                                    topMargin: Theme.spacingL
                                    bottomMargin: Theme.spacingL
                                }
                                spacing: Theme.spacingM

                                Rectangle {
                                    width:  38; height: 38
                                    radius: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Qt.rgba(0.592, 0.459, 0.980, 0.15)
                                    border.color: Qt.rgba(0.592, 0.459, 0.980, 0.35)
                                    border.width: 1

                                    EHIcon {
                                        anchors.centerIn: parent
                                        size: 20
                                        color: "#9775fa"
                                        name: "apps"
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: flatpakCardItem.modelData.name
                                            font.pixelSize: Math.round((Theme.fontSizeMedium || 14) * 2)
                                            font.weight: Font.SemiBold
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Rectangle {
                                            width:  flatpakBranchLabel.implicitWidth + Theme.spacingS * 2
                                            height: flatpakBranchLabel.implicitHeight + 4
                                            radius: 4
                                            color: Qt.rgba(0.592, 0.459, 0.980, 0.15)
                                            border.color: Qt.rgba(0.592, 0.459, 0.980, 0.45)
                                            border.width: 1
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                id: flatpakBranchLabel
                                                anchors.centerIn: parent
                                                text: (flatpakCardItem.modelData.branch || "").toUpperCase()
                                                font.pixelSize: Theme.fontSizeXS
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.7
                                                color: "#9775fa"
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: flatpakCardItem.modelData.origin + " · Op: " + flatpakCardItem.modelData.operation
                                        font.pixelSize: Theme.fontSizeSmall * 2
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        spacing: Theme.spacingM

                                        StyledText {
                                            text: "↓ " + flatpakCardItem.modelData.downloadSize
                                            font.pixelSize: Theme.fontSizeSmall * 2
                                            color: Theme.surfaceVariantText
                                        }

                                        Rectangle {
                                            visible: flatpakCardItem.modelData.isPartial
                                            width: partialLabel.implicitWidth + Theme.spacingS * 2
                                            height: partialLabel.implicitHeight + 4
                                            radius: 4
                                            color: Qt.rgba(0.898, 0.224, 0.208, 0.15)
                                            border.color: Qt.rgba(0.898, 0.224, 0.208, 0.45)
                                            border.width: 1
                                            Layout.alignment: Qt.AlignVCenter

                                            StyledText {
                                                id: partialLabel
                                                anchors.centerIn: parent
                                                text: "PARTIAL"
                                                font.pixelSize: Theme.fontSizeXS
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.6
                                                color: "#EF5350"
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: flatpakCardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 36
                    visible: SystemUpdateService.flatpakUpdates.length > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: flatpakUpdateBtnArea.containsMouse ? "#7c3aed" : "#8b5cf6"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            EHIcon {
                                name: "download"
                                size: Theme.fontSizeMedium
                                color: "#ffffff"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: "Update Flatpaks"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: flatpakUpdateBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SystemUpdateService.runUpdatesFlatpak()
                        }
                    }
                }
            }

            // ── 4. Settings card ───────────────────────────────────────────
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
                                text: "Auto-check interval"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Checks for updates every 30 minutes"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        StyledText {
                            text: "30 min"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            // ── 5. Footer ──────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 28

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    EHIcon {
                        name: "info"
                        size: 14
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "Updates require terminal authentication"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        opacity: 0.7
                    }
                }
            }

        }
    }
}
