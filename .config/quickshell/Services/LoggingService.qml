pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell

Singleton {
    id: root

    readonly property int logDebug: 0
    readonly property int logInfo: 1
    readonly property int logWarn: 2
    readonly property int logError: 3

    property int currentLogLevel: {
        const envLevel = Quickshell.env("QUICKSHELL_LOG_LEVEL")
        if (envLevel === "DEBUG") return logDebug
        if (envLevel === "INFO") return logInfo
        if (envLevel === "WARN") return logWarn
        if (envLevel === "ERROR") return logError
        return logInfo
    }

    readonly property bool enableFileLogging: Quickshell.env("QUICKSHELL_LOG_FILE") === "1"
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string logFilePath: Quickshell.env("QUICKSHELL_LOG_FILE_PATH") || (homeDir ? homeDir + "/.cache/quickshell.log" : "")

    property var performanceMetrics: ({})
    property int logCount: 0
    property int errorCount: 0

    function log(level, category, message, context) {
        if (level < currentLogLevel) {
            return
        }

        const timestamp = new Date().toISOString()
        const levelName = ["DEBUG", "INFO", "WARN", "ERROR"][level] || "UNKNOWN"
        
        let safeContext = null
        if (context) {
            safeContext = sanitizeContext(context)
        }

        let logEntry = `[${timestamp}] [${levelName}] [${category}] ${message}`
        if (safeContext) {
            logEntry += ` | Context: ${JSON.stringify(safeContext)}`
        }

        switch (level) {
        case logDebug:
            console.debug(logEntry)
            break
        case logInfo:
            console.info(logEntry)
            break
        case logWarn:
            console.warn(logEntry)
            break
        case logError:
            console.error(logEntry)
            errorCount++
            break
        }

        logCount++

        if (enableFileLogging && logFilePath) {
            writeToFile(logEntry)
        }
    }

    function sanitizeContext(context) {
        if (!context || typeof context !== 'object') {
            return context
        }

        const sanitized = {}
        const sensitiveKeys = ['password', 'secret', 'token', 'key', 'credential', 'private', 'apiKey']
        
        for (const key in context) {
            const lowerKey = key.toLowerCase()
            const isSensitive = sensitiveKeys.some(sk => lowerKey.includes(sk))
            
            if (isSensitive) {
                sanitized[key] = "[REDACTED]"
            } else if (typeof context[key] === 'object' && context[key] !== null) {
                sanitized[key] = sanitizeContext(context[key])
            } else {
                sanitized[key] = context[key]
            }
        }
        
        return sanitized
    }

    function writeToFile(entry) {
    }

    function debug(category, message, context) {
        log(logDebug, category, message, context)
    }

    function info(category, message, context) {
        log(logInfo, category, message, context)
    }

    function warn(category, message, context) {
        log(logWarn, category, message, context)
    }

    function error(category, message, context) {
        log(logError, category, message, context)
    }

    function logPerformance(operation, duration) {
        if (!performanceMetrics[operation]) {
            performanceMetrics[operation] = {
                count: 0,
                totalDuration: 0,
                minDuration: Infinity,
                maxDuration: 0
            }
        }

        const metric = performanceMetrics[operation]
        metric.count++
        metric.totalDuration += duration
        metric.minDuration = Math.min(metric.minDuration, duration)
        metric.maxDuration = Math.max(metric.maxDuration, duration)

        if (duration > 1000) {
            warn("Performance", `Slow operation: ${operation} took ${duration}ms`, {
                operation: operation,
                duration: duration,
                avgDuration: metric.totalDuration / metric.count
            })
        }
    }

    function getPerformanceSummary() {
        const summary = {}
        for (const operation in performanceMetrics) {
            const metric = performanceMetrics[operation]
            summary[operation] = {
                count: metric.count,
                avgDuration: metric.totalDuration / metric.count,
                minDuration: metric.minDuration,
                maxDuration: metric.maxDuration
            }
        }
        return summary
    }

    function resetPerformanceMetrics() {
        performanceMetrics = {}
    }

    function getStatistics() {
        return {
            totalLogs: logCount,
            errors: errorCount,
            performanceMetrics: getPerformanceSummary()
        }
    }
}

