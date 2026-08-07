import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    readonly property bool hasActivePrivacy: PrivacyService.anyPrivacyActive
    readonly property int activeCount: PrivacyService.microphoneActive + PrivacyService.cameraActive + PrivacyService.screensharingActive
    readonly property real contentWidth: hasActivePrivacy ? (activeCount * 18 + (activeCount - 1) * Theme.spacingXS) : 0

    width: hasActivePrivacy ? (contentWidth + horizontalPadding * 2) : 0
    height: hasActivePrivacy ? widgetHeight : 0
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    visible: hasActivePrivacy
    opacity: hasActivePrivacy ? 1 : 0
    enabled: hasActivePrivacy
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        return Qt.rgba(privacyArea.containsMouse ? Theme.errorPressed.r : Theme.errorHover.r, privacyArea.containsMouse ? Theme.errorPressed.g : Theme.errorHover.g, privacyArea.containsMouse ? Theme.errorPressed.b : Theme.errorHover.b, (privacyArea.containsMouse ? Theme.errorPressed.a : Theme.errorHover.a) * Theme.widgetTransparency);
    }

    MouseArea {

        id: privacyArea

        anchors.fill: parent
        hoverEnabled: hasActivePrivacy
        enabled: hasActivePrivacy
        cursorShape: Qt.PointingHandCursor
        onClicked: {
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        visible: hasActivePrivacy

        Item {
            width: 18
            height: 18
            visible: PrivacyService.microphoneActive
            anchors.verticalCenter: parent.verticalCenter

            EHIcon {
                name: "mic"
                size: Theme.iconSizeSmall
                color: Theme.error
                filled: true
                anchors.centerIn: parent
            }

        }

        Item {
            width: 18
            height: 18
            visible: PrivacyService.cameraActive
            anchors.verticalCenter: parent.verticalCenter

            EHIcon {
                name: "camera_video"
                size: Theme.iconSizeSmall
                color: Theme.surfaceText
                filled: true
                anchors.centerIn: parent
            }

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: Theme.error
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -2
                anchors.topMargin: -1
            }

        }

        Item {
            width: 18
            height: 18
            visible: PrivacyService.screensharingActive
            anchors.verticalCenter: parent.verticalCenter

            EHIcon {
                name: "screen_share"
                size: Theme.iconSizeSmall
                color: Theme.warning
                filled: true
                anchors.centerIn: parent
            }

        }

    }


    Behavior on width {
        enabled: hasActivePrivacy && visible

        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }

    }

}
