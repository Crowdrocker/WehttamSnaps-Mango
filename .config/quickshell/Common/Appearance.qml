pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    readonly property Rounding rounding: Rounding {}
    readonly property Spacing spacing: Spacing {}
    readonly property FontSize fontSize: FontSize {}
    readonly property Anim anim: Anim {}
    
    // UI Scale Ratio - user-adjustable scaling factor
    readonly property real uiScaleRatio: (SettingsData.uiScaleRatio > 0 ? SettingsData.uiScaleRatio : 1.0)
    
    // Auto scale based on resolution - disabled for now, use manual slider
    readonly property real autoScaleRatio: 1.0
    
    // Combined scale: user scale * auto scale
    readonly property real combinedScale: uiScaleRatio * autoScaleRatio
    
    // Use combinedScale for all derived scaling
    readonly property real fontSizeSmall: Math.round(12 * combinedScale)
    readonly property real fontSizeNormal: Math.round(14 * combinedScale)
    readonly property real fontSizeLarge: Math.round(16 * combinedScale)
    readonly property real fontSizeExtraLarge: Math.round(20 * combinedScale)
    readonly property real fontSizeHuge: Math.round(24 * combinedScale)
    
    // Scale factor for radius (separate from UI scale for more control)
    readonly property real radiusRatio: (SettingsData.radiusRatio > 0 ? SettingsData.radiusRatio : 1.0)
    
    // Scale factor for interactive elements
    readonly property real iRadiusRatio: (SettingsData.iRadiusRatio > 0 ? SettingsData.iRadiusRatio : 1.0)

    component Rounding: QtObject {
        readonly property int small: 8
        readonly property int normal: 12
        readonly property int large: 16
        readonly property int extraLarge: 24
        readonly property int full: 1000
    }

    component Spacing: QtObject {
        readonly property int small: 4
        readonly property int normal: 8
        readonly property int large: 12
        readonly property int extraLarge: 16
        readonly property int huge: 24
    }

    component FontSize: QtObject {
        readonly property int small: 12
        readonly property int normal: 14
        readonly property int large: 16
        readonly property int extraLarge: 20
        readonly property int huge: 24
    }

    component AnimCurves: QtObject {
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property list<real> emphasized: [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    }

    component AnimDurations: QtObject {
        readonly property int quick: 150
        readonly property int normal: 300
        readonly property int slow: 500
        readonly property int extraSlow: 1000
        readonly property int expressiveFastSpatial: 350
        readonly property int expressiveDefaultSpatial: 500
        readonly property int expressiveEffects: 200
    }

    component Anim: QtObject {
        readonly property AnimCurves curves: AnimCurves {}
        readonly property AnimDurations durations: AnimDurations {}
    }
    
    // Scaled spacing properties
    readonly property int spacingXXXS: Math.round(1 * combinedScale)
    readonly property int spacingXXS: Math.round(2 * combinedScale)
    readonly property int spacingXS: Math.round(4 * combinedScale)
    readonly property int spacingS: Math.round(6 * combinedScale)
    readonly property int spacingM: Math.round(9 * combinedScale)
    readonly property int spacingL: Math.round(13 * combinedScale)
    readonly property int spacingXL: Math.round(18 * combinedScale)
    
    // Scaled border properties
    readonly property int borderS: Math.max(1, Math.round(1 * combinedScale))
    readonly property int borderM: Math.max(1, Math.round(2 * combinedScale))
    readonly property int borderL: Math.max(1, Math.round(3 * combinedScale))
    
    // Scaled rounding properties
    readonly property int roundingSmall: Math.round(8 * radiusRatio * combinedScale)
    readonly property int roundingNormal: Math.round(12 * radiusRatio * combinedScale)
    readonly property int roundingLarge: Math.round(16 * radiusRatio * combinedScale)
    readonly property int roundingExtraLarge: Math.round(24 * radiusRatio * combinedScale)
    
    // Scaled input rounding
    readonly property int iRoundingSmall: Math.round(3 * iRadiusRatio * combinedScale)
    readonly property int iRoundingNormal: Math.round(8 * iRadiusRatio * combinedScale)
    readonly property int iRoundingLarge: Math.round(12 * iRadiusRatio * combinedScale)
    
    // Pixel-perfect utility functions
    function toOdd(n) {
        return Math.floor(n / 2) * 2 + 1
    }
    
    function toEven(n) {
        return Math.floor(n / 2) * 2
    }
    
    function pixelAlignCenter(containerSize, contentSize) {
        return Math.round((containerSize - contentSize) / 2)
    }
    
    // Scale a value by uiScaleRatio
    function scaled(value) {
        return Math.round(value * uiScaleRatio)
    }
    
    // Scale a value ensuring minimum of 1
    function scaledMin1(value) {
        return Math.max(1, Math.round(value * uiScaleRatio))
    }
    
    // Scale a value to odd pixel (for radius, dimensions that need to be odd)
    function scaledOdd(value) {
        return toOdd(Math.round(value * uiScaleRatio))
    }
}
