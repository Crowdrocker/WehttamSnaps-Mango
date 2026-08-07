import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DarkModal {
    id: root

    // Fullscreen overlay on the current screen.
    width: screenWidth
    height: screenHeight
    positioning: "custom"
    customPosition: Qt.point(0, 0)
    cornerRadius: 0
    borderWidth: 0
    showBackground: false
    closeOnBackgroundClick: false
    animationType: "scale"

    property string outPath: ""
    property string backgroundPath: ""
    property bool isSaving: false
    property bool selecting: false
    property bool backgroundReady: false

    // selection in overlay coords (same as screencopy view coords)
    property real sx0: 0
    property real sy0: 0
    property real sx1: 0
    property real sy1: 0
    readonly property rect selectionRect: {
        const x = Math.min(sx0, sx1)
        const y = Math.min(sy0, sy1)
        const w = Math.max(0, Math.abs(sx1 - sx0))
        const h = Math.max(0, Math.abs(sy1 - sy0))
        return Qt.rect(x, y, w, h)
    }

    signal finished(bool ok, string path)

    function start(path, bgPath) {
        outPath = path
        backgroundPath = bgPath || ""
        isSaving = false
        selecting = false
        backgroundReady = false
        sx0 = sy0 = sx1 = sy1 = 0
        open()
    }

    function _cancel() {
        close()
        finished(false, outPath)
    }

    function _doCapture() {
        if (isSaving)
            return
        const r = selectionRect
        if (r.width < 2 || r.height < 2) {
            _cancel()
            return
        }
        isSaving = true
        cropSurface._srcRect = r
        cropSurface._beginCrop()
    }

    content: Component {
        Item {
            anchors.fill: parent
            Image {
                id: bg
                anchors.fill: parent
                source: root.backgroundPath ? ("file://" + root.backgroundPath) : ""
                // 1:1 mapping with selectionRect coordinates
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
                visible: source !== ""
                z: 0

                onStatusChanged: {
                    root.backgroundReady = (status === Image.Ready)
                }
            }

            // No dimming overlay: keep full visibility while selecting.

            // Selection outline.
            Rectangle {
                id: sel
                x: root.selectionRect.x
                y: root.selectionRect.y
                width: root.selectionRect.width
                height: root.selectionRect.height
                color: "transparent"
                border.width: 2
                border.color: Theme.primary
                radius: Math.min(Theme.cornerRadius, 12)
                visible: width > 0 && height > 0
                z: 3
            }

            // Drag handling.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                enabled: root.backgroundReady && !root.isSaving
                z: 4

                onPressed: mouse => {
                    if (!root.selecting) {
                        root.selecting = true
                        root.sx0 = mouse.x
                        root.sy0 = mouse.y
                        root.sx1 = mouse.x
                        root.sy1 = mouse.y
                        return
                    }
                    root.sx1 = Math.max(0, Math.min(width, mouse.x))
                    root.sy1 = Math.max(0, Math.min(height, mouse.y))
                    root._doCapture()
                }
                onPositionChanged: mouse => {
                    if (!root.selecting)
                        return
                    root.sx1 = Math.max(0, Math.min(width, mouse.x))
                    root.sy1 = Math.max(0, Math.min(height, mouse.y))
                }
                onReleased: _ => {}
            }

            // Instructions.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                height: 44
                radius: height / 2
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                border.width: 1
                z: 5

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    EHIcon { name: "screenshot_region"; size: 18; color: Theme.surfaceText }
                    StyledText {
                        text: root.isSaving
                            ? I18n.tr("Saving…")
                            : (!root.backgroundReady
                               ? I18n.tr("Loading…")
                               : (root.selecting ? I18n.tr("Click to confirm — Esc to cancel") : I18n.tr("Click start, move, click end — Esc to cancel")))
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                    }
                }
            }



            Keys.onEscapePressed: event => {
                event.accepted = true
                root._cancel()
            }

            Keys.onReturnPressed: event => {
                event.accepted = true
                if (root.selecting)
                    root._doCapture()
            }
        }
    }
    // Offscreen crop surface. We flatten to opaque so translucent windows look like
    // the composed screen (wallpaper included), not transparent holes.
    Rectangle {
        id: cropSurface
        visible: true
        opacity: 1
        x: -99999
        y: -99999
        color: "black"
        width: Math.max(1, Math.round(_srcRect.width))
        height: Math.max(1, Math.round(_srcRect.height))
        property rect _srcRect: Qt.rect(0, 0, 1, 1)

        Image {
            id: cropImage
            anchors.fill: parent
            cache: false
            fillMode: Image.Pad
        }

        function _beginCrop() {
            if (!root.backgroundPath || !root.backgroundPath.length)
                return
            cropSurface.width = Math.max(1, Math.round(_srcRect.width))
            cropSurface.height = Math.max(1, Math.round(_srcRect.height))
            cropImage.sourceClipRect = _srcRect
            cropImage.source = ""         // force reload if same path used twice
            cropImage.source = "file://" + root.backgroundPath
        }

        Connections {
            target: cropImage
            function onStatusChanged() {
                if (cropImage.status !== Image.Ready)
                return
                grabTimer.restart()
            }
        }

        Timer {
            id: grabTimer
            interval: 50
            repeat: false
            onTriggered: {
                cropSurface.grabToImage(function (res) {
                    const ok = !!(res && res.saveToFile(root.outPath))
                    root.isSaving = false
                    root.close()
                    root.finished(ok, root.outPath)
                })
            }
        }
    }

}

