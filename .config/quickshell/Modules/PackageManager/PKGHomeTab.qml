import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    property var parentModal: null

    readonly property int flatpakCount: {
        if (!PackageManagerService.flatpakAvailable) return 0
        return PackageManagerService.installedPackages.filter(p => p.source === "flatpak").length
    }

    readonly property int systemPkgCount: {
        return PackageManagerService.installedPackages.filter(p => p.source !== "flatpak").length
    }

    readonly property int orphanCount: PackageManagerService.orphanedPackages.length

    Connections {
        target: PackageManagerService
        function onCapabilitiesDetected() {
            if (PackageManagerService.installedPackages.length === 0) {
                PackageManagerService.getInstalledPackages(true)
            }
        }
    }

    Component.onCompleted: {
        if (!PackageManagerService.isLoading && PackageManagerService.installedPackages.length === 0) {
            PackageManagerService.getInstalledPackages(true)
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: statsSection.implicitHeight + Theme.spacingL * 2
                radius: 10
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: statsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "analytics"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Package Overview"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StatCard {
                            cardWidth: (parent.width - Theme.spacingM) / 2
                            cardHeight: 100
                            title: "System Packages"
                            value: root.systemPkgCount
                            icon: "inventory_2"
                            accentColor: Theme.primary
                        }

                        StatCard {
                            cardWidth: (parent.width - Theme.spacingM) / 2
                            cardHeight: 100
                            title: "Flatpak Apps"
                            value: PackageManagerService.flatpakAvailable ? root.flatpakCount : "N/A"
                            icon: "apps"
                            accentColor: "#1f78d0"
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StatCard {
                            cardWidth: (parent.width - Theme.spacingM) / 2
                            cardHeight: 100
                            title: "Available Updates"
                            value: PackageManagerService.availableUpdates.length
                            icon: "upgrade"
                            accentColor: "#2e7d32"
                            cardClicked: function() {
                                if (parentModal) parentModal.showTab(3)
                            }
                        }

                        StatCard {
                            cardWidth: (parent.width - Theme.spacingM) / 2
                            cardHeight: 100
                            title: "Orphaned"
                            value: root.orphanCount
                            icon: "warning"
                            accentColor: "#c62828"
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: actionsSection.implicitHeight + Theme.spacingL * 2
                radius: 10
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: actionsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "bolt"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Quick Actions"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        spacing: Theme.spacingL
                        width: parent.width

                        QuickActionButton {
                            text: "Sync & Update"
                            iconName: "sync"
                            busy: PackageManagerService.isInstalling
                            clickHandler: function() { PackageManagerService.syncAndUpdate() }
                        }

                        QuickActionButton {
                            text: "Clean Cache"
                            iconName: "mop"
                            busy: PackageManagerService.isInstalling
                            clickHandler: function() { PackageManagerService.cleanCache() }
                        }

                        QuickActionButton {
                            text: "Remove Orphans"
                            iconName: "auto_delete"
                            busy: PackageManagerService.isInstalling
                            disabled: root.orphanCount === 0
                            clickHandler: function() { PackageManagerService.removeOrphans() }
                        }
                    }
                }
            }
        }
    }

    component StatCard: Rectangle {
        property string title: ""
        property var value: 0
        property string icon: ""
        property color accentColor: Theme.primary
        property var cardClicked: null
        property real cardWidth: 150
        property real cardHeight: 100

        width: cardWidth
        height: cardHeight
        radius: 8
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            EHIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: icon
                size: 24
                color: parent.accentColor || Theme.primary
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: title
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: value
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (cardClicked) cardClicked()
        }
    }

    component QuickActionButton: Rectangle {
        property string text: ""
        property string iconName: ""
        property var clickHandler: null
        property bool busy: false
        property bool disabled: false

        readonly property bool isActive: !busy && !disabled

        width: buttonRow.implicitWidth + Theme.spacingL * 2
        height: 44
        radius: 8
        color: !isActive
            ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
        border.color: !isActive
            ? Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
        border.width: 1
        opacity: disabled ? 0.45 : 1.0

        Behavior on color  { ColorAnimation { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: Theme.spacingM

            EHIcon {
                name: busy ? "sync" : iconName
                size: 22
                color: !isActive ? Theme.surfaceVariantText : Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                RotationAnimation on rotation {
                    running: busy
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1000
                    easing.type: Easing.Linear
                }
            }

            StyledText {
                text: busy ? "Working…" : parent.parent.text
                font.pixelSize: Theme.fontSizeMedium
                color: !isActive ? Theme.surfaceVariantText : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (isActive && clickHandler) clickHandler()
        }
    }
}
