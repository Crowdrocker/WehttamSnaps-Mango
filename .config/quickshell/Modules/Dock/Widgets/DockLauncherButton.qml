import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isActive: false
    property bool isVertical: false
    property bool isAtBottom: true
    property string section: "left"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    property real scaleFactor: 1
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    readonly property real logoSizePx: Math.max(spx(16), (SettingsData.launcherLogoSize || 24) * uiScale)
    property real padding: 0
    property real iconSize: 24 * scaleFactor
    property real iconSpacing: 8
    property real barHeight: 48
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    property bool _pendingTriggerPosition: false
    property real _pendingTriggerX: 0
    property real _pendingTriggerY: 0
    property real _pendingTriggerWidth: 0
    property string _pendingTriggerSection: "dock"
    property var _pendingTriggerScreen: null

    signal clicked()

    width: isBarVertical ? widgetHeight : (logoSizePx + horizontalPadding * 2)
    height: isBarVertical ? (logoSizePx + horizontalPadding * 2) : widgetHeight
    implicitWidth: width
    implicitHeight: height

    function applyTriggerPosition(target) {
        if (!target || !target.setTriggerPosition) {
            return
        }
        // Set bar properties for proper positioning
        const barPos = "bottom"; // TaskBar is always at bottom
        const barHeight = SettingsData?.taskBarHeight || 48;
        const bottomMargin = SettingsData?.topBarTopMargin || 0;
        const effectiveBarHeight = barHeight + bottomMargin;
        console.log(`[Dock LauncherButton] Setting bar properties: position="${barPos}", thickness=${barHeight}, margin=${bottomMargin}, effective=${effectiveBarHeight}`);
        target.barPosition = barPos;
        target.barThickness = effectiveBarHeight;
        console.log(`[Dock LauncherButton] Calling setTriggerPosition: (${_pendingTriggerX}, ${_pendingTriggerY}), width=${_pendingTriggerWidth}, section="${_pendingTriggerSection}"`);
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
            // Get widget position in screen coordinates (like dock does)
            const rect = parent.mapToItem(null, 0, 0, width, height);
            const currentScreen = parentScreen || Screen;

            // Calculate taskbar thickness (similar to dock)
            var taskBarThickness = SettingsData?.taskBarHeight || 48;

            // Position popup above taskbar, centered on button
            _pendingTriggerX = rect.x + rect.width / 2;
            _pendingTriggerY = currentScreen.y + currentScreen.height - taskBarThickness;
            _pendingTriggerWidth = rect.width;
            _pendingTriggerSection = "dock";
            _pendingTriggerScreen = currentScreen;
            _pendingTriggerPosition = true;
            applyTriggerPosition(popupTarget);
            root.clicked();
        }
    }

    Rectangle {
        id: launcherContent

        anchors.fill: parent
        radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
        color: {
            if (SettingsData.topBarNoBackground) {
                return "transparent";
            }

            const baseColor = launcherArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }

        SystemLogo {
            visible: SettingsData.useOSLogo && !SettingsData.useCustomLauncherImage
            anchors.centerIn: parent
            width: logoSizePx > 0 ? Math.max(0, logoSizePx - spx(3)) : 0
            height: logoSizePx > 0 ? Math.max(0, logoSizePx - spx(3)) : 0
            colorOverride: (SettingsData.osLogoAutoSync && Theme.primary) || (SettingsData.osLogoColorOverride !== "" ? SettingsData.osLogoColorOverride : "")
            brightnessOverride: SettingsData.osLogoBrightness
            contrastOverride: SettingsData.osLogoContrast

        }

        Item {
            visible: SettingsData.useCustomLauncherImage && SettingsData.customLauncherImagePath !== ""
            anchors.centerIn: parent
            width: logoSizePx > 0 ? Math.max(0, logoSizePx - spx(6)) : 0
            height: logoSizePx > 0 ? Math.max(0, logoSizePx - spx(6)) : 0

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
            size: logoSizePx > 0 ? Math.max(0, logoSizePx - spx(6)) : 0
            color: Theme.primary

        }
    }
}
