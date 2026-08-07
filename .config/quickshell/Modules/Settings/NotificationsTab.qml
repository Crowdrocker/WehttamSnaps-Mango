import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: notificationsTab

    property var parentModal: null

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

            // ════════════════════════════════════════════════════════════
            // HEADER
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: headerSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: headerSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "notifications"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Notifications"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text: "Control notification behavior, timeouts, overlay, and the internal popup pipeline."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Row {
                            spacing: Theme.spacingS
                            EHActionButton {
                                iconName: "delete_sweep"
                                iconSize: Theme.iconSizeSmall
                                buttonSize: 34
                                iconColor: Theme.primary
                                onClicked: {
                                    if (typeof NotificationService !== "undefined")
                                        NotificationService.clearAllNotifications()
                                }
                            }
                            StyledText {
                                text: "Clear all"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: Theme.spacingS
                            EHActionButton {
                                iconName: "bug_report"
                                iconSize: Theme.iconSizeSmall
                                buttonSize: 34
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    if (typeof NotificationService !== "undefined")
                                        NotificationService.pushLocal(
                                            "Test notification",
                                            "Notification settings preview",
                                            { urgency: 1, force: true, appName: "Quickshell", appIcon: "notifications" }
                                        )
                                }
                            }
                            StyledText {
                                text: "Test notification"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // USER-FACING SETTINGS (matches Modules/Notifications UI)
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: userSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: userSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "tune"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "General"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Do Not Disturb"
                        description: "Block notification popups"
                        checked: typeof SessionData !== "undefined" ? SessionData.doNotDisturb : false
                        onToggled: {
                            if (typeof SessionData !== "undefined")
                                SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                        }
                    }

                    EHToggle {
                        width: parent.width
                        text: "Notification overlay"
                        description: "Display all priorities over fullscreen apps"
                        checked: SettingsData.notificationOverlayEnabled
                        onToggled: toggled => SettingsData.setNotificationOverlayEnabled(toggled)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText { text: "Timeouts"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "0 = never auto-dismiss"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            Column {
                                width: parent.width
                                spacing: Theme.spacingS
                                StyledText { text: "Low priority (ms)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                                EHSlider {
                                    width: parent.width; height: 24
                                    value: SettingsData.notificationTimeoutLow
                                    minimum: 0; maximum: 60000; unit: "ms"; showValue: true; wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainer
                                    onSliderValueChanged: v => SettingsData.setNotificationTimeoutLow(Math.round(v))
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            StyledText { text: "Normal priority (ms)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.notificationTimeoutNormal
                                minimum: 0; maximum: 60000; unit: "ms"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: v => SettingsData.setNotificationTimeoutNormal(Math.round(v))
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            StyledText { text: "Critical priority (ms)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            EHSlider {
                                width: parent.width; height: 24
                                value: SettingsData.notificationTimeoutCritical
                                minimum: 0; maximum: 60000; unit: "ms"; showValue: true; wheelEnabled: false
                                thumbOutlineColor: Theme.surfaceContainer
                                onSliderValueChanged: v => SettingsData.setNotificationTimeoutCritical(Math.round(v))
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // PIPELINE / PERFORMANCE (NotificationService internals)
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: pipelineSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: pipelineSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "speed"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Popup pipeline"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Max visible popups"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationMaxVisiblePopups; minimum: 0; maximum: 10; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationMaxVisiblePopups(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Max popup queue size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationMaxQueueSize; minimum: 0; maximum: 200; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationMaxQueueSize(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Max ingress per second"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationMaxIngressPerSecond; minimum: 1; maximum: 200; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationMaxIngressPerSecond(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Max stored notifications"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationMaxStored; minimum: 0; maximum: 2000; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationMaxStored(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Enter animation (ms)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationEnterAnimMs; minimum: 0; maximum: 2000; unit: "ms"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationEnterAnimMs(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Bulk dismiss batch size"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationDismissBatchSize; minimum: 1; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationDismissBatchSize(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Bulk dismiss tick (ms)"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationDismissTickMs; minimum: 1; maximum: 200; unit: "ms"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationDismissTickMs(Math.round(v)) }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // POPUP STYLE (NotificationPopup.qml)
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: popupStyleSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: popupStyleSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "style"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Popup style"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Popup width"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationPopupWidth; minimum: 240; maximum: 900; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupWidth(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Popup max height"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationPopupMaxHeight; minimum: 140; maximum: 900; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupMaxHeight(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Stack spacing"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationPopupStackSpacing; minimum: 0; maximum: 80; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupStackSpacing(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Card margin"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationPopupMargin; minimum: 0; maximum: 32; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupMargin(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Corner radius"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: SettingsData.notificationPopupRadius; minimum: 0; maximum: 64; unit: "px"; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupRadius(Math.round(v)) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Opacity boost"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round((SettingsData.notificationPopupOpacityBoost ?? 0.08) * 100); minimum: 0; maximum: 30; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupOpacityBoost(v / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Border opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round((SettingsData.notificationPopupBorderOpacity ?? 0.22) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupBorderOpacity(v / 100) }
                    }

                    Column { width: parent.width; spacing: Theme.spacingS
                        StyledText { text: "Critical border opacity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                        EHSlider { width: parent.width; height: 24; value: Math.round((SettingsData.notificationPopupBorderCriticalOpacity ?? 0.70) * 100); minimum: 0; maximum: 100; unit: ""; showValue: true; wheelEnabled: false; thumbOutlineColor: Theme.surfaceContainer; onSliderValueChanged: v => SettingsData.setNotificationPopupBorderCriticalOpacity(v / 100) }
                    }
                }
            }
        }
    }
}

