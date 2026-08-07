import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: win

    WlrLayershell.namespace: "quickshell:dock:blur"

    function resolveArtUrl(url) {
        if (!url) {
            return "";
        }
        let path = url;
        if (url.startsWith("file://")) {
            path = url.substring(7); // Remove "file://" prefix
        }

        // Handle Cider/Chromium cache files which might be missing a .png extension.
        // These can appear in /var/tmp/ or inside the flatpak's cache directory.
        if (path.includes(".org.chromium.Chromium")) {
            // If the path is in /var/tmp/, it might be a Flatpak sandboxed path.
            // We need to remap it to the host path: ~/.var/app/sh.cider.Cider/cache/tmp/
            if (path.startsWith("/var/tmp/")) {
                const filename = path.substring(path.lastIndexOf("/") + 1);
                const home = Quickshell.env("HOME");
                const flatpakPath = home + "/.var/app/sh.cider.Cider/cache/tmp/" + filename;
                return flatpakPath;
            }
            return path;
        }

        // For HTTP/HTTPS or local files, return the path
        // QML Image components handle missing files gracefully
        if (path.startsWith("http") || path.startsWith("/")) {
            return path;
        }

        return ""; // Return empty if no valid path is found
    }

    required property var notificationData
    required property string notificationId
    readonly property bool hasValidData: notificationData && notificationData.notification
    property int screenY: 0
    property bool exiting: false
    property bool _isDestroying: false
    property bool _finalized: false
    readonly property string clearText: I18n.tr("Dismiss")

    signal entered
    signal exitFinished

    function startExit() {
        if (exiting || _isDestroying) {
            return
        }
        exiting = true
        exitAnim.restart()
        exitWatchdog.restart()
        if (NotificationService.removeFromVisibleNotifications)
            NotificationService.removeFromVisibleNotifications(win.notificationData)
    }

    function forceExit() {
        if (_isDestroying) {
            return
        }
        _isDestroying = true
        exiting = true
        visible = false
        exitWatchdog.stop()
        finalizeExit("forced")
    }

    function finalizeExit(reason) {
        if (_finalized) {
            return
        }

        _finalized = true
        _isDestroying = true
        exitWatchdog.stop()
        wrapperConn.enabled = false
        wrapperConn.target = null
        win.exitFinished()
    }

    visible: hasValidData
    WlrLayershell.layer: {
        if (!notificationData)
            return WlrLayershell.Top

        SettingsData.notificationOverlayEnabled

        const shouldUseOverlay = (SettingsData.notificationOverlayEnabled) || (notificationData.urgency === NotificationUrgency.Critical)

        return shouldUseOverlay ? WlrLayershell.Overlay : WlrLayershell.Top
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // Window is a full-screen surface; inner content is sized/positioned.
    // Do NOT force width/height; anchors + screen decide the surface geometry.
    implicitWidth: 1
    property real contentHeight: {
        if (!notificationContent) {
            return 110
        }
        const pad = (notificationContent.anchors ? (notificationContent.anchors.topMargin + notificationContent.anchors.bottomMargin) : 22)
        return notificationContent.implicitHeight + pad
    }
    implicitHeight: {
        const maxH = SettingsData.notificationPopupMaxHeight ?? 260
        const desired = contentHeight + 8
        return Math.min(desired, maxH)
    }
    // height is controlled by anchors
    onScreenYChanged: margins.top = (SettingsData.topBarHeight * SettingsData.topbarScale) - 4 + SettingsData.topBarSpacing + 4 + screenY
    onHasValidDataChanged: {
        if (!hasValidData && !exiting && !_isDestroying) {
            forceExit()
        }
    }
    Component.onCompleted: {
        if (hasValidData) {
            Qt.callLater(() => enterX.restart())
        } else {
            forceExit()
        }
    }
    onNotificationDataChanged: {
        if (!_isDestroying) {
            wrapperConn.target = win.notificationData || null
            notificationConn.target = (win.notificationData && win.notificationData.notification && win.notificationData.notification.Retainable) || null
        }
    }
    onEntered: {
        if (!_isDestroying) {
            enterDelay.start()
        }
    }
    Component.onDestruction: {
        _isDestroying = true
        exitWatchdog.stop()
        if (notificationData && notificationData.timer) {
            notificationData.timer.stop()
        }
    }


    // Make the PanelWindow a full-screen surface, and position the
    // visible card inside it. This avoids relying on live window resize support.
    anchors { top: true; bottom: true; left: true; right: true }
    // Limit input region to visible content so popups don't block desktop clicks.
    mask: Region { item: content }

    Item {
        id: content

        // Position the content card on the right, stacked by screenY.
        readonly property real s: Appearance.combinedScale || 1
        readonly property real topBase: (SettingsData.topBarHeight * SettingsData.topbarScale) - 4
                                      + SettingsData.topBarSpacing + 4
        readonly property real rightMargin: 12 * s
        readonly property real popupWidth: {
            const scrW = win.screen ? win.screen.width : win.width
            const desired = SettingsData.notificationPopupWidth || 400
            const maxW = Math.max(240, Math.min(500, scrW - 48))
            const minW = Math.min(maxW, 380)
            return Math.max(minW, Math.min(maxW, desired))
        }
        readonly property real popupHeight: {
            const desired = win.contentHeight + 8
            const scrH = win.screen ? win.screen.height : win.height
            const cap = Math.min(SettingsData.notificationPopupMaxHeight ?? 260, scrH * 0.8)
            return Math.max(80, Math.min(desired, cap))
        }

        x: Math.max(0, win.width - popupWidth - rightMargin)
        y: topBase + screenY
        width: popupWidth
        height: popupHeight
        visible: win.hasValidData
        layer.enabled: (enterX.running || exitAnim.running)
        layer.smooth: true

        Rectangle {
            id: card
            anchors.fill: parent
            radius: SettingsData.notificationPopupRadius ?? 16
            clip: true
            color: Theme.popupBackground()

            // ── Glow border — luminous edge, stronger on critical ─────────────
            border.color: notificationData && notificationData.urgency === NotificationUrgency.Critical
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, SettingsData.notificationPopupBorderCriticalOpacity ?? 0.70)
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, SettingsData.notificationPopupBorderOpacity ?? 0.22)
            border.width: 1

            // ── Outer glow halo ───────────────────────────────────────────────
            Rectangle {
                anchors { fill: parent; margins: -2 }
                radius: parent.radius + 2
                color: "transparent"
                border.width: 1
                border.color: notificationData && notificationData.urgency === NotificationUrgency.Critical
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                z: -1
            }
            Rectangle {
                anchors { fill: parent; margins: -4 }
                radius: parent.radius + 4
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.04)
                z: -2
            }

            // ── Drop shadow ───────────────────────────────────────────────────
            Rectangle {
                anchors { fill: parent; topMargin: 5; leftMargin: 2; rightMargin: -2; bottomMargin: -5 }
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.28)
                z: -3
            }

            // ── Top sheen — glass highlight across the upper third ────────────
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.height * 0.45
                radius: parent.radius
                // Only rounds top corners, bottom will be clipped
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.055) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.018) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0)   }
                }
                z: 10  // above content but below close button
            }

            // ── Inner top border highlight (1px bright line at very top) ──────
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin:  1; anchors.rightMargin: 1; anchors.topMargin: 1
                height: 1
                color: Qt.rgba(1, 1, 1, 0.18)
                radius: parent.radius
                z: 11
            }

            // ── Critical accent — glowing left stripe ─────────────────────────
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 3
                color: Theme.primary
                visible: notificationData && notificationData.urgency === NotificationUrgency.Critical
                z: 12
            }
            // Glow bleed from critical stripe
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 12
                visible: notificationData && notificationData.urgency === NotificationUrgency.Critical
                z: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) }
                    GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.0) }
                }
            }

            // ── Album art — left flush, full card height ──────────────────────
            readonly property bool hasArt: {
                if (!notificationData || !notificationData.image) return false
                return (notificationData.cleanImage || notificationData.image || "") !== ""
            }
            readonly property string artSrc: hasArt
                ? (win.resolveArtUrl(notificationData.cleanImage) || notificationData.cleanImage || "")
                : ""
            readonly property string artUrl: {
                if (!hasArt) return ""
                const src = artSrc
                const key = win.notificationId
                if (!src) return ""
                if (src.startsWith("http:") || src.startsWith("https:"))
                    return src + "?" + key
                return "file://" + src + "?" + key
            }

            Item {
                id: artPanel
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width: card.hasArt ? 76 : 0
                visible: card.hasArt
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: card.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }

                // Fade right edge into card background
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 28
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(
                            Theme.popupBackground().r * 0.85,
                            Theme.popupBackground().g * 0.88,
                            Theme.popupBackground().b * 0.95, 0.88) }
                    }
                }
            }

            // ── Main content (right of art or full width) ─────────────────────
            Item {
                id: notificationContent
                anchors {
                    left:   artPanel.right
                    right:  parent.right
                    top:    parent.top
                    bottom: parent.bottom
                    leftMargin:  card.hasArt ? 10 : 14
                    rightMargin: 36   // room for X button
                    topMargin:   12
                    bottomMargin: 10
                }

                // Bind the real implicitHeight so the popup window sizes correctly.
                implicitHeight: {
                    const textH = appRow.height + 4 + summaryText.implicitHeight
                        + (bodyText.visible ? 3 + bodyText.implicitHeight : 0)
                    const btnsH = actionsRow.visible ? 6 + actionsRow.height : 0
                    return textH + btnsH + 4
                }

                // ── App icon + app name · time ────────────────────────────────
                Row {
                    id: appRow
                    spacing: 6
                    anchors.top:  parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    // Small app icon badge
                    Item {
                        width:  20; height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIconImg
                            anchors.fill: parent
                            source: {
                                if (!notificationData?.appIcon) return ""
                                const i = notificationData.appIcon
                                if (i.startsWith("file://") || i.startsWith("http://") || i.startsWith("https://"))
                                    return i
                                return Quickshell.iconPath(i, true)
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // Fallback initial when no icon
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            visible: !appIconImg.visible

                            StyledText {
                                anchors.centerIn: parent
                                text: (notificationData?.appName || "?").charAt(0).toUpperCase()
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20 - parent.spacing
                        text: {
                            if (!notificationData) return ""
                            const app  = notificationData.appName || ""
                            const time = notificationData.timeStr  || ""
                            return time.length > 0 ? app + "  ·  " + time : app
                        }
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Separator line
                Rectangle {
                    anchors.top: appRow.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
                }

                // ── Summary (title) ───────────────────────────────────────────
                StyledText {
                    id: summaryText
                    anchors.top: appRow.bottom
                    anchors.topMargin: 9
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: notificationData?.summary ?? ""
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    // SemiBold isn't available on some Qt builds; use numeric weight.
                    font.weight: 600
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                }

                // ── Body ──────────────────────────────────────────────────────
                StyledText {
                    id: bodyText
                    anchors.top: summaryText.bottom
                    anchors.topMargin: 3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: notificationData?.htmlBody ?? ""
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                    linkColor: Theme.primary
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                // ── Action buttons ────────────────────────────────────────────
                Row {
                    id: actionsRow
                    anchors.bottom: parent.bottom
                    anchors.right:  parent.right
                    spacing: 5
                    visible: (notificationData?.actions?.length ?? 0) > 0
                    z: 20

                    Repeater {
                        model: notificationData?.actions ?? []

                        Rectangle {
                            property bool hov: ma.containsMouse
                            height: 22
                            width: Math.max(lbl.implicitWidth + 14, 48)
                            radius: height / 2
                            color: hov
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            StyledText {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData.text || "View"
                                color: parent.hov ? Theme.primary : Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData?.invoke) modelData.invoke()
                                    if (notificationData && !win.exiting) notificationData.popup = false
                                }
                            }
                        }
                    }
                }

                // Dismiss pill — only shown when no app actions (otherwise actions handle it)
                Rectangle {
                    id: dismissPill
                    anchors.bottom: parent.bottom
                    anchors.right:  parent.right
                    visible: (notificationData?.actions?.length ?? 0) === 0
                    property bool hov: dismissMa.containsMouse
                    height: 22
                    width: Math.max(dismissLbl.implicitWidth + 14, 62)
                    radius: height / 2
                    color: hov
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    z: 20

                    StyledText {
                        id: dismissLbl
                        anchors.centerIn: parent
                        text: win.clearText
                        color: dismissPill.hov ? Theme.primary : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: dismissMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (notificationData && !win.exiting)
                                NotificationService.dismissNotification(notificationData)
                        }
                    }
                }
            }

            // ── Close ✕ button ────────────────────────────────────────────────
            EHActionButton {
                anchors.right: parent.right
                anchors.top:   parent.top
                anchors.topMargin:   8
                anchors.rightMargin: 8
                iconName:   "close"
                iconSize:   14
                buttonSize: 22
                z: 15
                onClicked: {
                    if (notificationData && !win.exiting)
                        notificationData.popup = false
                }
            }

            // ── Pause timer on hover ──────────────────────────────────────────
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                z: -1
                onEntered: {
                    if (notificationData?.timer) notificationData.timer.stop()
                }
                onExited: {
                    if (notificationData?.popup && notificationData?.timer)
                        notificationData.timer.restart()
                }
                onClicked: {
                    if (notificationData && !win.exiting)
                        notificationData.popup = false
                }
            }
        }

        transform: Translate {
            id: tx
            x: Anims.slidePx
        }
    }

    NumberAnimation {
        id: enterX

        target: tx
        property: "x"
        from: Anims.slidePx
        to: 0
        duration: Anims.durMed
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
        onStopped: {
            if (!win.exiting && !win._isDestroying && Math.abs(tx.x) < 0.5) {
                win.entered()
            }
        }
    }

    ParallelAnimation {
        id: exitAnim

        onStopped: finalizeExit("animStopped")

        PropertyAnimation {
            target: tx
            property: "x"
            from: 0
            to: Anims.slidePx
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: content
            property: "opacity"
            from: 1
            to: 0
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.standardAccel
        }

        NumberAnimation {
            target: content
            property: "scale"
            from: 1
            to: 0.98
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }
    }

    Connections {
        id: wrapperConn

        function onPopupChanged() {
            if (!win.notificationData || win._isDestroying)
                return

            if (!win.notificationData.popup && !win.exiting)
                startExit()
        }

        target: win.notificationData || null
        ignoreUnknownSignals: true
        enabled: !win._isDestroying
    }

    Connections {
        id: notificationConn

        function onDropped() {
            if (!win._isDestroying && !win.exiting)
                forceExit()
        }

        target: (win.notificationData && win.notificationData.notification && win.notificationData.notification.Retainable) || null
        ignoreUnknownSignals: true
        enabled: !win._isDestroying
    }

    Timer {
        id: enterDelay

        interval: 160
        repeat: false
        onTriggered: {
            if (notificationData && notificationData.timer && !exiting && !_isDestroying)
                notificationData.timer.start()
        }
    }

    Timer {
        id: exitWatchdog

        interval: 600
        repeat: false
        onTriggered: finalizeExit("watchdog")
    }

    Behavior on screenY {
        id: screenYAnim

        enabled: !exiting && !_isDestroying

        NumberAnimation {
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.standardDecel
        }
    }
}
