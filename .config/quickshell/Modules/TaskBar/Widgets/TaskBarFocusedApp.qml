import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool compactMode: SettingsData.focusedWindowCompactMode
    property int availableWidth: 400
    property real widgetHeight: 30
    property real padding: 0
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real scaleFactor: uiScale
    property real iconSize: 24
    property real iconSpacing: 8
    property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real horizontalPadding: SettingsData.topBarNoBackground ? 2 : Theme.spacingS
    readonly property int baseWidth: contentRow.implicitWidth + horizontalPadding * 2
    readonly property int maxNormalWidth: 456
    readonly property int maxCompactWidth: 288
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool hasWindowsOnCurrentWorkspace: {
        if (!CompositorService.isNiri) {
            return activeWindow && activeWindow.title
        }

        let currentWorkspaceId = null
        for (var i = 0; i < NiriService.allWorkspaces.length; i++) {
            const ws = NiriService.allWorkspaces[i]
            if (ws.is_focused) {
                currentWorkspaceId = ws.id
                break
            }
        }

        if (!currentWorkspaceId) {
            return false
        }

        const workspaceWindows = NiriService.windows.filter(w => w.workspace_id === currentWorkspaceId)
        return workspaceWindows.length > 0 && activeWindow && activeWindow.title
    }

    width: !hasWindowsOnCurrentWorkspace ? 0 : (isBarVertical ? widgetHeight : (compactMode ? Math.min(baseWidth, Math.min(maxCompactWidth, availableWidth)) : Math.min(baseWidth, Math.min(maxNormalWidth, availableWidth))))
    height: !hasWindowsOnCurrentWorkspace ? 0 : (isBarVertical ? (compactMode ? Math.min(baseWidth, Math.min(maxCompactWidth, availableWidth)) : Math.min(baseWidth, Math.min(maxNormalWidth, availableWidth))) : widgetHeight)
    radius: SettingsData.topBarNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (!activeWindow || !activeWindow.title) {
            return "transparent";
        }

        if (SettingsData.topBarNoBackground) {
            return "transparent";
        }

        const baseColor = mouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    clip: true
    visible: hasWindowsOnCurrentWorkspace

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Theme.spacingS

        StyledText {
            id: appText

            text: {
                if (!activeWindow || !activeWindow.appId) {
                    return "";
                }

                const desktopEntry = DesktopEntries.heuristicLookup(activeWindow.appId);
                return desktopEntry && desktopEntry.name ? desktopEntry.name : activeWindow.appId;
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, compactMode ? 80 : 180)
            visible: !compactMode && text.length > 0
            
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.outlineButton
            anchors.verticalCenter: parent.verticalCenter
            visible: !compactMode && appText.text && titleText.text
            
        }

        StyledText {
            id: titleText

            text: {
                const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                const appName = appText.text;
                if (!title || !appName) {
                    return title;
                }

                if (title.endsWith(" - " + appName)) {
                    return title.substring(0, title.length - (" - " + appName).length);
                }

                if (title.endsWith(appName)) {
                    return title.substring(0, title.length - appName.length).replace(/ - $/, "");
                }

                return title;
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, compactMode ? 280 : 250)
            visible: text.length > 0
            
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
    }


    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }

    }

}
