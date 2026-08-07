import Quickshell
import Quickshell.Io
import qs.Common
pragma Singleton

Singleton {
    id: root

    function clearImageCache() {
        const cachePath = Paths.stringify(Paths.imagecache)
        Quickshell.execDetached(["rm", "-rf", cachePath])
        Paths.mkdir(Paths.imagecache)
    }

    function clearOldCache(ageInMinutes) {
        const cachePath = Paths.stringify(Paths.imagecache)
        Quickshell.execDetached(["find", cachePath, "-name", "*.png", "-mmin", `+${ageInMinutes}`, "-delete"])
    }

    function clearCacheForSize(size) {
        const cachePath = Paths.stringify(Paths.imagecache)
        const pattern = `*@${size}x${size}.png`
        Quickshell.execDetached(["find", cachePath, "-name", pattern, "-delete"])
    }

    function getCacheSize(callback) {
        if (typeof callback !== 'function') {
            if (typeof LoggingService !== 'undefined') {
                LoggingService.warn("CacheUtils", "getCacheSize called without valid callback")
            }
            return
        }

        const cachePath = Paths.stringify(Paths.imagecache)
        if (!cachePath || cachePath.length === 0) {
            callback(0)
            return
        }

        const escapedPath = cachePath.replace(/"/g, '\\"')
        const processCode = `
            import Quickshell.Io
            import QtQuick
            Process {
                id: cacheSizeProcess
                property var callback: null
                command: ["du", "-sm", "${escapedPath}"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const parts = text.split("\\t")
                            const sizeMB = parseInt(parts[0]) || 0
                            if (cacheSizeProcess.callback) {
                                cacheSizeProcess.callback(sizeMB)
                            }
                        } catch (e) {
                            if (typeof LoggingService !== 'undefined') {
                                LoggingService.error("CacheUtils", "Failed to parse cache size", { error: e.message })
                            }
                            if (cacheSizeProcess.callback) {
                                cacheSizeProcess.callback(0)
                            }
                        }
                        Qt.callLater(() => {
                            if (cacheSizeProcess) {
                                cacheSizeProcess.running = false
                                cacheSizeProcess.destroy()
                            }
                        })
                    }
                }
                onExited: exitCode => {
                    if (exitCode !== 0) {
                        if (typeof LoggingService !== 'undefined') {
                            LoggingService.warn("CacheUtils", "du command failed", { exitCode: exitCode })
                        }
                        if (cacheSizeProcess.callback) {
                            cacheSizeProcess.callback(0)
                        }
                    }
                    Qt.callLater(() => {
                        if (cacheSizeProcess && cacheSizeProcess.running) {
                            cacheSizeProcess.running = false
                        }
                    })
                }
            }
        `
        try {
            const process = Qt.createQmlObject(processCode, root, "CacheUtils.CacheSizeProcess")
            if (process) {
                process.callback = callback
            } else {
                if (typeof LoggingService !== 'undefined') {
                    LoggingService.error("CacheUtils", "Failed to create cache size process")
                }
                callback(0)
            }
        } catch (e) {
            if (typeof LoggingService !== 'undefined') {
                LoggingService.error("CacheUtils", "Failed to create cache size process", { error: e.message })
            }
            callback(0)
        }
    }
}
