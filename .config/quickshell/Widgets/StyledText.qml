import QtQuick
import qs.Common
import qs.Services

Text {
    property bool isMonospace: false
    property bool applyUiScale: true
    property real fontScale: 1.0

    readonly property real effectiveFontScale: applyUiScale ? fontScale * Appearance.combinedScale : fontScale

    readonly property string resolvedFontFamily: {
        const fallback = isMonospace ? "Monospace" : "DejaVu Sans"

        if (typeof SettingsData === "undefined") return fallback

        const requestedFont = isMonospace ? SettingsData.monoFontFamily : SettingsData.fontFamily
        const defaultFont = isMonospace ? SettingsData.defaultMonoFontFamily : SettingsData.defaultFontFamily

        if (!requestedFont) return fallback

        if (requestedFont === defaultFont) {
            const availableFonts = Qt.fontFamilies()
            if (!availableFonts.includes(requestedFont)) {
                return fallback
            }
        }
        return requestedFont
    }

    readonly property var standardAnimation: {
        "duration": Appearance.anim.durations.normal,
        "easing.type": Easing.BezierSpline,
        "easing.bezierCurve": Appearance.anim.curves.standard
    }

    color: Theme.surfaceText
    font.pixelSize: Math.max(1, Math.round(14 * effectiveFontScale))
    font.family: resolvedFontFamily
    font.weight: SettingsData.fontWeight
    font.letterSpacing: 0.0
    font.wordSpacing: 0.0
    font.capitalization: SettingsData.fontCapitalization
    // Note: font.stretch is not available in QML Text, kept in SettingsData for future use
    font.italic: SettingsData.fontItalic
    font.underline: SettingsData.fontUnderline
    font.strikeout: SettingsData.fontStrikeout
    font.hintingPreference: SettingsData.fontHintingPreference
    lineHeight: SettingsData.fontLineHeight
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: SettingsData.fontRenderType
    antialiasing: SettingsData.fontAntialiasing

    Behavior on color {
        ColorAnimation {
            duration: standardAnimation.duration
            easing.type: standardAnimation["easing.type"]
            easing.bezierCurve: standardAnimation["easing.bezierCurve"]
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: standardAnimation.duration
            easing.type: standardAnimation["easing.type"]
            easing.bezierCurve: standardAnimation["easing.bezierCurve"]
        }
    }
}
