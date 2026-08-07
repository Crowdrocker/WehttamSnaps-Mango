import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets as CCWidgets

Rectangle {
    id: root

    readonly property int _maxHeight: 320
    implicitHeight: Math.min(_maxHeight, contentCol.implicitHeight + Theme.spacingM * 2)
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b,
                   Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        StyledText {
            Layout.fillWidth: true
            text: "Displays"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root._maxHeight - (Theme.spacingM * 2 + 22), content.implicitHeight)
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            interactive: contentHeight > height

            Column {
                id: content
                width: flick.width
                spacing: Theme.spacingS

                CCWidgets.BrightnessSliderRow {
                    width: parent.width
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }
}

