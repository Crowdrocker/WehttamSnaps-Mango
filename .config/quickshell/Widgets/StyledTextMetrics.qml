import QtQuick
import qs.Common
import qs.Services

TextMetrics {
    property bool isMonospace: false

    readonly property string resolvedFontFamily: {
        const mono = isMonospace
        const fallback = mono ? "Monospace" : "DejaVu Sans"

        if (typeof SettingsData === "undefined") return fallback

        const requested = mono ? SettingsData.monoFontFamily : SettingsData.fontFamily
        const defaultFont = mono ? SettingsData.defaultMonoFontFamily : SettingsData.defaultFontFamily

        if (!requested) return fallback

        if (requested === defaultFont) {
            const fonts = Qt.fontFamilies()
            if (!fonts.includes(requested)) {
                return fallback
            }
        }
        return requested
    }

    font.pixelSize: Appearance.fontSize.normal
    font.family: resolvedFontFamily
    font.weight: SettingsData.fontWeight
}