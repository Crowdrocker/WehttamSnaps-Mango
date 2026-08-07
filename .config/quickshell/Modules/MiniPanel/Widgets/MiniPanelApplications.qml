import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string section: "follow-trigger"
    property var parentScreen: null
    property var applicationsLoader: null
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.miniPanelScale || 1.0)
    function spx(px) { return Math.round(px * uiScale) }

    property real widgetHeight: spx(30)
    property bool isBarVertical: SettingsData.minipanelPosition === "left" || SettingsData.minipanelPosition === "right"
    readonly property real horizontalPadding: SettingsData.minipanelNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
    readonly property real iconSize: Math.max(spx(16), widgetHeight - spx(12))

    width: isBarVertical ? widgetHeight : (iconSize + horizontalPadding * 2)
    height: isBarVertical ? (iconSize + horizontalPadding * 2) : widgetHeight
    radius: SettingsData.minipanelNoBackground ? 0 : Theme.widgetRadius
    color: {
        if (SettingsData.minipanelNoBackground) return "transparent"

        const baseColor = appsMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency)
    }

    EHIcon {
        id: appsIcon
        anchors.centerIn: parent
        name: "apps"
        size: root.iconSize
        color: Theme.surfaceText
    }

    MouseArea {
        id: appsMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            const loader = root.applicationsLoader
            if (!loader) return
            loader.active = true
            if (loader.item) {
                const pos = parent.mapToItem(null, 0, 0)
                const currentScreen = parentScreen || Screen
                loader.item.barPosition = SettingsData.miniPanelPosition || "top"
                loader.item.barThickness = (SettingsData.miniPanelHeight || 48) * (SettingsData.miniPanelScale || 1)
                loader.item.triggerHeight = root.height
                loader.item.setTriggerPosition(pos.x, pos.y, width, "center", currentScreen)
                loader.item.show()
            }
        }
    }
}
