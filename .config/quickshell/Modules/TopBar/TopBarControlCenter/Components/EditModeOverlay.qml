import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property bool editMode: false
    property var widgetData: null
    property int widgetIndex: -1
    property bool showSizeControls: true
    property bool isSlider: false

    signal removeWidget(int index)
    signal toggleWidgetSize(int index)
    signal moveWidget(int fromIndex, int toIndex)

    // ── Background tint when editing ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
        border.width: editMode ? 1 : 0
        visible: editMode
        z: -1
    }

    // ── Remove button (top-right) ─────────────────────────────────────────
    Rectangle {
        visible: editMode
        width: 24; height: 24; radius: 12
        color: Theme.error
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -5
        anchors.rightMargin: -5
        z: 10

        EHIcon { anchors.centerIn: parent; name: "close"; size: 14; color: "white" }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeWidget(root.widgetIndex)
        }
    }

    // ── Reorder arrows (top-left) ──────────────────────────────────────────
    Row {
        visible: editMode
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 4
        anchors.leftMargin: 4
        spacing: 3
        z: 10

        component ArrowBtn : Rectangle {
            property string arrowIcon: ""
            property bool btnEnabled: true
            signal tapped()

            width: 24; height: 24; radius: 12
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
            border.width: 1
            opacity: btnEnabled ? 1.0 : 0.35

            EHIcon { anchors.centerIn: parent; name: parent.arrowIcon; size: 14; color: Theme.surfaceText }

            MouseArea {
                anchors.fill: parent
                enabled: parent.btnEnabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: parent.tapped()
            }
        }

        ArrowBtn {
            arrowIcon: "keyboard_arrow_left"
            btnEnabled: root.widgetIndex > 0
            onTapped: root.moveWidget(root.widgetIndex, root.widgetIndex - 1)
        }

        ArrowBtn {
            arrowIcon: "keyboard_arrow_right"
            btnEnabled: root.widgetIndex < ((SettingsData.controlCenterWidgets?.length ?? 0) - 1)
            onTapped: root.moveWidget(root.widgetIndex, root.widgetIndex + 1)
        }
    }

    // ── Size controls (bottom-right) ───────────────────────────────────────
    Row {
        visible: editMode && showSizeControls
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: -6
        anchors.rightMargin: -6
        spacing: 3
        z: 10

        component SizeBtn : Rectangle {
            property int sizeValue: 50
            property bool btnVisible: true

            visible: btnVisible && !root.isSlider
            width: 28; height: 22; radius: 6
            color: (root.widgetData?.width || 50) === sizeValue
                   ? Theme.primary
                   : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
            border.color: Theme.primary
            border.width: 1

            StyledText {
                anchors.centerIn: parent
                text: parent.sizeValue
                font.pixelSize: 10
                font.weight: Font.SemiBold
                color: (root.widgetData?.width || 50) === parent.sizeValue ? "white" : Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (root.widgetIndex >= 0 && root.widgetIndex < widgets.length) {
                        widgets[root.widgetIndex].width = parent.sizeValue
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
        }

        // 50% always visible for sliders
        Rectangle {
            visible: editMode && root.isSlider
            width: 28; height: 22; radius: 6
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
            border.color: Theme.primary; border.width: 1
            StyledText { anchors.centerIn: parent; text: "50"; font.pixelSize: 10; font.weight: Font.SemiBold; color: Theme.primary }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (root.widgetIndex >= 0 && root.widgetIndex < widgets.length) {
                        widgets[root.widgetIndex].width = 50
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        Rectangle {
            visible: editMode && root.isSlider
            width: 32; height: 22; radius: 6
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
            border.color: Theme.primary; border.width: 1
            StyledText { anchors.centerIn: parent; text: "100"; font.pixelSize: 10; font.weight: Font.SemiBold; color: Theme.primary }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var widgets = SettingsData.controlCenterWidgets.slice()
                    if (root.widgetIndex >= 0 && root.widgetIndex < widgets.length) {
                        widgets[root.widgetIndex].width = 100
                        SettingsData.setControlCenterWidgets(widgets)
                    }
                }
            }
        }

        SizeBtn { sizeValue: 25;  btnVisible: true }
        SizeBtn { sizeValue: 50;  btnVisible: true }
        SizeBtn { sizeValue: 75;  btnVisible: true }
        SizeBtn { sizeValue: 100; btnVisible: true }
    }
}
