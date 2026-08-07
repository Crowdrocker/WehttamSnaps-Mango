pragma Singleton

import Quickshell
import QtCore

Singleton {
    id: root

    readonly property url home: StandardPaths.standardLocations(
                                    StandardPaths.HomeLocation)[0]
    readonly property url pictures: StandardPaths.standardLocations(
                                        StandardPaths.PicturesLocation)[0]

    readonly property url data: `${StandardPaths.standardLocations(
                                    StandardPaths.GenericDataLocation)[0]}/EventHorizon`
    readonly property url state: `${StandardPaths.standardLocations(
                                     StandardPaths.GenericStateLocation)[0]}/EventHorizon`
    readonly property url cache: `${StandardPaths.standardLocations(
                                     StandardPaths.GenericCacheLocation)[0]}/EventHorizon`
    readonly property url config: `${StandardPaths.standardLocations(
                                      StandardPaths.GenericConfigLocation)[0]}/EventHorizon`

    readonly property url imagecache: `${cache}/imagecache`

    function _toPathString(anyPath): string {
        // Normalize QUrl-ish strings like:
        // - file:///home/user/...
        // - file://home/user/... (rare)
        // - file:/home/user/...  (also seen)
        // into a plain filesystem path (/home/user/...).
        //
        // This prevents accidental concatenations like:
        //   /home/user/file:/home/user/.local/state/AppName
        if (anyPath === null || anyPath === undefined) {
            return ""
        }
        let s = String(anyPath)
        s = s.replace(/%20/g, " ")
        if (s.startsWith("file:")) {
            // Strip "file:" plus optional "//"
            s = s.replace(/^file:(\/\/)?/, "")
        }
        return s
    }

    function stringify(path: url): string {
        return _toPathString(path.toString())
    }

    function expandTilde(path: string): string {
        return strip(path.replace("~", stringify(root.home)))
    }

    function shortenHome(path: string): string {
        return path.replace(strip(root.home), "~")
    }

    function strip(path): string {
        // Accept either url or string.
        return _toPathString(path && path.toString ? path.toString() : path)
    }

    function mkdir(path: url): void {
        Quickshell.execDetached(["mkdir", "-p", strip(path)])
    }

    function copy(from: url, to: url): void {
        Quickshell.execDetached(["cp", strip(from), strip(to)])
    }

    function moddedAppId(appId: string): string {
        if (appId === "Spotify")
            return "spotify-launcher"
        if (appId === "beepertexts")
            return "beeper"
        if (appId === "home assistant desktop")
            return "homeassistant-desktop"
        if (appId.includes("com.transmissionbt.transmission"))
            return "transmission-gtk"
        return appId
    }
}
