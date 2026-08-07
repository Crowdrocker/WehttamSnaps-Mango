import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property string section: "left"
    property var popupTarget: null
    property var parentScreen: null
    property var appDrawerLoader: null
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }

    readonly property real logoSizePx: Math.max(spx(16), (SettingsData.launcherLogoSize || 24) * uiScale)

    property real widgetHeight: Math.max(logoSizePx + spx(6), spx(30))
    property real barHeight: 48
    property bool isBarVertical: SettingsData.minipanelPosition === "left" || SettingsData.minipanelPosition === "right"
    readonly property real horizontalPadding: SettingsData.minipanelNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    property bool _pendingTriggerPosition: false
    property real _pendingTriggerX: 0
    property real _pendingTriggerY: 0
    property real _pendingTriggerWidth: 0
    property string _pendingTriggerSection: "minipanel"
    property var _pendingTriggerScreen: null

    signal clicked()
    property bool _pendingToggle: false

    width: isBarVertical ? widgetHeight : (logoSizePx + horizontalPadding * 2)
    height: isBarVertical ? (logoSizePx + horizontalPadding * 2) : widgetHeight

    function applyTriggerPosition(target) {
        if (!target || !target.setTriggerPosition) {
            return
        }
        // Set bar properties for proper positioning
        const barPos = SettingsData.minipanelPosition;
        const barHeight = SettingsData.miniPanelHeight * (SettingsData.miniPanelScale || 1);
        const margin = (barPos === "bottom" && !isBarVertical) ? (SettingsData.miniPanelTopMargin || 0) : 0;
        const effectiveBarHeight = barHeight + margin;
        target.barPosition = barPos;
        target.barThickness = effectiveBarHeight;
        // Pass auto-fit width setting to the popup for proper positioning
        const autoFitValue = SettingsData.miniPanelAutoFit;
        target.autoFitWidth = autoFitValue;
        target.setTriggerPosition(_pendingTriggerX, _pendingTriggerY, _pendingTriggerWidth, _pendingTriggerSection, _pendingTriggerScreen)
        _pendingTriggerPosition = false
    }

    onPopupTargetChanged: {
        if (_pendingTriggerPosition) {
            applyTriggerPosition(popupTarget)
        }
    }

    MouseArea {
        id: launcherArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            // Toggle the app drawer directly
            if (root.appDrawerLoader) {
                root.appDrawerLoader.active = true
                if (root.appDrawerLoader.item) {
                    // Get button rect in screen coordinates
                    const rect = parent.mapToItem(null, 0, 0, width, height);
                    const currentScreen = parentScreen || Screen;

                    // Set trigger position for the popup using setTriggerPosition method
                    root.appDrawerLoader.item.barPosition = SettingsData.miniPanelPosition || "top"
                    root.appDrawerLoader.item.barThickness = (SettingsData.miniPanelHeight || 48) * (SettingsData.miniPanelScale || 1)
                    root.appDrawerLoader.item.setTriggerPosition(rect.x, rect.y, rect.width, "minipanel", currentScreen)
                    
                    // Toggle the popup
                    root.appDrawerLoader.item.toggle()
                }
            }
            root.clicked();
        }
    }

    Rectangle {
        id: launcherContent

        anchors.fill: parent
        radius: SettingsData.minipanelNoBackground ? 0 : Theme.widgetRadius
        color: {
            if (SettingsData.minipanelNoBackground) {
                return "transparent";
            }

            const baseColor = launcherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }

        SystemLogo {
            visible: SettingsData.useOSLogo && !SettingsData.useCustomLauncherImage
            anchors.centerIn: parent
            width: Math.max(1, root.logoSizePx - root.spx(3))
            height: Math.max(1, root.logoSizePx - root.spx(3))
            colorOverride: (SettingsData.osLogoAutoSync && Theme.primary) || (SettingsData.osLogoColorOverride !== "" ? SettingsData.osLogoColorOverride : "")
            brightnessOverride: SettingsData.osLogoBrightness
            contrastOverride: SettingsData.osLogoContrast

        }

        Item {
            visible: SettingsData.useCustomLauncherImage && SettingsData.customLauncherImagePath !== ""
            anchors.centerIn: parent
            width: Math.max(1, root.logoSizePx - root.spx(6))
            height: Math.max(1, root.logoSizePx - root.spx(6))

            Image {
                id: customImage
                anchors.fill: parent
                source: SettingsData.customLauncherImagePath
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: false
            }

            MultiEffect {
                anchors.fill: customImage
                source: customImage
                visible: true
                colorizationColor: Theme.primary
                colorization: 1.0
            }

        }

        EHIcon {
            visible: !SettingsData.useOSLogo && !SettingsData.useCustomLauncherImage
            anchors.centerIn: parent
            name: "apps"
            size: Math.max(1, root.logoSizePx - root.spx(6))
            color: Theme.primary

        }
    }
}
