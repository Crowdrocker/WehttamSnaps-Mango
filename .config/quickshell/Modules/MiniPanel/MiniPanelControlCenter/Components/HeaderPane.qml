import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell          // ← Added this import (required for Quickshell.execDetached)
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }
    property real scaleFactor: uiScale

    property bool powerOptionsExpanded: false
    property bool editMode: false

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested()
    signal editModeToggled()

    implicitHeight: spx(72)
    radius: Theme.cornerRadius
    
    // Compact dock-style background
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * 0.3
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingL + 2
        anchors.rightMargin: Theme.spacingL
        anchors.topMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        spacing: Theme.spacingM

        EHCircularImage {
            id: avatarContainer
            width: root.spx(48)
            height: root.spx(48)
            Layout.alignment: Qt.AlignVCenter
            imageSource: {
                if (PortalService.profileImage === "") return ""
                if (PortalService.profileImage.startsWith("/")) return "file://" + PortalService.profileImage
                return PortalService.profileImage
            }
            fallbackIcon: "settings"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                text: UserInfoService.fullName || UserInfoService.username || "User"
                font.pixelSize: Math.max(12, root.spx(15))
                font.weight: Font.SemiBold
                color: Theme.surfaceText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: (UserInfoService.uptime || "Unknown")
                font.pixelSize: Math.max(11, root.spx(12))
                color: Theme.surfaceVariantText
            }
        }

        // Compact dock-style action buttons
        RowLayout {
            id: actionButtonsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingM

            readonly property int btn: root.spx(52)
            readonly property int rad: root.spx(12)
            readonly property int icon: root.spx(26)

        Rectangle {
            width: actionButtonsRow.btn
            height: actionButtonsRow.btn
            radius: actionButtonsRow.rad
            color: lockArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4) : "transparent"
            border.width: 0

            EHIcon {
                anchors.centerIn: parent
                name: "lock"
                size: actionButtonsRow.icon
                color: Theme.surfaceText
            }

            MouseArea {
                id: lockArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.lockRequested()
            }
        }

        Rectangle {
            width: actionButtonsRow.btn
            height: actionButtonsRow.btn
            radius: actionButtonsRow.rad
            color: powerArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4) : (root.powerOptionsExpanded ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : "transparent")
            border.width: 0

            EHIcon {
                anchors.centerIn: parent
                name: root.powerOptionsExpanded ? "expand_less" : "power_settings_new"
                size: actionButtonsRow.icon
                color: root.powerOptionsExpanded ? Theme.primary : Theme.surfaceText
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerOptionsExpanded = !root.powerOptionsExpanded
            }
        }

        Rectangle {
            width: actionButtonsRow.btn
            height: actionButtonsRow.btn
            radius: actionButtonsRow.rad
            color: settingsArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4) : "transparent"
            border.width: 0

            EHIcon {
                anchors.centerIn: parent
                name: "settings"
                size: actionButtonsRow.icon
                color: Theme.surfaceText
            }

            MouseArea {
                id: settingsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Fixed: Open settings using IPC (no more ReferenceError)
                    ModalManager.openSettingsRequested()
                }
            }
        }

        } // actionButtonsRow
    }
}
