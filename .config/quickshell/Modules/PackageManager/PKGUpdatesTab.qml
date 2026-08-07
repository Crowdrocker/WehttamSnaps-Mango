import QtQuick
import QtQuick.Layouts
import QtQuick.Controls   // Required for ScrollBar
import qs.Common
import qs.Services
import qs.Widgets

// ─────────────────────────────────────────────────────────────────────────────
//  PKGUpdatesTab  —  Available updates across all package sources
//  Very closely mirrors SystemUpdateTab's card design
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property var parentModal: null

    // FIX: was Component.onCompleted — that fired every time the Loader
    // recreated this component (on every tab switch), causing the async
    // checkForUpdates() callback to mutate shared state while the Home tab
    // was visible, bleeding update cards into it.
    // onVisibleChanged only fires when this tab actually becomes visible.
    onVisibleChanged: {
        if (visible) PackageManagerService.checkForUpdates()
    }

    readonly property bool isBusy:       PackageManagerService.isLoading
    readonly property int  updateCount:  PackageManagerService.availableUpdates.length

    readonly property int uiState: {
        if (PackageManagerService.lastError !== "") return 3
        if (PackageManagerService.isLoading)        return 1
        if (updateCount > 0)                        return 2
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
        if (PackageManagerService.isLoading)
            return PackageManagerService.currentOperation || "Checking for updates…"
        if (PackageManagerService.lastError !== "")
            return "Update check failed"
        if (updateCount === 0)
            return "All packages are up to date"
        return updateCount + " update" + (updateCount === 1 ? "" : "s") + " available"
    }

    function sourceColor(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"
            case "aur":     return "#a9e34b"
            case "apt":     return "#FF9F43"
            case "dnf":     return "#EF5350"
            case "flatpak": return "#9775fa"
            default:        return Theme.surfaceVariantText
        }
    }

    EHFlickable {
        id: scroller
        anchors.fill:     parent
        anchors.topMargin: Theme.spacingL
        clip:              true
        contentHeight:     mainColumn.implicitHeight + Theme.spacingXL * 2
        contentWidth:      width

        ScrollBar.vertical: ScrollBar {}

        Column {
            id: mainColumn
            width:         scroller.width
            spacing:       Theme.spacingL
            topPadding:    Theme.spacingS
            bottomPadding: Theme.spacingXL

            // ── 1. Header ─────────────────────────────────────────────────────
            RowLayout {
                width: parent.width - Theme.spacingL * 2
                x:     Theme.spacingL
                spacing: Theme.spacingM

                // Animated state icon
                Item {
                    width: 52; height: 52
                    Layout.alignment: Qt.AlignVCenter

                    EHIcon {
                        anchors.centerIn: parent
                        name:  root.stateIcon()
                        size:  44
                        color: root.stateColor()

                        RotationAnimation on rotation {
                            running:  root.isBusy
                            loops:    Animation.Infinite
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
                        text:           "Package Updates"
                        font.pixelSize: Theme.fontSizeXXL
                        font.weight:    Font.ExtraBold
                        color:          Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            const d = PackageManagerService.distribution
                            const p = PackageManagerService.pkgManager
                            if (!d && !p) return "Detecting…"
                            const dn = d ? (d.charAt(0).toUpperCase() + d.slice(1)) : ""
                            return dn + (p ? " · " + p : "")
                                + (PackageManagerService.flatpakAvailable ? " + flatpak" : "")
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
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

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            EHIcon {
                                name:  "refresh"
                                size:  Theme.fontSizeSmall + 2
                                color: root.isBusy ? Theme.surfaceVariantText : Theme.primary

                                RotationAnimation on rotation {
                                    running:  root.isBusy
                                    loops:    Animation.Infinite
                                    from: 0; to: 360
                                    duration: 1000
                                    easing.type: Easing.Linear
                                }
                            }

                            StyledText {
                                text:           root.isBusy ? "Checking…" : "Check Updates"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight:    Font.Medium
                                color: root.isBusy ? Theme.surfaceVariantText : Theme.primary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    { if (!root.isBusy) PackageManagerService.checkForUpdates() }
                        }
                    }
                }
            }

            // ── 2. Status summary card ────────────────────────────────────────
            Rectangle {
                width: parent.width - Theme.spacingL * 2
                x:     Theme.spacingL
                implicitHeight: cardColumn.implicitHeight + Theme.spacingL * 2
                radius: 10
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                border.width: 1

                Column {
                    id: cardColumn                        // FIX: was missing id, breaking implicitHeight binding
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        margins: Theme.spacingL
                    }
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        // Pulsing dot
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.stateColor()
                            Layout.alignment: Qt.AlignVCenter

                            SequentialAnimation on opacity {
                                running: root.isBusy
                                loops:   Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600 }
                                NumberAnimation { to: 1.0; duration: 600 }
                            }

                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        StyledText {
                            text:           root.stateLabel()
                            font.pixelSize: Theme.fontSizeMedium
                            color:          Theme.surfaceText
                            Layout.fillWidth: true
                            elide:          Text.ElideRight
                        }
                    }

                    // Error message
                    StyledText {
                        visible:        PackageManagerService.lastError !== ""
                        text:           PackageManagerService.lastError
                        font.pixelSize: Theme.fontSizeSmall
                        color:          "#EF5350"
                        width:          parent.width
                        wrapMode:       Text.Wrap
                    }

                    // Upgrade all button
                    Item {
                        visible: updateCount > 0 && !root.isBusy
                        width:   parent.width
                        height:  visible ? 40 : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color:  upgradeArea.containsMouse ? "#43A047" : "#4CAF50"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                EHIcon {
                                    name:  "download"
                                    size:  Theme.fontSizeMedium + 2
                                    color: "#ffffff"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: "Upgrade All  ·  "
                                        + updateCount + " update"
                                        + (updateCount === 1 ? "" : "s")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight:    Font.Bold
                                    color:          "#ffffff"
                                }
                            }

                            MouseArea {
                                id: upgradeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    root.parentModal ? root.parentModal.getUpgradeWindow().open() : PackageManagerService.upgradeAll()
                            }
                        }
                    }
                }
            }

            // ── 3. Update cards ───────────────────────────────────────────────
            Column {
                id: updateCardsColumn
                width:   parent.width - Theme.spacingL * 2
                x:       Theme.spacingL
                spacing: Theme.spacingS
                visible: updateCount > 0

                // Section header
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    EHIcon {
                        name:  "upgrade"
                        size:  Theme.iconSize
                        color: "#FF9F43"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text:           "Available Updates"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text:           updateCount + " packages"
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                    }
                }

                // One card per pending update
                Repeater {
                    model: PackageManagerService.availableUpdates

                    delegate: Item {
                        id: updateItem
                        required property var modelData
                        // FIX: drop "required" — JS array models inject index implicitly,
                        // not as a named role, so "required" fails with undefined.
                        // index is available automatically in Repeater delegates

                        width:  updateCardsColumn.width
                        height: updateCard.implicitHeight

                        readonly property string availColor: root.sourceColor(modelData.source || "")

                        opacity: 0
                        Component.onCompleted: updateAppear.start()
                        Timer {
                            id: updateAppear
                            interval: (typeof updateItem.index !== "undefined" ? updateItem.index : 0) * 45
                            onTriggered: updateItem.opacity = 1
                        }
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        // Glow halo
                        Rectangle {
                            anchors.centerIn: updateCard
                            width:   updateCard.width  - 12
                            height:  updateCard.height - 8
                            radius:  18
                            color:   "transparent"
                            visible: updateHover.containsMouse
                            border.color: Qt.rgba(
                                Qt.color(updateItem.availColor).r, Qt.color(updateItem.availColor).g, Qt.color(updateItem.availColor).b, 0.18)
                            border.width: 6
                        }

                        // Glass card
                        Rectangle {
                            id: updateCard
                            width: parent.width
                            implicitHeight: updateCardRow.implicitHeight + Theme.spacingM + Theme.spacingS
                            radius: 10
                            clip:   true

                            color: updateHover.containsMouse ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.05)
                            border.color: updateHover.containsMouse
                                ? Qt.rgba(Qt.color(updateItem.availColor).r, Qt.color(updateItem.availColor).g, Qt.color(updateItem.availColor).b, 0.55)
                                : Qt.rgba(1,1,1,0.10)
                            border.width: 1
                            Behavior on color        { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            // Tint wash
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(
                                    Qt.color(updateItem.availColor).r, Qt.color(updateItem.availColor).g, Qt.color(updateItem.availColor).b,
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

                                // Source icon bubble
                                Rectangle {
                                    width: 34; height: 34; radius: 8
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Qt.rgba(Qt.color(updateItem.availColor).r, Qt.color(updateItem.availColor).g, Qt.color(updateItem.availColor).b, 0.15)
                                    border.color: Qt.rgba(Qt.color(updateItem.availColor).r, Qt.color(updateItem.availColor).g, Qt.color(updateItem.availColor).b, 0.35)
                                    border.width: 1

                                    EHIcon {
                                        anchors.centerIn: parent
                                        size:  20
                                        color: updateItem.availColor
                                        name: {
                                            switch (updateItem.modelData.source) {
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

                                // Name + version diff
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    StyledText {
                                        text:           updateItem.modelData.name || ""
                                        font.pixelSize: Theme.fontSizeMedium  // FIX: was * 2
                                        font.weight:    Font.Bold
                                        color:          Theme.surfaceText
                                        elide:          Text.ElideRight
                                        width:          parent.width
                                    }

                                    RowLayout {
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text:           updateItem.modelData.version    || "–"
                                            font.pixelSize: Theme.fontSizeSmall  // FIX: was * 2
                                            color:          Theme.surfaceVariantText
                                        }

                                        EHIcon {
                                            name:  "arrow_forward"
                                            size:  Theme.fontSizeSmall  // FIX: was * 2
                                            color: Theme.surfaceVariantText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        StyledText {
                                            text:           updateItem.modelData.newVersion || "?"
                                            font.pixelSize: Theme.fontSizeSmall  // FIX: was * 2
                                            color:          updateItem.availColor
                                            font.weight:    Font.Medium
                                        }
                                    }
                                }

                                // Source badge
                                PKGSourceBadge {
                                    source: updateItem.modelData.source || ""
                                    Layout.alignment: Qt.AlignVCenter
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

            // ── 4. Empty up-to-date state ─────────────────────────────────────
            Item {
                width:   parent.width
                height:  220
                visible: uiState === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    EHIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name:  "check_circle"
                        size:  56
                        color: Theme.primary
                        opacity: 0.7
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:           "Everything is up to date"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:           "No pending updates"
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                    }
                }
            }

            // ── 5. Footer ─────────────────────────────────────────────────────
            Item {
                width:  parent.width
                height: 28

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    EHIcon {
                        name:  "info"
                        size:  14
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text:           "Updates are applied via terminal"
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceVariantText
                        opacity:        0.7
                    }
                }
            }
        }
    }
}
