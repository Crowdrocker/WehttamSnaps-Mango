import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: widgetRoot
    property var widgetData:  ({})
    property int widgetIndex: 0
    property int cardRadius: 16
    property real cardBorderAlpha: 0.08
    property real cardBgAlpha: 0.28
    property bool editMode: false
    property var cardBg: "transparent"
    property var cardBorder: "transparent"
    property var model: null
    property var gridRoot: null

    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    width:  parent.width
    height: widgetRoot.spx(56)
    radius: widgetRoot.cardRadius
    color:  widgetRoot.cardBg
    border.color: widgetRoot.cardBorder
    border.width: 1

    property bool isActive: {
        switch (widgetData.id || "") {
        case "nightMode":     return DisplayService.nightModeEnabled  || false
        case "darkMode":      return !SessionData.isLightMode
        case "doNotDisturb":  return SessionData.doNotDisturb         || false
        case "idleInhibitor": return SessionService.idleInhibited     || false
        default:              return false
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: widgetRoot.spx(10)
        transform: Translate { x: -2 }

        Item { Layout.fillWidth: true }

        EHIcon {
            Layout.alignment: Qt.AlignVCenter
            name: {
                switch (widgetData.id || "") {
                case "nightMode":     return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode":      return "contrast"
                case "doNotDisturb":  return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor": return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default:              return "help"
                }
            }
            size: Theme.iconSize
            color: widgetRoot.isActive ? Theme.primary : Theme.surfaceText
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: {
                switch (widgetData.id || "") {
                case "nightMode":     return "Night Mode"
                case "darkMode":      return SessionData.isLightMode ? "Light" : "Dark"
                case "doNotDisturb":  return "Do Not Disturb"
                case "idleInhibitor": return SessionService.idleInhibited ? "Awake" : "Sleep"
                default:              return "Unknown"
                }
            }
            font.pixelSize: Math.max(12, widgetRoot.spx(14))
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Item { Layout.fillWidth: true }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        enabled: !widgetRoot.editMode
        onClicked: {
            switch (widgetData.id || "") {
            case "nightMode":     if (DisplayService.automationAvailable) DisplayService.toggleNightMode(); break
            case "darkMode":      Theme.toggleLightMode(); break
            case "doNotDisturb":  SessionData.setDoNotDisturb(!SessionData.doNotDisturb); break
            case "idleInhibitor": SessionService.toggleIdleInhibit(); break
            }
        }
    }

    EditModeOverlay {
        anchors.fill: parent
        editMode:    widgetRoot.editMode
        widgetData:  widgetRoot.widgetData
        widgetIndex: widgetRoot.widgetIndex
        showSizeControls: true
        isSlider: false
        onRemoveWidget:     function(index)             { widgetRoot.gridRoot.removeWidget(index) }
        onToggleWidgetSize: function(index)             { widgetRoot.gridRoot.toggleWidgetSize(index) }
        onMoveWidget:       function(fromIndex, toIndex) { widgetRoot.gridRoot.moveWidget(fromIndex, toIndex) }
    }
}