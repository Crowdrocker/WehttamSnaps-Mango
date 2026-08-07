import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var    anchorItem:    null
    property var    parentScreen:  null
    property string barPosition:   "bottom"
    property bool   isVertical:    false
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.dockScale || 1)
    function spx(px) { return Math.round(px * uiScale) }
    property real   barThickness:  spx(48)
    property real   popupDistance: 0
    property bool   showPopup:     false
    property bool   shouldBeVisible: showPopup

    property real   storedTriggerX:       0
    property real   storedTriggerY:       0
    property real   storedTriggerWidth:   70
    property string storedTriggerSection: "right"
    property var    storedTriggerScreen:  null

    // ── EQ presets ────────────────────────────────────────────────────────────
    readonly property var eqPresets: ({
        "Flat":         [0,0,0,0,0,0,0,0,0,0],
        "Bass Boost":   [6,5,3,1,0,0,0,0,0,0],
        "Treble Boost": [0,0,0,0,0,1,2,3,4,5],
        "V-Shape":      [5,3,1,0,-2,-2,0,1,3,5],
        "Vocal":        [-2,0,2,4,4,4,2,0,-1,-2],
        "Classical":    [4,3,2,1,0,0,1,2,3,3]
    })

    // ── API ───────────────────────────────────────────────────────────────────
    function openForItem(anchor, screen, barPos, vertical, barThick) {
        anchorItem   = anchor
        parentScreen = screen
        barPosition  = barPos   || "bottom"
        isVertical   = vertical || false
        barThickness = barThick || spx(48)
        if (parentScreen) {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i] === parentScreen) {
                    popupWindow.screen = Quickshell.screens[i]; break
                }
            }
        }
        showPopup = true
    }

    function open()  { openForItem(null, null, "bottom", false, spx(48)) }
    function close() { showPopup = false }

    function setTriggerPosition(x, y, width, section, screen) {
        storedTriggerX = x; storedTriggerY = y
        storedTriggerWidth = width; storedTriggerSection = section
        storedTriggerScreen = screen
    }

    // ── Window ────────────────────────────────────────────────────────────────
    PanelWindow {
        id: popupWindow
        visible: root.showPopup
        WlrLayershell.namespace: "quickshell:dock:blur"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

        onVisibleChanged: { if (visible) updatePosition() }

        function updatePosition() {
            if (!root.anchorItem) {
                anchorPos = Qt.point(root.storedTriggerX, root.storedTriggerY)
                return
            }
            var sx = screen.x || 0; var sy = screen.y || 0
            var tbT = root.barThickness; var gap = root.popupDistance + 15
            var gp = root.anchorItem.mapToGlobal(0, 0)
            var tx, ty
            if      (root.barPosition === "top")    { tx = gp.x - sx + root.anchorItem.width / 2;  ty = tbT + gap }
            else if (root.barPosition === "bottom")  { tx = gp.x - sx + root.anchorItem.width / 2;  ty = screen.height - tbT - gap }
            else if (root.barPosition === "left")    { tx = tbT + gap;                                ty = gp.y - sy + root.anchorItem.height / 2 }
            else if (root.barPosition === "right")   { tx = screen.width - tbT - gap;                 ty = gp.y - sy + root.anchorItem.height / 2 }
            else                                     { tx = screen.width / 2;                         ty = screen.height / 2 }
            anchorPos = Qt.point(tx, ty)
        }

            // ── Main card ─────────────────────────────────────────────────────────
            Rectangle {
                id: card
                width:  550
                height: Math.max(550, Math.min(topHeader.height + 1 + innerColumn.implicitHeight + 8, popupWindow.screen.height - 80))
                onWidthChanged:  popupWindow.updatePosition()
                onHeightChanged: popupWindow.updatePosition()

                border.color: SettingsData.dockVolumePopupDynamicBorderColors
                            ? Theme.primary
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.dockVolumePopupBorderOpacity)
                border.width: SettingsData.dockVolumePopupBorderEnabled ? Math.max(1, SettingsData.dockVolumePopupBorderThickness) : 0

                x: {
                    const m = 12
                    if (root.barPosition === "right") return Math.max(m, popupWindow.anchorPos.x - width)
                    if (root.barPosition === "left")  return Math.min(popupWindow.screen.width - width - m, popupWindow.anchorPos.x)
                    return Math.max(m, Math.min(popupWindow.screen.width - width - m, popupWindow.anchorPos.x - width / 2))
                }
                y: {
                    const m = 12
                    if (root.barPosition === "top")    return Math.max(m, popupWindow.anchorPos.y)
                    if (root.barPosition === "bottom") return Math.min(popupWindow.screen.height - height - m, popupWindow.anchorPos.y - height)
                    return Math.max(m, Math.min(popupWindow.screen.height - height - m, popupWindow.anchorPos.y - height / 2))
                }

                radius: 14
                color:  Theme.popupBackground()
                opacity: root.showPopup ? 1 : 0
                scale:   root.showPopup ? 1 : 0.92
                clip:    true

                // ── View toggle: "output" or "input" ──────────────────────
                property string deviceView: "output"

                Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
                Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                // Layered depth shadows: outer glow + hard offset
                Rectangle {
                    anchors { fill: parent; topMargin: 8; leftMargin: 0; rightMargin: 0; bottomMargin: -8 }
                    radius: parent.radius + 2
                    color: Qt.rgba(0, 0, 0, 0.38)
                    z: -2
                }
                Rectangle {
                    anchors { fill: parent; topMargin: 3; leftMargin: 1; rightMargin: -1; bottomMargin: -3 }
                    radius: parent.radius; color: Theme.shadowMedium; z: -1
                }

                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                }

                // ── Top header row ────────────────────────────────────────────────
                RowLayout {
                    id: topHeader
                    anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20; topMargin: 4 }
                    height: 44
                    spacing: 6

                    // Output pill — clickable, highlights when active view
                    Rectangle {
                        height: 28; radius: 8
                        width: _hdrOutputRow.implicitWidth + 16
                        color: card.deviceView === "output"
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : (_outPillHov.containsMouse
                                ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.45)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25))
                        border.color: card.deviceView === "output" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : "transparent"
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            id: _hdrOutputRow
                            anchors.centerIn: parent; spacing: 5
                            EHIcon {
                                name: AudioService.getOutputIcon(); size: 13
                                color: card.deviceView === "output" ? Theme.primary : (AudioService.muted ? Theme.error : Theme.surfaceTextMedium)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            StyledText {
                                text: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No Output"
                                font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium
                                color: card.deviceView === "output" ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                        MouseArea { id: _outPillHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.deviceView = "output" }
                    }

                    Item { Layout.fillWidth: true }

                    // Input pill — moved to right side of header
                    Rectangle {
                        height: 28; radius: 8
                        width: _hdrInputRightRow.implicitWidth + 16
                        color: card.deviceView === "input"
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : (_inRightHov.containsMouse
                                ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.45)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25))
                        border.color: card.deviceView === "input" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : "transparent"
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        visible: AudioService.hasInput
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            id: _hdrInputRightRow
                            anchors.centerIn: parent; spacing: 5
                            EHIcon {
                                name: "mic"; size: 13
                                color: card.deviceView === "input" ? Theme.primary : Theme.surfaceTextMedium
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            StyledText {
                                text: AudioService.source ? AudioService.displayName(AudioService.source) : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: card.deviceView === "input" ? Theme.primary : Theme.surfaceTextMedium
                                elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }
                        MouseArea { id: _inRightHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.deviceView = "input" }
                    }
                }

                // ── Header divider ───────────────────────────────────────────────
                Rectangle {
                    id: headerDiv
                    anchors { top: topHeader.bottom; left: parent.left; right: parent.right; topMargin: 4 }
                    height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                }

                // ── Scrollable body ───────────────────────────────────────────────
                Flickable {
                    id: flickable
                    anchors { top: headerDiv.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 4; rightMargin: 4; bottomMargin: 4 }
                    height: innerColumn.implicitHeight
                    contentHeight: innerColumn.implicitHeight
                    interactive: contentHeight > height
                    flickableDirection: Flickable.VerticalFlick
                    pressDelay: 100
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    // Yield pointer grab to horizontal drags (sliders) immediately
                    DragHandler {
                        id: _flickDragHandler
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.TouchScreen
                        grabPermissions: PointerHandler.TakeOverForbidden
                    }

                    Column {
                        id: innerColumn
                        width: Math.max(flickable.width, 550)
                        spacing: 0

                    // ── DEVICE ROWS (output or input depending on view) ───────
                    Repeater {
                        model: card.deviceView === "output" ? AudioService.sinks : AudioService.sources
                        delegate: Item {
                            required property PwNode modelData
                            required property int    index

                            property PwNodeAudio nodeAudio: modelData?.audio ?? null
                            property bool isDefault: card.deviceView === "output"
                                ? AudioService.sink   === modelData
                                : AudioService.source === modelData
                            property real devVolume: nodeAudio?.volume ?? 0
                            property bool devMuted:  nodeAudio?.muted  ?? false

                            PwObjectTracker { objects: modelData ? [modelData] : [] }

                            width: flickable.width
                            // Row grows to fit wrapped text, minimum 48px
                            height: Math.max(48, devRowLayout.implicitHeight + 16)

                            // Selected / hover highlight — semi-rounded inset pill
                            Rectangle {
                                anchors { fill: parent; leftMargin: 4; rightMargin: 4; topMargin: 3; bottomMargin: 3 }
                                radius: 8
                                color: isDefault
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                    : devRowHover.containsMouse
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                        : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            // Row separator line
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.07)
                            }

                            RowLayout {
                                id: devRowLayout
                                // Strict grid: 8px left pad, 8px icon pad, 8px text gap, 16px before slider
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 0; bottomMargin: 0 }
                                spacing: 0

                                // Radio — 8px right margin built into spacing
                                Rectangle {
                                    width: 18; height: 18; radius: 9; color: "transparent"
                                    border.color: isDefault ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.45)
                                    border.width: isDefault ? 2 : 1.5
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 8
                                    Rectangle {
                                        anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Theme.primary
                                        opacity: isDefault ? 1 : 0
                                        scale:  isDefault ? 1 : 0.4
                                        Behavior on opacity { NumberAnimation { duration: 180 } }
                                        Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                    }
                                }

                                // Device icon — covers both sinks and sources
                                EHIcon {
                                    name: {
                                        const n = modelData?.name || ""
                                        const d = AudioService.displayName(modelData).toLowerCase()
                                        if (n.includes("bluez") || d.includes("airpod") || d.includes("wh-") || d.includes("headphone")) return "headphones"
                                        if (n.includes("hdmi")) return "tv"
                                        if (n.includes("usb"))  return "usb"
                                        if (card.deviceView === "input") return "mic"
                                        return "laptop_mac"
                                    }
                                    // Unified icon size for all device types
                                    size: Theme.iconSize
                                    color: isDefault ? Theme.primary : Theme.surfaceTextMedium
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 8
                                }

                                // Name — wraps onto 2 lines for long names, vertically centered
                                StyledText {
                                    Layout.preferredWidth: 160
                                    Layout.maximumWidth: 160
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 16
                                    text: AudioService.displayName(modelData)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: isDefault ? Font.DemiBold : Font.Normal
                                    color: isDefault ? Theme.surfaceText : Theme.surfaceTextMedium
                                    opacity: isDefault ? 0.87 : 0.6
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.25
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                // Mute icon — hover feedback + animated color
                                Item {
                                    width: Theme.iconSize + 8; height: Theme.iconSize + 8
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 4
                                    Rectangle {
                                        anchors.fill: parent; radius: height / 2
                                        color: _devMuteHov.containsMouse
                                            ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
                                            : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                    EHIcon {
                                        anchors.centerIn: parent
                                        name: devMuted ? "volume_off" : "volume_up"
                                        size: Theme.iconSize
                                        color: devMuted ? Theme.error : Theme.surfaceTextMedium
                                        opacity: _devMuteHov.containsMouse ? 1.0 : 0.72
                                        Behavior on opacity { NumberAnimation { duration: 100 } }
                                        Behavior on color   { ColorAnimation  { duration: 150 } }
                                    }
                                    MouseArea { id: _devMuteHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (nodeAudio) nodeAudio.muted = !devMuted } }
                                }

                                // Slider — fillWidth so it spans remaining ~60-70% of row
                                EHSlider {
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                    minimum: 0; maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                    value: Math.round(devVolume * 100); showValue: true; unit: "%"
                                    enabled: nodeAudio !== null && modelData.ready
                                    onSliderValueChanged: function(v) { if (nodeAudio && modelData.ready) nodeAudio.volume = v / 100.0 }
                                }
                            }

                            MouseArea { id: devRowHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
                                onClicked: card.deviceView === "output"
                                    ? AudioService.setAudioSink(modelData)
                                    : AudioService.setAudioSource(modelData)
                            }
                        }
                    }

                    // ── APPS section separator ────────────────────────────────
                    // Extra vertical breathing room (16px) between devices → apps
                    Item { width: flickable.width; height: 16 }

                    // Full-width divider line
                    Rectangle {
                        width: flickable.width; height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                    }

                    // Section label row — uppercase, reduced opacity, proper hierarchy
                    Item {
                        width: flickable.width; height: 32
                        StyledText {
                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                            text: "APPS"
                            font.pixelSize: (Theme.fontSizeSmall || 12) - 2
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.5
                            color: Qt.rgba(Theme.surfaceTextMedium.r, Theme.surfaceTextMedium.g, Theme.surfaceTextMedium.b, 0.6)
                        }
                    }

                    // Empty state
                    Item {
                        width: flickable.width; height: 44
                        visible: ApplicationAudioService.applicationStreams.length === 0
                        Row {
                            anchors.centerIn: parent; spacing: Theme.spacingS
                            EHIcon { name: "volume_off"; size: Theme.fontSizeMedium; color: Theme.surfaceTextMedium; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: "No applications playing audio"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceTextMedium; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    // ── APP ROWS ──────────────────────────────────────────────
                    Repeater {
                        model: ApplicationAudioService.applicationStreams

                        delegate: Column {
                            id: appDelegate
                            required property PwNode modelData
                            required property int    index

                            property PwNodeAudio nodeAudio: modelData?.audio ?? null
                            property real  appVolume: nodeAudio?.volume ?? 0
                            property bool  appMuted:  nodeAudio?.muted  ?? false

                            property bool  eqExpanded:     false
                            property bool  eqEnabled:      false
                            property string eqPreset:      "Flat"
                            property var   eqBands:        [0,0,0,0,0,0,0,0,0,0]
                            property bool  routerExpanded: false
                            property var   routedSink:     null
                            property bool  multiMode:      false
                            property var   multiSinks:     []

                            PwObjectTracker { objects: modelData ? [modelData] : [] }

                            width: flickable.width

                            // ── Main app row ──────────────────────────────────
                            Item {
                                width: flickable.width; height: 48

                                // Semi-rounded hover highlight with 2px side padding
                                Rectangle {
                                    anchors { fill: parent; leftMargin: 2; rightMargin: 2; topMargin: 3; bottomMargin: 3 }
                                    radius: 8
                                    color: appRowHover.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                RowLayout {
                                    // 2px side padding to match highlight inset
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    spacing: 0

                                    // App icon — 8px gap to name
                                    Item {
                                        width: 24; height: 24
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: 8
                                        Image { anchors.fill: parent; source: ApplicationAudioService.getApplicationIcon(modelData); sourceSize: Qt.size(48, 48); smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit; asynchronous: true }
                                        EHIcon { anchors.fill: parent; name: "apps"; size: 24; color: Theme.primary; visible: parent.children[0].status !== Image.Ready }
                                    }

                                    // App name — shrinks to text width, cap at 110px, 4px gap to mute icon
                                    StyledText {
                                        Layout.minimumWidth: 0
                                        Layout.maximumWidth: 110
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: 4
                                        text: ApplicationAudioService.getApplicationName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        opacity: 0.87
                                        elide: Text.ElideRight
                                    }

                                    // Volume icon — 4px after name, hover feedback ring + animated color
                                    Item {
                                        width: Theme.iconSize + 8; height: Theme.iconSize + 8
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.rightMargin: 4
                                        Rectangle {
                                            anchors.fill: parent; radius: height / 2
                                            color: _appMuteHov.containsMouse
                                                ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
                                                : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }
                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: appMuted ? "volume_off" : "volume_up"
                                            size: Theme.iconSize
                                            color: appMuted ? Theme.error : Theme.surfaceTextMedium
                                            opacity: _appMuteHov.containsMouse ? 1.0 : 0.72
                                            Behavior on opacity { NumberAnimation { duration: 100 } }
                                            Behavior on color   { ColorAnimation  { duration: 150 } }
                                        }
                                        MouseArea { id: _appMuteHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: nodeAudio !== null && modelData.ready; onClicked: nodeAudio.muted = !appMuted }
                                    }

                                    // Volume slider — capped width to give device pill room
                                    EHSlider {
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 160
                                        Layout.alignment: Qt.AlignVCenter
                                        minimum: 0; maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value: Math.round(appVolume * 100); showValue: true; unit: "%"
                                        enabled: nodeAudio !== null && modelData.ready
                                        onSliderValueChanged: function(v) { if (nodeAudio && modelData.ready) nodeAudio.volume = v / 100.0 }
                                    }

                                    // Device picker button — shows actual default sink name
                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter; height: 26
                                        Layout.minimumWidth: 80; Layout.maximumWidth: 160
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 2; Layout.rightMargin: 2
                                        radius: 6
                                        color: _dpArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.6) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2); border.width: 1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            spacing: 4
                                            EHIcon {
                                                name: {
                                                    if (appDelegate.multiMode && appDelegate.multiSinks.length > 1) return "speaker_group"
                                                    if (appDelegate.routedSink) { const n = appDelegate.routedSink?.name || ""; if (n.includes("bluez")) return "headphones"; return "speaker" }
                                                    const sn = AudioService.sink?.name || ""
                                                    if (sn.includes("bluez")) return "headphones"
                                                    if (sn.includes("hdmi"))  return "tv"
                                                    if (sn.includes("usb"))   return "usb"
                                                    return "speaker"
                                                }
                                                size: 14; color: Theme.surfaceText; Layout.alignment: Qt.AlignVCenter
                                            }
                                            StyledText {
                                                text: {
                                                    if (appDelegate.multiMode && appDelegate.multiSinks.length > 1) return appDelegate.multiSinks.length + " devices"
                                                    if (appDelegate.routedSink) return AudioService.displayName(appDelegate.routedSink)
                                                    return AudioService.sink ? AudioService.displayName(AudioService.sink) : "System Default"
                                                }
                                                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText
                                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                                elide: Text.ElideRight; maximumLineCount: 1
                                            }
                                            EHIcon { name: appDelegate.routerExpanded ? "expand_less" : "expand_more"; size: 12; color: Theme.surfaceTextMedium; Layout.alignment: Qt.AlignVCenter }
                                        }
                                        MouseArea { id: _dpArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { appDelegate.routerExpanded = !appDelegate.routerExpanded; if (appDelegate.routerExpanded) appDelegate.eqExpanded = false } }
                                    }

                                    // EQ button (3 vertical bars)
                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 2; width: 30; height: 26; radius: 13
                                        color: _eqArea.containsMouse || appDelegate.eqExpanded ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.6) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.35)
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2); border.width: appDelegate.eqExpanded ? 1.5 : 1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Row { anchors.centerIn: parent; spacing: 2; Repeater { model: 3; Rectangle { width: 2; radius: 1; height: [10, 6, 8][index]; color: appDelegate.eqExpanded ? Theme.primary : Theme.surfaceTextMedium; anchors.verticalCenter: parent?.verticalCenter } } }
                                        MouseArea { id: _eqArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { appDelegate.eqExpanded = !appDelegate.eqExpanded; if (appDelegate.eqExpanded) appDelegate.routerExpanded = false } }
                                    }

                                    // X close button (only when panel open)
                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter; width: 26; height: 26; radius: 13
                                        visible: appDelegate.eqExpanded || appDelegate.routerExpanded
                                        color: _xArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15); border.width: 1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        EHIcon { anchors.centerIn: parent; name: "close"; size: 14; color: _xArea.containsMouse ? Theme.error : Theme.surfaceTextMedium }
                                        MouseArea { id: _xArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { appDelegate.eqExpanded = false; appDelegate.routerExpanded = false } }
                                    }
                                }

                                MouseArea { id: appRowHover; anchors.fill: parent; hoverEnabled: true; z: -1 }
                                Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
                                height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.09) }
                            }

                            // ── EQ panel ──────────────────────────────────────
                            Rectangle {
                                width: flickable.width
                                height: appDelegate.eqExpanded ? _eqContent.implicitHeight + Theme.spacingM * 2 : 0
                                visible: height > 0
                                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
                                clip: true
                                Behavior on height { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                                Column {
                                    id: _eqContent
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingM; rightMargin: Theme.spacingM * 2 }
                                    spacing: Theme.spacingM

                                    // EQ header
                                    RowLayout {
                                        width: parent.width; spacing: Theme.spacingS
                                        EHToggle { hideText: true; checked: appDelegate.eqEnabled; onToggled: function(checked) { appDelegate.eqEnabled = checked; ApplicationAudioService.applyEq(appDelegate.modelData, appDelegate.eqBands, checked) } }
                                        StyledText { text: "EQ"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: appDelegate.eqEnabled ? Theme.surfaceText : Theme.surfaceTextMedium; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                                        // Preset picker
                                        Rectangle {
                                            id: _presetBtn
                                            Layout.alignment: Qt.AlignVCenter; height: 30
                                            width: _presetRow.implicitWidth + 20; radius: 8
                                            color: _presetArea.containsMouse ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15); border.width: 1
                                            property bool open: false
                                            Row { id: _presetRow; anchors.centerIn: parent; spacing: 4
                                                StyledText { text: appDelegate.eqPreset; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                                                EHIcon { name: _presetBtn.open ? "expand_less" : "expand_more"; size: 12; color: Theme.surfaceTextMedium; anchors.verticalCenter: parent.verticalCenter }
                                            }
                                            MouseArea { id: _presetArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: _presetBtn.open = !_presetBtn.open }

                                            Rectangle {
                                                anchors { top: parent.bottom; topMargin: 4; right: parent.right }
                                                width: 130
                                                height: _presetBtn.open ? _presetList.implicitHeight + 8 : 0
                                                visible: height > 0; radius: 8
                                                color: Theme.surfaceContainer
                                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18); border.width: 1
                                                z: 10; clip: true
                                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                                Column {
                                                    id: _presetList
                                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
                                                    spacing: 2
                                                    Repeater {
                                                        model: Object.keys(root.eqPresets)
                                                        delegate: Rectangle {
                                                            required property string modelData
                                                            width: parent.width; height: 32; radius: 6
                                                            color: _pA.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                                                            StyledText { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                                            text: modelData; font.pixelSize: Theme.fontSizeSmall; color: appDelegate.eqPreset === modelData ? Theme.primary : Theme.surfaceText; font.weight: appDelegate.eqPreset === modelData ? Font.Medium : Font.Normal }
                                                            MouseArea { id: _pA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { appDelegate.eqPreset = modelData; appDelegate.eqBands = root.eqPresets[modelData]; _presetBtn.open = false; ApplicationAudioService.applyEq(appDelegate.modelData, root.eqPresets[modelData], appDelegate.eqEnabled) } }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 10-band vertical sliders
                                    readonly property var bandLabels: ["32\nHz","64\nHz","125\nHz","250\nHz","500\nHz","1k\nHz","2k\nHz","4k\nHz","8k\nHz","16k\nHz"]

                                    Row {
                                        width: parent.width; spacing: 0
                                        Repeater {
                                            model: 10
                                            delegate: Column {
                                                required property int index
                                                width: parent.width / 10; spacing: 4

                                                Item {
                                                    width: parent.width; height: 100
                                                    opacity: appDelegate.eqEnabled ? 1 : 0.4
                                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 3; height: parent.height; radius: 2; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3) }

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter; width: 3; radius: 2; color: Theme.primary
                                                        property real bv: appDelegate.eqBands[index] ?? 0
                                                        property real ctr: parent.height / 2
                                                        property real norm: bv / 12.0
                                                        height: Math.abs(norm) * ctr
                                                        y: norm >= 0 ? ctr - height : ctr
                                                    }

                                                    Rectangle {
                                                        id: _eqHandle
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: 14; height: 14; radius: 7
                                                        color: Theme.primary
                                                        border.color: Theme.surfaceContainer; border.width: 2
                                                        property real bv: appDelegate.eqBands[index] ?? 0
                                                        property real norm: bv / 12.0
                                                        y: (1 - (norm + 1) / 2) * (parent.height - height)
                                                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                                        // Glow ring on hover
                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: parent.width + 8; height: parent.height + 8; radius: (parent.width + 8) / 2
                                                            color: "transparent"
                                                            border.color: Theme.primary
                                                            border.width: 1.5
                                                            opacity: _eqHandleMA.containsMouse ? 0.5 : 0
                                                            Behavior on opacity { NumberAnimation { duration: 120 } }
                                                        }
                                                        MouseArea {
                                                            id: _eqHandleMA
                                                            anchors { fill: parent; margins: -6 }
                                                            cursorShape: Qt.SizeVerCursor; enabled: appDelegate.eqEnabled
                                                            property real startY: 0; property real startVal: 0
                                                            onPressed: function(mouse) { startY = mouse.y; startVal = appDelegate.eqBands[index] ?? 0 }
                                                            onPositionChanged: function(mouse) {
                                                                if (!pressed) return
                                                                var dy = mouse.y - startY
                                                                var range = _eqHandle.parent.height - _eqHandle.height
                                                                var delta = -(dy / range) * 24
                                                                var nv = Math.max(-12, Math.min(12, Math.round(startVal + delta)))
                                                                var arr = appDelegate.eqBands.slice(); arr[index] = nv; appDelegate.eqBands = arr
                                                                appDelegate.eqPreset = "Custom"
                                                                ApplicationAudioService.applyEq(appDelegate.modelData, arr, appDelegate.eqEnabled)
                                                            }
                                                        }
                                                    }
                                                }

                                                StyledText {
                                                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                                                    text: _eqContent.bandLabels[index]
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: Theme.surfaceTextMedium
                                                    opacity: 0.6
                                                    lineHeight: 1.25
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1) }
                            }

                            // ── Device router panel ───────────────────────────
                            Rectangle {
                                width: flickable.width
                                height: appDelegate.routerExpanded ? _routerContent.implicitHeight + Theme.spacingM * 2 : 0
                                visible: height > 0
                                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
                                clip: true
                                Behavior on height { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                                Column {
                                    id: _routerContent
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingM; rightMargin: Theme.spacingM * 2 }
                                    spacing: Theme.spacingXS

                                    RowLayout {
                                        width: parent.width
                                        EHButtonGroup {
                                            model: ["Single", "Multi"]; currentIndex: appDelegate.multiMode ? 1 : 0
                                            buttonHeight: 28; minButtonWidth: 56; textSize: Theme.fontSizeSmall
                                            Layout.alignment: Qt.AlignVCenter
                                            onSelectionChanged: {
                                                if (idx === 1 && sel) { appDelegate.multiMode = true }
                                                else if (idx === 0 && sel) { appDelegate.multiMode = false; appDelegate.multiSinks = [] }
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    Repeater {
                                        model: AudioService.sinks
                                        delegate: Rectangle {
                                            required property PwNode modelData; required property int index
                                            property bool isSysDefault: AudioService.sink === modelData
                                            property bool isChecked: appDelegate.multiMode ? appDelegate.multiSinks.indexOf(modelData) >= 0 : (appDelegate.routedSink === modelData || (!appDelegate.routedSink && isSysDefault))
                                            width: parent.width; height: 36; radius: 6
                                            color: _ri.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: Theme.spacingS; rightMargin: Theme.spacingS }
                                                spacing: Theme.spacingS
                                                Rectangle {
                                                    width: 16; height: 16; radius: appDelegate.multiMode ? 3 : 8
                                                    color: isChecked ? Theme.primary : "transparent"
                                                    border.color: isChecked ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.45); border.width: isChecked ? 0 : 1.5
                                                    Layout.alignment: Qt.AlignVCenter
                                                    EHIcon { anchors.centerIn: parent; name: "check"; size: 11; color: Theme.onPrimary; visible: isChecked && appDelegate.multiMode }
                                                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.onPrimary; visible: isChecked && !appDelegate.multiMode }
                                                }
                                                EHIcon {
                                                    name: { const n = modelData?.name || ""; if (n.includes("bluez")) return "headphones"; if (n.includes("hdmi")) return "tv"; return "laptop_mac" }
                                                    size: Theme.iconSize; color: isChecked ? Theme.primary : Theme.surfaceTextMedium; Layout.alignment: Qt.AlignVCenter
                                                    opacity: isChecked ? 0.87 : 0.6
                                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                                }
                                                StyledText { text: AudioService.displayName(modelData); font.pixelSize: Theme.fontSizeSmall; color: isChecked ? Theme.surfaceText : Theme.surfaceTextMedium; font.weight: isChecked ? Font.Medium : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; opacity: isChecked ? 0.87 : 0.6; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                                EHIcon { name: "star"; size: Theme.iconSize - 4; color: Qt.rgba(Theme.surfaceTextMedium.r, Theme.surfaceTextMedium.g, Theme.surfaceTextMedium.b, 0.6); visible: isSysDefault; Layout.alignment: Qt.AlignVCenter }
                                            }
                                            MouseArea {
                                                id: _ri; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appDelegate.multiMode) {
                                                        var i2 = appDelegate.multiSinks.indexOf(modelData)
                                                        var arr = appDelegate.multiSinks.slice()
                                                        if (i2 >= 0) { arr.splice(i2, 1) } else { arr.push(modelData) }
                                                        appDelegate.multiSinks = arr
                                                    } else { appDelegate.routedSink = modelData; ApplicationAudioService.routeStreamToOutput(appDelegate.modelData, modelData) }
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 1; color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1) }
                            }
                        }
                    }

                    Item { width: 1; height: Theme.spacingM }
                }
            }
        }

        MouseArea { anchors.fill: parent; z: -1; onClicked: root.close() }
    }
}
