import QtQuick
import qs.Common
import qs.Widgets

// ─────────────────────────────────────────────────────────────────────────────
//  PKGSourceBadge  —  colour-coded source pill
//  source: "pacman" | "aur" | "apt" | "dnf" | "flatpak"
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property string source: ""

    implicitWidth:  badgeText.implicitWidth + Theme.spacingM * 2
    implicitHeight: badgeText.implicitHeight + 6

    // ── Color map ─────────────────────────────────────────────────────────────
    function sourceColor(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"   // blue
            case "aur":     return "#a9e34b"   // green
            case "apt":     return "#FF9F43"   // orange
            case "dnf":     return "#EF5350"   // red
            case "flatpak": return "#9775fa"   // purple
            default:        return Theme.surfaceVariantText
        }
    }

    function sourceLabel(s) {
        switch (s) {
            case "pacman":  return "PACMAN"
            case "aur":     return "AUR"
            case "apt":     return "APT"
            case "dnf":     return "DNF"
            case "flatpak": return "FLATPAK"
            default:        return s.toUpperCase()
        }
    }

    readonly property string sColor: sourceColor(source)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  Qt.rgba(Qt.color(root.sColor).r, Qt.color(root.sColor).g, Qt.color(root.sColor).b, 0.14)
        border.color: Qt.rgba(Qt.color(root.sColor).r, Qt.color(root.sColor).g, Qt.color(root.sColor).b, 0.40)
        border.width: 1
    }

    StyledText {
        id: badgeText
        anchors.centerIn: parent
        text:            root.sourceLabel(root.source)
        font.pixelSize:  Theme.fontSizeXS
        font.weight:     Font.Bold
        font.letterSpacing: 0.6
        color:           root.sColor
    }
}
