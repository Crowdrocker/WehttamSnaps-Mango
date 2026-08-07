import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool powerOptionsExpanded: false
    property bool editMode: false

    signal powerActionRequested(string action, string title, string message)
    signal lockRequested()
    signal editModeToggled()

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.topbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    implicitHeight: spx(72)
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
    border.width: 1

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingL + 2
            rightMargin: Theme.spacingL
            topMargin: Theme.spacingS
            bottomMargin: Theme.spacingS
        }
        spacing: Theme.spacingM

        // Avatar
        EHCircularImage {
            width: root.spx(48)
            height: root.spx(48)
            Layout.alignment: Qt.AlignVCenter
            imageSource: {
                if (PortalService.profileImage === "") return ""
                if (PortalService.profileImage.startsWith("/")) return "file://" + PortalService.profileImage
                return PortalService.profileImage
            }
            fallbackIcon: "person"
        }

        // Name + uptime
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                text: UserInfoService.fullName || UserInfoService.username || "User"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.SemiBold
                color: Theme.surfaceText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: "up " + (UserInfoService.uptime || "—")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
            }
        }

        // Action buttons
        RowLayout {
            spacing: Theme.spacingM
            Layout.alignment: Qt.AlignVCenter

            // Lock
            HeaderButton {
                iconName: "lock"
                onActivated: root.lockRequested()
            }

            // Power toggle
            HeaderButton {
                iconName: root.powerOptionsExpanded ? "expand_less" : "power_settings_new"
                isActive: root.powerOptionsExpanded
                onActivated: root.powerOptionsExpanded = !root.powerOptionsExpanded
            }

            // Settings
            HeaderButton {
                iconName: "settings"
                onActivated: settingsModal.show()
            }

            // Edit button intentionally removed (requested).
        }
    }

    // ── Inline button component ──────────────────────────────────────────
    component HeaderButton : Rectangle {
        property string iconName: ""
        property bool isActive: false
        signal activated()

        width: root.spx(52); height: root.spx(52)
        radius: root.spx(12)
        color: {
            if (isActive) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            if (hbArea.containsMouse) return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.45)
            return "transparent"
        }

        EHIcon {
            anchors.centerIn: parent
            name: parent.iconName
            size: root.spx(26)
            color: parent.isActive ? Theme.primary : Theme.surfaceVariantText
        }

        MouseArea {
            id: hbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }

        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
    }
}
