import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

// ─────────────────────────────────────────────────────────────────────────────
//  PKGCard  —  single package row card (clickable for selection)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // ── Required data ─────────────────────────────────────────────────────────
    required property string pkgName
    required property string pkgVersion
    required property string pkgSource
    required property string pkgDescription
    required property bool   pkgInstalled     // ← This must exist

    // ── Optional ──────────────────────────────────────────────────────────────
    property string pkgNewVersion: ""
    property int    animDelay:     0
    property bool   isSelected:    false

    // ── Signal for selection ───────────────────────────────────────────────────
    signal clicked()

    // ── Source → accent color ─────────────────────────────────────────────────
    function sourceColor(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"
            case "aur":     return "#a9e34b"
            case "apt":     return "#FF9F43"
            case "dnf":     return "#EF5350"
            case "flatpak": return "#9775fa"
            default:        return Theme.surfaceVariantText
        }
    }

    function sourceIcon(s) {
        switch (s) {
            case "pacman":  return "deployed_code"
            case "aur":     return "code"
            case "apt":     return "terminal"
            case "dnf":     return "package_2"
            case "flatpak": return "apps"
            default:        return "inventory_2"
        }
    }

    readonly property string accentColor: sourceColor(pkgSource)

    width:  parent ? parent.width : 0
    height: pkgCard.implicitHeight

    // Stagger fade-in
    opacity: 0
    Component.onCompleted: staggerTimer.start()
    Timer {
        id: staggerTimer
        interval: root.animDelay
        onTriggered: root.opacity = 1
    }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Click handler on root Item
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("[PKGCard] Clicked:", root.pkgName, "source:", root.pkgSource)
            root.clicked()
        }
    }

    // Main glass card
    Rectangle {
        id: pkgCard
        width: parent.width
        implicitHeight: cardRow.implicitHeight + Theme.spacingM + Theme.spacingS
        radius: 10
        clip:   true

        color: root.isSelected
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
            : (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05))

        border.color: root.isSelected
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.70)
            : (cardHover.containsMouse
                ? Qt.rgba(Qt.color(root.accentColor).r, Qt.color(root.accentColor).g, Qt.color(root.accentColor).b, 0.55)
                : Qt.rgba(1, 1, 1, 0.10))
        border.width: root.isSelected ? 2 : 1

        Behavior on color        { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.isSelected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                : Qt.rgba(Qt.color(root.accentColor).r, Qt.color(root.accentColor).g, Qt.color(root.accentColor).b,
                          cardHover.containsMouse ? 0.07 : 0.03)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        RowLayout {
            id: cardRow
            anchors {
                left:         parent.left
                right:        parent.right
                top:          parent.top
                leftMargin:   Theme.spacingM
                rightMargin:  Theme.spacingM
                topMargin:    Theme.spacingS + 2
                bottomMargin: Theme.spacingS + 2
            }
            spacing: Theme.spacingS

            // Checkbox
            Rectangle {
                width:  20; height: 20
                radius: 5
                Layout.alignment: Qt.AlignVCenter
                color: root.isSelected
                    ? Theme.primary
                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                border.color: root.isSelected
                    ? Theme.primary
                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
                border.width: root.isSelected ? 0 : 1
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    visible: root.isSelected
                    anchors.centerIn: parent
                    text: "check"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: Theme.onPrimary
                }
            }

            Rectangle {
                width:  36; height: 36
                radius: 8
                Layout.alignment: Qt.AlignVCenter
                color: Qt.rgba(
                    Qt.color(root.accentColor).r,
                    Qt.color(root.accentColor).g,
                    Qt.color(root.accentColor).b, 0.15)
                border.color: Qt.rgba(
                    Qt.color(root.accentColor).r,
                    Qt.color(root.accentColor).g,
                    Qt.color(root.accentColor).b, 0.35)
                border.width: 1

                EHIcon {
                    anchors.centerIn: parent
                    size:  20
                    color: root.accentColor
                    name:  root.sourceIcon(root.pkgSource)
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text:             root.pkgName
                        font.pixelSize:   Theme.fontSizeMedium || 16
                        font.weight:      Font.DemiBold
                        color:            Theme.surfaceText
                        elide:            Text.ElideRight
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }

                    Rectangle {
                        visible:          root.pkgInstalled
                        height:           20
                        radius:           height / 2
                        color:            Qt.rgba(0.298, 0.686, 0.314, 0.15)
                        border.color:     Qt.rgba(0.298, 0.686, 0.314, 0.40)
                        border.width:     1
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: installedLabel.implicitWidth + Theme.spacingM * 2

                        Text {
                            id:                 installedLabel
                            text:               "INSTALLED"
                            font.pixelSize:     10
                            font.weight:        Font.Bold
                            font.letterSpacing: 0.6
                            color:              "#4CAF50"
                            anchors.centerIn:   parent
                        }
                    }

                    PKGSourceBadge {
                        source:           root.pkgSource
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Text {
                    visible:        root.pkgDescription !== ""
                    text:           root.pkgDescription
                    font.pixelSize: Theme.fontSizeSmall || 12
                    color:          Theme.surfaceVariantText
                    width:          parent.width
                    elide:          Text.ElideRight
                    maximumLineCount: 1
                }

                Row {
                    spacing: Theme.spacingXS

                    Text {
                        text:           root.pkgVersion || "–"
                        font.pixelSize: Theme.fontSizeSmall || 12
                        color:          Theme.surfaceVariantText
                    }

                    Text {
                        visible: root.pkgNewVersion !== ""
                        text:    "→"
                        font.pixelSize: Theme.fontSizeSmall || 12
                        color:   Theme.surfaceVariantText
                    }

                    Text {
                        visible:        root.pkgNewVersion !== ""
                        text:           root.pkgNewVersion
                        font.pixelSize: Theme.fontSizeSmall || 12
                        color:          root.accentColor
                        font.weight:    Font.Medium
                    }
                }
            }

            }

        // Card hover effect
        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onClicked: (mouse) => mouse.accepted = false
        }
    }
}
