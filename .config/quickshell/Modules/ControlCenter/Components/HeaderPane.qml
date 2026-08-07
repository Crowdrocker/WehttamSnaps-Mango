import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell          // ← Added this import (required for Quickshell.execDetached)
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root
    property real scaleFactor: Appearance.uiScaleRatio

    property bool powerOptionsExpanded: false
    property bool editMode: false

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested()
    signal editModeToggled()

    implicitHeight: Math.round(72 * Appearance.uiScaleRatio)
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
            width: Math.round(48 * Appearance.uiScaleRatio)
            height: Math.round(48 * Appearance.uiScaleRatio)
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
                font.pixelSize: Math.max(12, Math.round(15 * Appearance.uiScaleRatio))
                font.weight: Font.SemiBold
                color: Theme.surfaceText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: (UserInfoService.uptime || "Unknown")
                font.pixelSize: Math.max(11, Math.round(12 * Appearance.uiScaleRatio))
                color: Theme.surfaceVariantText
            }
        }

        // Compact dock-style action buttons
        RowLayout {
            id: actionButtonsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingM

            readonly property int btn: Math.round(52 * Appearance.uiScaleRatio)
            readonly property int rad: Math.round(12 * Appearance.uiScaleRatio)
            readonly property int icon: Math.round(26 * Appearance.uiScaleRatio)

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
