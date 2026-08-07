.pragma library

function calculateAspectRatio(width, height) {
    if (typeof width !== 'number' || typeof height !== 'number' || width <= 0 || height <= 0) {
        return 0
    }
    return width / height
}

function classifyMonitorType(width, height, transform) {
    if (typeof width !== 'number' || typeof height !== 'number' || width <= 0 || height <= 0) {
        return {
            aspectRatio: 0,
            category: "unknown",
            orientation: "unknown",
            isUltrawide: false,
            isPortrait: false
        }
    }

    var effectiveWidth = width
    var effectiveHeight = height
    if (transform === 1 || transform === 3) {
        effectiveWidth = height
        effectiveHeight = width
    }

    var aspectRatio = calculateAspectRatio(effectiveWidth, effectiveHeight)
    var isPortrait = effectiveHeight > effectiveWidth
    var isUltrawide = aspectRatio >= 2.0

    var category = "standard"
    if (isPortrait) {
        category = "portrait"
    } else if (aspectRatio >= 3.0) {
        category = "super-ultrawide"
    } else if (aspectRatio >= 2.0) {
        category = "ultrawide"
    } else if (aspectRatio >= 1.7) {
        category = "wide"
    } else if (aspectRatio >= 1.5) {
        category = "standard"
    } else if (aspectRatio >= 1.3) {
        category = "classic"
    } else {
        category = "square"
    }

    var orientation = isPortrait ? "portrait" : "landscape"

    return {
        aspectRatio: aspectRatio,
        category: category,
        orientation: orientation,
        isUltrawide: isUltrawide,
        isPortrait: isPortrait,
        effectiveWidth: effectiveWidth,
        effectiveHeight: effectiveHeight
    }
}

function calculateOptimalReservedZone(monitorInfo, componentType) {
    if (!monitorInfo || typeof monitorInfo.width !== 'number' || typeof monitorInfo.height !== 'number') {
        return 0
    }

    var classification = classifyMonitorType(
        monitorInfo.width,
        monitorInfo.height,
        monitorInfo.transform || 0
    )

    var baseSizes = {
        "dock": 65,
        "topBar": 40,
        "default": 50
    }

    var baseSize = baseSizes[componentType] || baseSizes["default"]

    if (classification.isUltrawide) {
        return Math.round(baseSize * 1.2)
    }

    if (classification.isPortrait) {
        return Math.round(baseSize * 0.8)
    }

    return baseSize
}

function shouldUseCompactMode(monitorInfo) {
    if (!monitorInfo || typeof monitorInfo.width !== 'number' || typeof monitorInfo.height !== 'number') {
        return false
    }

    var classification = classifyMonitorType(
        monitorInfo.width,
        monitorInfo.height,
        monitorInfo.transform || 0
    )

    return classification.isPortrait || (monitorInfo.width < 1366 && monitorInfo.height < 768)
}

function getLayoutRecommendations(monitorInfo) {
    if (!monitorInfo || typeof monitorInfo.width !== 'number' || typeof monitorInfo.height !== 'number') {
        return {
            useCompactMode: false,
            reservedZone: 50,
            spacing: "medium",
            widgetSize: "standard"
        }
    }

    var classification = classifyMonitorType(
        monitorInfo.width,
        monitorInfo.height,
        monitorInfo.transform || 0
    )

    var recommendations = {
        useCompactMode: shouldUseCompactMode(monitorInfo),
        reservedZone: calculateOptimalReservedZone(monitorInfo, "default"),
        spacing: "medium",
        widgetSize: "standard"
    }

    if (classification.isUltrawide) {
        recommendations.spacing = "large"
        recommendations.widgetSize = "large"
    } else if (classification.isPortrait) {
        recommendations.spacing = "small"
        recommendations.widgetSize = "compact"
    } else if (classification.category === "classic" || classification.category === "square") {
        recommendations.spacing = "small"
        recommendations.widgetSize = "compact"
    }

    return recommendations
}


