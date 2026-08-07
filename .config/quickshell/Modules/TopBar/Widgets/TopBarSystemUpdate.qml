import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool isActive: false
    property string section: "right"
    property var parentScreen: null
    property real widgetHeight: 30
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property bool hasUpdates: SystemUpdateService.updateCount > 0
    readonly property bool isChecking: SystemUpdateService.isChecking

    signal clicked()

    width: isBarVertical ? widgetHeight : (updaterIcon.width + horizontalPadding * 2)
    height: isBarVertical ? (updaterIcon.width + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.topBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = updaterArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Row {
        id: updaterIcon

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        EHIcon {
            id: statusIcon

            anchors.verticalCenter: parent.verticalCenter
            name: {
                if (isChecking) return "refresh";
                if (SystemUpdateService.hasError) return "error";
                if (hasUpdates) return "system_update_alt";
                return "check_circle";
            }
            size: (Theme.iconSize - 6) * (widgetHeight / 30)
            color: {
                if (SystemUpdateService.hasError) return Theme.error;
                if (hasUpdates) return Theme.primary;
                return (updaterArea.containsMouse || root.isActive ? Theme.primary : Theme.surfaceText);
            }

            RotationAnimation {
                id: rotationAnimation
                target: statusIcon
                property: "rotation"
                from: 0
                to: 360
                duration: 1000
                running: isChecking
                loops: Animation.Infinite

                onRunningChanged: {
                    if (!running) {
                        statusIcon.rotation = 0
                    }
                }
            }
        }

        StyledText {
            id: countText

            anchors.verticalCenter: parent.verticalCenter
            text: SystemUpdateService.updateCount.toString()
            font.pixelSize: Theme.fontSizeSmall * (widgetHeight / 30)
            font.weight: Font.Medium
            color: Theme.surfaceText
            visible: hasUpdates && !isChecking
        }
    }

    MouseArea {
        id: updaterArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            const popup = getSharedUpdatePopup();
            if (popup && popup.shouldBeVisible) {
                popup.close();
            } else if (popup) {
                const rect = updaterArea.mapToItem(null, 0, 0, width, height);

                // Position popup based on bar location
                let triggerX = rect.x;
                let triggerY = rect.y;

                if (isBarVertical && SettingsData.topBarPosition === "right") {
                    // For right bar, position popup on the right side of the screen
                    const screenWidth = parentScreen ? parentScreen.width : 2560;
                    triggerX = screenWidth - 210; // Center popup on right side of screen
                }

                popup.positioning = "center";
                popup.setTriggerPosition(triggerX, triggerY, rect.width, section, parentScreen);
                popup.open();
            }
            root.clicked();
        }
    }

    Component {
        id: systemUpdatePopoutComponent
        EHPopout {
            id: popoutRoot
            objectName: "systemUpdatePopout"

            popupWidth: 400
            popupHeight: 500

            // Set bar properties for automatic positioning
    barPosition: SettingsData?.topBarPosition || "top"
    barThickness: {
        const barPos = SettingsData?.topBarPosition || "top"
        const barHeight = (SettingsData?.topBarHeight || 32) * (SettingsData?.topbarScale || 1)
        const margin = (barPos === "bottom" && barPos !== "left" && barPos !== "right") ? (SettingsData?.topBarTopMargin || 0) : 0
        return barHeight + margin
    }

            function setTriggerPosition(x, y, width, section, screen) {
            // Set bar properties for proper positioning
            const barPos = SettingsData?.topBarPosition || "top"
            const barHeight = (SettingsData?.topBarHeight || 32) * (SettingsData?.topbarScale || 1)
            const margin = (barPos === "bottom" && barPos !== "left" && barPos !== "right") ? (SettingsData?.topBarTopMargin || 0) : 0
            barPosition = barPos
            barThickness = barHeight + margin

                triggerX = x
                triggerY = y
                triggerWidth = width
                triggerSection = section
                triggerScreen = screen
            }

            content: Component {
                Rectangle {
                    id: updaterPanel

                    color: Theme.popupBackground()
                    radius: Theme.cornerRadius
                    antialiasing: true
                    smooth: true

                    Repeater {
                        model: [{
                                "margin": -3,
                                "color": Qt.rgba(0, 0, 0, 0.05),
                                "z": -3
                            }, {
                                "margin": -2,
                                "color": Qt.rgba(0, 0, 0, 0.08),
                                "z": -2
                            }, {
                                "margin": 0,
                                "color": Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12),
                                "z": -1
                            }]
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: modelData.margin
                            color: "transparent"
                            radius: parent.radius + Math.abs(modelData.margin)
                            border.color: modelData.color
                            border.width: 1
                            z: modelData.z
                        }
                    }

                    Column {
                        width: parent.width - Theme.spacingL * 2
                        height: parent.height - Theme.spacingL * 2
                        x: Theme.spacingL
                        y: Theme.spacingL
                        spacing: Theme.spacingL

                        Item {
                            width: parent.width
                            height: 40

                            StyledText {
                                text: "System Updates"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (SystemUpdateService.isChecking) return "Checking...";
                                        if (SystemUpdateService.hasError) return "Error";
                                        if (SystemUpdateService.updateCount === 0) return "Up to date";
                                        return SystemUpdateService.updateCount + " updates";
                                    }
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: {
                                        if (SystemUpdateService.hasError) return Theme.error;
                                        return Theme.surfaceText;
                                    }
                                }

                                EHActionButton {
                                    id: checkForUpdatesButton
                                    buttonSize: 28
                                    iconName: "refresh"
                                    iconSize: 18
                                    z: 15
                                    iconColor: Theme.surfaceText
                                    enabled: !SystemUpdateService.isChecking
                                    opacity: enabled ? 1.0 : 0.5
                                    onClicked: {
                                        SystemUpdateService.checkForUpdates()
                                    }

                                    RotationAnimation {
                                        target: checkForUpdatesButton
                                        property: "rotation"
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        running: SystemUpdateService.isChecking
                                        loops: Animation.Infinite

                                        onRunningChanged: {
                                            if (!running) {
                                                checkForUpdatesButton.rotation = 0
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: {
                                let usedHeight = 40 + Theme.spacingL
                                usedHeight += 48 + Theme.spacingL
                                return parent.height - usedHeight
                            }
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                anchors.rightMargin: 0

                                StyledText {
                                    id: statusText
                                    width: parent.width
                                    text: {
                                        if (SystemUpdateService.hasError) {
                                            return "Failed to check for updates:\n" + SystemUpdateService.errorMessage;
                                        }
                                        if (!SystemUpdateService.helperAvailable) {
                                            return "No package manager found. Please install 'paru' or 'yay' to check for updates.";
                                        }
                                        if (SystemUpdateService.isChecking) {
                                            return "Checking for updates...";
                                        }
                                        if (SystemUpdateService.updateCount === 0) {
                                            return "Your system is up to date!";
                                        }
                                        return `Found ${SystemUpdateService.updateCount} packages to update:`;
                                    }
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: {
                                        if (SystemUpdateService.hasError) return Theme.errorText;
                                        return Theme.surfaceText;
                                    }
                                    wrapMode: Text.WordWrap
                                    visible: SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking
                                }

                                EHListView {
                                    id: packagesList

                                    width: parent.width
                                    height: parent.height - (SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking ? statusText.height + Theme.spacingM : 0)
                                    visible: SystemUpdateService.updateCount > 0 && !SystemUpdateService.isChecking && !SystemUpdateService.hasError
                                    clip: true
                                    spacing: Theme.spacingXS

                                    model: SystemUpdateService.availableUpdates

                                    delegate: Rectangle {
                                        width: ListView.view.width - Theme.spacingM
                                        height: 48
                                        radius: Theme.cornerRadius
                                        color: packageMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                                        border.color: Theme.outlineLight
                                        border.width: 1

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingM

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 24 - Theme.spacingM
                                                spacing: 2

                                                StyledText {
                                                    width: parent.width
                                                    text: modelData.name || ""
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    text: `${modelData.currentVersion} → ${modelData.newVersion}`
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceVariantText
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.shortDuration }
                                        }

                                        MouseArea {
                                            id: packageMouseArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 48
                            spacing: Theme.spacingM

                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: updateMouseArea.containsMouse ? Theme.primaryHover : Theme.secondaryHover
                                opacity: SystemUpdateService.updateCount > 0 ? 1.0 : 0.5

                                Behavior on color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    EHIcon {
                                        name: "system_update_alt"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Update All"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: updateMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: SystemUpdateService.updateCount > 0
                                    onClicked: {
                                        SystemUpdateService.runUpdates()
                                        popoutRoot.close()
                                    }
                                }
                            }


                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.secondaryHover

                                Behavior on color {
                                    ColorAnimation { duration: Theme.shortDuration }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    EHIcon {
                                        name: "close"
                                        size: Theme.iconSize
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "Close"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        popoutRoot.close()
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }

    property var sharedUpdatePopup: null

    function getSharedUpdatePopup() {
        if (!sharedUpdatePopup) {
            sharedUpdatePopup = systemUpdatePopoutComponent.createObject(root)
        }
        return sharedUpdatePopup
    }

    function showPopup() {
        const popup = getSharedUpdatePopup()
        if (popup) {
            // Close any existing popup first
            if (popup.shouldBeVisible) {
                popup.close()
            }

            // Calculate trigger position using the same method as VolumeMixerButton
            const rect = updaterArea.mapToItem(null, 0, 0, width, height)
            popup.setTriggerPosition(rect.x, rect.y, rect.width, section, parentScreen)
            popup.open()
        }
        root.clicked()
    }

}