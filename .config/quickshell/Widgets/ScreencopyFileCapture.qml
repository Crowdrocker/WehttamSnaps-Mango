import QtQuick
import Quickshell.Wayland

Item {
    id: root

    // Source: a ShellScreen (monitor) or Toplevel (window).
    property var captureSource: null
    property bool paintCursor: true

    property bool busy: false
    property string pendingPath: ""
    property var _onDone: null

    signal completed(bool ok, string path)

    width: screencopy.hasContent ? screencopy.sourceSize.width : 1
    height: screencopy.hasContent ? screencopy.sourceSize.height : 1
    // Must stay mapped/rendering or some compositors return transparent frames.
    // Keep fully opaque; capture host is placed behind UI.
    visible: true
    opacity: 1

    function captureToFile(source, path, onDone) {
        if (busy)
            return false
        busy = true
        pendingPath = path
        _onDone = onDone || null
        root.captureSource = source
        screencopy.paintCursor = paintCursor
        screencopy.live = true
        return true
    }

    ScreencopyView {
        id: screencopy
        anchors.fill: parent
        visible: true
        live: root.busy
        paintCursor: root.paintCursor
        captureSource: root.captureSource

        onHasContentChanged: {
            if (!hasContent || !root.busy)
                return
            // Give scenegraph time to paint the texture.
            grabDelay.restart()
        }
    }

    Timer {
        id: grabDelay
        interval: 100
        repeat: false
        onTriggered: {
            if (!root.busy || !screencopy.hasContent)
                return
            screencopy.grabToImage(function (result) {
                let ok = false
                try {
                    ok = !!(result && result.saveToFile(root.pendingPath))
                } catch (e) {
                    ok = false
                }
                const p = root.pendingPath
                root.busy = false
                root.pendingPath = ""
                // Stop painting between captures to avoid "replacing" wallpaper.
                root.captureSource = null
                const cb = root._onDone
                root._onDone = null
                root.completed(ok, p)
                if (cb)
                    cb(ok, p)
            })
        }
    }
}

