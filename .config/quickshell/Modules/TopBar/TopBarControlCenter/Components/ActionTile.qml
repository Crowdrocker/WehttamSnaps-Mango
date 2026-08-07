import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property string secondaryText: ""
    property bool isActive: false
    property bool enabled: true
    property int widgetIndex: 0
    property var widgetData: null
    property bool editMode: false

    signal clicked()

    width: parent ? parent.width : 200
    height: 56
    radius: Theme.cornerRadius

    // Background: active = primary tint, inactive = subtle surface
    color: isActive
           ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
           : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                     Theme.getContentBackgroundAlpha() * (SettingsData.controlCenterWidgetBackgroundOpacity || 0.5))

    border.color: isActive
                  ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                  : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: 1
    opacity: enabled ? 1.0 : 0.5

    // Active indicator strip
    Rectangle {
        visible: root.isActive
        x: 0; y: Theme.cornerRadius
        width: 3
        height: parent.height - Theme.cornerRadius * 2
        radius: 2
        color: Theme.primary
        opacity: 0.85
    }

    // Hover tint overlay
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: mouseArea.containsMouse
               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
               : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: Theme.spacingM + 4   // offset to clear the accent strip
            rightMargin: Theme.spacingM
        }
        spacing: Theme.spacingM

        // Icon
        EHIcon {
            name: root.iconName
            size: Theme.iconSize
            color: root.isActive ? Theme.primary : Theme.surfaceVariantText
            Layout.alignment: Qt.AlignVCenter
        }

        // Text block
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Typography {
                text: root.text
                style: Typography.Style.Body
                font.weight: Font.Medium
                color: root.isActive ? Theme.primary : Theme.surfaceText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Typography {
                text: root.secondaryText
                style: Typography.Style.Caption
                color: root.isActive
                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
                       : Theme.surfaceVariantText
                visible: root.secondaryText.length > 0
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled && !root.editMode
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }
}
